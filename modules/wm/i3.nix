# i3 (X11) with kime Korean input
# Default window manager configuration
{ pkgs, lib, ... }: {
  # We need an XDG portal for various applications to work properly
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  # Korean input method - fcitx5
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [
        fcitx5-hangul       # Korean input engine
        fcitx5-gtk          # GTK integration
        fcitx5-configtool   # Configuration GUI tool
      ];
      waylandFrontend = false;  # Currently using X11

      # Ensure reproducibility - ignore user config files
      ignoreUserConfig = true;

      settings = {
        inputMethod = {
          # Default group (0) - English only, for Emacs and apps that control IME
          "Groups/0" = {
            "Name" = "Default";
            "Default Layout" = "us";
            "DefaultIM" = "keyboard-us";
          };
          "Groups/0/Items/0" = {
            "Name" = "keyboard-us";
            "Layout" = "";
          };

          # Korean group (1) - for general applications with Korean input
          "Groups/1" = {
            "Name" = "Korean";
            "Default Layout" = "kr";
            "DefaultIM" = "keyboard-kr";
          };
          "Groups/1/Items/0" = {
            "Name" = "hangul";
            "Layout" = "";
          };
          "Groups/1/Items/1" = {
            "Name" = "keyboard-kr";
            "Layout" = "";
          };

          "GroupOrder" = {
            "0" = "Default";
            "1" = "Korean";
          };
        };
        globalOptions = {
          "Hotkey" = {
            "EnumerateWithTriggerKeys" = "True";
            "EnumerateSkipFirst" = "False";
            "ModifierOnlyKeyTimeout" = "250";
          };
          "Hotkey/TriggerKeys" = {
            "0" = "Shift+space";
            "1" = "Alt+Alt_R";
          };
          "Hotkey/EnumerateGroupForwardKeys" = {
            "0" = "Alt+Super+BackSpace";
          };
          "Hotkey/ActivateKeys" = {
            "0" = "Hangul_Hanja";
          };
          "Hotkey/DeactivateKeys" = {
            "0" = "Hangul_Romaja";
          };
          "Hotkey/PrevPage" = {
            "0" = "Up";
          };
          "Hotkey/NextPage" = {
            "0" = "Down";
          };
          "Hotkey/PrevCandidate" = {
            "0" = "Shift+Tab";
          };
          "Hotkey/NextCandidate" = {
            "0" = "Tab";
          };
          "Hotkey/TogglePreedit" = {
            "0" = "Control+Alt+P";
          };
          "Behavior" = {
            "ActiveByDefault" = "False";
            "resetStateWhenFocusIn" = "No";
            "ShareInputState" = "No";
            "PreeditEnabledByDefault" = "True";
            "ShowInputMethodInformation" = "True";
            "showInputMethodInformationWhenFocusIn" = "False";
            "CompactInputMethodInformation" = "True";
            "ShowFirstInputMethodInformation" = "True";
            "DefaultPageSize" = "5";
            "PreloadInputMethod" = "True";
            "AllowInputMethodForPassword" = "False";
            "ShowPreeditForPassword" = "False";
            "AutoSavePeriod" = "30";
          };
        };
        # Hangul addon settings are managed through GUI (fcitx5-configtool)
        # The settings are stored in ~/.config/fcitx5/conf/hangul.conf
        addons = { };
      };
    };
  };

  # Display manager configuration
  services.displayManager.defaultSession = "none+i3";

  # X server configuration
  services.xserver = {
    enable = true;
    xkb = {
      # xkb.layout = "us";  # For English-only systems
      layout = "kr";
      variant = "kr104";  # Korean (101/104-key compatible) - maps Right Alt to Hangul, Right Ctrl to Hanja
    };
    dpi = 96;  # Adjust based on your display

    desktopManager = {
      xterm.enable = false;
      wallpaper.mode = "fill";
    };

    displayManager = {
      lightdm.enable = lib.mkDefault true;  # Can be overridden by specialisations
      sessionCommands = ''
        ${pkgs.xorg.xset}/bin/xset r rate 200 40
      '';
    };

    windowManager = {
      i3 = {
        enable = true;
        extraPackages = with pkgs; [
          dmenu
          rofi
          i3status
          i3lock
          i3blocks
          ghostty  # Primary terminal
          kitty    # Backup terminal
          xfce.xfce4-terminal  # Alternative terminal
        ];
      };
    };
  };

  # Environment variables for IME support
  environment.sessionVariables = {
    GLFW_IM_MODULE = "ibus";  # Enable fcitx5 in kitty terminal
  };

  # Additional packages for i3 environment
  environment.systemPackages = with pkgs; [
    # X11 utilities
    xorg.xrandr
    xorg.xset
    xorg.xsetroot
    xorg.xmodmap
    arandr
    autorandr

    # Screenshot tools
    scrot
    flameshot

    # System tray and notifications
    dunst
    libnotify

    # File manager
    pcmanfm

    # Clipboard manager
    xclip
    xsel

    # System monitoring
    lxappearance
    pavucontrol

    # Wallpaper
    feh
    nitrogen

    # Lock screen
    xss-lock

    # Network manager applet
    networkmanagerapplet
  ];
}
