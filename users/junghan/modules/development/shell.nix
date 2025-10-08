# Shell scripting development environment
{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    shfmt          # Shell formatter
    shellcheck     # Shell linter
    jq             # JSON processor
  ];

  # thefuck is optional - enable if desired
  # programs.thefuck = {
  #   enable = true;
  #   enableBashIntegration = true;
  # };
}
