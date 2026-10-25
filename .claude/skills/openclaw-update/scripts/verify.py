#!/usr/bin/env python3
"""Post-swap verification without model calls — read-only, fail-closed.

Usage: verify.py --receipts DIR --image TAG [--accounts 6]
  --expect-disabled-plugin ID     repeat for an explicitly paused optional provider (zai/xai)
  --expect-disabled-telegram ID   repeat for an explicitly disabled Telegram account
  --expect-disabled-heartbeat ID repeat for an agent whose heartbeat must stay disabled
These are positive policy assertions, not skip switches; missing or contradictory evidence cannot PASS.
  --receipts  swap receipt dir holding openclaw.json.pre-swap (omitted → UNKNOWN)
  --image     candidate tag that was swapped in; the running container must use its image Id (omitted → UNKNOWN)
Exit: 0 all required checks PASS · 1 any FAIL · 2 any UNKNOWN (a required measurement is missing, or a human must judge).
Config paths changed against the pre-swap snapshot are UNKNOWN and printed by path only — a human decides whether
they are Doctor bookkeeping. INFO lines (restart count, badge, memory index) never pass a failing run.
The comments ping body is compared to "pong" and never printed.
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HOME = Path(os.environ.get('OPENCLAW_HOME', Path.home() / 'openclaw'))
TOMBSTONE = [{'queueName': 'outbound', 'count': 1, 'oldestFailedAt': 1781602445810}]  # June legacy baseline
URLS = {
	'https://agenda.junghanacs.com/': 200, 'https://analytics.junghanacs.com/': 200, 'https://ax.junghanacs.com/': 200,
	'https://claw.junghanacs.com/': 302, 'https://comments.junghanacs.com/': 404, 'https://forge.junghanacs.com/': 200,
	'https://ha.junghanacs.com/': 200, 'https://map.junghanacs.com/': 302,
	'https://aionsclubs.org/': 200, 'https://oracle.tailb0e905.ts.net/': 200,
}
IMAGE_ID = re.compile(r'^sha256:[0-9a-f]{64}$')
results = []


def note(level, msg):
	results.append(level)
	print(f'  [{level}] {msg}')


def dig(o, *keys):
	for k in keys:
		o = o.get(k) if isinstance(o, dict) else None
	return o


def run(cmd, timeout=60):
	try:
		p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
		return p.returncode, p.stdout
	except (OSError, subprocess.TimeoutExpired) as e:
		return 127, str(e)


def load(text):
	try:
		return json.loads(text)
	except (json.JSONDecodeError, TypeError):
		return None


def oc_json(*a):
	rc, out = run(['docker', 'exec', 'openclaw-gateway', 'openclaw', *a, '--json'])
	if rc != 0:
		return None
	i = out.find('{') if out.lstrip()[:1] != '[' else out.find('[')
	return load(out[i:]) if i >= 0 else None


ap = argparse.ArgumentParser()
ap.add_argument('--receipts', type=Path)
ap.add_argument('--image')
ap.add_argument('--accounts', type=int, default=6, help='expected number of connected, active Telegram accounts')
ap.add_argument('--expect-disabled-plugin', action='append', default=[], choices=('zai', 'xai'),
	help='assert this optional provider is disabled in both plugin metadata and config (repeatable)')
ap.add_argument('--expect-disabled-telegram', action='append', default=[], metavar='ID',
	help='assert this Telegram account is explicitly disabled (repeatable; not a skip)')
ap.add_argument('--expect-disabled-heartbeat', action='append', default=[], metavar='ID',
	help='assert this agent heartbeat is explicitly 0m and disabled in RPC metadata (repeatable)')
args = ap.parse_args()
if args.accounts < 1:
	ap.error('--accounts must be a positive number of active Telegram accounts')
for field in ('expect_disabled_plugin', 'expect_disabled_telegram', 'expect_disabled_heartbeat'):
	values = getattr(args, field)
	if len(values) != len(set(values)) or any(not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', v) for v in values):
		ap.error(f'--{field.replace("_", "-")}: IDs must be unique non-empty identifiers')

print('== version / container / image')
rc, out = run(['docker', 'exec', 'openclaw-gateway', 'openclaw', '--version'])
m = re.match(r'^OpenClaw (\d{4}\.\d+\.\d+) \(([0-9a-f]{7,40})\)\s*$', out.strip()) if rc == 0 else None
live_ver = m.group(1) if m else None
note('PASS' if m else 'UNKNOWN', f'version: {out.strip() if m else "unreadable"}')
rc, out = run(['docker', 'inspect', 'openclaw-gateway'])
ci = load(out) if rc == 0 else None
ci = ci[0] if isinstance(ci, list) and ci and isinstance(ci[0], dict) else None
st = dig(ci, 'State')
if not isinstance(st, dict):
	note('UNKNOWN', 'docker inspect unavailable')
else:
	note('PASS' if st.get('Running') is True else 'FAIL', f"running={st.get('Running')}")
	print(f"  [INFO] restarts={ci.get('RestartCount')} badge={dig(st, 'Health', 'Status')} started={st.get('StartedAt')} (badge lags; RPC health decides)")
if not args.image:
	note('UNKNOWN', 'no --image: running image not compared with the swapped-in candidate')
else:
	rc, out = run(['docker', 'image', 'inspect', args.image, '--format', '{{.Id}}'])
	want, got = out.strip() if rc == 0 else None, dig(ci, 'Image')
	if not (want and IMAGE_ID.match(want) and isinstance(got, str) and IMAGE_ID.match(got)):
		note('UNKNOWN', f'image Id unreadable: container {got} vs {args.image} {want}')
	else:
		note('PASS' if got == want else 'FAIL', f'container image {got[7:19]} vs {args.image} {want[7:19]}')

print('== RPC health')
h = oc_json('gateway', 'call', 'health', '--timeout', '30000')
if not isinstance(h, dict):
	note('UNKNOWN', 'health RPC failed or unparsable')
else:
	note('PASS' if h.get('ok') is True else 'FAIL', f"ok={h.get('ok')}")
	acc = dig(h, 'channels', 'telegram', 'accounts')
	acc = acc if isinstance(acc, dict) else {}
	paused = set(args.expect_disabled_telegram)
	active = {aid: value for aid, value in acc.items() if aid not in paused}
	conn = sum(1 for s in active.values() if dig(s, 'connected') is True)
	errs = sum(1 for s in acc.values() if dig(s, 'lastError'))
	note('PASS' if len(active) == args.accounts and conn == args.accounts and errs == 0 else 'FAIL',
		f'telegram connected {conn}/{len(active)} active (expect {args.accounts}), '
		f'observed total {len(acc)}, lastError {errs}')
	for aid in args.expect_disabled_telegram:
		account = acc.get(aid)
		if not isinstance(account, dict):
			note('UNKNOWN', f'telegram {aid}: disabled runtime metadata missing')
			continue
		enabled, running = account.get('enabled'), account.get('running')
		# Native disabled-state projection omits connected; omission alone proves nothing.
		# Config enabled=False is separately mandatory below, and config diff is still checked.
		connected = account.get('connected')
		if enabled is True or running is True or connected is True:
			note('FAIL', f'telegram {aid}: runtime contradicts disabled policy')
		elif (type(enabled) is not bool or type(running) is not bool
			or ('connected' in account and type(connected) is not bool)):
			note('UNKNOWN', f'telegram {aid}: disabled runtime booleans missing or malformed')
		else:
			note('PASS', f'telegram {aid}: enabled=false, running=false, '
				f'connected={"false" if "connected" in account else "omitted by native disabled projection"}')
	for aid in args.expect_disabled_heartbeat:
		agents = h.get('agents')
		rows = [a for a in agents if isinstance(a, dict) and a.get('agentId') == aid] if isinstance(agents, list) else []
		if len(rows) != 1 or not isinstance(rows[0].get('heartbeat'), dict):
			note('UNKNOWN', f'heartbeat {aid}: unique RPC metadata missing')
		else:
			hb = rows[0]['heartbeat']
			matches = hb.get('enabled') is False and hb.get('every') == 'disabled' and 'everyMs' in hb and hb['everyMs'] is None
			note('PASS' if matches else 'FAIL', f'heartbeat {aid}: disabled metadata matches policy: {matches}')
	pe, pu = dig(h, 'plugins', 'errors'), dig(h, 'plugins', 'unavailable')
	note('PASS' if pe == [] and pu == [] else 'FAIL', f'plugin errors={pe} unavailable={pu}')
	el = dig(h, 'eventLoop', 'degraded')
	note('PASS' if el is False else 'FAIL', f'eventLoop degraded={el}')
	dq = dig(h, 'deliveryQueues', 'failed')
	note('PASS' if dq in ([], TOMBSTONE) else 'FAIL', f"deliveryQueues.failed={dq} ({'June tombstone baseline' if dq == TOMBSTONE else 'empty' if dq == [] else 'differs from baseline — inspect'})")

print('== plugins that must hold')
pj = oc_json('plugins', 'list')
ps = pj.get('plugins') if isinstance(pj, dict) else pj
if not isinstance(ps, list):
	note('UNKNOWN', 'plugins list unavailable')
else:
	valid = [p for p in ps if isinstance(p, dict) and isinstance(p.get('id'), str) and p['id']]
	by = {p['id']: p for p in valid}
	if len(valid) != len(ps) or len(by) != len(ps):
		note('FAIL', 'plugins list has malformed or duplicate entries')
	for p in ps:
		if isinstance(p, dict) and p.get('status') in ('error', 'unavailable'):
			note('FAIL', f'plugin {p.get("id")}: unexpected status {p.get("status")}')
	expected = dict((('codex', 'disabled'), ('telegram', 'loaded'), ('openai', 'loaded'),
		('anthropic', 'loaded'), ('zai', 'loaded'), ('memory-core', 'loaded')))
	expected.update({pid: 'disabled' for pid in args.expect_disabled_plugin})
	for pid, want in expected.items():
		got = dig(by.get(pid), 'status')
		if pid in args.expect_disabled_plugin:
			enabled = dig(by.get(pid), 'enabled')
			note('PASS' if got == want and enabled is False else 'FAIL',
				f'{pid}: status={got}, enabled={enabled} (expect disabled, false)')
		else:
			note('PASS' if got == want else 'FAIL', f'{pid}: {got} (expect {want})')

print('== hotfix integrity (constants from the patch script)')
patch = HOME / 'patch-memory-cron-parent.py'
if not patch.exists():
	note('UNKNOWN', f'{patch.name} missing — retiring the hotfix is a reviewed decision, not an absence (SKILL §1-4)')
else:
	t = patch.read_text()
	c = {k: (re.search(rf'^{k} = "([^"]+)"', t, re.M) or [None, None])[1] for k in ('VERSION', 'CORPUS_NAME', 'KEY_NAME', 'PATCHED_SHA', 'HELPER_SHA256', 'MARKER')}
	if None in c.values():
		note('UNKNOWN', f'patch constants unreadable: {[k for k, v in c.items() if v is None]}')
	else:
		note('PASS' if live_ver == c['VERSION'] else 'FAIL', f"patch VERSION {c['VERSION']} vs live {live_ver}")
		rc, out = run(['docker', 'exec', 'openclaw-gateway', 'sha256sum', f"/app/dist/{c['CORPUS_NAME']}", f"/app/dist/{c['KEY_NAME']}"])
		sums = dict((ln.split()[1].rsplit('/', 1)[-1], ln.split()[0]) for ln in out.splitlines() if len(ln.split()) == 2) if rc == 0 else {}
		if len(sums) != 2:
			note('UNKNOWN', 'dist sha256 unavailable')
		else:
			note('PASS' if sums.get(c['CORPUS_NAME']) == c['PATCHED_SHA'] else 'FAIL', f"{c['CORPUS_NAME']} sha {str(sums.get(c['CORPUS_NAME']))[:16]} vs PATCHED {c['PATCHED_SHA'][:16]}")
			note('PASS' if sums.get(c['KEY_NAME']) == c['HELPER_SHA256'] else 'FAIL', f"{c['KEY_NAME']} sha {str(sums.get(c['KEY_NAME']))[:16]} vs HELPER {c['HELPER_SHA256'][:16]}")

print('== openclaw.json (paths only, never values)')
try:
	b = load((HOME / 'config' / 'openclaw.json').read_text())
except OSError:
	b = None
if not isinstance(b, dict):
	note('UNKNOWN', 'live config unreadable')
else:
	ce = dig(b, 'plugins', 'entries', 'codex', 'enabled')
	note('PASS' if ce is False else 'FAIL', f'plugins.entries.codex.enabled={ce}')
	for pid in args.expect_disabled_plugin:
		value = dig(b, 'plugins', 'entries', pid, 'enabled')
		note('PASS' if value is False else 'FAIL', f'plugins.entries.{pid}.enabled explicitly false: {value is False}')
	for aid in args.expect_disabled_telegram:
		value = dig(b, 'channels', 'telegram', 'accounts', aid, 'enabled')
		note('PASS' if value is False else 'FAIL', f'channels.telegram.accounts.{aid}.enabled explicitly false: {value is False}')
	if args.expect_disabled_telegram:
		configured = dig(b, 'channels', 'telegram', 'accounts')
		if not isinstance(configured, dict) or any(not isinstance(v, dict) for v in configured.values()):
			note('UNKNOWN', 'configured Telegram account metadata malformed')
		elif isinstance(h, dict):
			runtime = dig(h, 'channels', 'telegram', 'accounts')
			wanted = {aid for aid, value in configured.items() if value.get('enabled') is not False}
			actual = set(runtime) - set(args.expect_disabled_telegram) if isinstance(runtime, dict) else set()
			note('PASS' if wanted == actual and len(wanted) == args.accounts else 'FAIL',
				f'active Telegram identities match config: {wanted == actual}, configured count={len(wanted)}')
	for aid in args.expect_disabled_heartbeat:
		value = dig(b, 'agents', 'entries', aid, 'heartbeat', 'every')
		note('PASS' if value == '0m' else 'FAIL', f'agents.entries.{aid}.heartbeat.every explicitly 0m: {value == "0m"}')
if not args.receipts:
	note('UNKNOWN', 'no --receipts: config not compared with the pre-swap snapshot')
else:
	pre = args.receipts.expanduser() / 'openclaw.json.pre-swap'
	try:
		a = load(pre.read_text())
	except OSError:
		a = None
	if not isinstance(a, dict) or not isinstance(b, dict):
		note('UNKNOWN', f'pre-swap snapshot missing or not a JSON object: {pre}')
	else:
		def flat(o, p=''):
			if isinstance(o, dict) and o:
				for k, v in o.items():
					yield from flat(v, f'{p}.{k}' if p else k)
			else:
				yield p, json.dumps(o, sort_keys=True)
		fa, fz = dict(flat(a)), dict(flat(b))
		ch = [k for k in sorted(set(fa) | set(fz)) if fa.get(k) != fz.get(k)]
		note('PASS' if not ch else 'UNKNOWN', f'config paths changed vs pre-swap: {len(ch)}'
			+ (f' {ch[:20]} — a human decides; Doctor bookkeeping is not auto-allowed' if ch else ''))

print('== cron (consecutive errors)')
cj = oc_json('gateway', 'call', 'cron.list', '--timeout', '30000')
jobs = dig(cj, 'jobs')
if not isinstance(jobs, list) or not jobs:
	note('UNKNOWN', 'cron.list unavailable or empty')
else:
	for j in jobs:
		e = dig(j, 'state', 'consecutiveErrors')
		if not isinstance(e, int) or isinstance(e, bool):
			note('UNKNOWN', f"{dig(j, 'name')}: state.consecutiveErrors missing")
		else:
			note('PASS' if e == 0 else 'FAIL', f"{dig(j, 'name')} enabled={dig(j, 'enabled')} consecutiveErrors={e}")

print('== memory index (information)')
for a in ('main', 'glg', 'gpt', 'mini', 'gemini', 'bbot'):
	d = oc_json('memory', 'status', '--agent', a)
	d = d[0] if isinstance(d, list) and d else d
	s = d.get('status', d) if isinstance(d, dict) else None
	sc = dig(s, 'sourceCounts')
	parts = [f"{x.get('source')}={x.get('files')}/{x.get('eligible')}" for x in sc if isinstance(x, dict)] if isinstance(sc, list) else None
	print(f"  [INFO] {a}: " + (' '.join(parts) + f" dirty={dig(s, 'dirty')}" if parts is not None else 'unavailable'))

print('== serving 8+3 (+ comments ping)')
for url, want in URLS.items():
	rc, out = run(['curl', '-sS', '-m', '12', '-o', '/dev/null', '-w', '%{http_code}', url], timeout=20)
	note('PASS' if rc == 0 and out.strip() == str(want) else 'FAIL', f'{url} {out.strip() if rc == 0 else "error"} (expect {want})')
rc, out = run(['curl', '-sS', '-m', '10', 'https://comments.junghanacs.com/api/v1/ping'], timeout=20)
note('PASS' if rc == 0 and out.strip() == 'pong' else 'FAIL', 'comments /api/v1/ping == pong')

print('== summary')
f, u = results.count('FAIL'), results.count('UNKNOWN')
print(f'  PASS {results.count("PASS")} · FAIL {f} · UNKNOWN {u}')
sys.exit(1 if f else 2 if u else 0)
