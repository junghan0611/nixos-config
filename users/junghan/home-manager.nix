{ inputs, currentSystemName ? "nuc", ... }:

{ config, lib, pkgs, ... }:

let
  isLinux = pkgs.stdenv.isLinux;

  # Get hostname for pattern matching
  hostname = config.networking.hostName or currentSystemName;

  # Check if current system is oracle (aarch64-linux)
  isOracle = builtins.match ".*oracle.*" hostname != null;

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

  # Note: nixpkgs.config is not needed here because we use home-manager.useGlobalPkgs = true
  # which inherits nixpkgs.config from the system configuration (machines/shared.nix)

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
    fswatch
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
    gitu
    lazygit
    delta
    git-lfs
    direnv

    # Programming Languages & Tools (CLI)
    zig_0_14
    zls_0_14
    clojure
    clojure-lsp
    mitscheme

    google-clasp     # Google Apps Script CLI

    # AI CLI tools (from unstable)
    gemini-cli
    codex
    # opencode
    claude-code
    claude-monitor
    # claude-code-acp
    claude-code-router

    # System tools
    neofetch

    # Editors (moved to modules/emacs.nix)

    # Email and password management
    gnupg
    # pass - configured via programs.password-store in modules/shell.nix
    # passExtensions.pass-otp - included in shell.nix configuration
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
    claude-desktop  # Claude Desktop with MCP support

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
  ]) ++ (lib.optionals (isLinux && !isOracle) [
    # x86_64 Linux-specific packages (not available on ARM/Oracle VM)
    zotero          # Reference manager (x86_64 only)

    # Editors & IDEs (GUI, excluded from Oracle VM)
    zed-editor
    vscode
    inkscape

    # Collaboration (GUI, excluded from Oracle VM)
    slack
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

    # Force fcitx5 profile to ensure reproducibility
    ".config/fcitx5/profile".text = ''
      [GroupOrder]
      0=Default
      1=Korean

      [Groups/0]
      Default Layout=us
      DefaultIM=Keyboard-us
      Name=Default

      [Groups/0/Items/0]
      Layout=
      Name=keyboard-us

      [Groups/1]
      Default Layout=kr-kr104
      DefaultIM=keyboard-kr-kr104
      Name=Korean

      [Groups/1/Items/0]
      Layout=kr-kr104
      Name=keyboard-kr-kr104

      [Groups/1/Items/1]
      Layout=kr-kr104
      Name=hangul
    '';

    # Flameshot configuration with Denote timestamp pattern
    ".config/flameshot/flameshot.ini".text = ''
      [General]
      checkForUpdates=true
      contrastOpacity=188
      copyOnDoubleClick=true
      copyPathAfterSave=true
      filenamePattern=%Y%m%dT%H%M%S--
      saveAfterCopy=false
      saveAsFileExtension=png
      savePath=/home/${vars.username}/sync/screenshot
      savePathFixed=false
      showHelp=false
      showStartupLaunchMessage=false
      startupLaunch=true
      undoLimit=100
    '';
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
