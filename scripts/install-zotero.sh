#!/usr/bin/env bash
# Zotero 8.x installer for NixOS
# Installs Zotero from official tar.xz with NixOS library wrapper
#
# Usage: ./install-zotero.sh [path-to-tarball]
#   If no argument, auto-detects latest Zotero tarball in ~/Downloads
#
# What this script does:
# 1. Extracts Zotero tar.xz to /opt/zotero
# 2. Creates wrapper script in ~/bin/zotero with NixOS library paths
# 3. Installs .desktop file for application launchers

set -e

# Auto-detect latest Zotero tarball in ~/Downloads
find_latest_tarball() {
    local latest=""
    local latest_ver="0"
    for f in "$HOME/Downloads"/Zotero-*_linux-x86_64.tar.xz; do
        [[ -f "$f" ]] || continue
        # Extract version: Zotero-8.0.3_linux-x86_64.tar.xz → 8.0.3
        local ver=$(basename "$f" | sed 's/Zotero-\(.*\)_linux-x86_64\.tar\.xz/\1/')
        # Compare versions using sort -V (version sort)
        if printf '%s\n%s\n' "$latest_ver" "$ver" | sort -V | tail -1 | grep -qx "$ver"; then
            latest_ver="$ver"
            latest="$f"
        fi
    done
    echo "$latest"
}

# Configuration
if [[ -n "$1" ]]; then
    TARBALL="$1"
else
    TARBALL=$(find_latest_tarball)
fi
INSTALL_DIR="/opt/zotero"
BIN_DIR="$HOME/bin"
CACHE_FILE="$HOME/.cache/zotero-libs.sh"
DESKTOP_DIR="$HOME/.local/share/applications"

if [[ -z "$TARBALL" || ! -f "$TARBALL" ]]; then
    echo "Error: No Zotero tarball found."
    echo "Usage: $0 [path-to-Zotero-tarball.tar.xz]"
    echo "Or place Zotero-*_linux-x86_64.tar.xz in ~/Downloads"
    exit 1
fi

VERSION=$(basename "$TARBALL" | sed 's/Zotero-\(.*\)_linux-x86_64\.tar\.xz/\1/')

echo "=== Zotero $VERSION Installer for NixOS ==="
echo ""
echo "Tarball: $TARBALL"
echo "Version: $VERSION"
echo "Install: $INSTALL_DIR"
echo ""

# Check if already installed
if [[ -d "$INSTALL_DIR" ]]; then
    echo "Zotero already installed at $INSTALL_DIR"
    read -p "Reinstall? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    sudo rm -rf "$INSTALL_DIR"
fi

# Step 1: Extract tarball
echo "[1/4] Extracting to $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"
sudo tar -xJf "$TARBALL" -C "$INSTALL_DIR" --strip-components=1
sudo chown -R root:root "$INSTALL_DIR"
echo "Extracted successfully."

# Step 2: Create wrapper script
echo "[2/4] Creating wrapper script..."
mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/zotero" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# Zotero 8 wrapper for NixOS
# Caches library paths for fast startup, regenerates on system update

set -e

ZOTERO_DIR="/opt/zotero"
CACHE_FILE="$HOME/.cache/zotero-libs.sh"

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
    for pkg in \
        gtk3 \
        glib.out \
        gdk-pixbuf \
        pango.out \
        cairo \
        atk \
        dbus.lib \
        fontconfig.lib \
        freetype \
        alsa-lib \
        stdenv.cc.cc.lib \
        xorg.libX11 \
        xorg.libXcomposite \
        xorg.libXdamage \
        xorg.libXext \
        xorg.libXfixes \
        xorg.libXrandr \
        xorg.libXrender \
        xorg.libXcursor \
        xorg.libXi \
        xorg.libxcb \
        libxkbcommon \
        cups.lib \
        libGL \
        zlib \
        harfbuzz \
        expat \
        fribidi \
        libdrm \
        mesa.drivers \
        pipewire.lib \
    ; do
        local p=$(find_lib "$pkg")
        [[ -n "$p" ]] && LIBS="$LIBS:$p"
    done

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

# Set library paths (Zotero bundled libs + NixOS system libs)
export LD_LIBRARY_PATH="$ZOTERO_DIR:$NIX_LIBS${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

export MOZ_ALLOW_DOWNGRADE=1
export MOZ_LEGACY_PROFILES=1

# Clean browser launcher: Zotero spawns Firefox via GIO, which inherits
# LD_LIBRARY_PATH containing /opt/zotero. This causes libnss3.so version
# conflicts. Prepend a clean firefox wrapper to PATH to strip LD_LIBRARY_PATH.
WRAPPER_DIR="$HOME/.cache/zotero-wrappers"
mkdir -p "$WRAPPER_DIR"
REAL_FIREFOX=$(readlink -f "$(which firefox)")
cat > "$WRAPPER_DIR/firefox" << FWEOF
#!/bin/sh
unset LD_LIBRARY_PATH
exec "$REAL_FIREFOX" "\$@"
FWEOF
chmod +x "$WRAPPER_DIR/firefox"
export PATH="$WRAPPER_DIR:$PATH"

# Execute Zotero directly (bypass /bin/bash shebang issue on NixOS)
ulimit -n 4096
exec "$ZOTERO_DIR/zotero-bin" -app "$ZOTERO_DIR/app/application.ini" "$@"
WRAPPER_EOF

chmod +x "$BIN_DIR/zotero"
echo "Installed: $BIN_DIR/zotero"

# Step 3: Install .desktop file
echo "[3/4] Installing desktop entry..."
mkdir -p "$DESKTOP_DIR"

cat > "$DESKTOP_DIR/zotero.desktop" << EOF
[Desktop Entry]
Name=Zotero
Comment=Open-source reference manager
Exec=$BIN_DIR/zotero %u
Icon=$INSTALL_DIR/icons/icon128.png
Type=Application
Terminal=false
Categories=Office;Database;
MimeType=x-scheme-handler/zotero;application/x-research-info-systems;text/x-research-info-systems;text/ris;application/x-endnote-refer;application/x-inst-for-scientific-info;application/mods+xml;application/rdf+xml;application/x-bibtex;text/x-bibtex;application/marc;application/vnd.citationstyles.style+xml;
StartupWMClass=Zotero
EOF

echo "Installed: $DESKTOP_DIR/zotero.desktop"

# Step 4: Generate initial cache
echo "[4/4] Generating library paths cache (this may take a moment)..."
rm -f "$CACHE_FILE"
source <("$BIN_DIR/zotero" --version 2>/dev/null; echo "") || true

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Usage:"
echo "  zotero                  # Launch Zotero"
echo "  zotero /path/to/file    # Open a file"
echo ""
echo "Installed files:"
echo "  $INSTALL_DIR/            # Zotero binaries"
echo "  $BIN_DIR/zotero          # Wrapper script"
echo "  $DESKTOP_DIR/zotero.desktop"
echo "  $CACHE_FILE   # Library paths cache (auto-regenerated)"
echo ""
echo "To uninstall:"
echo "  sudo rm -rf $INSTALL_DIR"
echo "  rm $BIN_DIR/zotero $DESKTOP_DIR/zotero.desktop $CACHE_FILE"
