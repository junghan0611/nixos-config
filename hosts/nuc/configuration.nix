{ config, lib, pkgs, ... }:

let
  vars = import ./vars.nix;
in
  {
    imports =
      [
        ./hardware-configuration.nix  # nixos-generate-config로 자동 생성됨
        # ./disk-config.nix # disko 이미 완료 hardware-configuration.nix와 충돌
      ];

    boot = {
      loader = {
        systemd-boot.enable = true;
        efi = {
          canTouchEfiVariables = true;
          efiSysMountPoint = "/boot";
        };
      };
      initrd.systemd.enable = true;
      kernelParams = [ "nls=utf8" ];
    };

    networking = {
      hostName = vars.hostname;
      networkmanager.enable = true;  # NetworkManager로 WiFi 관리

      # 고정 IP 필요시 (선택사항)
      # interfaces.eno1.ipv4.addresses = [{
      #   address = "218.48.101.11";
      #   prefixLength = 24;
      # }];
      # defaultGateway = "218.48.101.1";
      # nameservers = [ "8.8.8.8" "8.8.4.4" ];
    };

    time.timeZone = vars.timezone;

    # 한글 로케일 설정
    i18n = {
      defaultLocale = vars.locale;
      supportedLocales = [
        "en_US.UTF-8/UTF-8"
        "ko_KR.UTF-8/UTF-8"
        "C.UTF-8/UTF-8"
      ];
      extraLocaleSettings = {
        LC_MESSAGES = "en_US.UTF-8";
        LC_TIME = "ko_KR.UTF-8";
        LC_MONETARY = "ko_KR.UTF-8";
        LC_NUMERIC = "en_US.UTF-8";
        LC_CTYPE = "en_US.UTF-8";
      };
    };

    # 콘솔 한글 지원
    console = {
      font = "Lat2-Terminus16";
      keyMap = "us";
    };

    # 폰트 설정
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        liberation_ttf
        dejavu_fonts
        noto-fonts-cjk-sans
        noto-fonts-emoji
        d2coding
        fira-code
      ];
      fontconfig = {
        defaultFonts = {
          sansSerif = [ "Liberation Sans" "Noto Sans CJK KR" ];
          serif = [ "Liberation Serif" "Noto Serif CJK KR" ];
          monospace = [ "D2Coding" "Fira Code" ];
          emoji = [ "Noto Emoji" ];
        };
      };
      fontDir.enable = true;
    };

    users = {
      mutableUsers = true;
      users.${vars.username} = {
        isNormalUser = true;
        description = "Junghan Kim NUC";
        extraGroups = [
          "networkmanager"
          "wheel"
          "docker"
          "audio"
          "video"
        ];
        shell = pkgs.bash;
        openssh.authorizedKeys.keys = [ vars.sshKey ];
        initialPassword = "password";  # 설치 후 변경
      };
    };

    # Sudo 설정
    security.sudo.extraRules = [
      {
        users = [vars.username];
        commands = [
          {
            command = "ALL";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

    # 환경 변수
    environment.variables = {
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
    };

    # 시스템 패키지
    environment.systemPackages = with pkgs; [
      # 기본 도구
      wget
      vim
      curl
      git
      htop
      tmux
      jq
      uv
      fd
      ack
      tree
      lsof
      unzip
      iotop
      ncdu

      # 네트워크
      networkmanager
      iwd

      # 개발 도구
      python312
      nodejs_22
      pam
      gcc
      gh  # github
      neovim
      tree-sitter
      fzf
      delta
      git-lfs
      gnumake
      pkg-config
      mosh
      ripgrep
      pnpm # pnpm setup, pnpm add -g @anthropic-ai/claude-code
      openssl
      linux-pam

      # 네트워크 도구
      dnsutils      # nslookup, dig, host
      traceroute    # 네트워크 경로 추적
      yq-go         # YAML 처리 (Go 버전)
      bat           # 구문 강조 cat
      eza           # 모던 ls 대체
      httpie        # HTTP 클라이언트

      # 추가 도구
      infisical
      emacs-nox libvterm libtool cmake
      lnav
      pciutils
      direnv nix-direnv
      atuin
      starship
      lazygit
      zoxide
      broot
      onefetch
      bottom
      syncthing
      stc-cli

      # 한글 관련 도구
      glibc
      glibcLocales
      fontconfig
      file          # 파일 타입 확인 (한글 파일명 지원)
      less          # 텍스트 뷰어 (한글 지원)
      iconv         # 인코딩 변환
      enca          # 인코딩 자동 감지
    ];

    # SSH 서버
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };

    # Docker
    virtualisation.docker = {
      enable = true;
      daemon.settings = {
        data-root = "/var/lib/docker";
      };
    };

    # Syncthing
    services.syncthing = {
      enable = true;
      user = vars.username;
      dataDir = "/home/${vars.username}/sync";
      configDir = "/home/${vars.username}/.config/syncthing";
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        gui = {
          enabled = true;
          address = "127.0.0.1:8384";
        };
      };
    };

    # 방화벽
    networking.firewall = {
      allowedTCPPorts = [ 22 22000 ];
      allowedUDPPorts = [ 21027 22000 ];
    };

    # Nix 설정
    nixpkgs.config.allowUnfree = true;
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    system.stateVersion = "25.05";
  }
