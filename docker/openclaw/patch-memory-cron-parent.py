#!/usr/bin/env python3
"""11.4-only cron-parent admission port against exact linux/arm64 image bytes (v5).

Upstream d843d6af39a42cd3c30084edbeabeece732fd93a keeps corpus-policy source blob ff6b892
(identical to 11.2/11.3) and still classifies only cron run keys. 11.4 emits the classifier in
the same three places as 11.3 (main session-actor-memory-owner chunk, sqlite-store worker bundle,
worker chunk); only chunk names and file bytes changed, helpers are byte-identical to 11.3.
Keep the upstream cycle propagation; replace only the one classifier call per copy and bind
the existing isCronSessionKey helper. Every target is pinned by file, block and result sha.
"""
import argparse
import hashlib
import json
from pathlib import Path

VERSION = "2026.11.4"
SIG = "function collectCronGeneratedSessionKeys("
MARKER_LINE = "// operator-hotfix: memory-cron-parent-admission-v5 (11.4)"
MARKER_INLINE = "/* operator-hotfix: memory-cron-parent-admission-v5 (11.4) */"

TARGETS = [
	{
		"name": "session-actor-memory-owner-BB0qFpdR.mjs",
		"original": "22fa69c435027e4d9882331987750cc2c5f3dbecb9d13f4bf249dfa172e901e9",
		"patched": "fdb250adf5699871ad548a9b015f3a17f5b52e5d8d4073f9f1493a0f94b3e6bb",
		"call": ("isCronRunSessionKey(", "isCronSessionKey("),
		"import": (
			'import { C as isDreamingNarrativeSessionStoreKey, M as parseAgentSessionKey, _ as toAgentStoreSessionKey, x as isCronRunSessionKey } from "./session-key-CSDERtm3.mjs";',
			'import { C as isDreamingNarrativeSessionStoreKey, M as parseAgentSessionKey, S as isCronSessionKey, _ as toAgentStoreSessionKey, x as isCronRunSessionKey } from "./session-key-CSDERtm3.mjs";',
		),
		"absent": "isCronSessionKey",
		"helper": ("session-key-CSDERtm3.mjs", "ce1d2ed04cd22cfedaf92acefb59e32c9c522e5b75c6907fccf9f9d80df67299", "isCronSessionKey as S"),
		"marker": "line",
	},
	{
		"name": "worker/sqlite-store.worker.mjs",
		"original": "69a913115ea479fb0b570709aadad9c27a63e6afeb77e565859ee87537854867",
		"patched": "cd32a9a631c1f3afc6a19f0c03fdddb42733d3599d5ce8260ec5a965f8a56f6c",
		"call": ("isCronRunSessionKey(", "isCronSessionKey("),
		"import": None,
		"absent": None,
		"in_bundle": "function isCronSessionKey(Ot){let Kt=parseAgentSessionKey(Ot);return Kt?normalizeOptionalLowercaseString(Kt.rest)?.startsWith(`cron:`)===!0:!1}",
		"marker": "inline",
	},
	{
		"name": "worker/worker-chunk-BSVxjM55.mjs",
		"original": "f46bc94616b2b5d896d90e4b84bb0d401ed62408765d58a967719c40d2ae52e8",
		"patched": "33cea8ba5fb6733b3e4f03755251ad7506f5ffee9b592d4c62e1122081b4cf59",
		"call": ("Se(", "ocIsCronSessionKey("),
		"import": (
			'import{C as ye,N as be,_ as xe,o as E,x as Se}from"./worker-chunk-BlaVrMFq.mjs";',
			'import{C as ye,N as be,_ as xe,o as E,x as Se,S as ocIsCronSessionKey}from"./worker-chunk-BlaVrMFq.mjs";',
		),
		"absent": "ocIsCronSessionKey",
		"helper": ("worker/worker-chunk-BlaVrMFq.mjs", "87058fa01482a28d0cd0448208682e67fb6ea228b4820aae98bd8eadd15ce142", "isCronSessionKey as S"),
		"marker": "inline",
	},
]


def sha(data: bytes) -> str:
	return hashlib.sha256(data).hexdigest()


def brace_end(text: str, start: int) -> int:
	depth = 0
	for i in range(text.index("{", start), len(text)):
		if text[i] == "{":
			depth += 1
		elif text[i] == "}":
			depth -= 1
			if depth == 0:
				return i + 1
	raise ValueError("unterminated classifier block")


def patch_text(t: dict, text: str) -> str:
	name = t["name"]
	current = sha(text.encode())
	if current == t["patched"]:
		return text
	if current != t["original"]:
		raise ValueError(f"11.4 {name} content drift; refusing patch")
	if text.count(SIG) != 1:
		raise ValueError(f"11.4 {name} classifier locator drift; refusing patch")
	if t["absent"] and t["absent"] in text:
		raise ValueError(f"11.4 {name} binding name already present; refusing patch")
	if t["import"] and text.count(t["import"][0]) != 1:
		raise ValueError(f"11.4 {name} import drift; refusing patch")
	if t.get("in_bundle") and text.count(t["in_bundle"]) != 1:
		raise ValueError(f"11.4 {name} in-bundle helper drift; refusing patch")
	start = text.index(SIG)
	end = brace_end(text, start)
	block = text[start:end]
	old, new = t["call"]
	if block.count(old) != 1:
		raise ValueError(f"11.4 {name} classifier call drift; refusing patch")
	block = block.replace(old, new)
	if t["marker"] == "inline":
		block = MARKER_INLINE + block
	text = text[:start] + block + text[end:]
	if t["import"]:
		replacement = t["import"][1]
		if t["marker"] == "line":
			replacement = MARKER_LINE + "\n" + replacement
		text = text.replace(t["import"][0], replacement)
	if sha(text.encode()) != t["patched"]:
		raise ValueError(f"unexpected {name} patch result; refusing write")
	return text


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--app", type=Path, default=Path("/app"))
	args = parser.parse_args()
	dist = args.app / "dist"
	if json.loads((args.app / "package.json").read_text())["version"] != VERSION:
		raise SystemExit("hotfix requires OpenClaw 2026.11.4; review/retire on upgrade")
	found = sorted(str(p.relative_to(dist)) for p in dist.rglob("*")
		if p.suffix in (".mjs", ".js") and p.is_file() and SIG in p.read_text(encoding="utf-8", errors="replace"))
	if found != sorted(t["name"] for t in TARGETS):
		raise SystemExit(f"11.4 classifier locator drift; refusing patch: {found}")
	for t in TARGETS:
		if "helper" in t:
			helper, helper_sha, export = t["helper"]
			data = (dist / helper).read_bytes()
			if sha(data) != helper_sha or export not in data.decode():
				raise SystemExit(f"11.4 helper/export drift ({helper}); refusing patch")
	# All guards first, then all writes: never leave a partial port.
	outputs = []
	for t in TARGETS:
		path = dist / t["name"]
		text = path.read_text(encoding="utf-8")
		try:
			outputs.append((path, text, patch_text(t, text)))
		except ValueError as error:
			raise SystemExit(str(error))
	for path, text, patched in outputs:
		if patched != text:
			path.write_text(patched, encoding="utf-8")
	print(f"memory-cron-parent-admission-v5: applied/verified (11.4, guarded, {len(outputs)} copies)")


if __name__ == "__main__":
	main()
