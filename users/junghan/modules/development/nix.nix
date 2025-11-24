# Nix development environment
{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    nixd              # Nix language server
    nil               # Alternative Nix LSP
    nixfmt-classic    # Nix formatter LEGACY
    # nixfmt-rfc-style  # Nix formatter NEW
    statix # linter for nix
    nix-init # auto create nix expressions
    nixpkgs-review # review upstream PRs
    nix-update # update package in nix
  ];
}
