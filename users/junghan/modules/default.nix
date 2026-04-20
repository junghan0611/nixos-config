# Home Manager modules
# This file aggregates all user-specific home-manager modules
{ currentSystemName ? "nuc" }:
{ lib, ... }:
let
  isOracle = currentSystemName == "oracle";
in
{
  imports = [
    # Phase 2: Shell configuration (git, bash, tmux, etc)
    ./shell.nix

    # Phase 5: Development environments
    ./development

    # Phase 6: Emacs configuration
    ./emacs.nix

    # Email (mu4e + mbsync)
    ./email.nix

    # Fonts
    ./fonts.nix
  ] ++ lib.optionals (!isOracle) [
    # Desktop-only 모듈 — Oracle headless 제외
    ./i3.nix         # i3 window manager config
    ./autorandr.nix  # display auto-layout
    ./dunst.nix      # notification daemon
    ./picom.nix      # compositor
    ./gtk.nix        # GTK dark theme
  ];
}
