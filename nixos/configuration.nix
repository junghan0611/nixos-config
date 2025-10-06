{ config, lib, pkgs, ... }:

let
  vars = import ./vars.nix;
in
  {
    imports =
      [
        ./hardware-configuration.nix
        "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/v1.11.0.tar.gz"}/module.nix"
        ./disk-config.nix
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
      # 한글 파일명 지원
      kernelParams = [ "nls=utf8" ];
    };

    systemd.targets.multi-user.enable = true;

    networking.hostName = vars.hostname;
    networking.networkmanager.enable = true;

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
      useXkbConfig = false;
    };

    # 폰트 설정 (서버용 최소 구성)
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        # 기본 영어 폰트
        liberation_ttf
        dejavu_fonts

        # 한글 폰트 (필수만)
        noto-fonts-cjk-sans    # Noto Sans CJK
        noto-fonts-emoji       # 이모지 지원

        # 개발용 폰트
        d2coding              # D2Coding (네이버 한글 코딩 폰트)
        fira-code             # Fira Code (프로그래밍 폰트)
      ];

      fontconfig = {
        defaultFonts = {
          sansSerif = [
            "Liberation Sans"
            "Noto Sans CJK KR"
          ];
          serif = [
            "Liberation Serif"
            "Noto Serif CJK KR"
          ];
          monospace = [
            "D2Coding"
            "Fira Code"
            "Liberation Mono"
          ];
          emoji = [ "Noto Emoji" ];
        };
        hinting = {
          enable = true;
          style = "slight";
        };
        antialias = true;
      };
      fontDir.enable = true;
    };

    users = {
      mutableUsers = true;
      users.${vars.username} = {
        isNormalUser = true;
        description = "Junghan Kim, SUPA-USER";
        extraGroups = [
          "networkmanager"
          "docker"         # Docker 사용 권한
          "users"          # 기본 사용자 그룹
          "wheel"
        ];

        shell = pkgs.bash;
        openssh.authorizedKeys.keys = [ vars.sshKey ];
        initialPassword = "password";
      };
    };

    # Enable passwordless sudo.
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

    # 환경 변수 설정 (한글 지원)
    environment.variables = {
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      FONTCONFIG_PATH = "/etc/fonts";
    };

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

      # 한글 관련 도구
      glibc
      glibcLocales
      fontconfig
      file          # 파일 타입 확인 (한글 파일명 지원)
      less          # 텍스트 뷰어 (한글 지원)
      iconv         # 인코딩 변환
      enca          # 인코딩 자동 감지
    ];

    # Enable the OpenSSH daemon.
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };

    nixpkgs.config.allowUnfree = true;

    # Disable autologin.
    services.getty.autologinUser = null;

    # Open ports in the firewall.
    networking.firewall.allowedTCPPorts = [ 22 ];
    # networking.firewall.allowedUDPPorts = [ ... ];

    # Disable documentation for minimal install.
    documentation.enable = false;

    # Docker 설정
    virtualisation.docker = {
      enable = true;
      daemon.settings = {
        data-root = "/var/lib/docker";  # Oracle Cloud는 기본 경로 사용
      };
    };

    # 폰트 캐시 업데이트 서비스
    systemd.services.font-cache-update = {
      description = "Update font cache for Korean fonts";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.fontconfig}/bin/fc-cache -fv";
      };
    };

    # This option defines the first version of NixOS you have installed on this particular machine,
    # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
    #
    # Most users should NEVER change this value after the initial install, for any reason,
    # even if you've upgraded your system to a new NixOS release.
    #
    # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
    # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
    # to actually do that.
    #
    # This value being lower than the current NixOS release does NOT mean your system is
    # out of date, out of support, or vulnerable.
    #
    # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
    # and migrated your data accordingly.
    #
    # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
    system.stateVersion = "25.05"; # Did you read the comment?
  }