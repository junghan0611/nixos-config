#!/usr/bin/env python3
"""11.7-only cron-parent admission port against exact linux/arm64 image bytes (v6).

Upstream e31bbf056de321127988ec5c1a36ff1b59297de0 keeps corpus-policy source blob ff6b892
(identical to 11.2-11.4) and still classifies only cron run keys. 11.7 emits the classifier in
FOUR places: the three 11.3/11.4 locations (main session-actor-memory-owner chunk, sqlite-store
worker bundle, worker chunk) plus a new standalone corpus-policy chunk under config/sessions/.
Keep the upstream cycle propagation; replace only the one classifier call per copy and bind
the existing isCronSessionKey helper. Every target is pinned by file, block and result sha.
"""
import argparse
import hashlib
import json
from pathlib import Path

VERSION = "2026.11.7"
SIG = "function collectCronGeneratedSessionKeys("
MARKER_LINE = "// operator-hotfix: memory-cron-parent-admission-v6 (11.7)"
MARKER_INLINE = "/* operator-hotfix: memory-cron-parent-admission-v6 (11.7) */"

TARGETS = [
	{
		"name": "session-actor-memory-owner-DRpZ0XX2.mjs",
		"original": "938fb2da4161ee9cea7f5daa7e0d2de34ea41b2ad9d9e9dfbff14f8d5b583225",
		"patched": "7c0b5e66a1e47603250e3a531367b2867d237cd190e3eadf3620e2571791e399",
		"call": ("isCronRunSessionKey(", "isCronSessionKey("),
		"import": (
			'import { S as isDreamingNarrativeSessionStoreKey, b as isCronRunSessionKey, g as toAgentStoreSessionKey, j as parseAgentSessionKey } from "./session-key-CqAyZeVk.mjs";',
			'import { S as isDreamingNarrativeSessionStoreKey, b as isCronRunSessionKey, g as toAgentStoreSessionKey, j as parseAgentSessionKey, x as isCronSessionKey } from "./session-key-CqAyZeVk.mjs";',
		),
		"absent": "isCronSessionKey",
		"helper": ("session-key-CqAyZeVk.mjs", "170317b6f76d44a271d5a0fbc411b27ddcbb8ab493838c2120a9e8bd697bd735", "isCronSessionKey as x"),
		"marker": "line",
	},
	{
		"name": "worker/sqlite-store.worker.mjs",
		"original": "5008d20ebcc1da2c0f22fa39503187ff1943354d7f7bd759935dec941bbd74b3",
		"patched": "df78c8922a4d5a946280f54e8ecc1bdce0740d3397455ebbeb54e2520dbc6e34",
		"call": ("isCronRunSessionKey(", "isCronSessionKey("),
		"import": None,
		"absent": None,
		"in_bundle": "function isCronSessionKey(N){let Fe=parseAgentSessionKey(N);return Fe?normalizeOptionalLowercaseString(Fe.rest)?.startsWith(`cron:`)===!0:!1}",
		"marker": "inline",
	},
	{
		"name": "worker/worker-chunk-BfQ4KGLU.mjs",
		"original": "5db603ecd49e7b8d8f819ff76fa837f84856c122c72f371b8f8e1aad6331b57b",
		"patched": "2bd9f82c17a475b9535e2d7323496728a175d8bc8272e8cb71efe31c9d73ce35",
		"call": ("if(le(", "if(ocIsCronSessionKey("),
		"import": (
			'import{C as oe,N as se,_ as ce,s as T,x as le}from"./worker-chunk-CP2kH91A.mjs";',
			'import{C as oe,N as se,_ as ce,s as T,x as le,S as ocIsCronSessionKey}from"./worker-chunk-CP2kH91A.mjs";',
		),
		"absent": "ocIsCronSessionKey",
		"helper": ("worker/worker-chunk-CP2kH91A.mjs", "f46ef0c4145e36739da3538050ca1c5de65ec02e7d914132c7aedfb5652da49e", "isCronSessionKey as S"),
		"marker": "inline",
	},
	{
		"name": "config/sessions/transcript-session-transcript-corpus-policy-CyAVnza1.mjs",
		"original": "83e049d392c1514f06e345fff54e84f995ad96554eae7e74c7b9a281acde5fcf",
		"patched": "aad566615147e8e5d6ec2ea9e1d253652c853febe6ff82100df14ea2755710d6",
		"call": ("if(e(", "if(ocIsCronSessionKey("),
		"import": (
			'import{f as e,m as t}from"./transcript-store-entry-Ch3rW6qd.mjs";',
			'import{f as e,m as t,p as ocIsCronSessionKey}from"./transcript-store-entry-Ch3rW6qd.mjs";',
		),
		"absent": "ocIsCronSessionKey",
		"helper": ("config/sessions/transcript-store-entry-Ch3rW6qd.mjs", "79e5405b0b45e0f33b26bfe35ccda66311d38502290db9b3f64154fd6c6bc8d7", "isCronSessionKey as p"),
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
		raise ValueError(f"11.7 {name} content drift; refusing patch")
	if text.count(SIG) != 1:
		raise ValueError(f"11.7 {name} classifier locator drift; refusing patch")
	if t["absent"] and t["absent"] in text:
		raise ValueError(f"11.7 {name} binding name already present; refusing patch")
	if t["import"] and text.count(t["import"][0]) != 1:
		raise ValueError(f"11.7 {name} import drift; refusing patch")
	if t.get("in_bundle") and text.count(t["in_bundle"]) != 1:
		raise ValueError(f"11.7 {name} in-bundle helper drift; refusing patch")
	start = text.index(SIG)
	end = brace_end(text, start)
	block = text[start:end]
	old, new = t["call"]
	if block.count(old) != 1:
		raise ValueError(f"11.7 {name} classifier call drift; refusing patch")
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
		raise SystemExit("hotfix requires OpenClaw 2026.11.7; review/retire on upgrade")
	found = sorted(str(p.relative_to(dist)) for p in dist.rglob("*")
		if p.suffix in (".mjs", ".js") and p.is_file() and SIG in p.read_text(encoding="utf-8", errors="replace"))
	if found != sorted(t["name"] for t in TARGETS):
		raise SystemExit(f"11.7 classifier locator drift; refusing patch: {found}")
	for t in TARGETS:
		if "helper" in t:
			helper, helper_sha, export = t["helper"]
			data = (dist / helper).read_bytes()
			if sha(data) != helper_sha or export not in data.decode():
				raise SystemExit(f"11.7 helper/export drift ({helper}); refusing patch")
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
	print(f"memory-cron-parent-admission-v6: applied/verified (11.7, guarded, {len(outputs)} copies)")


if __name__ == "__main__":
	main()
