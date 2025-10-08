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
