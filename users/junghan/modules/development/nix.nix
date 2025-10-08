# Nix development environment
{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    nixd              # Nix language server
    nil               # Alternative Nix LSP
    nixfmt-classic    # Nix formatter
  ];
}
