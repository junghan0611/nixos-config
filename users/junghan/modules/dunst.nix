# Dunst notification daemon configuration
# Based on ElleNajit's setup with Solarized colors
{ config, lib, ... }:

let
  solarized = import ./solarized.nix;
  fontName = "D2Coding ligature";
  fontSize = 12;
in {
  services.dunst = {
    enable = true;

    settings = {
      global = {
        # Font
        font = "${fontName} ${toString fontSize}";

        # Markup (allow_markup → markup in dunst 1.5+)
        markup = "full";
        format = "<b>%s</b>\\n%b";

        # Sorting
        sort = true;

        # Alignment
        alignment = "left";

        # Geometry (geometry → width/height/offset/origin in dunst 1.5+)
        width = 600;
        height = 300;
        origin = "top-right";
        offset = "40x40";

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

        # Frame (frame section → global in dunst 1.5+)
        frame_width = 0;
        frame_color = solarized.base01;
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
        timeout = 10;
      };

      # Claude Code notifications (visual only — sound handled by peon-ping hooks)
      claudecode_sound = {
        appname = "claude-code";
        background = "#cc241d";
        foreground = "#ebdbb2";
        frame_color = "#fb4934";
        urgency = "normal";
      };
    };
  };

  # Deploy Claude Code notification script (fallback when peon-ping is not active)
  home.file = {
    ".config/dunst/claude-notify.sh" = {
      source = ../configs/dunst/claude-notify.sh;
      executable = true;
    };
  };
}
