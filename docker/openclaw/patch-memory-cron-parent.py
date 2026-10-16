#!/usr/bin/env python3
"""10.4-only cron-parent admission port, verified against pinned ARM64 dist.

Upstream source: packages/memory-host-sdk/src/host/session-transcript-corpus.ts
and src/sessions/session-key-utils.ts at 383c124cc32ffee3f8e56f549b88da94d269a4af
(blobs unchanged since 10.2 b8952d47; only the emitted chunk name/imports moved).
Only the two classifier calls change; all other bytes and the key helper remain
unchanged. Do not weaken version/content guards for another build or release.
"""
import argparse
import hashlib
import json
from pathlib import Path

VERSION = "2026.10.4"
CORPUS_NAME = "session-transcript-corpus-CuTed983.mjs"
KEY_NAME = "session-key-C09ow4h0.mjs"
ORIGINAL_SHA = "54d5a1f1505cfa90b904c700a5eba07117d0f9f4a79ace43edc7b0f1e64663e6"
PATCHED_SHA = "6ac93a1e690af2cfffc7f29a21b65f96f223f4d1d116ea7e1879f9ea429813f4"
HELPER_SHA256 = "34c459c8cb5c33755e67fcbebbc6ba27438c09406fad29f0a2ecedae18e18cd5"
IMPORT = 'import { C as isDreamingNarrativeSessionStoreKey, x as isCronRunSessionKey } from "./session-key-C09ow4h0.mjs";'
MARKER = "// operator-hotfix: memory-cron-parent-admission-v3 (10.4)"


def sha(data: bytes) -> str:
	return hashlib.sha256(data).hexdigest()


def patch_text(text: str) -> str:
	current = sha(text.encode())
	if current == PATCHED_SHA:
		return text
	if current != ORIGINAL_SHA:
		raise ValueError("10.4 corpus content drift; refusing patch")
	if text.count(IMPORT) != 1:
		raise ValueError("10.4 import drift; refusing patch")
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
		raise SystemExit("hotfix requires OpenClaw 2026.10.4; review/retire on upgrade")
	files = [p for p in (app / "dist").glob("session-transcript-corpus-*.mjs")
		if "function collectCronGeneratedSessionKeys(summaries) {" in p.read_text()]
	if len(files) != 1 or files[0].name != CORPUS_NAME:
		raise SystemExit("10.4 corpus locator drift; refusing patch")
	if sha((app / "dist" / KEY_NAME).read_bytes()) != HELPER_SHA256:
		raise SystemExit("10.4 session-key helper/export drift; refusing patch")
	file = files[0]
	text = file.read_text()
	patched = patch_text(text)
	output = args.output or file
	if args.output or patched != text:
		output.write_text(patched)
	print("memory-cron-parent-admission-v3: applied/verified (10.4, guarded)")


if __name__ == "__main__":
	main()
