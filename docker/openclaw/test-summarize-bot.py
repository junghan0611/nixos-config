#!/usr/bin/env python3
"""Offline guard regressions; optional --image runs network-isolated extraction tests.

No credentials, external network, Gateway state or model calls are used.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

P = argparse.ArgumentParser(add_help=False)
P.add_argument('--image')
P.add_argument('--wrapper', default='/home/junghan/repos/gh/agent-config/skills/summarize/scripts/summarize')
OPTIONS, REST = P.parse_known_args()
GUARD = Path(__file__).with_name('summarize-bot.sh')
WRAPPER_DEST = '/home/junghan/repos/gh/agent-config/skills/summarize/scripts/summarize'
WRAPPER_SHA = '74fcc0c1e2c59d029849142065b09a761d8ee65f9eddf8c37795f68b9820acfd'
LOOPBACK = '''import http.server,threading,subprocess,sys
body=b'<html><title>Community garden</title><article><h1>SYNTHETIC_SOURCE_MARKER</h1>'+b'<p>A community garden saves rainwater. Volunteers record plant growth and rainfall every week. Clear observations let the next gardener continue without guessing.</p>'*400+b'</article></html>'
class Handler(http.server.BaseHTTPRequestHandler):
 def do_GET(self):
  self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8');self.end_headers();self.wfile.write(body)
 def log_message(self,*a):pass
s=http.server.HTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=s.serve_forever,daemon=True).start()
try:
 args=[f'http://127.0.0.1:{s.server_port}/article' if x=='__URL__' else x for x in sys.argv[1:]]
 p=subprocess.run(['/usr/local/bin/summarize',*args],capture_output=True,text=True,timeout=35)
 assert p.returncode==0,(p.returncode,p.stderr)
 assert 'SYNTHETIC_SOURCE_MARKER' in p.stdout
 assert 19500<=len(p.stdout)<=20500,('character cap',len(p.stdout))
 print('EXTRACTION_PASS chars='+str(len(p.stdout)))
finally:s.shutdown()
'''


class GuardTests(unittest.TestCase):
	def test_forbidden_modes(self):
		cases = [
			['--model', 'openrouter/fixture'], ['--cli=pi'], ['--markdown-mode', 'llm'],
			['--'], ['--slides'], ['Transcriber', 'setup'], ['Refresh-Free'],
			['Daemon', 'install'], ['SLIDES', 'https://example.invalid'], ['Status'],
			['--diarize=openai'], ['--transcriber', 'fixture'], ['--identify-speakers'],
			['--speaker-profile=fixture'], ['--remember-speakers'], ['--video-mode', 'understand'],
			['--MODEL=fixture'], ['--json'], ['--JSON=true'],
		]
		for args in cases:
			with self.subTest(args=args):
				p = subprocess.run(['bash', str(GUARD), *args], capture_output=True, text=True, timeout=5)
				self.assertEqual(p.returncode, 2)
				self.assertIn('extract-only', p.stderr)
				self.assertEqual(p.stdout, '')


@unittest.skipUnless(OPTIONS.image, 'pass --image for isolated container integration')
class ContainerTests(unittest.TestCase):
	@classmethod
	def setUpClass(cls):
		cls.temp = tempfile.TemporaryDirectory(prefix='summarize-guard-test-')
		cls.root = Path(cls.temp.name)
		wrapper = Path(OPTIONS.wrapper)
		assert hashlib.sha256(wrapper.read_bytes()).hexdigest() == WRAPPER_SHA, 'central scrubber drift'
		cfg = cls.run_docker(['--entrypoint', 'node', OPTIONS.image, '-e', 'process.stdout.write(require("fs").readFileSync("/home/node/.summarize/config.json","utf8"))'])
		assert json.loads(cfg.stdout) == {'cli': {'enabled': [], 'autoFallback': {'enabled': False}}}
		(cls.root / 'config.json').write_text(cfg.stdout)
		(cls.root / 'loopback.py').write_text(LOOPBACK)
		cls.common = ['--tmpfs', '/tmp:rw,size=64m', '--tmpfs', '/home/node/.cache:rw,size=32m', '--tmpfs', '/home/node/.summarize:rw,uid=1000,gid=1000,mode=700,size=32m', '--mount', f'type=bind,src={cls.root}/config.json,dst=/home/node/.summarize/config.json,readonly', '--mount', f'type=bind,src={wrapper},dst={WRAPPER_DEST},readonly']

	@classmethod
	def tearDownClass(cls):
		cls.temp.cleanup()

	@staticmethod
	def run_docker(args, check=True):
		return subprocess.run(['docker', 'run', '--rm', '--pull', 'never', '--network', 'none', '--read-only', *args], capture_output=True, text=True, timeout=60, check=check)

	def test_image_guard_matches_source(self):
		p = self.run_docker(['--entrypoint', 'sha256sum', OPTIONS.image, '/usr/local/bin/summarize-bot'])
		self.assertEqual(p.stdout.split()[0], hashlib.sha256(GUARD.read_bytes()).hexdigest())

	def test_web_extract_flag_order_firecrawl_and_cap(self):
		for args in [['__URL__', '--plain', '--firecrawl', 'always', '--max-extract-characters', '999999'], ['--plain', '--firecrawl=always', '__URL__']]:
			with self.subTest(args=args):
				p = self.run_docker([*self.common, '--mount', f'type=bind,src={self.root}/loopback.py,dst=/tmp/loopback.py,readonly', '--entrypoint', 'python3', OPTIONS.image, '/tmp/loopback.py', *args])
				self.assertIn('EXTRACTION_PASS', p.stdout)

	def test_alias_and_model_json_denial(self):
		for executable in ['summarize', 'summarizer']:
			for args in [['--model', 'openrouter/fixture'], ['--json']]:
				p = self.run_docker([*self.common, '--entrypoint', '/usr/local/bin/' + executable, OPTIONS.image, *args], check=False)
				self.assertEqual(p.returncode, 2)
				self.assertIn('extract-only', p.stderr)

	def test_scrub_and_forced_args(self):
		fake = self.root / 'upstream'
		fake.write_text('#!/usr/bin/env python3\nimport os,sys\nexpected=["--extract"]+(["--markdown-mode","readability"] if any(a.startswith("https://") for a in sys.argv) else [])+["--firecrawl","off","--max-extract-characters","20000"]\nassert sys.argv[-len(expected):]==expected\nassert all(k not in os.environ for k in ["OPENROUTER_API_KEY","OPENAI_API_KEY","ANTHROPIC_API_KEY","GROQ_API_KEY"])\nprint("SAFE_FORWARDING")\n')
		fake.chmod(0o755)
		env = [a for k in ['OPENROUTER_API_KEY', 'OPENAI_API_KEY', 'ANTHROPIC_API_KEY', 'GROQ_API_KEY'] for a in ['-e', k + '=fixture-not-a-secret']]
		for source in ['https://example.invalid', '/tmp/source.pdf']:
			with self.subTest(source=source):
				p = self.run_docker([*self.common, *env, '--mount', f'type=bind,src={fake},dst=/usr/local/libexec/summarize-upstream/summarize,readonly', '--entrypoint', '/usr/local/bin/summarize', OPTIONS.image, source])
				self.assertIn('SAFE_FORWARDING', p.stdout)

	def test_no_extra_pi_and_memory_regression(self):
		p = self.run_docker(['--entrypoint', 'sh', OPTIONS.image, '-c', 'summarize --version; if command -v pi >/dev/null; then exit 9; fi; node /usr/local/lib/openclaw-hotfix/test-memory-cron-parent.mjs'])
		self.assertIn('0.25.2', p.stdout)
		self.assertIn('12 behavior assertions passed', p.stdout)  # 10.7+ also preserves two upstream cycle cases


if __name__ == '__main__':
	unittest.main(argv=[sys.argv[0], *REST])
