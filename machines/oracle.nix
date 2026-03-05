{ config, lib, pkgs, ... }:

{
  imports = [
    ./shared.nix
    # Import the existing hardware configuration
    ../hosts/oracle/hardware-configuration.nix
    # Oracle-specific disk configuration (초기 설치용 - 부팅 시에는 hardware-configuration.nix 사용)
    # ../hosts/oracle/disk-config.nix
  ];

  # Oracle Cloud specific configuration
  networking.hostName = "oracle";

  # Boot configuration for Oracle Cloud ARM VM
  boot = {
    initrd.systemd.enable = true;
    kernelParams = [
      "nls=utf8"
      "console=tty1"
      "console=ttyAMA0,115200n8"  # ARM serial console
    ];
  };

  # Oracle Cloud ARM specific hardware settings
  hardware = {
    enableRedistributableFirmware = true;

    # No bluetooth on cloud VM
    bluetooth.enable = false;
  };

  # Power management not needed for cloud VM
  powerManagement.enable = false;

  # Audio support - minimal for cloud environment
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = false;  # ARM64, no 32-bit support needed
    pulse.enable = true;
  };

  # Basic graphics support for cloud environment
  hardware.graphics = {
    enable = true;
    enable32Bit = false;  # ARM64 only
  };

  # Oracle Cloud specific packages
  environment.systemPackages = with pkgs; [
    # Cloud utilities
    cloud-utils

    # Monitoring for cloud environment
    htop
    iotop
    nethogs
    iftop

    # Basic tools
    # mesa-demos
  ];

  # Networking - Oracle Cloud specific
  networking.firewall = {
    enable = true;

    allowedTCPPorts = [
      22     # SSH
      80     # HTTP (Remark42 ACME challenge)
      443    # HTTPS (Remark42)
      22000  # Syncthing sync
    ];

    allowedUDPPorts = [
      21027  # Syncthing discovery
      22000  # Syncthing QUIC
      # mosh: 22번 포트로 사용 중, 외부 UDP 불필요
    ];
  };

  # Oracle Cloud Volume management
  # Auto-resize root partition on boot
  boot.growPartition = true;

  # Disable unnecessary services for cloud VM
  services.avahi.enable = false;
  services.printing.enable = false;
  services.libinput.enable = false;  # No touchpad in cloud

  # ZRAM swap disabled
  zramSwap = {
    enable = false;
    # algorithm = "zstd";
    # memoryPercent = 50;  # Use up to 50% of RAM for compressed swap
  };

  # System-wide performance tuning
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 87380 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
  };

  # ============================================================
  # Security hardening (Oracle VM — 공인 IP 노출 서버)
  # ============================================================

  # P0: SSH 패스워드 인증 끄기 (shared.nix의 true를 mkForce override)
  services.openssh.settings.PasswordAuthentication = lib.mkForce false;
  services.openssh.settings.KbdInteractiveAuthentication = lib.mkForce false;

  # P0: fail2ban — SSH 무차별 대입 공격 차단
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;      # 반복 공격 시 밴 시간 점진적 증가
      maxtime = "168h";   # 최대 7일
    };
  };

  # P1: sudo 패스워드 요구 (shared.nix의 NOPASSWD override)
  # 개인 PC는 편의상 NOPASSWD 유지, 클라우드 서버만 패스워드 요구
  security.sudo.wheelNeedsPassword = lib.mkForce true;
  security.sudo.extraRules = lib.mkForce [
    {
      users = [ "junghan" ];
      commands = [
        {
          command = "${pkgs.systemd}/bin/systemctl";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Oracle Cloud specific notes
  system.nixos.tags = [ "oracle-cloud" "arm64" ];
}
