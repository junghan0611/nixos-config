# i3 window manager configuration
# Declarative i3 config with Solarized color scheme
{ config, lib, pkgs, ... }:

let
  mod = "Mod4";
  alt = "Mod1";

  # Solarized color scheme
  solarized = import ./solarized.nix;

  # Font configuration
  fontName = "D2CodingLigature Nerd Font";
  fontSize = 9;
  barFontSize = 11;

  fonts = {
    names = [ fontName ];
    size = fontSize * 1.0;
  };

  # py3status configuration (ElleNajit pattern)
  py3status = pkgs.python3Packages.py3status;

  i3status-conf = pkgs.writeText "i3status.conf" ''
    general {
        output_format = i3bar
        colors = true
        interval = 1
        color_good = "${solarized.green}"
        color_bad = "${solarized.red}"
        color_degraded = "${solarized.yellow}"
    }

    order += "read_file emacs_task"
    order += "ethernet _first_"
    order += "disk /"
    order += "load"
    order += "memory"
    order += "tztime local"

    read_file emacs_task {
        format = "Task: %content"
        path = "${config.home.homeDirectory}/.emacs.d/current-task"
        color_good = "${solarized.cyan}"
    }

    ethernet _first_ {
        format_up = "E: %ip (%speed)"
        format_down = "E: down"
    }

    disk "/" {
        format = "/ %avail"
    }

    load {
        format = "%1min"
    }

    memory {
        format = "%used / %total"
        threshold_degraded = "1G"
        format_degraded = "MEMORY < %available"
    }

    tztime local {
        format = "%Y-%m-%d %H:%M:%S"
    }
  '';
in {
  xsession.windowManager.i3 = {
    enable = true;

    config = {
      modifier = mod;

      # Fonts
      fonts = fonts;

      # Gaps (from Xresources)
      gaps = {
        inner = 12;
        outer = 8;
      };

      # Window appearance
      window = {
        border = 5;  # Xresources: wm.window.border.size
        titlebar = true;
      };

      floating = {
        border = 5;
        modifier = mod;
        criteria = [
          { title = "^float$"; }
        ];
      };

      focus = {
        followMouse = false;
      };

      #---------------------------------------------------------------------
      # Colors (Custom from Xresources)
      #---------------------------------------------------------------------
      colors = {
        focused = {
          border = "#00E5FF";       # Xresources: cyan
          background = "#00E5FF";
          text = "#000000";
          indicator = "#FF8C00";    # Xresources: orange indicator
          childBorder = "#00E5FF";
        };
        focusedInactive = {
          border = "#1a1a2e";
          background = "#1a1a2e";
          text = "#888888";
          indicator = "#1a1a2e";
          childBorder = "#1a1a2e";
        };
        unfocused = {
          border = "#1a1a2e";       # Xresources: dark navy
          background = "#0f0f23";   # Xresources: darker navy
          text = "#888888";
          indicator = "#0f0f23";
          childBorder = "#1a1a2e";
        };
        urgent = {
          border = "#FF6600";       # Xresources: orange
          background = "#FF6600";
          text = "#FFFFFF";
          indicator = "#FF6600";
          childBorder = "#FF6600";
        };
        placeholder = {
          border = "#0f0f23";
          background = "#0f0f23";
          text = "#888888";
          indicator = "#0f0f23";
          childBorder = "#0f0f23";
        };
        background = "#0f0f23";
      };

      #---------------------------------------------------------------------
      # Keybindings
      #---------------------------------------------------------------------
      keybindings = lib.mkMerge [
        # Workspace 1-10 (using mkMerge for dynamic generation)
        (builtins.listToAttrs (map (n: {
          name = "${mod}+${toString n}";
          value = "workspace number ${toString n}";
        }) (lib.range 1 9)))

        (builtins.listToAttrs (map (n: {
          name = "${mod}+Shift+${toString n}";
          value = "move container to workspace number ${toString n}";
        }) (lib.range 1 9)))

        # Main keybindings
        {
          # Terminal
          "${mod}+Return" = "exec ${pkgs.ghostty}/bin/ghostty --gtk-single-instance=true";

          # Kill window
          "${mod}+Shift+q" = "kill";

          # Rofi launcher
          "${mod}+d" = "exec ${
              pkgs.writeShellScript "rofi-launcher" ''
                ${pkgs.rofi}/bin/rofi \
                  -modi 'combi' \
                  -combi-modi "window,drun,run" \
                  -font '${fontName} ${toString fontSize}' \
                  -show combi
              ''
            }";
          "${mod}+Tab" = "exec ${pkgs.rofi}/bin/rofi -show window -font '${fontName} ${toString fontSize}'";
          "${mod}+Shift+d" = "exec ${pkgs.rofi}/bin/rofi -show run -font '${fontName} ${toString fontSize}'";

          # Password manager (rofi-pass)
          "${mod}+p" = "exec ${pkgs.rofi-pass}/bin/rofi-pass -font '${fontName} ${toString fontSize}'";

          # Edit input field with Emacs
          "${mod}+i" = "exec edit-input";

          # Toggle compositor (picom)
          "${mod}+c" = "exec --no-startup-id pkill picom || ${pkgs.picom}/bin/picom -b";

          # Notifications (dunst control)
          "${mod}+n" = "exec ${pkgs.dunst}/bin/dunstctl close";
          "${mod}+Shift+n" = "exec ${pkgs.dunst}/bin/dunstctl close-all";
          "${mod}+grave" = "exec ${pkgs.dunst}/bin/dunstctl history-pop";
          "${mod}+period" = "exec ${pkgs.dunst}/bin/dunstctl action";

          # Focus (vim keys)
          "${mod}+h" = "focus left";
          "${mod}+j" = "focus down";
          "${mod}+k" = "focus up";
          "${mod}+l" = "focus right";

          # Focus (arrow keys)
          "${mod}+Left" = "focus left";
          "${mod}+Down" = "focus down";
          "${mod}+Up" = "focus up";
          "${mod}+Right" = "focus right";

          # Move window (vim keys)
          "${mod}+Shift+h" = "move left";
          "${mod}+Shift+j" = "move down";
          "${mod}+Shift+k" = "move up";
          "${mod}+Shift+l" = "move right";

          # Move window (arrow keys)
          "${mod}+Shift+Left" = "move left";
          "${mod}+Shift+Down" = "move down";
          "${mod}+Shift+Up" = "move up";
          "${mod}+Shift+Right" = "move right";

          # Split orientation
          "${mod}+b" = "split h";
          "${mod}+v" = "split v";

          # Fullscreen
          "${mod}+f" = "fullscreen toggle";

          # Container layout
          "${mod}+s" = "layout stacking";
          "${mod}+w" = "layout tabbed";
          "${mod}+e" = "layout toggle split";

          # Toggle floating
          "${mod}+Shift+space" = "floating toggle";

          # Change focus between tiling/floating
          "${mod}+space" = "focus mode_toggle";

          # Focus parent/child
          "${mod}+a" = "focus parent";
          "${mod}+Shift+a" = "focus child";

          # Workspace 10 (special case for 0 key)
          "${mod}+0" = "workspace number 10";
          "${mod}+Shift+0" = "move container to workspace number 10";

          # System control
          "${mod}+Shift+c" = "reload";
          "${mod}+Shift+r" = "restart";
          "${mod}+Shift+e" = ''exec "i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'"'';

          # Lock screen
          "${mod}+Shift+x" = "exec ${pkgs.i3lock}/bin/i3lock -c ${solarized.base03}";

          # Volume control
          "XF86AudioRaiseVolume" = "exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%";
          "XF86AudioLowerVolume" = "exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%";
          "XF86AudioMute" = "exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
          "XF86AudioMicMute" = "exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ toggle";

          # Screenshot
          "Print" = "exec --no-startup-id ${pkgs.scrot}/bin/scrot '%Y-%m-%d_%H-%M-%S.png' -e 'mv $f ~/Pictures/'";
          "${mod}+Print" = "exec --no-startup-id ${pkgs.scrot}/bin/scrot -u '%Y-%m-%d_%H-%M-%S.png' -e 'mv $f ~/Pictures/'";
          "${mod}+Shift+Print" = "exec --no-startup-id ${pkgs.scrot}/bin/scrot -s '%Y-%m-%d_%H-%M-%S.png' -e 'mv $f ~/Pictures/'";

          # Resize mode
          "${mod}+r" = "mode resize";
        }
      ];

      #---------------------------------------------------------------------
      # Resize mode
      #---------------------------------------------------------------------
      modes = {
        resize = {
          # Vim keys
          h = "resize shrink width 10 px or 10 ppt";
          j = "resize grow height 10 px or 10 ppt";
          k = "resize shrink height 10 px or 10 ppt";
          l = "resize grow width 10 px or 10 ppt";

          # Arrow keys
          Left = "resize shrink width 10 px or 10 ppt";
          Down = "resize grow height 10 px or 10 ppt";
          Up = "resize shrink height 10 px or 10 ppt";
          Right = "resize grow width 10 px or 10 ppt";

          # Exit resize mode
          Return = "mode default";
          Escape = "mode default";
          "${mod}+r" = "mode default";
        };
      };

      #---------------------------------------------------------------------
      # Status bar (py3status with Emacs org-clock integration)
      #---------------------------------------------------------------------
      bars = [{
        statusCommand = "${py3status}/bin/py3status -c ${i3status-conf}";
        position = "top";
        fonts = {
          names = [ fontName ];
          size = barFontSize * 1.0;
        };

        colors = {
          background = "#0f0f23";
          statusline = "#ffffff";
          separator = "#666666";

          focusedWorkspace = {
            border = "#00E5FF";
            background = "#00E5FF";
            text = "#000000";
          };
          activeWorkspace = {
            border = "#1a1a2e";
            background = "#1a1a2e";
            text = "#ffffff";
          };
          inactiveWorkspace = {
            border = "#0f0f23";
            background = "#0f0f23";
            text = "#888888";
          };
          urgentWorkspace = {
            border = "#FF6600";
            background = "#FF6600";
            text = "#FFFFFF";
          };
          bindingMode = {
            border = "#FF8C00";
            background = "#FF8C00";
            text = "#FFFFFF";
          };
        };
      }];

      #---------------------------------------------------------------------
      # Startup applications
      #---------------------------------------------------------------------
      startup = [
        # Power management
        { command = "${pkgs.xorg.xset}/bin/xset s 3600 3600"; notification = false; }
        { command = "${pkgs.xorg.xset}/bin/xset dpms 0 0 7200"; notification = false; }

        # Lock screen setup
        { command = "${pkgs.xss-lock}/bin/xss-lock --transfer-sleep-lock -- ${pkgs.i3lock}/bin/i3lock --nofork"; notification = false; }

        # Wallpaper
        { command = "${pkgs.feh}/bin/feh --bg-scale ~/.config/nixos-wallpaper.png"; notification = false; }

        # Keyboard layout
        { command = "${pkgs.xorg.setxkbmap}/bin/setxkbmap -layout us"; notification = false; }

        # Korean input method (kime)
        { command = "kime"; notification = false; }

        # System tray applets
        { command = "${pkgs.networkmanagerapplet}/bin/nm-applet"; notification = false; }
        { command = "${pkgs.blueman}/bin/blueman-applet"; notification = false; }

        # Compositor managed by services.picom (see modules/picom.nix)
        # Can be toggled with Mod+c

        # Notifications are handled by services.dunst (see modules/dunst.nix)
      ];
    };
  };
}
