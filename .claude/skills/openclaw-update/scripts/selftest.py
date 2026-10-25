#!/usr/bin/env python3
"""Offline fixtures for preflight.py / verify.py — no docker, network, runtime or model access.

Stubs `docker`, `gh`, `curl`, `df` on PATH and feeds each scenario; asserts the exit code and that nothing crashed.
Run: python3 -I selftest.py
"""
import copy
import json
import os
import shutil
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
	if a[:2] == ["image", "inspect"]: out(fx["image_id"])
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
IMAGE_ID = 'sha256:' + '7' * 64
GOOD = {
	'version': 'OpenClaw 2026.10.3 (59cb447)\n',
	'pkg': {'2026.10.2': {'openclaw': {'schemaVersions': {'state': 20, 'agent': 24}}},
		'2026.10.3': {'openclaw': {'schemaVersions': {'state': 20, 'agent': 24}}}},
	'compare': {'status': 'ahead', 'ahead_by': 90, 'behind_by': 0},
	'commit': {'sha': COMMIT},
	'index': {'manifests': [{'platform': {'architecture': 'amd64', 'os': 'linux'}, 'digest': 'sha256:' + 'e' * 64},
		{'platform': {'architecture': 'unknown', 'os': 'unknown'}, 'digest': 'sha256:' + 'f' * 64},
		{'platform': {'architecture': 'arm64', 'os': 'linux'}, 'digest': 'sha256:' + 'd' * 64}]},
	'image': {'config': {'Labels': {'org.opencontainers.image.revision': COMMIT}}},
	'inspect': [{'RestartCount': 4, 'Image': IMAGE_ID, 'State': {'Running': True, 'Health': {'Status': 'healthy'}, 'StartedAt': 'x'}}],
	'image_id': IMAGE_ID + '\n',
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
	if script == 'verify.py' and argv is None:
		argv = ['--receipts', str(receipts), '--image', 'openclaw-custom:cand']
	with tempfile.TemporaryDirectory(prefix='openclaw-verify-fixture-') as tmp:
		d = Path(tmp)
		if 'config' in fx:
			shutil.copytree(home, d / 'home')  # synthetic fixture only, never the operator's HOME
			home = d / 'home'
			(home / 'config/openclaw.json').write_text(json.dumps(fx['config']))
		(d / 'fx.json').write_text(json.dumps(fx))
		for n in ('docker', 'gh', 'curl', 'df'):
			(d / n).write_text(STUB)
			(d / n).chmod(0o755)
		env = dict(os.environ, PATH=f'{d}:{os.environ["PATH"]}', FX=str(d / 'fx.json'), OPENCLAW_HOME=str(home))
		r = subprocess.run([sys.executable, '-I', str(HERE / script), *argv], env=env, capture_output=True, text=True, timeout=30)
		if 'Traceback' in r.stderr:
			print(r.stdout, r.stderr)
		return 'traceback' if 'Traceback' in r.stderr else r.returncode  # a crash must never pass for an expected exit


CFG = {'plugins': {'allow': ['telegram'], 'entries': {'codex': {'enabled': False}}}, 'meta': {}}
home = Path(tempfile.mkdtemp())
(home / 'config').mkdir()
(home / 'config' / 'openclaw.json').write_text(json.dumps(CFG))
receipts = Path(tempfile.mkdtemp())  # valid snapshot shared by every verify case


def snapshot(name, content):
	d = Path(tempfile.mkdtemp())
	(d / 'openclaw.json.pre-swap').write_text(content)
	return ['--receipts', str(d), '--image', 'openclaw-custom:cand']


(receipts / 'openclaw.json.pre-swap').write_text(json.dumps(CFG))
nopatch = Path(tempfile.mkdtemp())
(nopatch / 'config').mkdir()
(nopatch / 'config' / 'openclaw.json').write_text(json.dumps(CFG))
(home / 'Dockerfile').write_text('ARG OPENCLAW_BASE=img@sha256:x\n')
(home / 'patch-memory-cron-parent.py').write_text(
	'VERSION = "2026.10.3"\nCORPUS_NAME = "session-transcript-corpus-X.mjs"\nKEY_NAME = "session-key-Y.mjs"\n'
	f'PATCHED_SHA = "{SHA["corpus"]}"\nHELPER_SHA256 = "{SHA["helper"]}"\nMARKER = "// m"\n')
urls = {u: c for u, c in (('https://agenda.junghanacs.com/', 200), ('https://analytics.junghanacs.com/', 200), ('https://ax.junghanacs.com/', 200),
	('https://claw.junghanacs.com/', 302), ('https://comments.junghanacs.com/', 404), ('https://forge.junghanacs.com/', 200),
	('https://ha.junghanacs.com/', 200), ('https://map.junghanacs.com/', 302), ('https://aionsclubs.org/', 200), ('https://oracle.tailb0e905.ts.net/', 200))}
GOOD['urls'] = urls
pre = {**GOOD, 'version': 'OpenClaw 2026.10.2 (b8952d4)\n'}

# A paused provider is an explicit expected state, never an ignored failure.
ACTIVE_ACCOUNTS = ('default', 'bbot', 'glg', 'gpt', 'mini')
PAUSED = copy.deepcopy(GOOD)
PAUSED['config'] = copy.deepcopy(CFG)
PAUSED['config']['plugins']['entries'].update({'zai': {'enabled': False}, 'xai': {'enabled': False}})
PAUSED['config']['channels'] = {'telegram': {'accounts': {
	**{aid: {'enabled': True} for aid in ACTIVE_ACCOUNTS}, 'gemini': {'enabled': False}}}}
PAUSED['config']['agents'] = {'entries': {'gemini': {'heartbeat': {'every': '0m'}}}}
for plugin in PAUSED['plugins']['plugins']:
	if plugin['id'] == 'zai':
		plugin.update(status='disabled', enabled=False)
PAUSED['plugins']['plugins'].append({'id': 'xai', 'status': 'disabled', 'enabled': False})
# Matches the coordinator's 10.4 bool/key-only receipt: disabled omits connected.
PAUSED['health']['channels']['telegram']['accounts'] = {
	**{aid: {'accountId': aid, 'enabled': True, 'configured': True, 'connected': True, 'running': True}
		for aid in ACTIVE_ACCOUNTS},
	'gemini': {'accountId': 'gemini', 'enabled': False, 'configured': True, 'running': False}}
PAUSED['health']['agents'] = [{'agentId': 'gemini',
	'heartbeat': {'enabled': False, 'every': 'disabled', 'everyMs': None}}]
PAUSED_ARGV = snapshot('paused', json.dumps(PAUSED['config'])) + [
	'--accounts', '5', '--expect-disabled-plugin', 'zai', '--expect-disabled-plugin', 'xai',
	'--expect-disabled-telegram', 'gemini', '--expect-disabled-heartbeat', 'gemini']


def paused_with(path, value):
	fx = copy.deepcopy(PAUSED)
	cur = fx
	keys = path.split('__')
	for key in keys[:-1]:
		cur = cur[int(key)] if isinstance(cur, list) else cur[key]
	if value is MISSING:
		del cur[keys[-1]]
	else:
		cur[keys[-1]] = value
	return fx


MISSING = object()
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
	('preflight', 'arm64 but not linux', {**pre, 'index': {'manifests': [{'platform': {'architecture': 'arm64', 'os': 'windows'}, 'digest': 'sha256:' + 'd' * 64}]}}, ['2026.10.3'], 1),
	('preflight', 'two linux/arm64 manifests', {**pre, 'index': {'manifests': [{'platform': {'architecture': 'arm64', 'os': 'linux'}, 'digest': 'sha256:' + 'd' * 64}] * 2}}, ['2026.10.3'], 1),
	('preflight', 'malformed digest', {**pre, 'index': {'manifests': [{'platform': {'architecture': 'arm64', 'os': 'linux'}, 'digest': 'd' * 64}]}}, ['2026.10.3'], 1),
	('preflight', 'manifests not a list', {**pre, 'index': {'manifests': {'a': 1}}}, ['2026.10.3'], 2),
	('preflight', 'manifest entry not a dict', {**pre, 'index': {'manifests': ['x']}}, ['2026.10.3'], 2),
	('preflight', 'index is a JSON list', {**pre, 'index': []}, ['2026.10.3'], 2),
	('preflight', 'package.json openclaw is a list', {**pre, 'pkg': {k: {'openclaw': []} for k in ('2026.10.2', '2026.10.3')}}, ['2026.10.3'], 2),
	('preflight', 'image config is a list', {**pre, 'image': []}, ['2026.10.3'], 2),
	('verify', 'good', GOOD, None, 0),
	('verify', 'health ok=false', with_(health__ok=False), None, 1),
	('verify', 'telegram 0/0', with_(health__channels={'telegram': {'accounts': {}}}), None, 1),
	('verify', 'health RPC fails, URLs fine', {**GOOD, 'health': None}, None, 2),
	('verify', 'plugin error', with_(health__plugins={'errors': ['x'], 'unavailable': []}), None, 1),
	('verify', 'new failed delivery', with_(health__deliveryQueues={'failed': [{'queueName': 'outbound', 'count': 2, 'oldestFailedAt': 1}]}), None, 1),
	('verify', 'codex enabled in plugins', with_(plugins={'plugins': [{'id': 'codex', 'status': 'loaded'}]}), None, 1),
	('verify', 'hotfix sha drift', {**GOOD, 'sums': f"{'0' * 64}  /app/dist/session-transcript-corpus-X.mjs\n{SHA['helper']}  /app/dist/session-key-Y.mjs\n"}, None, 1),
	('verify', 'version != patch VERSION', {**GOOD, 'version': 'OpenClaw 2026.10.4 (abcdef1)\n'}, None, 1),
	('verify', 'ping wrong body', {**GOOD, 'ping': 'nope'}, None, 1),
	('verify', 'cron consecutive errors', with_(cron={'jobs': [{'name': 'bbot', 'enabled': True, 'state': {'consecutiveErrors': 2}}]}), None, 1),
	('verify', 'receipts snapshot missing', GOOD, ['--receipts', '/nonexistent', '--image', 'openclaw-custom:cand'], 2),
	('verify', 'no --receipts at all', GOOD, ['--image', 'openclaw-custom:cand'], 2),
	('verify', 'no --image at all', GOOD, ['--receipts', str(receipts)], 2),
	('verify', 'snapshot not JSON', GOOD, snapshot('bad', '{not json'), 2),
	('verify', 'snapshot is a JSON list', GOOD, snapshot('list', '[]'), 2),
	('verify', 'config changed vs snapshot', GOOD, snapshot('chg', json.dumps({**CFG, 'plugins': {'allow': ['telegram', 'groq'], 'entries': {'codex': {'enabled': False}}}})), 2),
	('verify', 'key added under empty object', GOOD, snapshot('emp', json.dumps({**CFG, 'meta': {'x': 1}})), 2),
	('verify', 'patch script missing', ('nopatch', GOOD), None, 2),
	('verify', 'running image != candidate', {**GOOD, 'image_id': 'sha256:' + '8' * 64}, None, 1),
	('verify', 'image Id unreadable', {**GOOD, 'image_id': None}, None, 2),
	('verify', '--accounts 0', GOOD, ['--receipts', str(receipts), '--image', 'x', '--accounts', '0'], 2),
	('verify', 'cron jobs empty', with_(cron={'jobs': []}), None, 2),
	('verify', 'cron state missing', with_(cron={'jobs': [{'name': 'new', 'enabled': True}]}), None, 2),
	('verify', 'telegram account not a dict', with_(health__channels={'telegram': {'accounts': {str(i): 'x' for i in range(6)}}}), None, 1),
	('verify', 'health is a JSON list', {**GOOD, 'health': []}, None, 2),
	('verify', 'paused native connected omission', PAUSED, PAUSED_ARGV, 0),
	('verify', 'paused explicit connected false', paused_with('health__channels__telegram__accounts__gemini__connected', False), PAUSED_ARGV, 0),
	('verify', 'pause is not default policy', PAUSED, None, 1),
	('verify', 'account count alone cannot skip', PAUSED, PAUSED_ARGV[:4] + ['--accounts', '5'], 1),
	('verify', 'paused provider reloaded', paused_with('plugins__plugins__4__status', 'loaded'), PAUSED_ARGV, 1),
	('verify', 'paused provider enabled true', paused_with('plugins__plugins__4__enabled', True), PAUSED_ARGV, 1),
	('verify', 'paused provider enabled missing', paused_with('plugins__plugins__4__enabled', MISSING), PAUSED_ARGV, 1),
	('verify', 'paused provider enabled zero', paused_with('plugins__plugins__4__enabled', 0), PAUSED_ARGV, 1),
	('verify', 'paused provider not installed', paused_with('plugins__plugins', PAUSED['plugins']['plugins'][:-1]), PAUSED_ARGV, 1),
	('verify', 'paused provider config missing', paused_with('config__plugins__entries__zai', MISSING), PAUSED_ARGV, 1),
	('verify', 'paused provider config true', paused_with('config__plugins__entries__xai__enabled', True), PAUSED_ARGV, 1),
	('verify', 'paused provider config zero', paused_with('config__plugins__entries__xai__enabled', 0), PAUSED_ARGV, 1),
	('verify', 'paused Telegram reconnected', paused_with('health__channels__telegram__accounts__gemini__connected', True), PAUSED_ARGV, 1),
	('verify', 'paused Telegram still running', paused_with('health__channels__telegram__accounts__gemini__running', True), PAUSED_ARGV, 1),
	('verify', 'paused Telegram runtime missing', paused_with('health__channels__telegram__accounts__gemini', MISSING), PAUSED_ARGV, 2),
	('verify', 'paused Telegram running missing', paused_with('health__channels__telegram__accounts__gemini__running', MISSING), PAUSED_ARGV, 2),
	('verify', 'paused Telegram enabled missing', paused_with('health__channels__telegram__accounts__gemini__enabled', MISSING), PAUSED_ARGV, 2),
	('verify', 'paused Telegram enabled true', paused_with('health__channels__telegram__accounts__gemini__enabled', True), PAUSED_ARGV, 1),
	('verify', 'paused Telegram enabled zero', paused_with('health__channels__telegram__accounts__gemini__enabled', 0), PAUSED_ARGV, 2),
	('verify', 'paused Telegram enabled null', paused_with('health__channels__telegram__accounts__gemini__enabled', None), PAUSED_ARGV, 2),
	('verify', 'paused Telegram running string', paused_with('health__channels__telegram__accounts__gemini__running', 'false'), PAUSED_ARGV, 2),
	('verify', 'paused Telegram running zero', paused_with('health__channels__telegram__accounts__gemini__running', 0), PAUSED_ARGV, 2),
	('verify', 'paused Telegram connected null', paused_with('health__channels__telegram__accounts__gemini__connected', None), PAUSED_ARGV, 2),
	('verify', 'paused Telegram connected zero', paused_with('health__channels__telegram__accounts__gemini__connected', 0), PAUSED_ARGV, 2),
	('verify', 'paused Telegram connected string', paused_with('health__channels__telegram__accounts__gemini__connected', 'false'), PAUSED_ARGV, 2),
	('verify', 'paused reconnect beats unknown running', paused_with('health__channels__telegram__accounts__gemini', {'enabled': False, 'connected': True}), PAUSED_ARGV, 1),
	('verify', 'paused enabled beats unknown running', paused_with('health__channels__telegram__accounts__gemini', {'enabled': True}), PAUSED_ARGV, 1),
	('verify', 'paused omission alone insufficient', paused_with('health__channels__telegram__accounts__gemini', {}), PAUSED_ARGV, 2),
	('verify', 'paused Telegram error retained', paused_with('health__channels__telegram__accounts__gemini__lastError', 'fixture error'), PAUSED_ARGV, 1),
	('verify', 'paused Telegram config enabled', paused_with('config__channels__telegram__accounts__gemini__enabled', True), PAUSED_ARGV, 1),
	('verify', 'paused Telegram config absent', paused_with('config__channels__telegram__accounts__gemini', MISSING), PAUSED_ARGV, 1),
	('verify', 'paused heartbeat reenabled', paused_with('health__agents__0__heartbeat__enabled', True), PAUSED_ARGV, 1),
	('verify', 'paused heartbeat row missing', paused_with('health__agents', []), PAUSED_ARGV, 2),
	('verify', 'paused heartbeat config absent', paused_with('config__agents__entries__gemini__heartbeat', MISSING), PAUSED_ARGV, 1),
	('verify', 'paused heartbeat config inherited', paused_with('config__agents__entries__gemini__heartbeat__every', MISSING), PAUSED_ARGV, 1),
	('verify', 'paused heartbeat config 1h', paused_with('config__agents__entries__gemini__heartbeat__every', '1h'), PAUSED_ARGV, 1),
	('verify', 'paused heartbeat everyMs missing', paused_with('health__agents__0__heartbeat__everyMs', MISSING), PAUSED_ARGV, 1),
	('verify', 'active Telegram identity changed', paused_with('health__channels__telegram__accounts', {
		**{aid: {'connected': True} for aid in (*ACTIVE_ACCOUNTS[1:], 'unexpected')},
		'gemini': {'enabled': False, 'running': False}}), PAUSED_ARGV, 1),
	('verify', 'active Telegram missing', paused_with('health__channels__telegram__accounts__default', MISSING), PAUSED_ARGV, 1),
	('verify', 'unexpected plugin failure while paused', paused_with('health__plugins__errors', ['fixture']), PAUSED_ARGV, 1),
	('verify', 'disabled is not unavailable exemption', paused_with('health__plugins__unavailable', ['zai']), PAUSED_ARGV, 1),
	('verify', 'extra plugin error status', paused_with('plugins__plugins', PAUSED['plugins']['plugins'] + [{'id': 'extra', 'status': 'error'}]), PAUSED_ARGV, 1),
	('verify', 'duplicate plugin metadata', paused_with('plugins__plugins', PAUSED['plugins']['plugins'] + [PAUSED['plugins']['plugins'][4]]), PAUSED_ARGV, 1),
	('verify', 'malformed plugin id list', paused_with('plugins__plugins', PAUSED['plugins']['plugins'] + [{'id': [], 'status': 'disabled'}]), PAUSED_ARGV, 1),
	('verify', 'paused RPC health fails', paused_with('health__ok', False), PAUSED_ARGV, 1),
	('verify', 'paused RPC unavailable', paused_with('health', None), PAUSED_ARGV, 2),
	('verify', 'paused hotfix still mandatory', paused_with('sums', 'bad'), PAUSED_ARGV, 2),
	('verify', 'paused hotfix digest drift', paused_with('sums', f"{'0' * 64}  /app/dist/session-transcript-corpus-X.mjs\n{SHA['helper']}  /app/dist/session-key-Y.mjs\n"), PAUSED_ARGV, 1),
	('verify', 'paused candidate still mandatory', paused_with('image_id', 'sha256:' + '8' * 64), PAUSED_ARGV, 1),
	('verify', 'paused cron errors still fail', paused_with('cron__jobs__0__state__consecutiveErrors', 2), PAUSED_ARGV, 1),
	('verify', 'paused config drift still unknown', paused_with('config__meta', {'fixture': True}), PAUSED_ARGV, 2),
	('verify', 'paused public ping still mandatory', paused_with('ping', 'wrong'), PAUSED_ARGV, 1),
	('verify', 'paused public HTTP still mandatory', paused_with('urls__https://agenda.junghanacs.com/', 503), PAUSED_ARGV, 1),
	('verify', 'cannot exempt mandatory openai', PAUSED, PAUSED_ARGV + ['--expect-disabled-plugin', 'openai'], 2),
	('verify', 'cannot repeat same exemption', PAUSED, PAUSED_ARGV + ['--expect-disabled-plugin', 'zai'], 2),
	('verify', 'disabled ID cannot be empty', PAUSED, PAUSED_ARGV + ['--expect-disabled-telegram', ''], 2),
]
bad = 0
for script, name, fx, argv, want in cases:
	h = nopatch if isinstance(fx, tuple) else home
	fx = fx[1] if isinstance(fx, tuple) else fx
	got = run(f'{script}.py', fx, h, argv)
	ok = got == want
	bad += not ok
	print(f"{'ok  ' if ok else 'FAIL'} {script:9} {name:32} exit {got} (want {want})")
print(f'{len(cases) - bad}/{len(cases)} fixtures passed')
sys.exit(1 if bad else 0)
