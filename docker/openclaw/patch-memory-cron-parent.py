#!/usr/bin/env python3
"""10.8-only cron-parent admission port against exact linux/arm64 image bytes.

Upstream dc2523e5a5c7a309517fd7fa834add938231d526 keeps the 10.7 corpus source
(blob 5cbb0ea1) and still classifies only cron run keys. Keep the upstream cycle
propagation; replace only the one classifier call and helper import.
"""
import argparse
import hashlib
import json
from pathlib import Path

VERSION = "2026.10.8"
CORPUS_NAME = "session-transcript-corpus-BQbjaNeO.mjs"
KEY_NAME = "session-key-utils-CDyBC9Gn.mjs"
ORIGINAL_SHA = "ad97f0967522b1ccbbe4a36cf3dac47576415fc72d7f38b68e42799b4c0a9e7b"
PATCHED_SHA = "2d36b2c38fda561e0542a4ad0be49cba0407e062bd9cadaa1ef4b4b90093d9c2"
HELPER_SHA256 = "984caee804349a2b2e70b72eb3760528fb255024295132ceccf4d879fbe8edf6"
IMPORT = 'import { i as isCronRunSessionKey, o as isDreamingNarrativeSessionStoreKey } from "./session-key-utils-CDyBC9Gn.mjs";'
MARKER = "// operator-hotfix: memory-cron-parent-admission-v4 (10.8)"


def sha(data: bytes) -> str:
	return hashlib.sha256(data).hexdigest()


def patch_text(text: str) -> str:
	current = sha(text.encode())
	if current == PATCHED_SHA:
		return text
	if current != ORIGINAL_SHA:
		raise ValueError("10.8 corpus content drift; refusing patch")
	if text.count(IMPORT) != 1:
		raise ValueError("10.8 import drift; refusing patch")
	start = text.index("function collectCronGeneratedSessionKeys(summaries) {")
	end = text.index("\nfunction ", start + 1)
	block = text[start:end]
	if block.count("isCronRunSessionKey(") != 1:
		raise ValueError("10.8 classifier call drift; refusing patch")
	block = block.replace("isCronRunSessionKey(", "isCronSessionKey(")
	text = text[:start] + block + text[end:]
	text = text.replace(IMPORT, MARKER + "\n" + IMPORT.replace(
		"i as isCronRunSessionKey", "a as isCronSessionKey, i as isCronRunSessionKey"))
	if sha(text.encode()) != PATCHED_SHA:
		raise ValueError("unexpected patch result; refusing write")
	return text


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--app", type=Path, default=Path("/app"))
	parser.add_argument("--output", type=Path, help="emit test override without changing source")
	args = parser.parse_args()
	if json.loads((args.app / "package.json").read_text())["version"] != VERSION:
		raise SystemExit("hotfix requires OpenClaw 2026.10.8; review/retire on upgrade")
	files = [p for p in (args.app / "dist").glob("session-transcript-corpus-*.mjs")
		if "function collectCronGeneratedSessionKeys(summaries) {" in p.read_text()]
	if len(files) != 1 or files[0].name != CORPUS_NAME:
		raise SystemExit("10.8 corpus locator drift; refusing patch")
	if sha((args.app / "dist" / KEY_NAME).read_bytes()) != HELPER_SHA256:
		raise SystemExit("10.8 helper/export drift; refusing patch")
	text = files[0].read_text()
	patched = patch_text(text)
	if args.output or patched != text:
		(args.output or files[0]).write_text(patched)
	print("memory-cron-parent-admission-v4: applied/verified (10.8, guarded)")


if __name__ == "__main__":
	main()
