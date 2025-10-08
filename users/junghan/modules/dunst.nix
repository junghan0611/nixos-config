# Dunst notification daemon configuration
# Based on ElleNajit's setup with Solarized colors
{ config, lib, pkgs, ... }:

let
  solarized = import ./solarized.nix;
  fontName = "D2CodingLigature Nerd Font";
  fontSize = 12;
in {
  services.dunst = {
    enable = true;

    settings = {
      global = {
        # Font
        font = "${fontName} ${toString fontSize}";

        # Markup
        allow_markup = true;
        format = ''<b>%s</b>
%b'';

        # Sorting
        sort = true;

        # Alignment
        alignment = "left";

        # Geometry
        geometry = "600x15-40+40";

        # Timeout
        idle_threshold = 120;

        # Separator
        separator_color = "frame";
        separator_height = 1;

        # Text wrapping
        word_wrap = true;

        # Padding
        padding = 8;
        horizontal_padding = 8;

        # Icon
        max_icon_size = 45;
      };

      frame = {
        width = 0;
        color = solarized.base01;
      };

      urgency_low = {
        background = solarized.base03;
        foreground = solarized.base0;
        timeout = 5;
      };

      urgency_normal = {
        background = solarized.base02;
        foreground = solarized.base0;
        timeout = 7;
      };

      urgency_critical = {
        background = solarized.red;
        foreground = solarized.base3;
        timeout = 0;
      };
    };
  };
}
