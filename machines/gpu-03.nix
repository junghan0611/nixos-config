{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware/gpu-03-hardware-configuration.nix
  ];

  networking.hostName = "gpu-03";

  # Static IP configuration for 10G network (same as hej-nixos-cluster)
  networking.interfaces.enp5s0.ipv4.addresses = [
    {
      address = "192.168.2.13";
      prefixLength = 24;
    }
  ];
  networking.interfaces.enp5s0.mtu = 9000;

  networking.useDHCP = lib.mkDefault false;

  #############################
  # NFS 클라이언트 구성 (동일)
  #############################
  fileSystems."/storage/shared" = {
    device = "192.168.2.10:/storage/shared";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" ];
  };

  fileSystems."/storage/data" = {
    device = "192.168.2.10:/storage/data";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" ];
  };

  fileSystems."/storage/backup" = {
    device = "192.168.2.10:/storage/backup";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" ];
  };

  # /storage/models (ollama/vLLM용) - hej-nixos-cluster/modules/gpu/ollama.nix 에서 이식
  fileSystems."/storage/models" = {
    device = "192.168.2.10:/storage/models";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "rsize=1048576"
      "wsize=1048576"
      "nofail"
    ];
  };

  #############################
  # NVIDIA / CUDA 구성 (동일)
  #############################
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;
    nvidiaSettings = true;
    nvidiaPersistenced = true;
  };

  hardware.graphics.enable = true;

  nixpkgs.config.cudaSupport = true;

  environment.systemPackages = with pkgs; [
    cudatoolkit
    nvtopPackages.nvidia
  ];

  #############################
  # Docker 설정
  #############################
  virtualisation.docker.enable = true;

  #############################
  # hej-nixos-cluster/common/networking.nix 대응
  #############################
  networking.networkmanager.enable = true;
  networking.firewall.enable = lib.mkForce false;

  #############################
  # hej-nixos-cluster/common/korean-fonts.nix 대응
  #############################
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

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      liberation_ttf
      dejavu_fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      noto-fonts-monochrome-emoji
      d2coding
      fira-code
      fira-code-symbols
      nanum
      nanum-gothic-coding
      font-awesome
      noto-fonts
    ];
    fontconfig = {
      defaultFonts = {
        sansSerif = [
          "Liberation Sans"
          "Noto Sans CJK KR"
          "DejaVu Sans"
        ];
        serif = [
          "Liberation Serif"
          "Noto Serif CJK KR"
          "DejaVu Serif"
        ];
        monospace = [
          "D2Coding"
          "Fira Code"
          "Liberation Mono"
          "DejaVu Sans Mono"
        ];
        emoji = [ "Noto Emoji" ];
      };
      hinting = {
        enable = true;
        style = "slight";
      };
      antialias = true;
      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
      };
    };
    fontDir.enable = true;
  };

  environment.variables = {
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    FONTCONFIG_PATH = "/etc/fonts";
  };

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

  # Boot loader (UEFI, systemd-boot like existing configs)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = [ "nls=utf8" ];

  #############################
  # 사용자 및 SSH (hej-nixos-cluster/common/base.nix 대응)
  #############################
  users = {
    defaultUserShell = pkgs.bash;
    users = {
      root = {
        openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDZUK8p2ckBgEd7HUc+LKLSNIiWWo+JsLMGOw964r5zs975rBV+8vt6IYY5T/n3irVG4fdju/g5q8TBcIHx7upELF9ObgsO31MDg9Sv2R1KQOLQhYwS6rXx1Bg3wo1IqddnuMbZvS5pFt4PTmu2n08i2N4/PTc44H5e7TC9tXhpKdjC5zPLVtmvI93rQA+j9x61nvxoJa3YuB4x62Ak1KjQ+B6jZRZo/UkjYTy9DDSkYi/7mLkjQ3LXGXo1sRXgkV9BN2SYuFr8gPqqaDbdyEE5HaJ8BmTLEKq/GiQbBwAtLblmAkJHVJHUCAGQKW9W2Br3vDkNCY1jvWsvQSGbFS8fCCWaEyO6BRKqEXLPI0CgQe6/vj44jpWx3q9Wn2OPOOU/bPGxXjsyjPgzFZBFYX53AEkBsDE8edZYSFdkATu5Okb1W/znBV602bS9p9dGzIqS4yjY8efaYujlhsMXfD7KHBdrEP4TCydKpWzkULk+xizCcE8MfAVlFkEsuTKpbs= jhkim2@goqual.com"
        ];
        hashedPassword = null;
      };

      goqual = {
        isNormalUser = true;
        description = "GoQual AI Cluster User";
        extraGroups = [ "wheel" "docker" "users" ];
        shell = pkgs.bash;
        home = "/home/goqual";
        openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDZUK8p2ckBgEd7HUc+LKLSNIiWWo+JsLMGOw964r5zs975rBV+8vt6IYY5T/n3irVG4fdju/g5q8TBcIHx7upELF9ObgsO31MDg9Sv2R1KQOLQhYwS6rXx1Bg3wo1IqddnuMbZvS5pFt4PTmu2n08i2N4/PTc44H5e7TC9tXhpKdjC5zPLVtmvI93rQA+j9x61nvxoJa3YuB4x62Ak1KjQ+B6jZRZo/UkjYTy9DDSkYi/7mLkjQ3LXGXo1sRXgkV9BN2SYuFr8gPqqaDbdyEE5HaJ8BmTLEKq/GiQbBwAtLblmAkJHVJHUCAGQKW9W2Br3vDkNCY1jvWsvQSGbFS8fCCWaEyO6BRKqEXLPI0CgQe6/vj44jpWx3q9Wn2OPOOU/bPGxXjsyjPgzFZBFYX53AEkBsDE8edZYSFdkATu5Okb1W/znBV602bS9p9dGzIqS4yjY8efaYujlhsMXfD7KHBdrEP4TCydKpWzkULk+xizCcE8MfAVlFkEsuTKpbs= jhkim2@goqual.com"
        ];
        initialPassword = "goqual1!";
        passwordFile = null;
      };
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = true;
    };
  };

  system.stateVersion = "25.05";

  #############################
  # Ollama (stable pkgs.ollama)
  #############################
  users.users.ollama = {
    isSystemUser = true;
    group = "ollama";
    uid = 1042;
  };

  users.groups.ollama = {
    gid = 1042;
  };

  services.ollama = {
    enable = true;
    package = pkgs.ollama;
    acceleration = "cuda";
    models = "/storage/models/ollama";
    host = "0.0.0.0";
    user = "ollama";
    group = "ollama";
    environmentVariables = {
      OLLAMA_NUM_PARALLEL = "4";
      OLLAMA_MAX_LOADED_MODELS = "2";
      OLLAMA_KEEP_ALIVE = "10m";
      CUDA_VISIBLE_DEVICES = "0";
    };
  };

  systemd.services.ollama = {
    requires = [ "storage-models.mount" ];
    after = [ "storage-models.mount" ];
  };
}
