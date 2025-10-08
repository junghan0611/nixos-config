# Home Manager modules
# This file aggregates all user-specific home-manager modules
{
  imports = [
    # Phase 2: Shell configuration (git, bash, tmux, etc)
    ./shell.nix

    # Phase 3: i3 window manager configuration
    ./i3.nix

    # Phase 4: Dunst notification daemon
    ./dunst.nix

    # Phase 5: Development environments
    ./development

    # Phase 6: Emacs configuration (optional)
    # ./emacs.nix
  ];
}
