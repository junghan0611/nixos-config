# GNOME desktop environment
{ pkgs, ... }: {
  specialisation.gnome.configuration = {
    # XDG portal for GNOME
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    };

    # Korean input method - kime (inherited from i3.nix)
    # GNOME can use Wayland, where kime works well
    # No need to redefine - uses the same kime config from modules/wm/i3.nix

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
