{ config, pkgs, lib, currentSystem, currentSystemName, currentSystemUser, ... }:

let
  isOracle = currentSystemName == "oracle";
in
{
  imports = lib.optionals (!isOracle) [
    # Default window manager (Oracle headless 제외)
    ../modules/wm/i3.nix

    # Alternative desktop environments (specialisations)
    ../modules/specialization/gnome.nix
    # ../modules/specialization/sway.nix  # Future
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
      trusted-users = [ "root" "junghan" ];
      substituters = [
        "https://cache.nixos.org"
        "https://nix-wpe-webkit.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-wpe-webkit.cachix.org-1:ItCjHkz1Y5QcwqI9cTGNWHzcox4EqcXqKvOygxpwYHE="
      ];
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

  # Time synchronization - force sync on resume from suspend
  services.timesyncd = {
    enable = true;
    servers = [
      "0.nixos.pool.ntp.org"
      "1.nixos.pool.ntp.org"
      "2.nixos.pool.ntp.org"
      "3.nixos.pool.ntp.org"
    ];
  };

  # Force time sync immediately after resume from suspend
  # Also refresh py3status (i3 statusbar) to update time display
  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemctl restart systemd-timesyncd.service
    # Refresh py3status for all users (SIGUSR1 forces module refresh)
    ${pkgs.procps}/bin/pkill -USR1 py3status || true
  '';

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

  # Enable nix-ld for running dynamically linked executables (필요: x86_64 환경에서 uvx 등)
  programs.nix-ld.enable = true;
  # libcap: pnpm으로 설치한 codex-acp(@zed-industries) 같은 prebuilt 바이너리가 요구.
  # 기본 nix-ld 라이브러리 셋에는 libcap이 없어 추가.
  programs.nix-ld.libraries = with pkgs; [ libcap ];

  # dconf — home-manager gtk 모듈이 내부적으로 필요로 함
  programs.dconf.enable = true;

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

  # Console configuration for Korean support (Oracle headless 제외)
  # Use kmscon for proper Unicode/Korean support in TTY
  services.kmscon = lib.mkIf (!isOracle) {
    enable = true;
    hwRender = true;
    fonts = [
      {
        name = "D2Coding";
        package = pkgs.d2coding;
      }
    ];
    extraConfig = ''
      font-size=14
      xkb-layout=us
    '';
  };

  # Fallback console settings (used when kmscon is not available) — Oracle headless 제외
  console = lib.mkIf (!isOracle) {
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
    # Disable defaults to avoid noto-fonts-color-emoji being pulled in.
    # Base fonts below are re-added explicitly.
    enableDefaultPackages = false;

    packages = with pkgs; [
      # Basic fonts (explicit — replaces enableDefaultPackages set minus color emoji)
      liberation_ttf
      dejavu_fonts
      freefont_ttf
      gyre-fonts           # TrueType substitutes for standard PostScript fonts
      unifont              # Last-resort fallback for missing glyphs
      noto-fonts           # Noto Sans/Serif + Symbols + Symbols2 + Math
      symbola              # Unicode symbol coverage (math, emoji fallback)

      # Korean fonts
      pretendard
      sarasa-gothic
      noto-fonts-cjk-sans    # Noto Sans CJK
      noto-fonts-cjk-serif   # Noto Serif CJK (인쇄/PDF용)
      noto-fonts-monochrome-emoji  # Emoji support (monochrome) — system-wide mono policy
      d2coding               # D2Coding (Korean coding font)

      # English coding fonts
      jetbrains-mono
      fira-code
    ];

    fontconfig = {
      defaultFonts = {
        serif = [ "Liberation Serif" "Noto Serif CJK KR" ];
        sansSerif = [ "Pretendard" "Liberation Sans" "Noto Sans CJK KR" ];
        monospace = [ "D2Coding" "JetBrainsMono Nerd Font" "Fira Code" "Liberation Mono" ];
        emoji = [ "Noto Emoji" "Symbola" ];
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
    zip
    unzip
    lsof
    iotop

    # Development tools
    tmux
    zellij
    neovim
    tree-sitter  # Emacs tree-sitter-grammars 빌드/런타임 의존
    fzf
    delta
    git-lfs
    python312
    nodejs_24
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

    lsd
    gawk # for tmux-fingers
    unixtools.watch

    diff-so-fancy # really good diff
    icdiff # simple colorful diff replacement
    difftastic # syntax aware diff (useful for conflicts)
    ctags # code tag stuff
    git-absorb # automatic git commit --fixup
    git-crypt # encrypt git stuff
    entr # continuously run stuff
    emacs-lsp-booster # lsp json translation proxy
    jujutsu # better git wrapper
    lazyjj # tui for jj
    tz # timezone viewer
    chafa # show images in terminal using half blocks
    ddgr # search ddg from terminal
    typos

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
    axel
    cloc

    # Networking tools
    dnsutils
    traceroute
    httpie
    tailscale
    syncthing
    stc-cli
    unixtools.netstat

    # System monitoring
    btop
    ncdu
    pciutils

    # Editor and tools
    emacs-nox
    libvterm
    libtool
    cmake

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
  ] ++ lib.optionals (!isOracle) [
    # Oracle(헤드리스, 저장공간 민감)에서는 제외
    quarto         # ~2.6 GB (문서 빌드)
    android-tools  # adb/fastboot (Oracle 불필요)
    mermaid-cli    # nodejs_22 transitive (다이어그램 렌더)
    jira-cli-go    # CLI (Oracle 호스트에서 쓰지 않음)
    remmina        # GUI RDP/VNC/SSH client
    freerdp        # Command-line RDP client
    infisical      # 시크릿 관리 CLI (필요 시만)
    awscli2        # AWS CLI (Oracle 호스트에서 쓰지 않음)
    qemu           # ~700MB. pi-chat Gondolin micro-VM 격리 (Oracle 헤드리스 제외)
  ];

  # Default desktop environment: i3
  # GNOME is available as specialisation.gnome
  # (i3 configuration is in modules/specialization/i3.nix but applied as default)

  # Enable the OpenSSH daemon
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;
  services.openssh.settings.PermitRootLogin = "no";

  # Syncthing service configuration
  # SSH tunnel for secure access: ssh -L 8384:localhost:8384 <host>
  # Note: overrideDevices/Folders = false allows web UI management
  services.syncthing = {
    enable = true;
    user = currentSystemUser;
    dataDir = "/home/${currentSystemUser}/sync";
    configDir = "/home/${currentSystemUser}/.config/syncthing";

    overrideDevices = false;  # Allow web UI to manage devices
    overrideFolders = false;  # Allow web UI to manage folders

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
    ] ++ (lib.range 60000 61000);  # mosh
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken.
  system.stateVersion = "25.05";
}
