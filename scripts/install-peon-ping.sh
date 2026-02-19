#!/usr/bin/env bash
# peon-ping installer for NixOS
# Wraps the official install.sh from local clone at ~/repos/3rd/peon-ping
#
# Usage:
#   bash scripts/install-peon-ping.sh                    # en+ko packs (default)
#   bash scripts/install-peon-ping.sh --langs=en,ko,fr   # specific languages
#   bash scripts/install-peon-ping.sh --all               # all packs
#   bash scripts/install-peon-ping.sh --packs=peon,glados # specific packs

set -euo pipefail

PEON_REPO="$HOME/repos/3rd/peon-ping"

if [ ! -d "$PEON_REPO" ]; then
  echo "Error: peon-ping repo not found at $PEON_REPO"
  echo "Clone it first: git clone https://github.com/PeonPing/peon-ping.git $PEON_REPO"
  exit 1
fi

# --- Argument parsing ---
LANGS=""
PASSTHROUGH_ARGS=()
HAS_PACKS_OR_ALL=false

for arg in "$@"; do
  case "$arg" in
    --langs=*)
      LANGS="${arg#--langs=}"
      ;;
    --packs=*|--all)
      HAS_PACKS_OR_ALL=true
      PASSTHROUGH_ARGS+=("$arg")
      ;;
    *)
      PASSTHROUGH_ARGS+=("$arg")
      ;;
  esac
done

# Conflict check: --langs with --packs/--all
if [ -n "$LANGS" ] && [ "$HAS_PACKS_OR_ALL" = true ]; then
  echo "Error: --langs cannot be combined with --packs or --all"
  exit 1
fi

# Default: --langs=en,ko when neither --langs nor --packs/--all specified
if [ -z "$LANGS" ] && [ "$HAS_PACKS_OR_ALL" = false ]; then
  LANGS="en,ko"
fi

echo "=== peon-ping NixOS installer ==="
echo ""

# 0) Update upstream repo
echo "[0/7] Updating peon-ping upstream repo..."
if git -C "$PEON_REPO" pull --ff-only 2>/dev/null; then
  echo "  Updated to latest upstream"
else
  echo "  Already up-to-date (or not on tracking branch)"
fi
echo ""

# 1) Resolve --langs to --packs via registry
if [ -n "$LANGS" ]; then
  echo "[1/7] Fetching pack registry and filtering by language: $LANGS ..."
  REGISTRY_URL="https://peonping.github.io/registry/index.json"
  PACKS_CSV=$(curl -fsSL "$REGISTRY_URL" | python3 -c "
import json, sys
langs = set('$LANGS'.split(','))
data = json.load(sys.stdin)
names = []
for p in data.get('packs', []):
    pack_langs = set(p.get('language', '').split(','))
    if pack_langs & langs:
        names.append(p['name'])
print(','.join(names))
  ")
  PACK_COUNT=$(echo "$PACKS_CSV" | tr ',' '\n' | wc -l)
  echo "  Languages: $LANGS -> $PACK_COUNT packs"
  PASSTHROUGH_ARGS+=("--packs=$PACKS_CSV")
fi

echo ""
echo "[2/7] Running official peon-ping installer..."
cd "$PEON_REPO" && bash install.sh "${PASSTHROUGH_ARGS[@]}"

# 2) NixOS: /bin/bash doesn't exist — patch shebangs to #!/usr/bin/env bash
INSTALL_DIR="$HOME/.claude/hooks/peon-ping"

echo ""
echo "[3/7] Patching shebangs for NixOS (/bin/bash -> /usr/bin/env bash)..."

for f in "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/scripts/*.sh "$INSTALL_DIR"/adapters/*.sh; do
  [ -f "$f" ] || continue
  if head -1 "$f" | grep -q '^#!/bin/bash'; then
    sed -i '1s|^#!/bin/bash|#!/usr/bin/env bash|' "$f"
    echo "  Patched: $(basename "$f")"
  fi
done

# 3) NixOS: ~/.bashrc is read-only (home-manager symlink), write to ~/.bashrc.local
BASHRC_LOCAL="$HOME/.bashrc.local"

echo ""
echo "[4/7] Adding peon alias and completions to ~/.bashrc.local..."

touch "$BASHRC_LOCAL"

if ! grep -qF 'alias peon=' "$BASHRC_LOCAL"; then
  cat >> "$BASHRC_LOCAL" << EOF

# peon-ping quick controls
alias peon="bash $INSTALL_DIR/peon.sh"
[ -f "$INSTALL_DIR/completions.bash" ] && source "$INSTALL_DIR/completions.bash"
EOF
  echo "  Added peon alias + completions to $BASHRC_LOCAL"
else
  echo "  Already present in $BASHRC_LOCAL"
fi

# 4) OpenCode adapter — symlink packs to share with Claude Code
echo ""
echo "[5/7] Setting up OpenCode peon-ping adapter..."

OPENCODE_PACKS="$HOME/.openpeon/packs"
CLAUDE_PACKS="$INSTALL_DIR/packs"

# Run the adapter (downloads TS plugin + creates config)
if [ -f "$INSTALL_DIR/adapters/opencode.sh" ]; then
  bash "$INSTALL_DIR/adapters/opencode.sh"

  # Symlink packs: ~/.openpeon/packs → Claude's packs (avoid duplication)
  if [ -d "$CLAUDE_PACKS" ]; then
    if [ -L "$OPENCODE_PACKS" ]; then
      echo "  Symlink already exists: $OPENCODE_PACKS"
    elif [ -d "$OPENCODE_PACKS" ]; then
      # Adapter created its own dir with default pack — replace with symlink
      rm -rf "$OPENCODE_PACKS"
      ln -s "$CLAUDE_PACKS" "$OPENCODE_PACKS"
      echo "  Symlinked: $OPENCODE_PACKS -> $CLAUDE_PACKS"
    else
      mkdir -p "$(dirname "$OPENCODE_PACKS")"
      ln -s "$CLAUDE_PACKS" "$OPENCODE_PACKS"
      echo "  Symlinked: $OPENCODE_PACKS -> $CLAUDE_PACKS"
    fi
  fi
else
  echo "  Skip: OpenCode adapter not found"
fi

# 5) Set up project-specific pack configs
echo ""
echo "[6/7] Setting up project-specific sound packs..."

setup_project_config() {
  local project_dir="$1"
  local pack_name="$2"
  local config_dir="$project_dir/.claude/hooks/peon-ping"
  local config_file="$config_dir/config.json"

  if [ ! -d "$project_dir" ]; then
    echo "  Skip: $project_dir (not found)"
    return
  fi

  if [ -f "$config_file" ]; then
    echo "  Exists: $config_file"
    return
  fi

  mkdir -p "$config_dir"
  cat > "$config_file" << EOF
{
  "active_pack": "$pack_name"
}
EOF
  echo "  Created: $config_file (pack: $pack_name)"
}

setup_project_config "$HOME/repos/gh/nixos-config" "peon"
setup_project_config "$HOME/repos/work/hej-nixos-cluster" "sc_battlecruiser"
setup_project_config "$HOME/repos/gh/doomemacs-config" "glados"

# 6) ntfy mobile notification guidance
echo ""
echo "[7/7] Summary"
echo ""
echo "  ntfy mobile notifications:"
echo "    peon mobile ntfy <your-topic>"
echo "    peon mobile test"
echo ""
echo "=== NixOS-specific notes ==="
echo ""
echo "  Claude Code:"
echo "    - Alias 'peon' via shell.nix (home-manager)"
echo "    - Sound packs: ~/.claude/hooks/peon-ping/packs/"
echo "    - Dunst visual notifications remain; sound via peon-ping hooks"
echo ""
echo "  OpenCode:"
echo "    - Plugin: ~/.config/opencode/plugins/peon-ping.ts"
echo "    - Config: ~/.config/opencode/peon-ping/config.json"
echo "    - Packs: ~/.openpeon/packs -> symlink to Claude packs"
echo ""
echo "Quick test:"
echo "  peon status"
echo "  peon preview session.start"
echo "  peon preview task.complete"
