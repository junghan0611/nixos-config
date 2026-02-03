#!/usr/bin/env bash
# Hancom Office (한컴오피스) installer for NixOS
# Installs HWP word processor with kime Korean input support
#
# Usage: ./install-hoffice.sh
#
# What this script does:
# 1. Downloads hoffice .deb package
# 2. Extracts to /opt/hnc
# 3. Downloads kime Qt 5.11.3 plugin (for Korean input)
# 4. Installs hwp wrapper script to ~/bin

set -e

# URLs
HOFFICE_URL="https://dl.dropbox.com/scl/fi/ia3ub05nti01h8lzb3vwr/1732118678_hoffice_11.20.0.1520_amd64.deb?rlkey=8bnxl9chpm7rt6sr6nc4eoqp0&st=yaxlb481&dl=0"
KIME_QT_URL="https://github.com/Riey/kime/releases/latest/download/libkime-qt-5.11.3.so"

# Paths
HOFFICE_DIR="/opt/hnc"
HOFFICE_BIN="$HOFFICE_DIR/opt/hnc/hoffice11/Bin"
BIN_DIR="$HOME/bin"
CACHE_FILE="$HOME/.cache/hoffice-libs.sh"
TMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "=== Hancom Office Installer for NixOS ==="
echo ""

# Check if already installed
if [[ -d "$HOFFICE_BIN" ]]; then
    echo "Hancom Office already installed at $HOFFICE_DIR"
    read -p "Reinstall? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    sudo rm -rf "$HOFFICE_DIR"
fi

# Step 1: Download .deb package
echo "[1/5] Downloading Hancom Office .deb package..."
DEB_FILE="$TMP_DIR/hoffice.deb"
curl -L -o "$DEB_FILE" "$HOFFICE_URL"
echo "Downloaded: $(du -h "$DEB_FILE" | cut -f1)"

# Step 2: Extract to /opt/hnc
echo "[2/5] Extracting to $HOFFICE_DIR..."
sudo mkdir -p "$HOFFICE_DIR"
sudo chown "$USER:users" "$HOFFICE_DIR"
nix-shell -p dpkg --run "dpkg-deb -x '$DEB_FILE' '$HOFFICE_DIR'"
echo "Extracted successfully."

# Step 3: Download kime Qt 5.11.3 plugin
echo "[3/5] Downloading kime Qt 5.11.3 plugin..."
KIME_PLUGIN="$TMP_DIR/libkime-qt-5.11.3.so"
curl -L -o "$KIME_PLUGIN" "$KIME_QT_URL"

# Install kime plugin to hoffice Qt directory
PLATFORMINPUTCONTEXTS="$HOFFICE_BIN/qt/plugins/platforminputcontexts"
cp "$KIME_PLUGIN" "$PLATFORMINPUTCONTEXTS/libkimeplatforminputcontextplugin.so"
echo "Installed kime plugin."

# Step 4: Create wrapper script
echo "[4/5] Creating wrapper script..."
mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/hoffice-wrapper" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# Hancom Office wrapper for NixOS
# Caches library paths for fast startup, regenerates on system update

set -e

HOFFICE_DIR="/opt/hnc/opt/hnc/hoffice11"
HOFFICE_BIN="$HOFFICE_DIR/Bin"
CACHE_FILE="$HOME/.cache/hoffice-libs.sh"

# Determine which app to run from symlink name or argument
SCRIPT_NAME=$(basename "$0")

case "$SCRIPT_NAME" in
    hwp|hcl|hsl|hword)
        APP="$SCRIPT_NAME"
        ;;
    *)
        APP="${1:-hwp}"
        shift 2>/dev/null || true
        ;;
esac

case "$APP" in
    hwp|hcl|hsl|hword)
        EXEC="$HOFFICE_BIN/$APP"
        ;;
    *)
        echo "Usage: hwp [args...] or hoffice-wrapper [hwp|hcl|hsl|hword] [args...]"
        exit 1
        ;;
esac

# Generate library paths cache
generate_cache() {
    echo "Generating library paths cache..." >&2
    mkdir -p "$(dirname "$CACHE_FILE")"

    find_lib() {
        local pkg="$1"
        local result=$(nix-build '<nixpkgs>' -A "$pkg" --no-out-link 2>/dev/null)
        [[ -d "$result/lib" ]] && echo "$result/lib"
    }

    local LIBS=""
    for pkg in xorg.libxcb xorg.libX11 xorg.libXext xorg.libXrender xorg.libXi xorg.libXrandr \
               xorg.libXcursor xorg.libXfixes xorg.libXinerama xorg.libXcomposite xorg.libXdamage \
               xorg.libxkbfile xorg.libXau xorg.libXdmcp libxkbcommon cups.lib stdenv.cc.cc.lib \
               zlib libGL libGLU fontconfig.lib freetype dbus.lib glib.out expat bzip2.out \
               libpng libjpeg.out harfbuzz icu openssl.out pcre2 util-linux.lib cairo pixman \
               pango.out gdk-pixbuf libdrm libffi fribidi graphite2 kime; do
        local p=$(find_lib "$pkg")
        [[ -n "$p" ]] && LIBS="$LIBS:$p"
    done

    # harfbuzz-icu (separate output)
    local HB_ICU=$(find /nix/store -maxdepth 2 -name "*harfbuzz-icu*" -type d 2>/dev/null | head -1)
    [[ -n "$HB_ICU" ]] && LIBS="$LIBS:$HB_ICU/lib"

    cat > "$CACHE_FILE" << EOF
# Generated: $(date)
# System: $(readlink /run/current-system)
NIX_LIBS="${LIBS#:}"
EOF
    echo "Cache generated: $CACHE_FILE" >&2
}

# Check if cache is valid (system hasn't changed)
CURRENT_SYSTEM=$(readlink /run/current-system 2>/dev/null || echo "unknown")

if [[ -f "$CACHE_FILE" ]]; then
    CACHED_SYSTEM=$(grep "^# System:" "$CACHE_FILE" 2>/dev/null | cut -d' ' -f3-)
    if [[ "$CACHED_SYSTEM" != "$CURRENT_SYSTEM" ]]; then
        generate_cache
    fi
else
    generate_cache
fi

# Load cached paths
source "$CACHE_FILE"

# Set environment variables
export LD_LIBRARY_PATH="$HOFFICE_BIN:$HOFFICE_BIN/qt/lib:$NIX_LIBS${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="$HOFFICE_BIN/qt/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"

# Korean locale for UI
export LANG=ko_KR.UTF-8
export LC_ALL=ko_KR.UTF-8

# Input method (kime)
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
export GTK_IM_MODULE=kime

cd "$HOFFICE_BIN"
exec "$EXEC" "$@"
WRAPPER_EOF

chmod +x "$BIN_DIR/hoffice-wrapper"

# Create symlink for hwp
ln -sf hoffice-wrapper "$BIN_DIR/hwp"

echo "Installed: $BIN_DIR/hwp"

# Step 5: Generate initial cache
echo "[5/5] Generating library paths cache (this may take a moment)..."
rm -f "$CACHE_FILE"
"$BIN_DIR/hwp" --help >/dev/null 2>&1 || true

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Usage:"
echo "  hwp                  # Launch HWP (한글)"
echo "  hwp document.hwp     # Open a file"
echo ""
echo "Korean input: Press Shift+Space to toggle (kime)"
echo ""
echo "Installed files:"
echo "  $HOFFICE_DIR/           # Hancom Office binaries"
echo "  $BIN_DIR/hwp             # Wrapper script"
echo "  $CACHE_FILE  # Library paths cache"
