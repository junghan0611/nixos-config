# i3 (X11) with kime Korean input
# Default window manager configuration
{ pkgs, ... }: {
  # We need an XDG portal for various applications to work properly
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  # Korean input method - kime
  i18n.inputMethod = {
    enable = true;
    type = "kime";
    kime.extraConfig = ''
      [indicator]
      icon_color = "White"
    '';
  };

  # Display manager configuration
  services.displayManager.defaultSession = "none+i3";

  # X server configuration
  services.xserver = {
    enable = true;
    xkb.layout = "us";
    dpi = 96;  # Adjust based on your display

    desktopManager = {
      xterm.enable = false;
      wallpaper.mode = "fill";
    };

    displayManager = {
      lightdm.enable = true;
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
