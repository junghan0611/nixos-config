#!/usr/bin/env python3
"""Offline tests for oracle-rdp-connector.sh: stub cloudflared, isolated tmux server; no Cloudflare.

The real connectors on the host run other tunnel ids, so the fixture id never matches them.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

SCRIPT = Path(__file__).with_name('oracle-rdp-connector.sh')


class ConnectorTests(unittest.TestCase):
	def setUp(self):
		self.temp = tempfile.TemporaryDirectory(prefix='rdp-conn-test-')
		self.addCleanup(self.temp.cleanup)
		root = Path(self.temp.name)
		self.home = root / 'home'
		self.home.mkdir()
		(self.home / '.current-device').write_text('oracle-nixos\n')
		self.bin = root / 'bin'
		self.bin.mkdir()
		self.calls = root / 'calls'
		stub = self.bin / 'cloudflared'
		bash = subprocess.run(['bash', '-c', 'command -v bash'], capture_output=True, text=True).stdout.strip()
		# Direct bash shebang: one exec, so the process name stays "cloudflared" like the real binary.
		stub.write_text(
			f'#!{bash}\n'
			'printf "%s\\n" "$*" >> "$FIXTURE_CALLS"\n'
			'echo "INF Registered tunnel connection connIndex=0"\n'
			'while sleep 1; do :; done\n'
		)
		stub.chmod(0o755)
		self.stub = stub
		self.cfg = root / 'oracle-rdp.yml'
		self.cfg.write_text('tunnel: fixture-tunnel-id\ncredentials-file: /nonexistent\n')
		self.cfg.chmod(0o600)
		self.tmux = root / 'tmux'
		self.tmux.mkdir()
		self.addCleanup(lambda: subprocess.run(['tmux', 'kill-server'], env=self.env(), capture_output=True))
		self.addCleanup(lambda: subprocess.run(['pkill', '-f', '--', f'--config {self.cfg} run'], capture_output=True))

	def env(self, extra=None):
		env = {
			'HOME': str(self.home),
			'PATH': f'{self.bin}:{os.environ["PATH"]}',
			'FIXTURE_CALLS': str(self.calls),
			'TMUX_TMPDIR': str(self.tmux),
			'ORACLE_RDP_TUNNEL_CONFIG': str(self.cfg),
			'ORACLE_RDP_TMUX_SESSION': 'fixture-connector',
		}
		env.update(extra or {})
		return env

	def run_conn(self, *args, extra=None):
		return subprocess.run(['bash', str(SCRIPT), *args], env=self.env(extra), capture_output=True, text=True, timeout=60)

	def test_start_status_refuse_second_stop(self):
		r = self.run_conn('start')
		self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
		self.assertIn('켜짐', r.stdout)
		self.assertIn('상한 10800s', r.stdout)
		self.assertEqual(self.calls.read_text().splitlines(), [f'tunnel --no-autoupdate --config {self.cfg} run'])
		log = self.home / '.local/state/oracle-rdp/connector.log'
		self.assertEqual(oct(log.stat().st_mode & 0o777), '0o600')
		self.assertIn('limit=10800s', log.read_text())
		again = self.run_conn('start')
		self.assertEqual(again.returncode, 1)
		self.assertIn('연장·중복 시작하지 않는다', again.stderr)
		self.assertEqual(len(self.calls.read_text().splitlines()), 1, 'second start must not launch another connector')
		s = self.run_conn('status')
		self.assertEqual(s.returncode, 0)
		stop = self.run_conn('stop')
		self.assertEqual(stop.returncode, 0, stop.stdout + stop.stderr)
		self.assertIn('꺼짐', stop.stdout)
		self.assertEqual(self.run_conn('status').returncode, 1)

	def manual(self, cfg_text, cwd, rel):
		"""A connector started by hand, outside this script: relative --config, no timeout parent."""
		cwd.mkdir(parents=True, exist_ok=True)
		(cwd / rel).write_text(cfg_text)
		proc = subprocess.Popen([str(self.stub), 'tunnel', '--no-autoupdate', '--config', rel, 'run'],
			cwd=cwd, env=self.env(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
		self.addCleanup(lambda: (proc.kill(), proc.wait()))
		time.sleep(0.5)
		return proc

	def test_old_connector_on_another_path_is_found_and_stopped(self):
		root = Path(self.temp.name)
		old = self.manual('tunnel: fixture-tunnel-id\n', root / 'old-cwd', 'old.yml')
		other = self.manual('tunnel: some-other-tunnel\n', root / 'other-cwd', 'other.yml')
		r = self.run_conn('start')
		self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
		self.assertIn('중복 시작하지 않는다', r.stderr)
		self.assertIn(f'PID {old.pid}', r.stdout)
		self.assertIn('상한 미상', r.stdout)
		self.assertEqual(len(self.calls.read_text().splitlines()), 2, 'only the two manual processes ran')
		stop = self.run_conn('stop')
		self.assertEqual(stop.returncode, 0, stop.stdout + stop.stderr)
		self.assertIn(f'TERM → {old.pid}', stop.stdout)
		self.assertNotIn(str(other.pid), stop.stdout)
		self.assertIsNotNone(old.wait(timeout=10))
		self.assertIsNone(other.poll(), 'a different tunnel must survive stop')

	def test_refuses_off_oracle(self):
		(self.home / '.current-device').write_text('thinkpad\n')
		r = self.run_conn('start')
		self.assertEqual(r.returncode, 2)
		self.assertFalse(self.calls.exists())

	def test_refuses_loose_symlinked_or_missing_config(self):
		self.cfg.chmod(0o644)
		self.assertEqual(self.run_conn('start').returncode, 2)
		self.cfg.chmod(0o600)
		link = Path(self.temp.name) / 'link.yml'
		link.symlink_to(self.cfg)
		self.assertEqual(self.run_conn('start', extra={'ORACLE_RDP_TUNNEL_CONFIG': str(link)}).returncode, 2)
		Path(self.temp.name).chmod(0o755)
		self.assertEqual(self.run_conn('start').returncode, 2)
		Path(self.temp.name).chmod(0o700)
		self.cfg.unlink()
		self.assertEqual(self.run_conn('start').returncode, 2)
		self.assertFalse(self.calls.exists())

	def test_stop_when_off_is_noop(self):
		r = self.run_conn('stop')
		self.assertEqual(r.returncode, 0)
		self.assertIn('이미 꺼짐', r.stdout)


if __name__ == '__main__':
	unittest.main()
