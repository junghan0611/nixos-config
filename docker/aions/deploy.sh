#!/usr/bin/env bash
# Publish aionsclubs git tree → live web root (oracle).
# Creator-mode: no fortress. Only refuse obvious secret filenames.
set -euo pipefail

REPO="${AIONS_REPO:-$HOME/repos/gh/aionsclubs}"
WEB="${AIONS_WEB:-$HOME/docker-data/aions}"
RELEASES="$WEB/releases"

if [[ ! -d "$REPO/.git" ]]; then
	echo "not a git repo: $REPO" >&2
	exit 1
fi
if [[ ! -d "$WEB" ]]; then
	echo "web root missing: $WEB (oracle Stage A path)" >&2
	exit 1
fi

cd "$REPO"
# dirty tree ok for B iteration — snapshot working tree + HEAD label
SHA=$(git rev-parse --short HEAD)
if [[ -n "$(git status --porcelain)" ]]; then
	LABEL="${SHA}-dirty-$(date +%Y%m%dT%H%M%S)"
	echo "note: working tree dirty → release $LABEL"
else
	LABEL="$SHA"
fi

# refuse shipping common secret names (soft gate — homepage work stays easy)
if git ls-files | rg -n '(^|/)\.env(\.|$)|credentials|\.pem$|\.key$|id_rsa|cf-token' >/dev/null; then
	echo "refusing deploy: secret-like path tracked in git" >&2
	git ls-files | rg '(^|/)\.env(\.|$)|credentials|\.pem$|\.key$|id_rsa|cf-token' >&2 || true
	exit 2
fi

DEST="$RELEASES/$LABEL"
if [[ -e "$DEST" ]]; then
	echo "release exists: $DEST (already published?)" >&2
	# still retarget current
else
	mkdir -p "$DEST"
	# copy tree without .git
	if command -v git >/dev/null; then
		git archive HEAD | tar -x -C "$DEST"
		# if dirty, overlay working tree files on top of archive
		if [[ -n "$(git status --porcelain)" ]]; then
			rsync -a --delete --exclude='.git/' "$REPO"/ "$DEST"/
		fi
	else
		rsync -a --delete --exclude='.git/' "$REPO"/ "$DEST"/
	fi
	# drop agent-only docs from public HTML tree? keep them — static is fine, B decides
	printf '%s\n' "$LABEL" "$(git rev-parse HEAD)" "$(date -Iseconds)" >"$DEST/.deployed"
fi

ln -sfn "releases/$LABEL" "$WEB/current.new"
mv -Tf "$WEB/current.new" "$WEB/current"
echo "published → $WEB/current -> releases/$LABEL"
echo "check: curl -sI https://aionsclubs.org | head -1"
