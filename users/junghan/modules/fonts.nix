# Custom fonts configuration
{ config, lib, pkgs, ... }:

let
  # MonoplexNerd font package
  monoplex-nerd = pkgs.stdenvNoCC.mkDerivation {
    name = "monoplex-nerd";
    version = "1.0";

    src = ../../fonts/MonoplexNerd.zip;

    dontUnpack = false;
    buildInputs = [ pkgs.unzip ];

    unpackPhase = ''
      unzip $src
    '';

    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      find . -name "*.ttf" -not -path "*/__MACOSX/*" -exec cp {} $out/share/fonts/truetype/ \;
    '';

    meta = with lib; {
      description = "Monoplex Nerd Font";
      platforms = platforms.all;
    };
  };
in {
  home.packages = with pkgs; [
    monoplex-nerd
  ];

  # Font configuration
  fonts.fontconfig.enable = true;
}
