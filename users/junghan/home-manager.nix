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
  # Pass currentSystemName to submodules (emacs.nix 등에서 headless 분기에 사용)
  _module.args.currentSystemName = currentSystemName;

  # Import modular configuration (currentSystemName 주입 — oracle headless 분기)
  imports = [
    (import ./modules { inherit currentSystemName; })
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
    gdu
    procs
    psmisc       # killall, fuser (ElleNajit)

    # Essential UNIX utilities (agent-friendly)
    bubblewrap     # sandbox (codex 등에서 필요)
    bc             # 계산기 (에이전트 수식 계산)
    sqlite-interactive  # sqlite3 CLI (에이전트 DB 조회)
    pv             # pipe viewer (진행률 표시)
    dos2unix       # 줄바꿈 변환
    socat          # 다목적 소켓 릴레이
    mtr            # traceroute + ping 통합
    whois          # 도메인 조회
    parallel       # GNU parallel (병렬 처리)

    # Data processing (에이전트 데이터 파이프라인)
    miller         # mlr: JSON/CSV/TSV 변환·필터·집계
    htmlq          # HTML → 텍스트 추출 (jq for HTML)

    # Development
    gitu
    lazygit
    delta
    git-lfs
    direnv

    logdy
    angle-grinder
    lnav
    grafana-loki     # logcli for Grafana Cloud Loki queries
    tokei

    # programming Languages & Tools (CLI)
    bun             # JavaScript runtime (from unstable)
    zig
    zls
    go
    gopls
    clojure
    clojure-lsp
    mitscheme

    google-clasp     # Google Apps Script CLI

    # AI CLI tools (from unstable)
    gemini-cli
    codex
    # opencode
    # claude-code
    claude-monitor
    # claude-code-acp
    # claude-code-router

    # System tools
    fortune
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
    sox          # Sample Rate Converter for audio
    python312Packages.edge-tts  # Text-to-Speech (Microsoft Edge TTS)
    yt-dlp       # YouTube downloader (ElleNajit)
    ffmpeg       # Video processing (ElleNajit)
    asciinema     # Terminal session recorder
    asciinema-agg # asciicast → animated GIF (agg)
    gifski        # High-quality GIF encoder
  ] ++ (lib.optionals isLinux [
    # Linux-common CLI (headless 포함)
    xclip
    wl-clipboard
    nmap            # Network scanner
    libpcap         # nmap dependency (packet capture)
    iproute2        # ip command
    nettools        # ifconfig, arp, etc.
    iftop           # Network monitoring
    tdlib             # TDLib (telega.el 의존성, GUI Emacs에서만 필요)
  ]) ++ (lib.optionals (isLinux && !isOracle) [
    # Desktop GUI / 주변장치 / 무거운 런타임 — Oracle headless 제외
    firefox
    microsoft-edge
    claude-desktop  # Claude Desktop with MCP support
    # telegram-desktop  # Telegram 메신저 (한글 입력 불가)

    telegram-bot-api  # Telegram Bot API server (OpenClaw는 Docker 안에서 실행)

    # System utilities (ElleNajit) — 데스크톱/주변장치
    powertop        # Power management
    usbutils        # USB tools
    minicom         # Serial port terminal
    gdmap           # Disk usage visualizer (GUI)
    scrcpy          # Android screen mirroring (4.0 from unstable)

    # Security (ElleNajit)
    keybase         # Encrypted communication
    yubikey-manager # YubiKey support

    # Terminal emulators (한글 입력 지원)
    wezterm        # Rust-based, excellent Korean input support

    # X11 utilities (ElleNajit)
    xorg.xev        # X event viewer
    xorg.libxcvt    # cvt replacement
    xorg.xprop      # X window property inspector (emacs-everywhere dependency)
    xorg.xwininfo   # X window info (emacs-everywhere dependency)
    xdotool         # X automation (for edit-input)

    # Display management (ElleNajit)
    xlayoutdisplay  # Auto display layout

    # Desktop applications (ElleNajit platforms/linux.nix)
    # chromium        # Alternative browser
    signal-desktop  # Messaging
    # 문서: PDF 뷰어 zathura는 programs.zathura(modules/zathura.nix)로 관리 (apvlv 대체)
    readest         # EPUB 리더 (Tauri)
    foliate         # EPUB 리더 대안 (GTK)
    mupdf           # 빠른 렌더링 + mutool CLI (PDF 조작/추출)
    # OCR: tesseract/ocrmypdf/gImageReader 제거 (2026-06-02). 한글 스캔 OCR 경로는
    # marker(surya, memex-kb flake의 uv venv)로 일원화됨. tesseract 한글 품질 사용 불가.
    libreoffice     # doc/docx/odt 기본 핸들러 (writer.desktop)
    vlc             # Video player
    gimp            # Image editor
    # x86_64 Linux-specific packages (not available on ARM/Oracle VM)
    google-chrome   # Browser (x86_64 only)
    # zotero        # Reference manager → 8.x manual install (scripts/install-zotero.sh)

    # Editors & IDEs (GUI, excluded from Oracle VM)
    # zed-editor
    vscode
    inkscape

    # Collaboration (GUI, excluded from Oracle VM)
    slack

    # zigbee and matter
    zigbee2mqtt
    python-matter-server
  ]);

  #---------------------------------------------------------------------
  # Dotfiles
  # (i3 config moved to modules/i3.nix)
  # (rofi configured via command-line options in modules/i3.nix)
  #---------------------------------------------------------------------
  home.file = {
    # Fortune data files (~/.fortunes)
    ".fortunes".source = ./../../fortunes;

    # User scripts (~/.local/bin)
    ".local/bin/scan-hubs" = {
      source = ./../../scripts/scan-hubs.sh;
      executable = true;
    };
    # ghostty: 레포 파일로 직접 symlink (편집 가능, nix store 경유 아님)
    ".config/ghostty/config".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/gh/nixos-config/users/junghan/configs/ghostty.linux";
    # kitty: NixOS 관리에서 분리 — 직접 ~/.config/kitty/kitty.conf 편집으로 테스트 중
    # ".config/kitty/kitty.conf".text = builtins.readFile ./configs/kitty;
    # wezterm: 레포 파일로 직접 symlink (편집 가능, nix store 경유 아님)
    ".config/wezterm/wezterm.lua".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/gh/nixos-config/users/junghan/configs/wezterm.lua";

    # wezterm cell_widths: per-codepoint 셀 폭 테이블. wezterm.lua 가 require 로 로드.
    # doomemacs-config 의 korean-input-config.el char-width-table 과 동기화 필요.
    ".config/wezterm/cell-widths.lua".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/gh/nixos-config/users/junghan/configs/cell-widths.lua";

    # i3-fcitx5-group: 포커스 창에 따라 fcitx5 그룹 자동 전환
    ".local/bin/i3-fcitx5-group" = {
      source = ./configs/i3-fcitx5-group.sh;
      executable = true;
    };
    ".inputrc".text = builtins.readFile ./configs/inputrc;

    # 기본 애플리케이션(mimeapps.list): nix store 불변 심볼릭 대신 레포 파일로
    # out-of-store symlink → Thunar 등에서 런타임 변경 가능 (쓰면 레포 파일에 반영).
    # pdf=zathura, epub=foliate, doc/docx/odt=libreoffice writer.
    ".config/mimeapps.list".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/gh/nixos-config/users/junghan/configs/mimeapps.list";

    # Wallpaper for i3
    ".config/nixos-wallpaper.png".source = ./../../assets/indistractable.png;

    # [ARCHIVED] kime configuration - kept for reference
    # Reason: kime X11 Consume blocks Hangul/S-Space from reaching Kitty/KKP (2026-04-11)
    # Docs: https://github.com/Riey/kime/blob/develop/docs/CONFIGURATION.ko.md
    # ".config/kime/config.yaml".text = ''
    #   daemon:
    #     modules:
    #     - Xim
    #     - Indicator
    #     indicator:
    #       icon_color: White
    #     log:
    #       global_level: WARN
    #     engine:
    #       default_category: Latin
    #       global_hotkeys:
    #         AltR/Hangul/S-Space: Toggle [Hangul, Latin] Consume
    #         Esc: Switch Latin Bypass
    #       hangul: dubeolsik, word_commit: false
    # '';

    # [ARCHIVED] fcitx5 profile - kept for reference
    # Reason: Switched to kime for simpler config
    # ".config/fcitx5/profile".text = ''
    #   [GroupOrder]
    #   0=Default
    #   1=Korean
    #
    #   [Groups/0]
    #   Default Layout=us
    #   DefaultIM=Keyboard-us
    #   Name=Default
    #
    #   [Groups/0/Items/0]
    #   Layout=
    #   Name=keyboard-us
    #
    #   [Groups/1]
    #   Default Layout=kr-kr104
    #   DefaultIM=keyboard-kr-kr104
    #   Name=Korean
    #
    #   [Groups/1/Items/0]
    #   Layout=kr-kr104
    #   Name=keyboard-kr-kr104
    #
    #   [Groups/1/Items/1]
    #   Layout=kr-kr104
    #   Name=hangul
    # '';

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

  # X resources configuration (Oracle headless 제외)
  xresources = lib.mkIf (!isOracle) {
    extraConfig = builtins.readFile ./configs/Xresources;
  };

  #---------------------------------------------------------------------
  # X11 and Desktop configuration
  # (Shell configuration moved to modules/shell.nix)
  #---------------------------------------------------------------------

  # Cursor theme (96 DPI에 적합한 크기) — Oracle headless 제외
  home.pointerCursor = lib.mkIf (!isOracle) {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 32;
    x11.enable = true;
  };

  # i3status configuration moved to modules/i3.nix (py3status)
}
