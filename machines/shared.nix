{ config, pkgs, lib, currentSystem, currentSystemName, currentSystemUser, ... }:

{
  imports = [
    ../modules/specialization/i3.nix
    ../modules/specialization/gnome.nix
  ];

  # Be careful updating this.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';

    settings = {
      substituters = ["https://cache.nixos.org"];
      trusted-public-keys = ["cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="];
      auto-optimise-store = true;
    };

    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Boot loader settings
  boot.loader.systemd-boot.consoleMode = "0";

  # Networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Seoul";

  # Don't require password for sudo
  security.sudo.wheelNeedsPassword = false;

  # Enable passwordless sudo for the user
  security.sudo.extraRules = [
    {
      users = [ currentSystemUser ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Virtualization settings
  virtualisation.docker.enable = true;

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "ko_KR.UTF-8/UTF-8"
      "C.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_MESSAGES = "en_US.UTF-8";
      LC_TIME = "ko_KR.UTF-8";
      LC_MONETARY = "ko_KR.UTF-8";
      LC_PAPER = "ko_KR.UTF-8";
      LC_NAME = "ko_KR.UTF-8";
      LC_ADDRESS = "ko_KR.UTF-8";
      LC_TELEPHONE = "ko_KR.UTF-8";
      LC_MEASUREMENT = "ko_KR.UTF-8";
      LC_IDENTIFICATION = "ko_KR.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_CTYPE = "en_US.UTF-8";
    };
  };

  # Console configuration for Korean support
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    useXkbConfig = false;
  };

  # Environment variables for Korean support
  environment.variables = {
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    FONTCONFIG_PATH = "/etc/fonts";
  };

  # Enable tailscale
  services.tailscale.enable = true;

  # Define a user account
  users.mutableUsers = true;  # Allow password changes and user management

  # Font configuration with Korean support
  fonts = {
    fontDir.enable = true;
    enableDefaultPackages = true;

    packages = with pkgs; [
      # Basic fonts
      liberation_ttf
      dejavu_fonts

      # Korean fonts
      pretendard
      sarasa-gothic
      noto-fonts-cjk-sans  # Noto Sans CJK
      noto-fonts-emoji     # Emoji support
      d2coding            # D2Coding (Korean coding font)

      # Nerd Fonts - try individual packages
      # (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" ]; })
      # Temporarily comment out until we find the right package names

      # English coding fonts
      jetbrains-mono
      fira-code
    ];

    fontconfig = {
      defaultFonts = {
        serif = [ "Liberation Serif" "Noto Serif CJK KR" ];
        sansSerif = [ "Pretendard" "Liberation Sans" "Noto Sans CJK KR" ];
        monospace = [ "D2Coding" "JetBrainsMono Nerd Font" "Fira Code" "Liberation Mono" ];
        emoji = [ "Noto Color Emoji" ];
      };
      hinting = {
        enable = true;
        style = "slight";
      };
      antialias = true;
    };
  };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
    # Basic tools
    cachix
    gnumake
    killall
    xclip
    git
    vim
    wget
    curl
    htop
    tree
    unzip
    lsof
    iotop

    # Development tools
    tmux
    neovim
    tree-sitter
    fzf
    delta
    git-lfs
    python312
    nodejs_22
    pnpm
    uv
    gh  # GitHub CLI
    mosh
    pkg-config
    gcc
    openssl

    # Terminal and shell enhancements
    direnv
    nix-direnv
    atuin
    starship
    zoxide
    broot
    onefetch

    # Modern CLI tools
    fd
    ripgrep
    ack
    bat
    eza
    jq
    yq-go
    bottom
    lnav
    lazygit

    # Networking tools
    dnsutils
    traceroute
    httpie
    tailscale
    syncthing
    stc-cli

    # System monitoring
    btop
    ncdu
    pciutils

    # Editor and tools
    emacs-nox
    libvterm
    libtool
    cmake

    # Cloud and DevOps
    infisical

    # Locale and encoding tools
    glibc
    glibcLocales
    fontconfig
    file
    less
    libiconv
    enca

    # For X11
    (writeShellScriptBin "xrandr-auto" ''
      xrandr --output Virtual-1 --auto
    '')
  ];

  # Our default non-specialised desktop environment
  services.xserver = lib.mkIf (config.specialisation != {}) {
    enable = true;
    xkb.layout = "us";
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };

  # Enable the OpenSSH daemon
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;
  services.openssh.settings.PermitRootLogin = "no";

  # Syncthing service configuration
  # SSH tunnel for secure access: ssh -L 8384:localhost:8384 <host>
  services.syncthing = {
    enable = true;
    user = currentSystemUser;
    dataDir = "/home/${currentSystemUser}/sync";
    configDir = "/home/${currentSystemUser}/.config/syncthing";

    overrideDevices = true;
    overrideFolders = true;

    settings = {
      gui = {
        enabled = true;
        address = "127.0.0.1:8384";  # Local access only
      };
      options = {
        urAccepted = -1;  # Disable usage reporting
        relaysEnabled = true;
      };
    };
  };

  # Firewall configuration
  networking.firewall = {
    enable = true;  # Enable firewall for security
    allowedTCPPorts = [
      22      # SSH
      22000   # Syncthing sync
    ];
    allowedUDPPorts = [
      21027   # Syncthing discovery
      22000   # Syncthing QUIC
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken.
  system.stateVersion = "25.05";
}