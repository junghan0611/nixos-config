# GNOME desktop environment
{ pkgs, ... }: {
  specialisation.gnome.configuration = {
    # XDG portal for GNOME
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    };

    # Korean input method - kime
    i18n.inputMethod = {
      enable = true;
      type = "kime";
      kime.extraConfig = ''
        [indicator]
        icon_color = "Black"
      '';
    };

    services.xserver = {
      enable = true;
      xkb.layout = "us";

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