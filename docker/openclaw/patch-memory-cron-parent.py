#!/usr/bin/env python3
"""11.3-only cron-parent admission port against exact linux/arm64 image bytes (v5).

Upstream 847611dcaa3bf0e2783335f961dd1fd0580e4d9f keeps corpus-policy source blob ff6b892
(identical to 11.2) and still classifies only cron run keys. 11.3 emits the classifier in
three places (main session-actor-memory-owner chunk, sqlite-store worker bundle, worker chunk);
which one serves a given runtime path is not statically single, so all three are ported.
Keep the upstream cycle propagation; replace only the one classifier call per copy and bind
the existing isCronSessionKey helper. Every target is pinned by file, block and result sha.
"""
import argparse
import hashlib
import json
from pathlib import Path

VERSION = "2026.11.3"
SIG = "function collectCronGeneratedSessionKeys("
MARKER_LINE = "// operator-hotfix: memory-cron-parent-admission-v5 (11.3)"
MARKER_INLINE = "/* operator-hotfix: memory-cron-parent-admission-v5 (11.3) */"

TARGETS = [
	{
		"name": "session-actor-memory-owner-BSARM2d5.mjs",
		"original": "7ad2cb1ccba8237ff91905ccd7e4e5df75bb8e30847ea08ec19064bd0a935c14",
		"patched": "89fe2d56e92620566708bce43dd2849874d5967e0e5c70ee960912233b5b8b47",
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
		"original": "438aa890bf0db6213aae1dad2d3e116e2a428cf35d6fc9991067e170d4501299",
		"patched": "1fe83e1ace2e396557a3fc7988af08dcbcf7af227a131ba6f10e6ec96b72ad0b",
		"call": ("isCronRunSessionKey(", "isCronSessionKey("),
		"import": None,
		"absent": None,
		"in_bundle": "function isCronSessionKey(Ot){let Kt=parseAgentSessionKey(Ot);return Kt?normalizeOptionalLowercaseString(Kt.rest)?.startsWith(`cron:`)===!0:!1}",
		"marker": "inline",
	},
	{
		"name": "worker/worker-chunk-KkGEpzZj.mjs",
		"original": "cec82762021c329181b49143b33c440a41e90b24ae0a53d9509db21a270e3bce",
		"patched": "909b8329cb9a58a6393d736ed710a8e6d5efe7d285e68e2cfbb3f9bfe5b9545b",
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
		raise ValueError(f"11.3 {name} content drift; refusing patch")
	if text.count(SIG) != 1:
		raise ValueError(f"11.3 {name} classifier locator drift; refusing patch")
	if t["absent"] and t["absent"] in text:
		raise ValueError(f"11.3 {name} binding name already present; refusing patch")
	if t["import"] and text.count(t["import"][0]) != 1:
		raise ValueError(f"11.3 {name} import drift; refusing patch")
	if t.get("in_bundle") and text.count(t["in_bundle"]) != 1:
		raise ValueError(f"11.3 {name} in-bundle helper drift; refusing patch")
	start = text.index(SIG)
	end = brace_end(text, start)
	block = text[start:end]
	old, new = t["call"]
	if block.count(old) != 1:
		raise ValueError(f"11.3 {name} classifier call drift; refusing patch")
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
		raise SystemExit("hotfix requires OpenClaw 2026.11.3; review/retire on upgrade")
	found = sorted(str(p.relative_to(dist)) for p in dist.rglob("*")
		if p.suffix in (".mjs", ".js") and p.is_file() and SIG in p.read_text(encoding="utf-8", errors="replace"))
	if found != sorted(t["name"] for t in TARGETS):
		raise SystemExit(f"11.3 classifier locator drift; refusing patch: {found}")
	for t in TARGETS:
		if "helper" in t:
			helper, helper_sha, export = t["helper"]
			data = (dist / helper).read_bytes()
			if sha(data) != helper_sha or export not in data.decode():
				raise SystemExit(f"11.3 helper/export drift ({helper}); refusing patch")
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
	print(f"memory-cron-parent-admission-v5: applied/verified (11.3, guarded, {len(outputs)} copies)")


if __name__ == "__main__":
	main()
