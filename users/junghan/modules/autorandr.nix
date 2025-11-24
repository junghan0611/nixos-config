# Autorandr configuration for automatic display management
# Profiles for laptop-only and dual-monitor setups
{ config, lib, pkgs, ... }:

{
  programs.autorandr = {
    enable = true;

    profiles = {
      # Laptop only (single monitor)
      "laptop" = {
        fingerprint = {
          eDP-1 = "*";
        };
        config = {
          eDP-1 = {
            enable = true;
            primary = true;
            mode = "1920x1080";
            rate = "59.98";
            position = "0x0";
          };
        };
      };

      # Dual monitor: External 4K above laptop
      # Layout: DP-1 (4K) on top, eDP-1 (laptop) below
      "dual-vertical" = {
        fingerprint = {
          eDP-1 = "*";
          DP-1 = "*";
        };
        config = {
          DP-1 = {
            enable = true;
            mode = "3840x2160";
            rate = "60.00";
            position = "0x0";
          };
          eDP-1 = {
            enable = true;
            primary = true;
            mode = "1920x1080";
            rate = "59.98";
            # Center laptop below 4K monitor: (3840-1920)/2 = 960
            position = "960x2160";
          };
        };
      };

      # Alternative: DP-2 connection
      "dual-vertical-dp2" = {
        fingerprint = {
          eDP-1 = "*";
          DP-2 = "*";
        };
        config = {
          DP-2 = {
            enable = true;
            mode = "3840x2160";
            rate = "60.00";
            position = "0x0";
          };
          eDP-1 = {
            enable = true;
            primary = true;
            mode = "1920x1080";
            rate = "59.98";
            position = "960x2160";
          };
        };
      };
    };

    hooks = {
      postswitch = {
        "notify" = ''
          ${pkgs.libnotify}/bin/notify-send "Display" "Profile switched"
        '';
        "reset-wallpaper" = ''
          ${pkgs.feh}/bin/feh --bg-scale ~/.config/nixos-wallpaper.png
        '';
      };
    };
  };

  # Auto-detect on login and hotplug
  services.autorandr = {
    enable = true;
  };
}
