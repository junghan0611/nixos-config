# i3 window manager configuration
# Declarative i3 config with Solarized color scheme
{ config, lib, pkgs, ... }:

let
  mod = "Mod4";
  alt = "Mod1";

  # Solarized color scheme
  solarized = import ./solarized.nix;

  # Font configuration (monospace)
  fontName = "D2Coding ligature";
  fontSize = 9;
  barFontSize = 11;

  fonts = {
    names = [ fontName ];
    size = fontSize * 1.0;
  };

  # py3status configuration (ElleNajit pattern)
  py3status = pkgs.python3Packages.py3status;

  # Whisper voice input script
  whisperScript = "${config.home.homeDirectory}/repos/gh/nixos-config/scripts/whisper-input.sh";

  # Scratchpad toggle script (from regolith, improved)
  # Shows scratchpad window if exists, otherwise creates it
  # Improvements:
  # - Tracks window ID to avoid marking wrong window
  # - Handles emacsclient fallback correctly
  # - Timeout for i3-msg subscribe (prevents infinite wait)
  scratchpad-toggle = pkgs.writeShellScript "scratchpad-toggle" ''
    if [ $# -ne 2 ]; then
      echo "Usage: $0 <i3_mark> <launch_cmd>"
      exit 1
    fi

    I3_MARK=$1
    LAUNCH_CMD=$2

    # Check if mark already exists
    mark_exists() {
      ${pkgs.i3}/bin/i3-msg -t get_marks | ${pkgs.gnugrep}/bin/grep -q "\"$I3_MARK\""
    }

    scratchpad_show() {
      ${pkgs.i3}/bin/i3-msg "[con_mark=$I3_MARK]" scratchpad show
    }

    # Get current focused window ID
    get_focused_id() {
      ${pkgs.i3}/bin/i3-msg -t get_tree | ${pkgs.jq}/bin/jq -r '.. | select(.focused? == true) | .id' 2>/dev/null | head -1
    }

    # If mark exists, just toggle scratchpad visibility
    if mark_exists; then
      scratchpad_show
      exit 0
    fi

    # Save current window ID before launching
    OLD_WINDOW_ID=$(get_focused_id)

    # Launch the command
    eval "$LAUNCH_CMD" &
    LAUNCH_PID=$!

    # Wait for new window with polling (more reliable than subscribe)
    MAX_WAIT=50  # 5 seconds (50 * 100ms)
    for i in $(seq 1 $MAX_WAIT); do
      sleep 0.1
      NEW_WINDOW_ID=$(get_focused_id)

      # Check if we have a NEW focused window (different from before)
      if [ -n "$NEW_WINDOW_ID" ] && [ "$NEW_WINDOW_ID" != "$OLD_WINDOW_ID" ]; then
        # Mark and move to scratchpad
        ${pkgs.i3}/bin/i3-msg mark "$I3_MARK"
        ${pkgs.i3}/bin/i3-msg move scratchpad
        scratchpad_show
        exit 0
      fi
    done

    echo "Warning: Timed out waiting for new window" >&2
    exit 1
  '';

  i3status-conf = pkgs.writeText "i3status.conf" ''
    general {
        output_format = i3bar
        colors = true
        color_good = "${solarized.green}"
        color_bad = "${solarized.red}"
        color_degraded = "${solarized.yellow}"
    }

    order += "read_file emacs_task"
    order += "volume master"
    order += "battery all"
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

    volume master {
        format = "♪ %volume"
        format_muted = "♪ muted (%volume)"
        device = "default"
        mixer = "Master"
        mixer_idx = 0
        min_width = "♪ 100%"
        align = "left"
    }

    battery all {
        format = "%status %percentage %remaining"
        format_down = "No battery"
        status_chr = "⚡"
        status_bat = "🔋"
        status_unk = "?"
        status_full = "☻"
        path = "/sys/class/power_supply/BAT%d/uevent"
        low_threshold = 10
        min_width = "🔋 100% 00:00:00"
        align = "left"
    }

    ethernet _first_ {
        format_up = "E: %ip (%speed)"
        format_down = "E: down"
        min_width = "E: 000.000.000.000 (1000M)"
        align = "left"
    }

    disk "/" {
        format = "/ %avail"
        min_width = "  / 000.0 GiB  "
        align = "center"
    }

    load {
        format = "%1min"
        min_width = "00.00"
        align = "right"
    }

    memory {
        format = "%used / %total"
        threshold_degraded = "1G"
        format_degraded = "MEMORY < %available"
        min_width = "00.00 GiB / 00.00 GiB"
        align = "left"
    }

    tztime local {
        format = "  %Y-%m-%d %H:%M:%S  "
        timezone = "Asia/Seoul"
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

      # Force border on apps that request no decoration (like ghostty)
      window.commands = [
        {
          command = "border normal 5";
          criteria = { class = "com.mitchellh.ghostty"; };
        }
        {
          command = "border normal 5";
          criteria = { class = "ghostty"; };
        }
      ];

      focus = {
        followMouse = false;
      };

      #---------------------------------------------------------------------
      # Workspace to monitor assignment
      # eDP-1 (노트북): 1-5, HDMI-1 (외부 모니터): 6-10
      #---------------------------------------------------------------------
      workspaceOutputAssign = [
        { workspace = "1"; output = "eDP-1"; }
        { workspace = "2"; output = "eDP-1"; }
        { workspace = "3"; output = "eDP-1"; }
        { workspace = "4"; output = "eDP-1"; }
        { workspace = "5"; output = "eDP-1"; }
        { workspace = "6"; output = "HDMI-1"; }
        { workspace = "7"; output = "HDMI-1"; }
        { workspace = "8"; output = "HDMI-1"; }
        { workspace = "9"; output = "HDMI-1"; }
        { workspace = "10"; output = "HDMI-1"; }
      ];

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
          "${mod}+Return" = "exec ${pkgs.ghostty}/bin/ghostty --gtk-single-instance=false";

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

          # Split orientation (Regolith style: g=horizontal, v=vertical)
          "${mod}+g" = "split h";
          "${mod}+v" = "split v";

          # Fullscreen
          "${mod}+f" = "fullscreen toggle";

          # Container layout
          "${mod}+s" = "layout stacking";
          "${mod}+w" = "layout tabbed";

          # Toggle floating (Regolith style: Shift+f)
          "${mod}+Shift+f" = "floating toggle";

          # Change focus between tiling/floating (Regolith style: Shift+t)
          "${mod}+Shift+t" = "focus mode_toggle";

          # Focus parent/child (Regolith style: a=parent, z=child)
          "${mod}+a" = "focus parent";
          "${mod}+z" = "focus child";

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

          # Brightness control (Intel backlight)
          "XF86MonBrightnessUp" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl set +5%";
          "XF86MonBrightnessDown" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl set 5%-";

          # Keyboard backlight control (Samsung Galaxy Book)
          "XF86KbdBrightnessUp" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl --device='samsung-galaxybook::kbd_backlight' set +1";
          "XF86KbdBrightnessDown" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl --device='samsung-galaxybook::kbd_backlight' set 1-";

          # Screenshot
          "Print" = "exec --no-startup-id ${pkgs.scrot}/bin/scrot '%Y-%m-%d_%H-%M-%S.png' -e 'mv $f ~/Pictures/'";
          "${mod}+Print" = "exec --no-startup-id ${pkgs.scrot}/bin/scrot -u '%Y-%m-%d_%H-%M-%S.png' -e 'mv $f ~/Pictures/'";
          "${mod}+Shift+Print" = "exec --no-startup-id ${pkgs.scrot}/bin/scrot -s '%Y-%m-%d_%H-%M-%S.png' -e 'mv $f ~/Pictures/'";

          # Scratchpad (Regolith style: Ctrl+a=show, Ctrl+m=move)
          # -c: create new frame, -s server: socket name, -a emacs: fallback if daemon not running
          "${mod}+m" = "exec --no-startup-id ${scratchpad-toggle} 'scratch-emacs' '${pkgs.emacs}/bin/emacsclient -c -s server -a ${pkgs.emacs}/bin/emacs'";
          "${mod}+Ctrl+a" = "scratchpad show";
          "${mod}+Ctrl+m" = "move scratchpad";

          # Browsers
          "${mod}+Shift+Return" = "exec firefox";
          "${mod}+Ctrl+Return" = "exec microsoft-edge";

          # Additional terminal (WezTerm)
          "${mod}+${alt}+Return" = "exec ${pkgs.wezterm}/bin/wezterm";

          # Whisper voice input
          "${mod}+e" = "exec --no-startup-id ${whisperScript}";
          "F1" = "exec --no-startup-id ${whisperScript}";

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
      # Status bar (i3status - simpler, reliable tray support)
      #---------------------------------------------------------------------
      bars = [{
        statusCommand = "${pkgs.i3status}/bin/i3status -c ${i3status-conf}";
        position = "top";
        trayOutput = "primary";  # Enable system tray for kime-indicator
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

        # Raw i3 config for system tray
        extraConfig = ''
          tray_output primary
          tray_padding 4
        '';
      }];

      #---------------------------------------------------------------------
      # Startup applications
      #---------------------------------------------------------------------
      startup = [
        # Power management
        { command = "${pkgs.xorg.xset}/bin/xset s 10800 10800"; notification = false; }
        { command = "${pkgs.xorg.xset}/bin/xset dpms 0 0 18000"; notification = false; }

        # Lock screen setup
        { command = "${pkgs.xss-lock}/bin/xss-lock --transfer-sleep-lock -- ${pkgs.i3lock}/bin/i3lock --nofork"; notification = false; }

        # Wallpaper
        { command = "${pkgs.feh}/bin/feh --bg-scale ~/.config/nixos-wallpaper.png"; notification = false; }

        # Keyboard layout
        # { command = "${pkgs.xorg.setxkbmap}/bin/setxkbmap -layout us"; notification = false; }  # For English-only
        { command = "${pkgs.xorg.setxkbmap}/bin/setxkbmap -layout kr -variant kr104 -option korean:ralt_hangul"; notification = false; }

        # SNI to XEmbed proxy (required for kime-indicator in i3bar)
        { command = "${pkgs.snixembed}/bin/snixembed --fork"; notification = false; }

        # System tray applets
        { command = "${pkgs.networkmanagerapplet}/bin/nm-applet"; notification = false; }
        { command = "${pkgs.blueman}/bin/blueman-applet"; notification = false; }

        # Compositor managed by services.picom (see modules/picom.nix)
        # Can be toggled with Mod+c

        # Notifications are handled by services.dunst (see modules/dunst.nix)

        # Korean input method - kime
        { command = "${pkgs.kime}/bin/kime"; notification = false; }

        # [ARCHIVED] fcitx5 startup commands - kept for reference
        # { command = "${pkgs.fcitx5}/bin/fcitx5 -d -s 3"; notification = false; }
        # { command = "sleep 1 && ${pkgs.fcitx5}/bin/fcitx5-remote -s hangul"; notification = false; }

        # Auto-detect and apply monitor configuration
        { command = "${pkgs.autorandr}/bin/autorandr --change --default thinkpad"; notification = false; }
      ];
    };
  };
}
