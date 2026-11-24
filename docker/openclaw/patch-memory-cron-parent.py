#!/usr/bin/env python3
"""11.8-only cron-parent admission port against exact linux/arm64 image bytes (v6).

Upstream 2d4ab292114df2ab9670c91c9b846f701c565bd7 keeps corpus-policy source blob ff6b892
(identical to 11.2-11.7) and still classifies only cron run keys. 11.8, like 11.7, emits the classifier in
FOUR places: the three 11.3/11.4 locations (main session-actor-memory-owner chunk, sqlite-store
worker bundle, worker chunk) plus a new standalone corpus-policy chunk under config/sessions/.
Keep the upstream cycle propagation; replace only the one classifier call per copy and bind
the existing isCronSessionKey helper. Every target is pinned by file, block and result sha.
"""
import argparse
import hashlib
import json
from pathlib import Path

VERSION = "2026.11.8"
SIG = "function collectCronGeneratedSessionKeys("
MARKER_LINE = "// operator-hotfix: memory-cron-parent-admission-v6 (11.8)"
MARKER_INLINE = "/* operator-hotfix: memory-cron-parent-admission-v6 (11.8) */"

TARGETS = [
	{
		"name": "session-actor-memory-owner-BkB9Vtu4.mjs",
		"original": "4c04c31d0903ffbd2e7c1635935bdbb832022543e2fd5f8d65228e458d28b1d3",
		"patched": "34024960359d6d0885a11c1772a5f4c40d930b1a938234af86d85796a06406f6",
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
		"original": "2ca1339df2d865232e0fbc32e108577aba3c0df69540e7ae684684d6e4edab50",
		"patched": "6d28324dd496e1428ee695af30d1959a993de1568d10cfa120e7a86b16ad4e10",
		"call": ("isCronRunSessionKey(", "isCronSessionKey("),
		"import": None,
		"absent": None,
		"in_bundle": "function isCronSessionKey(N){let Fe=parseAgentSessionKey(N);return Fe?normalizeOptionalLowercaseString(Fe.rest)?.startsWith(`cron:`)===!0:!1}",
		"marker": "inline",
	},
	{
		"name": "worker/worker-chunk-5IktB7k2.mjs",
		"original": "6fc62a7d1af0dc901a5212d8d6faf7490412641ddb7101b46c7c3c3fdb4406bf",
		"patched": "976cf198e4ca27762050edeb883ba126fbf3873af88b3d082a3a525424426a69",
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
		"name": "config/sessions/transcript-session-transcript-corpus-policy-YTf-w7Rw.mjs",
		"original": "639f7ee346c92fa2a4d59eee4528c1f877d6da8adbd01c662843068709cb1b56",
		"patched": "b71f46d170b0b6af6a86be5806da65eb520e4ae18d555b71c3c858ddc5ff1b81",
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
		raise ValueError(f"11.8 {name} content drift; refusing patch")
	if text.count(SIG) != 1:
		raise ValueError(f"11.8 {name} classifier locator drift; refusing patch")
	if t["absent"] and t["absent"] in text:
		raise ValueError(f"11.8 {name} binding name already present; refusing patch")
	if t["import"] and text.count(t["import"][0]) != 1:
		raise ValueError(f"11.8 {name} import drift; refusing patch")
	if t.get("in_bundle") and text.count(t["in_bundle"]) != 1:
		raise ValueError(f"11.8 {name} in-bundle helper drift; refusing patch")
	start = text.index(SIG)
	end = brace_end(text, start)
	block = text[start:end]
	old, new = t["call"]
	if block.count(old) != 1:
		raise ValueError(f"11.8 {name} classifier call drift; refusing patch")
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
		raise SystemExit("hotfix requires OpenClaw 2026.11.8; review/retire on upgrade")
	found = sorted(str(p.relative_to(dist)) for p in dist.rglob("*")
		if p.suffix in (".mjs", ".js") and p.is_file() and SIG in p.read_text(encoding="utf-8", errors="replace"))
	if found != sorted(t["name"] for t in TARGETS):
		raise SystemExit(f"11.8 classifier locator drift; refusing patch: {found}")
	for t in TARGETS:
		if "helper" in t:
			helper, helper_sha, export = t["helper"]
			data = (dist / helper).read_bytes()
			if sha(data) != helper_sha or export not in data.decode():
				raise SystemExit(f"11.8 helper/export drift ({helper}); refusing patch")
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
	print(f"memory-cron-parent-admission-v6: applied/verified (11.8, guarded, {len(outputs)} copies)")


if __name__ == "__main__":
	main()
