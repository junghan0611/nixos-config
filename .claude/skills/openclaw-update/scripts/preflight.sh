#!/usr/bin/env bash
# OpenClaw update preflight — read-only. Prints the facts that decide minor vs major.
# Usage: preflight.sh <target-version>   e.g. preflight.sh 2026.10.3
# Touches nothing: GitHub API, registry manifest (no layer download), docker/df reads.
set -uo pipefail

TARGET="${1:?usage: preflight.sh <target-version>}"
R=repos/openclaw/openclaw
L="$HOME/openclaw"
IMG=ghcr.io/openclaw/openclaw

live=$(docker exec openclaw-gateway openclaw --version 2>/dev/null)
CURRENT=$(sed -E 's/.*OpenClaw ([0-9.]+).*/\1/' <<<"$live")
echo "== live: $live"
[ -n "$CURRENT" ] || { echo "cannot read live version"; exit 2; }

echo "== declared schemaVersions (package.json openclaw.schemaVersions)"
schema() { gh api "$R/contents/package.json?ref=v$1" -H 'Accept: application/vnd.github.raw' \
	| python3 -c 'import json,sys;d=json.load(sys.stdin);print(json.dumps((d.get("openclaw") or {}).get("schemaVersions"),sort_keys=True))'; }
SC=$(schema "$CURRENT"); ST=$(schema "$TARGET")
echo "  $CURRENT: $SC"
echo "  $TARGET: $ST"

echo "== compare v$CURRENT...v$TARGET"
gh api "$R/compare/v$CURRENT...v$TARGET" -q '"  status=\(.status) ahead=\(.ahead_by) behind=\(.behind_by)"'
COMMIT=$(gh api "$R/commits/v$TARGET" -q .sha)
echo "  v$TARGET commit: $COMMIT"

echo "== registry (no pull)"
ARM=$(docker buildx imagetools inspect --raw "$IMG:$TARGET" \
	| python3 -c 'import json,sys;print(next(m["digest"] for m in json.load(sys.stdin)["manifests"] if m.get("platform",{}).get("architecture")=="arm64"))')
REV=$(docker buildx imagetools inspect "$IMG@$ARM" --format '{{json .Image}}' \
	| python3 -c 'import json,sys;print((json.load(sys.stdin).get("config",{}).get("Labels") or {}).get("org.opencontainers.image.revision"))')
echo "  arm64 manifest: $ARM"
echo "  label revision: $REV $([ "$REV" = "$COMMIT" ] && echo '(= tag commit)' || echo '(!= tag commit — STOP)')"
echo "  Dockerfile pin now: $(grep -oE 'OPENCLAW_BASE=[^ ]+' "$L/Dockerfile")"

echo "== local hotfix guards"
for p in "$L"/patch-*.py; do
	[ -e "$p" ] || continue
	v=$(grep -oE '^VERSION = "[^"]+"' "$p" | cut -d'"' -f2)
	echo "  $(basename "$p"): VERSION=$v $([ "$v" = "$TARGET" ] && echo ok || echo '→ build will fail closed; port it (SKILL step 4)')"
done

echo "== disk (docker on root, ~/openclaw on home)"
df -h / /home | sed 's/^/  /'
docker system df | sed 's/^/  /'
docker system df -v 2>/dev/null | awk '/^Images space usage/,/^Containers space usage/' \
	| grep -E 'openclaw' | awk '{printf "  %-40s %-36s unique=%s\n",$1,$2,$(NF-1)}'

echo "== verdict"
if [ "$SC" = "$ST" ] && [ "$SC" != "null" ]; then
	echo "  MINOR (schema identical) — swap only, per GLG. Still confirm in the pulled image."
else
	echo "  MAJOR or UNKNOWN (schema differs/missing) — outside the GLG minor rule; decide separately."
fi
