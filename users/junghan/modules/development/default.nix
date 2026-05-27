# Development environment configuration
# Aggregates language-specific development modules
{ config, lib, pkgs, ... }:

{
  imports = [
    ./c.nix
    ./elisp.nix
    ./latex.nix
    ./nix.nix
    ./python.nix
    ./shell.nix
  ];

  # Common development tools
  home.packages = with pkgs; [
    # Documentation
    mdbook

    # Version control
    gh              # GitHub CLI
    trufflehog      # Secret scanning in git repos (deep history)
    gitleaks        # Secret scanning — used by agent-config global pre-commit/pre-push hooks

    # Build tools
    libnotify
    autoconf
    automake
    libtool
    m4

    # AI tools
    aider-chat
  ];
}
