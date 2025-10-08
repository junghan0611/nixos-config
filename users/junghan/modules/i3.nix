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

  # i3status integration (already configured in home-manager.nix)
  # We use the existing programs.i3status configuration
in {
  xsession.windowManager.i3 = {
    enable = true;

    config = {
      modifier = mod;

      # Fonts
      fonts = fonts;

      # Window appearance
      window = {
        border = 2;
        titlebar = true;
      };

      floating = {
        border = 2;
        modifier = mod;
        criteria = [
          { title = "^float$"; }
        ];
      };

      focus = {
        followMouse = false;
      };

      #---------------------------------------------------------------------
      # Colors (Solarized Dark)
      #---------------------------------------------------------------------
      colors = {
        focused = {
          border = solarized.green;
          background = solarized.green;
          text = solarized.base03;
          indicator = solarized.blue;
          childBorder = solarized.green;
        };
        focusedInactive = {
          border = solarized.base02;
          background = solarized.base02;
          text = solarized.base1;
          indicator = solarized.base01;
          childBorder = solarized.base02;
        };
        unfocused = {
          border = solarized.base02;
          background = solarized.base02;
          text = solarized.base0;
          indicator = solarized.base01;
          childBorder = solarized.base02;
        };
        urgent = {
          border = solarized.red;
          background = solarized.red;
          text = solarized.base3;
          indicator = solarized.red;
          childBorder = solarized.red;
        };
        placeholder = {
          border = solarized.base03;
          background = solarized.base03;
          text = solarized.base0;
          indicator = solarized.base03;
          childBorder = solarized.base03;
        };
        background = solarized.base03;
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
          "${mod}+d" = "exec ${pkgs.rofi}/bin/rofi -show drun";
          "${mod}+Tab" = "exec ${pkgs.rofi}/bin/rofi -show window";
          "${mod}+Shift+d" = "exec ${pkgs.rofi}/bin/rofi -show run";

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
      # Status bar
      #---------------------------------------------------------------------
      bars = [{
        statusCommand = "${pkgs.i3status}/bin/i3status";
        position = "top";
        fonts = {
          names = [ fontName ];
          size = barFontSize * 1.0;
        };

        colors = {
          background = solarized.base03;
          statusline = solarized.base0;
          separator = solarized.base01;

          focusedWorkspace = {
            border = solarized.green;
            background = solarized.green;
            text = solarized.base03;
          };
          activeWorkspace = {
            border = solarized.base02;
            background = solarized.base02;
            text = solarized.base0;
          };
          inactiveWorkspace = {
            border = solarized.base03;
            background = solarized.base03;
            text = solarized.base01;
          };
          urgentWorkspace = {
            border = solarized.red;
            background = solarized.red;
            text = solarized.base3;
          };
          bindingMode = {
            border = solarized.magenta;
            background = solarized.magenta;
            text = solarized.base3;
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

        # Notifications (dunst will be handled by services.dunst in Phase 4)
        # For now, keep manual startup
        { command = "${pkgs.dunst}/bin/dunst"; notification = false; }
      ];
    };
  };
}
