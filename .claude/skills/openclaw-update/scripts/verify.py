#!/usr/bin/env python3
"""Post-swap verification without model calls — read-only, fail-closed.

Usage: verify.py [--receipts DIR] [--accounts 6]
Exit: 0 all required checks PASS · 1 any FAIL · 2 any UNKNOWN (a required measurement is missing).
Information lines (restarts, memory lag, new .bak, cron next run) never pass a failing run.
The comments ping body is compared to "pong" and never printed.
"""
import argparse
import hashlib
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
results = []


def note(level, msg):
	results.append(level)
	print(f'  [{level}] {msg}')


def run(cmd, timeout=60):
	try:
		p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
		return p.returncode, p.stdout
	except (OSError, subprocess.TimeoutExpired) as e:
		return 127, str(e)


def oc_json(*a):
	rc, out = run(['docker', 'exec', 'openclaw-gateway', 'openclaw', *a, '--json'])
	if rc != 0:
		return None
	i = out.find('{') if out.lstrip()[:1] != '[' else out.find('[')
	try:
		return json.loads(out[i:]) if i >= 0 else None
	except json.JSONDecodeError:
		return None


ap = argparse.ArgumentParser()
ap.add_argument('--receipts', type=Path)
ap.add_argument('--accounts', type=int, default=6)
args = ap.parse_args()

print('== version / container')
rc, out = run(['docker', 'exec', 'openclaw-gateway', 'openclaw', '--version'])
m = re.match(r'^OpenClaw (\d{4}\.\d+\.\d+) \(([0-9a-f]{7,40})\)\s*$', out.strip()) if rc == 0 else None
live_ver = m.group(1) if m else None
note('PASS' if m else 'UNKNOWN', f'version: {out.strip() or "unreadable"}')
rc, out = run(['docker', 'inspect', 'openclaw-gateway'])
try:
	st = json.loads(out)[0]['State'] if rc == 0 else None
	restarts = json.loads(out)[0].get('RestartCount') if rc == 0 else None
except (json.JSONDecodeError, IndexError, KeyError):
	st, restarts = None, None
if st is None:
	note('UNKNOWN', 'docker inspect unavailable')
else:
	note('PASS' if st.get('Running') else 'FAIL', f"running={st.get('Running')}")
	print(f"  [INFO] restarts={restarts} badge={st.get('Health', {}).get('Status')} started={st.get('StartedAt')} (badge lags; RPC health decides)")

print('== RPC health')
h = oc_json('gateway', 'call', 'health', '--timeout', '30000')
if not isinstance(h, dict):
	note('UNKNOWN', 'health RPC failed or unparsable')
else:
	note('PASS' if h.get('ok') is True else 'FAIL', f"ok={h.get('ok')}")
	acc = ((h.get('channels') or {}).get('telegram') or {}).get('accounts') or {}
	conn = sum(1 for s in acc.values() if s.get('connected'))
	errs = sum(1 for s in acc.values() if s.get('lastError'))
	note('PASS' if len(acc) == args.accounts and conn == args.accounts and errs == 0 else 'FAIL',
		f'telegram connected {conn}/{len(acc)} (expect {args.accounts}), lastError {errs}')
	pl = h.get('plugins') or {}
	note('PASS' if pl.get('errors') == [] and pl.get('unavailable') == [] else 'FAIL', f"plugin errors={pl.get('errors')} unavailable={pl.get('unavailable')}")
	note('PASS' if (h.get('eventLoop') or {}).get('degraded') is False else 'FAIL', f"eventLoop degraded={(h.get('eventLoop') or {}).get('degraded')}")
	dq = (h.get('deliveryQueues') or {}).get('failed')
	note('PASS' if dq in ([], TOMBSTONE) else 'FAIL', f"deliveryQueues.failed={dq} ({'June tombstone baseline' if dq == TOMBSTONE else 'differs from baseline — inspect'})")

print('== plugins that must hold')
pj = oc_json('plugins', 'list')
ps = (pj.get('plugins') if isinstance(pj, dict) else pj) if pj is not None else None
if not isinstance(ps, list):
	note('UNKNOWN', 'plugins list unavailable')
else:
	by = {p.get('id'): p for p in ps}
	for pid, want in (('codex', 'disabled'), ('telegram', 'loaded'), ('openai', 'loaded'), ('anthropic', 'loaded'), ('zai', 'loaded'), ('memory-core', 'loaded')):
		got = (by.get(pid) or {}).get('status')
		note('PASS' if got == want else 'FAIL', f'{pid}: {got} (expect {want})')

print('== hotfix integrity (constants from the patch script)')
patch = HOME / 'patch-memory-cron-parent.py'
if not patch.exists():
	print('  [INFO] no patch script — hotfix retired')
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

print('== openclaw.json')
cfg = HOME / 'config' / 'openclaw.json'
try:
	b = json.loads(cfg.read_text())
	note('PASS' if b['plugins']['entries']['codex'].get('enabled') is False else 'FAIL', f"plugins.entries.codex.enabled={b['plugins']['entries']['codex'].get('enabled')}")
except (OSError, json.JSONDecodeError, KeyError) as e:
	note('UNKNOWN', f'live config unreadable: {e!r}')
	b = None
if args.receipts:
	pre = args.receipts.expanduser() / 'openclaw.json.pre-swap'
	if not pre.exists() or b is None:
		note('UNKNOWN', f'pre-swap snapshot missing: {pre}')
	else:
		def flat(o, p=''):
			if isinstance(o, dict):
				for k, v in o.items():
					yield from flat(v, f'{p}.{k}' if p else k)
			else:
				yield p, json.dumps(o, sort_keys=True)
		a, z = dict(flat(json.loads(pre.read_text()))), dict(flat(b))
		ch = [k for k in sorted(set(a) | set(z)) if a.get(k) != z.get(k)]
		print(f'  [INFO] changed paths vs pre-swap: {len(ch)} {ch[:12]}')

print('== cron (information + consecutive errors)')
cj = oc_json('gateway', 'call', 'cron.list', '--timeout', '30000')
if not isinstance(cj, dict) or not isinstance(cj.get('jobs'), list):
	note('UNKNOWN', 'cron.list unavailable')
else:
	for j in cj['jobs']:
		e = (j.get('state') or {}).get('consecutiveErrors')
		note('PASS' if not e else 'FAIL', f"{j.get('name')} enabled={j.get('enabled')} consecutiveErrors={e}")

print('== memory index (information)')
for a in ('main', 'glg', 'gpt', 'mini', 'gemini', 'bbot'):
	d = oc_json('memory', 'status', '--agent', a)
	d = d[0] if isinstance(d, list) and d else d
	s = (d or {}).get('status', d) if isinstance(d, dict) else None
	print(f"  [INFO] {a}: " + (' '.join('%s=%s/%s' % (x['source'], x['files'], x['eligible']) for x in s.get('sourceCounts', [])) + f" dirty={s.get('dirty')}" if s else 'unavailable'))

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
