#!/usr/bin/env python3
"""10.2-only cron-parent admission port, verified against pinned ARM64 dist.

Upstream source: packages/memory-host-sdk/src/host/session-transcript-corpus.ts
and src/sessions/session-key-utils.ts at b8952d477f0c932d8ddc6da5c89cab5a169b6ff1.
Only the two classifier calls change; all other bytes and the key helper remain
unchanged. Do not weaken version/content guards for another build or release.
"""
import argparse
import hashlib
import json
from pathlib import Path

VERSION = "2026.10.2"
CORPUS_NAME = "session-transcript-corpus-B2gUPO4D.mjs"
KEY_NAME = "session-key-C09ow4h0.mjs"
ORIGINAL_SHA = "1fc438cc61bc9d6106734aa5f8e3c0841e34ea67c264dae2baceca61b0cf6102"
PATCHED_SHA = "ca089fb0481d4c6445db264bc2549d56acb9d6da6ce0506ff3e3a4f1677487ff"
HELPER_SHA256 = "34c459c8cb5c33755e67fcbebbc6ba27438c09406fad29f0a2ecedae18e18cd5"
IMPORT = 'import { C as isDreamingNarrativeSessionStoreKey, x as isCronRunSessionKey } from "./session-key-C09ow4h0.mjs";'
MARKER = "// operator-hotfix: memory-cron-parent-admission-v2 (10.2)"


def sha(data: bytes) -> str:
	return hashlib.sha256(data).hexdigest()


def patch_text(text: str) -> str:
	current = sha(text.encode())
	if current == PATCHED_SHA:
		return text
	if current != ORIGINAL_SHA:
		raise ValueError("10.2 corpus content drift; refusing patch")
	if text.count(IMPORT) != 1:
		raise ValueError("10.2 import drift; refusing patch")
	start = text.index("function collectCronGeneratedSessionKeys(summaries) {")
	end = text.index("\nfunction ", start + 1)
	block = text[start:end]
	if block.count("isCronRunSessionKey(") != 2:
		raise ValueError("cron classifier call drift; refusing patch")
	block = block.replace("isCronRunSessionKey(", "isCronSessionKey(")
	text = text[:start] + block + text[end:]
	text = text.replace(IMPORT, MARKER + "\n" + IMPORT.replace(
		"x as isCronRunSessionKey", "S as isCronSessionKey, x as isCronRunSessionKey"))
	if sha(text.encode()) != PATCHED_SHA:
		raise ValueError("unexpected patch result; refusing write")
	return text


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--app", type=Path, default=Path("/app"))
	parser.add_argument("--output", type=Path, help="emit a test override without changing source")
	args = parser.parse_args()
	app = args.app
	if json.loads((app / "package.json").read_text())["version"] != VERSION:
		raise SystemExit("hotfix requires OpenClaw 2026.10.2; review/retire on upgrade")
	files = [p for p in (app / "dist").glob("session-transcript-corpus-*.mjs")
		if "function collectCronGeneratedSessionKeys(summaries) {" in p.read_text()]
	if len(files) != 1 or files[0].name != CORPUS_NAME:
		raise SystemExit("10.2 corpus locator drift; refusing patch")
	if sha((app / "dist" / KEY_NAME).read_bytes()) != HELPER_SHA256:
		raise SystemExit("10.2 session-key helper/export drift; refusing patch")
	file = files[0]
	text = file.read_text()
	patched = patch_text(text)
	output = args.output or file
	if args.output or patched != text:
		output.write_text(patched)
	print("memory-cron-parent-admission-v2: applied/verified (10.2, guarded)")


if __name__ == "__main__":
	main()
