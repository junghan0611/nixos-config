# Custom fonts configuration
# Install PretendardVariable and MonoplexNerd fonts if available
{ config, lib, pkgs, ... }:

let
  fontsDir = ../../../fonts;
  fontFiles = builtins.readDir fontsDir;

  # Filter: PretendardVariable.ttf and MonoplexNerd-*.ttf
  customFonts = lib.filterAttrs (name: type:
    type == "regular" && lib.hasSuffix ".ttf" name &&
    (name == "PretendardVariable.ttf" || lib.hasPrefix "MonoplexNerd-" name)
  ) fontFiles;
in {
  # Install custom fonts to ~/.local/share/fonts/
  home.file = lib.mapAttrs' (name: _: {
    name = ".local/share/fonts/${name}";
    value = {
      source = "${fontsDir}/${name}";
    };
  }) customFonts;

  # Font configuration
  fonts.fontconfig.enable = true;
}
