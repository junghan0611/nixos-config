# C/C++ development environment
{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    lldb
    clang-tools
    # gcc is already in system packages
  ];
}
