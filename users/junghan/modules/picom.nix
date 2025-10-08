# Picom compositor configuration
# Based on Regolith Linux picom config
{ config, lib, pkgs, ... }:

{
  services.picom = {
    enable = true;
    backend = "glx";
    vSync = true;

    # Shadow settings
    shadow = true;
    shadowOffsets = [ (-5) (-5) ];
    shadowOpacity = 0.8;

    shadowExclude = [
      "! name~=''"
      "name = 'Notification'"
      "name = 'Plank'"
      "name = 'Docky'"
      "name = 'Kupfer'"
      "name = 'xfce4-notifyd'"
      "name *= 'compton'"
      "name *= 'picom'"
      "name *= 'cpt_frame_window'"
      "name *= 'cpt_frame_xcb_window'"
      "name *= 'wrapper-2.0'"
      "class_g = 'Conky'"
      "class_g = 'Kupfer'"
      "class_g = 'Synapse'"
      "class_g ?= 'Notify-osd'"
      "class_g ?= 'Cairo-dock'"
      "_GTK_FRAME_EXTENTS@:c"
      "_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'"
    ];

    # Fading
    fade = true;
    fadeDelta = 3;
    fadeSteps = [ 0.03 0.03 ];
    fadeExclude = [
      "name *= 'ilia'"
    ];

    # Opacity
    opacityRules = [
      "100:class_g = 'i3lock'"
    ];

    settings = {
      # GLX backend settings
      glx-no-stencil = true;
      glx-copy-from-front = false;
      glx-no-rebind-pixmap = true;
      use-damage = true;
      xrender-sync-fence = true;

      # Shadow
      shadow-radius = 7;
      shadow-ignore-shaped = false;

      # Opacity
      inactive-opacity = 1.0;
      active-opacity = 1.0;
      frame-opacity = 1.0;
      inactive-opacity-override = false;

      # Dimming
      inactive-dim = 0.03;
      inactive-dim-fixed = true;

      # Blur
      blur-background-fixed = false;
      blur-background-exclude = [
        "window_type = 'dock'"
        "window_type = 'desktop'"
      ];

      # Other
      mark-wmwin-focused = true;
      mark-ovredir-focused = true;
      use-ewmh-active-win = true;
      detect-rounded-corners = true;
      detect-client-opacity = true;
      detect-transient = true;
      detect-client-leader = true;
      xinerama-shadow-crop = true;

      # Performance
      unredir-if-possible = true;  # Unredirect fullscreen windows

      # Window type settings
      wintypes = {
        tooltip = {
          fade = true;
          shadow = false;
          opacity = 0.85;
          focus = true;
        };
        dock = {
          shadow = true;
        };
        dnd = {
          shadow = false;
        };
        popup_menu = {
          opacity = 1.0;
          shadow = false;
          fade = false;
        };
        dropdown_menu = {
          opacity = 1.0;
          fade = false;
        };
      };
    };
  };
}
