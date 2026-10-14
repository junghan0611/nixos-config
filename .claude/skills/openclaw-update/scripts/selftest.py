#!/usr/bin/env python3
"""Offline fixtures for preflight.py / verify.py — no docker, network, runtime or model access.

Stubs `docker`, `gh`, `curl`, `df` on PATH and feeds each scenario; asserts the exit code.
Run: python3 -I selftest.py
"""
import copy
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
STUB = r'''#!/usr/bin/env python3
import json, os, sys
fx = json.load(open(os.environ["FX"]))
name = os.path.basename(sys.argv[0]); a = sys.argv[1:]; j = " ".join(a)
def out(v, rc=0):
	if v is None: sys.exit(1)
	sys.stdout.write(v if isinstance(v, str) else json.dumps(v)); sys.exit(rc)
if name == "df": out("Filesystem Size Used Avail Use% Mounted on\n")
if name == "curl":
	url = a[-1]
	out(fx["ping"] if url.endswith("/ping") else str(fx["urls"].get(url, 0)))
if name == "gh":
	p = a[1]
	if "contents/package.json?ref=v" in p: out(fx["pkg"].get(p.split("ref=v")[1]))
	if "/compare/" in p: out(fx["compare"])
	if "/commits/" in p: out(fx["commit"])
	out(None)
if name == "docker":
	if a[:2] == ["system", "df"]: out("TYPE TOTAL\n")
	if a[:1] == ["inspect"]: out(fx["inspect"])
	if a[:3] == ["buildx", "imagetools", "inspect"]: out(fx["index"] if "--raw" in a else fx["image"])
	if a[:2] == ["exec", "openclaw-gateway"]:
		if "--version" in a: out(fx["version"])
		if "sha256sum" in a: out(fx["sums"])
		if "health" in a: out(fx["health"])
		if "plugins" in a: out(fx["plugins"])
		if "cron.list" in a: out(fx["cron"])
		if "memory" in a: out(fx["memory"])
	out(None)
'''

SHA = {'corpus': 'a' * 64, 'helper': 'b' * 64}
COMMIT = 'c' * 40
GOOD = {
	'version': 'OpenClaw 2026.10.3 (59cb447)\n',
	'pkg': {'2026.10.2': {'openclaw': {'schemaVersions': {'state': 20, 'agent': 24}}},
		'2026.10.3': {'openclaw': {'schemaVersions': {'state': 20, 'agent': 24}}}},
	'compare': {'status': 'ahead', 'ahead_by': 90, 'behind_by': 0},
	'commit': {'sha': COMMIT},
	'index': {'manifests': [{'platform': {'architecture': 'arm64'}, 'digest': 'sha256:' + 'd' * 64}]},
	'image': {'config': {'Labels': {'org.opencontainers.image.revision': COMMIT}}},
	'inspect': [{'RestartCount': 4, 'State': {'Running': True, 'Health': {'Status': 'healthy'}, 'StartedAt': 'x'}}],
	'sums': f"{SHA['corpus']}  /app/dist/session-transcript-corpus-X.mjs\n{SHA['helper']}  /app/dist/session-key-Y.mjs\n",
	'health': {'ok': True, 'channels': {'telegram': {'accounts': {str(i): {'connected': True} for i in range(6)}}},
		'plugins': {'errors': [], 'unavailable': []}, 'eventLoop': {'degraded': False},
		'deliveryQueues': {'failed': [{'queueName': 'outbound', 'count': 1, 'oldestFailedAt': 1781602445810}]}},
	'plugins': {'plugins': [{'id': i, 'status': s} for i, s in (('codex', 'disabled'), ('telegram', 'loaded'), ('openai', 'loaded'),
		('anthropic', 'loaded'), ('zai', 'loaded'), ('memory-core', 'loaded'))]},
	'cron': {'jobs': [{'name': 'bbot', 'enabled': True, 'state': {'consecutiveErrors': 0}}]},
	'memory': {'sourceCounts': [{'source': 'sessions', 'files': 1, 'eligible': 1}], 'dirty': False},
	'urls': {}, 'ping': 'pong',
}


def with_(**kw):
	fx = copy.deepcopy(GOOD)
	for path, v in kw.items():
		cur = fx
		keys = path.split('__')
		for k in keys[:-1]:
			cur = cur[int(k)] if isinstance(cur, list) else cur[k]
		cur[keys[-1]] = v
	return fx


def run(script, fx, home, argv):
	d = Path(tempfile.mkdtemp())
	(d / 'fx.json').write_text(json.dumps(fx))
	for n in ('docker', 'gh', 'curl', 'df'):
		(d / n).write_text(STUB)
		(d / n).chmod(0o755)
	env = dict(os.environ, PATH=f'{d}:{os.environ["PATH"]}', FX=str(d / 'fx.json'), OPENCLAW_HOME=str(home))
	return subprocess.run([sys.executable, '-I', str(HERE / script), *argv], env=env, capture_output=True, text=True).returncode


home = Path(tempfile.mkdtemp())
(home / 'config').mkdir()
(home / 'config' / 'openclaw.json').write_text(json.dumps({'plugins': {'entries': {'codex': {'enabled': False}}}}))
(home / 'Dockerfile').write_text('ARG OPENCLAW_BASE=img@sha256:x\n')
(home / 'patch-memory-cron-parent.py').write_text(
	'VERSION = "2026.10.3"\nCORPUS_NAME = "session-transcript-corpus-X.mjs"\nKEY_NAME = "session-key-Y.mjs"\n'
	f'PATCHED_SHA = "{SHA["corpus"]}"\nHELPER_SHA256 = "{SHA["helper"]}"\nMARKER = "// m"\n')
urls = {u: c for u, c in (('https://agenda.junghanacs.com/', 200), ('https://analytics.junghanacs.com/', 200), ('https://ax.junghanacs.com/', 200),
	('https://claw.junghanacs.com/', 302), ('https://comments.junghanacs.com/', 404), ('https://forge.junghanacs.com/', 200),
	('https://ha.junghanacs.com/', 200), ('https://map.junghanacs.com/', 302), ('https://aionsclubs.org/', 200), ('https://oracle.tailb0e905.ts.net/', 200))}
GOOD['urls'] = urls
pre = {**GOOD, 'version': 'OpenClaw 2026.10.2 (b8952d4)\n'}

cases = [
	('preflight', 'good minor', pre, ['2026.10.3'], 0),
	('preflight', 'schema fetch fails', {**pre, 'pkg': {}}, ['2026.10.3'], 2),
	('preflight', 'schemaVersions {} on both', {**pre, 'pkg': {'2026.10.2': {'openclaw': {'schemaVersions': {}}}, '2026.10.3': {'openclaw': {'schemaVersions': {}}}}}, ['2026.10.3'], 2),
	('preflight', 'schema as strings', {**pre, 'pkg': {k: {'openclaw': {'schemaVersions': {'state': '20', 'agent': '24'}}} for k in ('2026.10.2', '2026.10.3')}}, ['2026.10.3'], 2),
	('preflight', 'live version unreadable', {**pre, 'version': 'garbage'}, ['2026.10.3'], 2),
	('preflight', 'wrong label revision', {**pre, 'image': {'config': {'Labels': {'org.opencontainers.image.revision': 'e' * 40}}}}, ['2026.10.3'], 1),
	('preflight', 'diverged compare', {**pre, 'compare': {'status': 'diverged', 'ahead_by': 3, 'behind_by': 2}}, ['2026.10.3'], 1),
	('preflight', 'no arm64 manifest', {**pre, 'index': {'manifests': []}}, ['2026.10.3'], 1),
	('preflight', 'schema bump = major', {**pre, 'pkg': {'2026.10.2': {'openclaw': {'schemaVersions': {'state': 20, 'agent': 24}}}, '2026.10.3': {'openclaw': {'schemaVersions': {'state': 21, 'agent': 24}}}}}, ['2026.10.3'], 3),
	('preflight', 'bad target arg', pre, ['latest'], 2),
	('verify', 'good', GOOD, [], 0),
	('verify', 'health ok=false', with_(health__ok=False), [], 1),
	('verify', 'telegram 0/0', with_(health__channels={'telegram': {'accounts': {}}}), [], 1),
	('verify', 'health RPC fails, URLs fine', {**GOOD, 'health': None}, [], 2),
	('verify', 'plugin error', with_(health__plugins={'errors': ['x'], 'unavailable': []}), [], 1),
	('verify', 'new failed delivery', with_(health__deliveryQueues={'failed': [{'queueName': 'outbound', 'count': 2, 'oldestFailedAt': 1}]}), [], 1),
	('verify', 'codex enabled in plugins', with_(plugins={'plugins': [{'id': 'codex', 'status': 'loaded'}]}), [], 1),
	('verify', 'hotfix sha drift', {**GOOD, 'sums': f"{'0' * 64}  /app/dist/session-transcript-corpus-X.mjs\n{SHA['helper']}  /app/dist/session-key-Y.mjs\n"}, [], 1),
	('verify', 'version != patch VERSION', {**GOOD, 'version': 'OpenClaw 2026.10.4 (abcdef1)\n'}, [], 1),
	('verify', 'ping wrong body', {**GOOD, 'ping': 'nope'}, [], 1),
	('verify', 'cron consecutive errors', with_(cron={'jobs': [{'name': 'bbot', 'enabled': True, 'state': {'consecutiveErrors': 2}}]}), [], 1),
	('verify', 'receipts snapshot missing', GOOD, ['--receipts', '/nonexistent'], 2),
]
bad = 0
for script, name, fx, argv, want in cases:
	got = run(f'{script}.py', fx, home, argv)
	ok = got == want
	bad += not ok
	print(f"{'ok  ' if ok else 'FAIL'} {script:9} {name:32} exit {got} (want {want})")
print(f'{len(cases) - bad}/{len(cases)} fixtures passed')
sys.exit(1 if bad else 0)
