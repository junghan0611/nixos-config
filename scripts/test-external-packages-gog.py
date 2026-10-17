#!/usr/bin/env python3
"""Offline installer fixtures: isolated HOME, mocked network/linkage, real tar/install."""
import io
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

SOURCE = Path(__file__).with_name("external-packages.sh")


class GogInstallerTests(unittest.TestCase):
	def run_fixture(self, members, *, dynamic=False, download_fail=False, version="v9.8.7"):
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			library = root / "library.sh"
			library.write_text(SOURCE.read_text().split("# ── dispatch")[0])
			archive = root / "release.tgz"
			with tarfile.open(archive, "w:gz") as tar:
				for name in members:
					data = f"#!/bin/sh\nprintf '{version} (fixture)\\n'\n".encode()
					entry = tarfile.TarInfo(name)
					entry.mode = 0o755
					entry.size = len(data)
					tar.addfile(entry, io.BytesIO(data))
			installed = root / ".local/bin/gog"
			installed.parent.mkdir(parents=True)
			installed.write_text("previous-install")
			env = os.environ | {
				"HOME": str(root), "FIXTURE_ARCHIVE": str(archive),
				"FIXTURE_DYNAMIC": str(int(dynamic)),
				"FIXTURE_DOWNLOAD_FAIL": str(int(download_fail)),
			}
			command = r'''
source "$1"
uname() { printf 'x86_64\n'; }
curl() {
	if [[ "$2" == *api.github.com* ]]; then
		printf '{"tag_name": "v9.8.7"}\n'
	else
		[[ "$FIXTURE_DOWNLOAD_FAIL" == 0 ]] || return 1
		cp "$FIXTURE_ARCHIVE" "${@: -1}"
	fi
}
file() {
	if [[ "$FIXTURE_DYNAMIC" == 1 ]]; then printf 'dynamically linked\n'
	else printf 'statically linked\n'; fi
}
install_gog
'''
			result = subprocess.run(["bash", "-c", command, "fixture", str(library)],
				env=env, capture_output=True, text=True)
			return result.returncode, installed.read_text(), result.stdout + result.stderr

	def test_both_official_member_layouts(self):
		for member in ("gog", "./gog"):
			with self.subTest(member=member):
				code, installed, output = self.run_fixture([member])
				self.assertEqual(code, 0, output)
				self.assertIn("v9.8.7", installed)

	def test_failure_preserves_existing_install(self):
		cases = [
			(["other"], {}),
			(["gog", "./gog"], {}),
			(["gog"], {"dynamic": True}),
			(["gog"], {"download_fail": True}),
			(["gog"], {"version": "v0.0.0"}),
		]
		for members, options in cases:
			with self.subTest(members=members, options=options):
				code, installed, output = self.run_fixture(members, **options)
				self.assertNotEqual(code, 0, output)
				self.assertEqual(installed, "previous-install")


if __name__ == "__main__":
	unittest.main()
