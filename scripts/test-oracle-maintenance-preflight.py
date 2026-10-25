#!/usr/bin/env python3
"""Offline sandbox tests: no real system/Docker/Nix operations or user reports."""
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).with_name('oracle-maintenance-preflight.sh')


class PreflightTests(unittest.TestCase):
	def setUp(self):
		self.temp = tempfile.TemporaryDirectory(prefix='maintenance-test-')
		self.addCleanup(self.temp.cleanup)
		self.root = Path(self.temp.name)
		self.repo = self.root / 'repo'
		(self.repo / 'scripts').mkdir(parents=True)
		shutil.copyfile(SCRIPT, self.repo / 'scripts' / SCRIPT.name)
		(self.repo / 'scripts/diskclean.sh').write_text('#!/usr/bin/env bash\n[[ "$*" == "deep --dry-run" ]] || exit 91\nprintf "FIXTURE_DRY_RUN_ONLY\\n"\n')
		(self.repo / 'run.sh').write_text('# fixture operator\n')
		(self.repo / 'docs').mkdir()
		(self.repo / 'docs/oracle-maintenance.md').write_text('# fixture procedure\n')
		(self.repo / 'docs/data-retirement.md').write_text('# fixture data retirement\n')
		(self.repo / 'ORACLE.md').write_text('# fixture provider availability\n')
		(self.repo / 'docs/openclaw-automations.md').write_text('# fixture automation policy\n')
		(self.repo / '.claude/skills/oracle-reboot').mkdir(parents=True)
		(self.repo / '.claude/skills/oracle-reboot/SKILL.md').write_text('# fixture reboot skill\n')
		self.home = self.root / 'home'
		self.home.mkdir()
		(self.home / '.current-device').write_text('oracle-nixos\n')
		self.bin = self.root / 'bin'
		self.bin.mkdir()
		stub = '#!/usr/bin/env bash\nname=$(basename "$0")\nprintf "%s %s\\n" "$name" "$*" >> "$FIXTURE_CALLS"\nif [[ "$name" == "${FIXTURE_FAIL:-}" ]]; then echo FIXTURE_FAILURE >&2; exit 7; fi\nprintf "FIXTURE_%s\\n" "$name"\n'
		for name in ('git', 'df', 'free', 'uname', 'systemctl', 'docker', 'python3', 'nix', 'nix-store', 'readlink', 'ps', 'emacsclient'):
			p = self.bin / name
			p.write_text(stub)
			p.chmod(0o755)
		self.calls = self.root / 'calls'
		self.env = {**os.environ, 'HOME': str(self.home), 'PATH': str(self.bin) + ':' + os.environ['PATH'], 'FIXTURE_CALLS': str(self.calls)}
		for key in ('DEVICE', 'FIXTURE_FAIL'):
			self.env.pop(key, None)

	def run_check(self, *args):
		return subprocess.run(['bash', str(self.repo / 'scripts' / SCRIPT.name), *args], env=self.env, capture_output=True, text=True, timeout=10)

	def logs(self):
		return list((self.repo / '.agent-reports/oracle-maintenance').glob('*/preflight.log'))

	def test_default_is_persistent_private_and_no_nix(self):
		base = self.repo / '.agent-reports/oracle-maintenance'
		base.mkdir(parents=True)
		base.chmod(0o755)
		p = self.run_check()
		self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
		self.assertEqual(base.stat().st_mode & 0o777, 0o700)
		self.assertIn('COLLECTION_COMPLETE', p.stdout)
		self.assertIn('NOT health/cleanup/reboot approval', p.stdout)
		log, = self.logs()
		self.assertEqual(log.stat().st_mode & 0o777, 0o600)
		self.assertEqual(log.parent.stat().st_mode & 0o777, 0o700)
		self.assertIn('FIXTURE_DRY_RUN_ONLY', log.read_text())
		self.assertEqual((log.parent / 'source' / SCRIPT.name).read_bytes(), SCRIPT.read_bytes())
		self.assertEqual((log.parent / 'source' / SCRIPT.name).stat().st_mode & 0o777, 0o600)
		self.assertEqual((log.parent / 'source/SKILL.md').read_text(), '# fixture reboot skill\n')
		self.assertNotIn('nix ', self.calls.read_text())
		self.assertNotIn('sudo', self.calls.read_text())
		self.assertIn('git --no-optional-locks ', self.calls.read_text())
		self.assertIn('systemctl --user --failed', self.calls.read_text())
		self.assertIn('emacsclient -s server --alternate-editor=false', self.calls.read_text())
		self.assertIn('nix-store --gc --print-roots', self.calls.read_text())
		self.assertIn('ESTIMATE_UNAUDITED', log.read_text())
		self.assertIn('DATA_REVIEW_PENDING', log.read_text())
		self.assertIn('storage-review.md', log.read_text())
		self.assertFalse((log.parent / 'storage-review.md').exists(), 'A collection must not manufacture a reviewed decision')
		self.assertEqual((log.parent / 'source/data-retirement.md').read_text(), '# fixture data retirement\n')
		self.assertEqual((log.parent / 'source/data-retirement.md').stat().st_mode & 0o777, 0o600)
		self.assertEqual((log.parent / 'source/ORACLE.md').read_text(), '# fixture provider availability\n')
		self.assertEqual((log.parent / 'source/openclaw-automations.md').read_text(), '# fixture automation policy\n')
		self.assertEqual(len(list((log.parent / 'source').iterdir())), 8)
		self.assertIn('df -B1 / ', self.calls.read_text())

	def test_optional_nix_is_plan_only(self):
		p = self.run_check('--nix-plan')
		self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
		calls = self.calls.read_text()
		self.assertIn('nix build --offline --no-update-lock-file --dry-run --no-link ', calls)
		self.assertIn('nix eval --offline --no-update-lock-file --raw ', calls)
		self.assertNotIn('nixos-rebuild', calls)
		self.assertIn('desired/current=DIFF', p.stdout)

	def test_nix_plan_failure_is_incomplete(self):
		self.env['FIXTURE_FAIL'] = 'nix'
		p = self.run_check('--nix-plan')
		self.assertEqual(p.returncode, 2)
		self.assertIn('COLLECTION_INCOMPLETE', p.stdout)
		self.assertNotIn('desired/current=', p.stdout)

	def test_collection_failure_is_not_hidden(self):
		self.env['FIXTURE_FAIL'] = 'systemctl'
		p = self.run_check()
		self.assertEqual(p.returncode, 2)
		self.assertIn('COLLECTION_INCOMPLETE', p.stdout)
		self.assertIn('command=systemctl exit=7', self.logs()[0].read_text())
		self.assertIn('docker inspect', self.calls.read_text())

	def test_run_menu_d_preserves_ssh_socket_until_explicit_g(self):
		shutil.copyfile(SCRIPT.parent.parent / 'run.sh', self.repo / 'run.sh')
		path = self.home / '.ssh/sockets/git@github.com-22'
		path.parent.mkdir(parents=True)
		sock = socket.socket(socket.AF_UNIX)
		sock.bind(str(path))
		self.addCleanup(sock.close)
		command = ['bash', str(self.repo / 'run.sh')]
		p = subprocess.run(command, input='d\n\n0\n', env=self.env, capture_output=True, text=True, timeout=10)
		self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
		self.assertTrue(path.is_socket())
		self.assertIn('COLLECTION_COMPLETE', p.stdout)
		p = subprocess.run(command, input='g\n\n0\n', env=self.env, capture_output=True, text=True, timeout=10)
		self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
		self.assertFalse(path.exists())

	def test_missing_procedure_does_not_claim_collection(self):
		(self.repo / 'docs/oracle-maintenance.md').unlink()
		p = self.run_check()
		self.assertEqual(p.returncode, 2)
		self.assertIn('Procedure source missing', p.stderr)
		self.assertFalse(self.calls.exists())

	def test_missing_skill_does_not_probe(self):
		(self.repo / '.claude/skills/oracle-reboot/SKILL.md').unlink()
		p = self.run_check()
		self.assertEqual(p.returncode, 2)
		self.assertIn('Procedure source missing', p.stderr)
		self.assertFalse(self.calls.exists())

	def test_missing_data_procedure_does_not_probe(self):
		(self.repo / 'docs/data-retirement.md').unlink()
		p = self.run_check()
		self.assertEqual(p.returncode, 2)
		self.assertIn('Procedure source missing: docs/data-retirement.md', p.stderr)
		self.assertFalse(self.calls.exists())

	def test_missing_availability_policy_does_not_probe(self):
		for relative in ('ORACLE.md', 'docs/openclaw-automations.md'):
			with self.subTest(relative=relative):
				p = self.repo / relative
				original = p.read_bytes()
				p.unlink()
				result = self.run_check()
				self.assertEqual(result.returncode, 2)
				self.assertIn('Procedure source missing: ' + relative, result.stderr)
				self.assertFalse(self.calls.exists())
				p.write_bytes(original)

	def test_wrong_device_and_bad_option_do_not_probe(self):
		(self.home / '.current-device').write_text('laptop\n')
		self.assertEqual(self.run_check().returncode, 2)
		self.assertFalse(self.calls.exists())
		self.assertEqual(self.run_check('--reboot').returncode, 2)
		self.assertFalse(self.calls.exists())


class RebootSkillGateTests(unittest.TestCase):
	def test_documented_gate_is_fail_closed_without_running_shell(self):
		skill = SCRIPT.parent.parent / '.claude/skills/oracle-reboot/SKILL.md'
		match = re.search(r"python3 -I - \"\$R/suspend-prepare.final.json\" \"\$shutdown_budget_ms\" <<'PY_GATE'\n(.*?)\nPY_GATE", skill.read_text(), re.S)
		self.assertIsNotNone(match, 'Documented Python-only gate changed; review the test contract')
		code = match.group(1)
		base = {'status': 'ready', 'activeCount': 0, 'blockers': [], 'suspensionId': 'fixture-only', 'expiresAtMs': int(time.time()*1000)+120000}
		cases = [('ready', base, True)]
		for name, patch in (
			('busy', {'status': 'busy'}),
			('active', {'activeCount': 1}),
			('boolean_count', {'activeCount': False}),
			('blocked', {'blockers': ['fixture']}),
			('unknown_blockers', {'blockers': None}),
			('missing_id', {'suspensionId': ''}),
			('expired', {'expiresAtMs': 1}),
			('insufficient_ttl', {'expiresAtMs': int(time.time()*1000)+1000}),
			('above_5s_but_below_budget', {'expiresAtMs': int(time.time()*1000)+59000}),
			('unknown_expiry', {'expiresAtMs': None}),
		):
			cases.append((name, {**base, **patch}, False))
		cases.extend([('empty', {}, False), ('wrong_root_type', [], False)])
		with tempfile.TemporaryDirectory(prefix='reboot-gate-test-') as tmp:
			p = Path(tmp) / 'response.json'
			for name, value, expected in cases:
				with self.subTest(name=name):
					p.write_text(json.dumps(value))
					result = subprocess.run([sys.executable, '-I', '-', str(p), '60000'], input=code, capture_output=True, text=True, env={**os.environ, 'PYTHONOPTIMIZE': '1'}, timeout=5)
					self.assertEqual(result.returncode == 0, expected, result.stderr)
			p.write_text(json.dumps(base))
			result = subprocess.run([sys.executable, '-I', '-', str(p), '5000'], input=code, capture_output=True, text=True, timeout=5)
			self.assertNotEqual(result.returncode, 0, 'Old 5s minimum must not bypass shutdown budget')

	def test_documented_bash_syntax_and_isolation_shape(self):
		skill = SCRIPT.parent.parent / '.claude/skills/oracle-reboot/SKILL.md'
		blocks = re.findall(r'^([ \t]*)```bash\n(.*?)\n\1```', skill.read_text(), re.S | re.M)
		self.assertTrue(blocks)
		for _, code in blocks:
			r = subprocess.run(['bash', '-n'], input=code, text=True, capture_output=True, timeout=5)
			self.assertEqual(r.returncode, 0, r.stderr)
		gate, = [code for _, code in blocks if 'PY_GATE' in code]
		self.assertTrue(gate.strip().startswith('(') and gate.strip().endswith(')'))
		self.assertIn('set -C', gate)
		self.assertLess(gate.index('sudo -n -l '), gate.index('gateway.suspend.prepare'))
		self.assertIn('reboot-attempt.flag', gate)
		self.assertIn('reboot-command.exit', gate)


class DiskcleanSafetyTests(unittest.TestCase):
	def test_oracle_dry_run_preserves_emacs_and_journal(self):
		with tempfile.TemporaryDirectory(prefix='diskclean-test-') as tmp:
			root = Path(tmp)
			home = root / 'home'
			home.mkdir()
			bin_dir = root / 'bin'
			bin_dir.mkdir()
			paths = []
			for name in ('agent-emacs-init', 'emacs1000', 'old-fixture'):
				p = root / name
				p.mkdir()
				paths.append(p)
			stubs = {
				'id': '#!/usr/bin/env bash\necho 999999999\n',
				'find': '#!/usr/bin/env bash\nif [[ "$1" == /tmp ]]; then printf "%s\\n" "$TEST_ROOT/agent-emacs-init" "$TEST_ROOT/emacs1000" "$TEST_ROOT/old-fixture"; fi\n',
				'du': '#!/usr/bin/env bash\nprintf "60\\tfixture\\n"\n',
				'df': '#!/usr/bin/env bash\nprintf "Filesystem Size Used Avail Use%% Mounted\\n/fixture 100G 50G 50G 50%% /\\n"\n',
			}
			for name in ('rm', 'sudo', 'nix-store', 'nix-collect-garbage', 'uv', 'journalctl'):
				stubs[name] = '#!/usr/bin/env bash\necho FORBIDDEN > "$TEST_ROOT/forbidden"\nexit 99\n'
			for name, body in stubs.items():
				p = bin_dir / name
				p.write_text(body)
				p.chmod(0o755)
			env = {**os.environ, 'HOME': str(home), 'DEVICE': 'oracle', 'TEST_ROOT': str(root), 'PATH': str(bin_dir) + ':' + os.environ['PATH']}
			p = subprocess.run(['bash', str(SCRIPT.with_name('diskclean.sh')), 'deep', '--dry-run'], env=env, capture_output=True, text=True, timeout=10)
			self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
			self.assertIn('old-fixture', p.stdout)
			self.assertNotIn('agent-emacs-init', p.stdout)
			self.assertNotIn('emacs1000', p.stdout)
			self.assertNotIn('journalctl --vacuum', p.stdout)
			self.assertFalse((root / 'forbidden').exists())
			self.assertTrue(all(path.exists() for path in paths))


if __name__ == '__main__':
	unittest.main()
