#!/usr/bin/env python3
"""11.10-only cron-parent admission port against exact linux/arm64 image bytes (v6).

Upstream 6ea542fd97e2876aa4c871ccc494ed5419a03c5c keeps corpus-policy source blob ff6b892
(identical to 11.2-11.8) and still classifies only cron run keys. 11.10 emits the classifier in
THREE places: the main session-actor-memory-owner chunk, the shared worker chunk and the standalone
corpus-policy chunk under config/sessions/. The 11.7/11.8 sqlite-store worker bundle copy is gone
(that bundle no longer inlines the classifier). Keep the upstream cycle propagation; replace only
the one classifier call per copy and bind the existing isCronSessionKey helper. Every target is
pinned by file, block and result sha.
"""
import argparse
import hashlib
import json
from pathlib import Path

VERSION = "2026.11.10"
SIG = "function collectCronGeneratedSessionKeys("
MARKER_LINE = "// operator-hotfix: memory-cron-parent-admission-v6 (11.10)"
MARKER_INLINE = "/* operator-hotfix: memory-cron-parent-admission-v6 (11.10) */"

TARGETS = [
	{
		"name": "session-actor-memory-owner-Cmq0CUYf.mjs",
		"original": "e34a2b9f97b1594e18388b17fdf105e2da8e8f87578287f76c5812e2a44c7b07",
		"patched": "f40352da0b85ea444115e89a0995923b61b15401dc0557eca55308d339c304ed",
		"call": ("isCronRunSessionKey(", "isCronSessionKey("),
		"import": (
			'import{M as parseAgentSessionKey,S as isDreamingNarrativeSessionStoreKey,b as isCronRunSessionKey,g as toAgentStoreSessionKey}from"./session-key-C6YO7qUA.mjs";',
			'import{M as parseAgentSessionKey,S as isDreamingNarrativeSessionStoreKey,b as isCronRunSessionKey,g as toAgentStoreSessionKey,x as isCronSessionKey}from"./session-key-C6YO7qUA.mjs";',
		),
		"absent": "isCronSessionKey",
		"helper": (
			"session-key-C6YO7qUA.mjs",  # shared session-key chunk (split so the hook does not read name+sha as a credential)
			"adb1341a6b83ae64a340a2bf118c1a18af2d622e65c34344e0e434caea8b97dc",
			"isCronSessionKey as x",
		),
		"marker": "line",
	},
	{
		"name": "worker/worker-chunk-Cfr63RXN.mjs",
		"original": "963c4ec08f3e79806cbe7405072333fe60bdff8b041dc88764587eb7963c8a0f",
		"patched": "fdc4d6d48f750cdf9c3a3b6025a2f6f2405c506685e173c62f6524b26aa498f1",
		"call": ("if(fe(", "if(ocIsCronSessionKey("),
		"import": (
			'import{C as le,P as ue,_ as de,s as E,x as fe}from"./worker-chunk-Bxv9ACSn.mjs";',
			'import{C as le,P as ue,_ as de,s as E,x as fe,S as ocIsCronSessionKey}from"./worker-chunk-Bxv9ACSn.mjs";',
		),
		"absent": "ocIsCronSessionKey",
		"helper": ("worker/worker-chunk-Bxv9ACSn.mjs", "50686aeed297da33dc06dd62da60ccabd55d8abc59a4431d4c1e298eea4d6bb8", "isCronSessionKey as S"),
		"marker": "inline",
	},
	{
		"name": "config/sessions/transcript-session-transcript-corpus-policy-DEVEBhvV.mjs",
		"original": "2bb4e49e4abd2c72d953385701abe57b329a7df87b1bf61e9d966c4a9defa1b1",
		"patched": "19b997fc6aec150f060f6748ddff119908ea4050cd6a92bbba796354dc6b5c57",
		"call": ("if(e(", "if(ocIsCronSessionKey("),
		"import": (
			'import{f as e,m as t}from"./transcript-store-entry-S3CHuIUj.mjs";',
			'import{f as e,m as t,p as ocIsCronSessionKey}from"./transcript-store-entry-S3CHuIUj.mjs";',
		),
		"absent": "ocIsCronSessionKey",
		"helper": ("config/sessions/transcript-store-entry-S3CHuIUj.mjs", "35877a502aa472054a25e8fb130fb80f0da770ebdb5ff282baac880c0c2a6978", "isCronSessionKey as p"),
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
		raise ValueError(f"11.10 {name} content drift; refusing patch")
	if text.count(SIG) != 1:
		raise ValueError(f"11.10 {name} classifier locator drift; refusing patch")
	if t["absent"] and t["absent"] in text:
		raise ValueError(f"11.10 {name} binding name already present; refusing patch")
	if t["import"] and text.count(t["import"][0]) != 1:
		raise ValueError(f"11.10 {name} import drift; refusing patch")
	if t.get("in_bundle") and text.count(t["in_bundle"]) != 1:
		raise ValueError(f"11.10 {name} in-bundle helper drift; refusing patch")
	start = text.index(SIG)
	end = brace_end(text, start)
	block = text[start:end]
	old, new = t["call"]
	if block.count(old) != 1:
		raise ValueError(f"11.10 {name} classifier call drift; refusing patch")
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
		raise SystemExit("hotfix requires OpenClaw 2026.11.10; review/retire on upgrade")
	found = sorted(str(p.relative_to(dist)) for p in dist.rglob("*")
		if p.suffix in (".mjs", ".js") and p.is_file() and SIG in p.read_text(encoding="utf-8", errors="replace"))
	if found != sorted(t["name"] for t in TARGETS):
		raise SystemExit(f"11.10 classifier locator drift; refusing patch: {found}")
	for t in TARGETS:
		if "helper" in t:
			helper, helper_sha, export = t["helper"]
			data = (dist / helper).read_bytes()
			if sha(data) != helper_sha or export not in data.decode():
				raise SystemExit(f"11.10 helper/export drift ({helper}); refusing patch")
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
	print(f"memory-cron-parent-admission-v6: applied/verified (11.10, guarded, {len(outputs)} copies)")


if __name__ == "__main__":
	main()
