{ inputs, currentSystemName ? "nuc", ... }:

{ config, lib, pkgs, ... }:

let
  isLinux = pkgs.stdenv.isLinux;

  # Get hostname for pattern matching
  hostname = config.networking.hostName or currentSystemName;

  # Import vars based on hostname pattern matching
  vars = if (builtins.match ".*oracle.*" hostname != null) then
    import ../../hosts/oracle/vars.nix
  else if (builtins.match ".*nuc.*" hostname != null) then
    import ../../hosts/nuc/vars.nix
  else if (builtins.match ".*laptop.*" hostname != null) then
    import ../../hosts/laptop/vars.nix
  else
    # Default to nuc for backward compatibility
    import ../../hosts/nuc/vars.nix;
in {
  # Import modular configuration
  imports = [
    ./modules
  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";

  # This value determines the Home Manager release that your
  # configuration is compatible with.
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Enable XDG base directories
  xdg.enable = true;

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------
  home.packages = with pkgs; [
    # CLI tools
    bat
    eza
    fd
    fzf
    gh
    htop
    jq
    ripgrep
    tree
    watch
    ncdu
    duf
    procs
    psmisc       # killall, fuser (ElleNajit)

    # Development
    lazygit
    delta
    git-lfs
    direnv

    # System tools
    neofetch

    # Editors (moved to modules/emacs.nix)

    # Email and password management
    gnupg
    pass
    passExtensions.pass-otp
    notmuch
    isync
    afew

    # Media
    yt-dlp       # YouTube downloader (ElleNajit)
    ffmpeg       # Video processing (ElleNajit)
  ] ++ (lib.optionals isLinux [
    # Linux-specific packages
    xclip
    wl-clipboard
    firefox

    # X11 utilities (ElleNajit)
    xorg.xev        # X event viewer
    xorg.libxcvt    # cvt replacement
    xdotool         # X automation (for edit-input)

    # Display management (ElleNajit)
    xlayoutdisplay  # Auto display layout

    # Desktop applications (ElleNajit platforms/linux.nix)
    chromium        # Alternative browser
    signal-desktop  # Messaging
    apvlv           # PDF viewer
    vlc             # Video player
    gimp            # Image editor

    # System utilities (ElleNajit)
    powertop        # Power management
    usbutils        # USB tools
    gdmap           # Disk usage visualizer
    nmap            # Network scanner
    iftop           # Network monitoring

    # Security (ElleNajit)
    keybase         # Encrypted communication
    yubikey-manager # YubiKey support
  ]);

  #---------------------------------------------------------------------
  # Dotfiles
  # (i3 config moved to modules/i3.nix)
  # (rofi configured via command-line options in modules/i3.nix)
  #---------------------------------------------------------------------
  home.file = {
    ".config/ghostty/config".text = builtins.readFile ./configs/ghostty.linux;
    ".config/kitty/kitty.conf".text = builtins.readFile ./configs/kitty;
    ".inputrc".text = builtins.readFile ./configs/inputrc;
    # Wallpaper for i3
    ".config/nixos-wallpaper.png".source = ./../../assets/indistractable.png;
  };

  # X resources configuration
  xresources.extraConfig = builtins.readFile ./configs/Xresources;

  #---------------------------------------------------------------------
  # X11 and Desktop configuration
  # (Shell configuration moved to modules/shell.nix)
  #---------------------------------------------------------------------

  # Cursor theme (96 DPI에 적합한 크기)
  home.pointerCursor = {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 32;
    x11.enable = true;
  };

  # i3status configuration moved to modules/i3.nix (py3status)
}
