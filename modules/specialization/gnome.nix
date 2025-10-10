# GNOME desktop environment
{ pkgs, ... }: {
  specialisation.gnome.configuration = {
    # XDG portal for GNOME
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
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
        waylandFrontend = false;
      };
    };

    services.xserver = {
      enable = true;
      xkb = {
        # xkb.layout = "us";  # For English-only systems
        layout = "kr";
        variant = "kr104";  # Korean (101/104-key compatible) - maps Right Alt to Hangul, Right Ctrl to Hanja
      };

      desktopManager.gnome.enable = true;
      displayManager = {
        lightdm.enable = false;  # Disable i3's lightdm
        gdm.enable = true;       # Use GDM for GNOME
      };
    };

    # GNOME-specific packages
    environment.systemPackages = with pkgs; [
      gnome-tweaks
      gnomeExtensions.appindicator
      gnomeExtensions.dash-to-dock
      gnomeExtensions.blur-my-shell
    ];

    # Enable GNOME-specific services
    services.gnome = {
      gnome-keyring.enable = true;
      gnome-settings-daemon.enable = true;
    };
  };
}
