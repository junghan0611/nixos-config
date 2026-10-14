#!/usr/bin/env python3
"""OpenClaw update preflight — read-only, fail-closed.

Usage: preflight.py <target-version>        e.g. preflight.py 2026.10.3

Reads: live version (docker exec), GitHub API (package.json schemaVersions, compare, tag commit),
registry manifest + labels (no layer download), Dockerfile pin, hotfix VERSION, disk.
Exit: 0 MINOR candidate · 3 MAJOR (separate decision) · 1 FAIL · 2 UNKNOWN (a measurement is missing).
A MINOR candidate only means the declared schema is identical. It does not approve config/auth/plugin
contracts or permissions — those stay with the release-note review and the pulled-image checks.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = 'repos/openclaw/openclaw'
IMG = 'ghcr.io/openclaw/openclaw'
HOME = Path(os.environ.get('OPENCLAW_HOME', Path.home() / 'openclaw'))
VER = re.compile(r'^\d{4}\.\d+\.\d+$')
results = []


def note(level, msg):
	results.append(level)
	print(f'  [{level}] {msg}')


def run(cmd):
	try:
		p = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
		return p.returncode, p.stdout
	except (OSError, subprocess.TimeoutExpired) as e:
		return 127, str(e)


def gh_json(path, raw=False):
	cmd = ['gh', 'api', path] + (['-H', 'Accept: application/vnd.github.raw'] if raw else [])
	rc, out = run(cmd)
	if rc != 0:
		return None
	try:
		return json.loads(out)
	except json.JSONDecodeError:
		return None


def dig(o, *keys):
	for k in keys:
		o = o.get(k) if isinstance(o, dict) else None
	return o


def is_int(v):
	return isinstance(v, int) and not isinstance(v, bool)


def schema(ver):
	s = dig(gh_json(f'{REPO}/contents/package.json?ref=v{ver}', raw=True), 'openclaw', 'schemaVersions')
	if not (is_int(dig(s, 'state')) and is_int(dig(s, 'agent'))):
		return None
	return {'state': s['state'], 'agent': s['agent']}


if len(sys.argv) != 2 or not VER.match(sys.argv[1]):
	print('usage: preflight.py <target-version>  (YYYY.M.D)')
	sys.exit(2)
target = sys.argv[1]

print('== live')
rc, out = run(['docker', 'exec', 'openclaw-gateway', 'openclaw', '--version'])
m = re.match(r'^OpenClaw (\d{4}\.\d+\.\d+) \(([0-9a-f]{7,40})\)\s*$', out.strip()) if rc == 0 else None
current = m.group(1) if m else None
note('OK' if m else 'UNKNOWN', f'live version: {out.strip() or "unreadable"}')

print('== declared schemaVersions')
sc = schema(current) if current else None
st = schema(target)
note('OK' if sc else 'UNKNOWN', f'{current}: {sc}')
note('OK' if st else 'UNKNOWN', f'{target}: {st}')

print('== compare (must be linear: ahead or identical, behind 0)')
cmp = gh_json(f'{REPO}/compare/v{current}...v{target}') if current else None
if not isinstance(cmp, dict) or not isinstance(cmp.get('status'), str):
	note('UNKNOWN', 'compare unavailable')
elif cmp.get('status') not in ('ahead', 'identical') or cmp.get('behind_by') != 0:
	note('FAIL', f"status={cmp.get('status')} ahead={cmp.get('ahead_by')} behind={cmp.get('behind_by')} — not a linear upgrade")
else:
	note('OK', f"status={cmp.get('status')} ahead={cmp.get('ahead_by')} behind=0")

commit = dig(gh_json(f'{REPO}/commits/v{target}'), 'sha')
if not (isinstance(commit, str) and re.fullmatch(r'[0-9a-f]{40}', commit)):
	commit = None
note('OK' if commit else 'UNKNOWN', f'v{target} commit: {commit}')

print('== registry (no pull; exactly one linux/arm64 manifest)')
digest = None
rc, out = run(['docker', 'buildx', 'imagetools', 'inspect', '--raw', f'{IMG}:{target}'])
try:
	ms = dig(json.loads(out), 'manifests') if rc == 0 else None
except json.JSONDecodeError:
	ms = None
if not isinstance(ms, list) or not all(isinstance(x, dict) for x in ms):
	note('UNKNOWN', f'manifest index for {IMG}:{target} unavailable or malformed')
else:
	hits = [x for x in ms if dig(x, 'platform', 'os') == 'linux' and dig(x, 'platform', 'architecture') == 'arm64']
	d = hits[0].get('digest') if len(hits) == 1 else None
	if len(hits) != 1:
		note('FAIL', f'expected exactly 1 linux/arm64 manifest, found {len(hits)}')
	elif not (isinstance(d, str) and re.fullmatch(r'sha256:[0-9a-f]{64}', d)):
		note('FAIL', f'linux/arm64 digest malformed: {d!r}')
	else:
		digest = d
		note('OK', f'linux/arm64 manifest: {digest}')
if digest:
	rc, out = run(['docker', 'buildx', 'imagetools', 'inspect', f'{IMG}@{digest}', '--format', '{{json .Image}}'])
	try:
		rev = dig(json.loads(out), 'config', 'Labels', 'org.opencontainers.image.revision') if rc == 0 else None
	except json.JSONDecodeError:
		rev = None
	if not (isinstance(rev, str) and commit):
		note('UNKNOWN', f'label revision {rev} vs commit {commit}')
	elif rev != commit:
		note('FAIL', f'label revision {rev} != tag commit {commit} — STOP')
	else:
		note('OK', 'label revision == tag commit')

print('== Dockerfile / hotfix guards (information)')
df = HOME / 'Dockerfile'
pin = re.search(r'OPENCLAW_BASE=(\S+)', df.read_text()) if df.exists() else None
print(f"  Dockerfile pin: {pin.group(1) if pin else 'not found'}")
for p in sorted(HOME.glob('patch-*.py')):
	v = re.search(r'^VERSION = "([^"]+)"', p.read_text(), re.M)
	v = v.group(1) if v else None
	print(f"  {p.name}: VERSION={v} {'(matches target)' if v == target else '→ build fails closed until ported (SKILL §1-4)'}")

print('== disk (information; docker on /, ~/openclaw on /home)')
for cmd in (['df', '-h', '/', '/home'], ['docker', 'system', 'df']):
	rc, out = run(cmd)
	print('\n'.join('  ' + line for line in out.strip().splitlines()) if rc == 0 else f'  {" ".join(cmd)}: unavailable')

print('== verdict')
if 'FAIL' in results:
	print('  FAIL — stop and report; do not pull/build')
	sys.exit(1)
if 'UNKNOWN' in results:
	print('  UNKNOWN — a required measurement is missing; report instead of guessing')
	sys.exit(2)
if sc != st:
	print(f'  MAJOR (schema {sc} -> {st}) — outside the GLG minor rule; decide separately')
	sys.exit(3)
print('  MINOR candidate (declared schema identical). Still: release-note scope review + pulled-image schema/config check.')
sys.exit(0)
