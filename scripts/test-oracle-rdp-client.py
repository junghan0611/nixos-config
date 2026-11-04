#!/usr/bin/env python3
"""Offline tests for oracle-rdp-client.sh: a stub cloudflared records argv; no real Access login.

PATH holds only the stub dir and a dir of symlinked basic tools, so no test can reach a real
cloudflared on the host (an earlier version did, for ~20 s, through the inherited PATH).
"""
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('oracle-rdp-client.sh')
HOST = 'oracle-rdp.junghanacs.com'
TOOLS = ['bash', 'env', 'tr', 'cut', 'cat', 'ss', 'touch']


class ClientTests(unittest.TestCase):
	def setUp(self):
		self.temp = tempfile.TemporaryDirectory(prefix='rdp-client-test-')
		self.addCleanup(self.temp.cleanup)
		root = Path(self.temp.name)
		self.home = root / 'home'
		self.home.mkdir()
		(self.home / '.current-device').write_text('thinkpad\n')
		self.bin = root / 'bin'
		self.bin.mkdir()
		self.tools = root / 'tools'
		self.tools.mkdir()
		for name in TOOLS:
			real = subprocess.run(['bash', '-c', f'command -v {name}'], capture_output=True, text=True).stdout.strip()
			if real:
				(self.tools / name).symlink_to(real)
		self.calls = root / 'calls'
		stub = self.bin / 'cloudflared'
		stub.write_text(f'#!{self.tools / "bash"}\nprintf "%s\\n" "$*" >> "$FIXTURE_CALLS"\n')
		stub.chmod(0o755)

	def run_client(self, env_extra=None):
		env = {
			'HOME': str(self.home),
			'PATH': f'{self.bin}:{self.tools}',
			'FIXTURE_CALLS': str(self.calls),
		}
		env.update(env_extra or {})
		return subprocess.run([str(self.tools / 'bash'), str(SCRIPT)], env=env, capture_output=True, text=True, timeout=20)

	def called(self):
		return self.calls.read_text().splitlines() if self.calls.exists() else []

	def test_fixed_hostname_and_default_port(self):
		r = self.run_client()
		self.assertEqual(r.returncode, 0, r.stderr)
		self.assertEqual(self.called(), [f'access rdp --hostname {HOST} --url rdp://127.0.0.1:13389'])
		self.assertIn('browser', r.stdout)

	def test_hostname_is_not_taken_from_env_or_env_local(self):
		marker = Path(self.temp.name) / 'sourced-marker'
		(self.home / '.env.local').write_text(f'touch {marker}\nexport ORACLE_RDP_HOSTNAME=rdp.example.test\n')
		r = self.run_client({'ORACLE_RDP_HOSTNAME': 'other.example.test', 'ORACLE_RDP_LOCAL_PORT': str(free_port())})
		self.assertEqual(r.returncode, 0, r.stderr)
		self.assertEqual(len(self.called()), 1)
		self.assertIn(f'--hostname {HOST} ', self.called()[0])
		self.assertFalse(marker.exists(), '.env.local must not be sourced')

	def test_oracle_device_refuses(self):
		(self.home / '.current-device').write_text('oracle-nixos\n')
		r = self.run_client()
		self.assertEqual(r.returncode, 2)
		self.assertEqual(self.called(), [])

	def test_bad_port_refuses(self):
		for port in ['80', 'abc', '70000']:
			r = self.run_client({'ORACLE_RDP_LOCAL_PORT': port})
			self.assertEqual(r.returncode, 2, port)
		self.assertEqual(self.called(), [])

	def test_busy_port_refuses_without_touching_owner(self):
		with socket.socket() as s:
			s.bind(('127.0.0.1', 0))
			s.listen(1)
			port = s.getsockname()[1]
			r = self.run_client({'ORACLE_RDP_LOCAL_PORT': str(port)})
			self.assertEqual(r.returncode, 1, r.stderr)
			self.assertEqual(self.called(), [])
			s.settimeout(0.1)  # still ours: the script did not kill or take the listener

	def test_missing_cloudflared_refuses(self):
		(self.bin / 'cloudflared').unlink()
		r = self.run_client()
		self.assertEqual(r.returncode, 2, r.stderr)
		self.assertIn('cloudflared', r.stderr)
		self.assertEqual(self.called(), [])


def free_port():
	with socket.socket() as s:
		s.bind(('127.0.0.1', 0))
		return s.getsockname()[1]


if __name__ == '__main__':
	unittest.main()
