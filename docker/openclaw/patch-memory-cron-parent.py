#!/usr/bin/env python3
"""9.8-only hotfix: classify cron parent sessions before memory admission.

Source: packages/memory-host-sdk/src/host/session-transcript-corpus.ts,
collectCronGeneratedSessionKeys. Use the existing isCronSessionKey parser, not
substring matching. Retirement: upstream corpus classifies the parent as cron
and memory status/index admission agrees. Never silently carry across upgrades.
"""
import argparse
import re
from pathlib import Path

MARKER = "// operator-hotfix: memory-cron-parent-admission-v1"


def patch_text(text: str) -> str:
	if MARKER in text:
		return text
	pattern = r'import \{ b as isCronRunSessionKey \} from "(\./session-key-[^"/]+\.mjs)";'
	matches = list(re.finditer(pattern, text))
	if len(matches) != 1:
		raise ValueError("session-key import drift; refusing patch")
	start = text.index("function collectCronGeneratedSessionKeys(summaries) {")
	end = text.index("\nfunction ", start + 1)
	block = text[start:end]
	if block.count("isCronRunSessionKey(") != 2:
		raise ValueError("cron lineage classifier drift; refusing patch")
	block = block.replace("isCronRunSessionKey(", "isCronSessionKey(")
	text = text[:start] + block + text[end:]
	match = matches[0]
	return text[:match.start()] + MARKER + '\n' + (
		'import { b as isCronRunSessionKey, x as isCronSessionKey } from "'
		+ match.group(1) + '";'
	) + text[match.end():]


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--app", type=Path, default=Path("/app"))
	args = parser.parse_args()
	app = args.app
	# Refuse a blind patch when the upstream release changes.
	import json
	if json.loads((app / "package.json").read_text())["version"] != "2026.9.8":
		raise SystemExit("hotfix requires OpenClaw 2026.9.8; review/retire on upgrade")
	files = [p for p in (app / "dist").glob("session-files-*.mjs")
		if "function collectCronGeneratedSessionKeys(summaries) {" in p.read_text()]
	if len(files) != 1:
		raise SystemExit(f"expected one corpus bundle, found {len(files)}")
	file = files[0]
	text = file.read_text()
	match = re.search(r'import \{ b as isCronRunSessionKey[^}]*\} from "(\./session-key-[^"/]+\.mjs)";', text)
	if not match or "isCronSessionKey as x" not in (file.parent / match.group(1)).read_text():
		raise SystemExit("isCronSessionKey export drift; refusing patch")
	patched = patch_text(text)
	if patched != text:
		file.write_text(patched)
	print("memory-cron-parent-admission-v1: applied/verified")


if __name__ == "__main__":
	main()
