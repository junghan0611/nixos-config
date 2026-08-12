#!/usr/bin/env bash
# Ops entry — delegates to aionsclubs self-contained publish.
set -euo pipefail
REPO="${AIONS_REPO:-$HOME/repos/gh/aionsclubs}"
exec "$REPO/scripts/publish"
