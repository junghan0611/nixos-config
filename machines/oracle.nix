{ config, lib, pkgs, ... }:

let
  # sudoers는 명령 인자를 안전하게 구조화하지 못한다. 이 wrapper가 허용 동작을
  # 고정해 OpenClaw Android node 실험에 필요한 tailnet 조작만 root로 수행한다.
  tailscaleOpenClawNode = pkgs.writeShellScriptBin "tailscale-openclaw-node" ''
    set -eu

    if [ "$#" -ne 1 ]; then
      echo "usage: tailscale-openclaw-node {up|serve}" >&2
      exit 64
    fi

    case "$1" in
      up)
        exec ${pkgs.tailscale}/bin/tailscale up
        ;;
      serve)
        exec ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://127.0.0.1:18789
        ;;
      *)
        echo "allowed actions: up, serve" >&2
        exit 64
        ;;
    esac
  '';

  # audit 로그는 0700 root라 조회에 root가 필요한데, sudo NOPASSWD로 auditctl을
  # 통째로 열면 `-D`(규칙 전체 삭제)와 `-e 0`(감사 끄기)까지 같이 열린다.
  # 즉 감사 설비를 감사 대상이 무력화할 수 있게 된다. 그래서 위 tailscale
  # wrapper와 같은 방식으로 "읽기 전용 질의"만 고정해 노출한다.
  # 사용자 인자를 일절 받지 않으므로 인자 주입면이 없다.
  auditQuery = pkgs.writeShellScriptBin "audit-query" ''
    set -eu
    AUDITCTL=${pkgs.audit}/bin/auditctl
    AUSEARCH=${pkgs.audit}/bin/ausearch

    if [ "$#" -ne 1 ]; then
      echo "usage: audit-query {rules|status|term|kill|recent|size}" >&2
      exit 64
    fi

    case "$1" in
      rules)  exec "$AUDITCTL" -l ;;
      status) exec "$AUDITCTL" -s ;;
      # -i = 숫자를 이름으로 해석. a0=대상 pid, a1=신호, pid/comm/auid=발신자.
      term)   exec "$AUSEARCH" -i -k sig_term -ts today ;;
      kill)   exec "$AUSEARCH" -i -k sig_kill -ts today ;;
      # -k는 한 번만 먹으므로 두 키를 합칠 땐 syscall로 거른다 (두 규칙 다 kill(2)).
      recent) exec "$AUSEARCH" -i -sc kill -ts recent ;;
      # 잡음량 실측용 — 로그가 실제로 얼마나 차는지 본다.
      size)   exec ${pkgs.coreutils}/bin/du -sh /var/log/audit ;;
      *)
        echo "allowed actions: rules, status, term, kill, recent, size" >&2
        exit 64
        ;;
    esac
  '';
in
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
    tailscaleOpenClawNode
    auditQuery

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
          command = "/run/current-system/sw/bin/systemctl";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nix-env";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nix-collect-garbage";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nix-store";
          options = [ "NOPASSWD" ];
        }
        # OpenClaw Android node의 1차 tailnet 실험. wrapper 내부가 up과 이
        # gateway loopback Serve 레인만 허용한다.
        {
          command = "/run/current-system/sw/bin/tailscale-openclaw-node";
          options = [ "NOPASSWD" ];
        }
        # 읽기 전용 audit 질의만. wrapper 내부가 조회 6종으로 고정하므로
        # 규칙 삭제(-D)·감사 비활성(-e 0) 경로는 열리지 않는다.
        {
          command = "/run/current-system/sw/bin/audit-query";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # P2: 신호 감사 — "누가 이 프로세스를 죽였나"를 남긴다.
  #
  # 2026-09-01 20:42:53, uid 1000 프로세스 전체에 SIGTERM 한 방이 들어와
  # SSH 세션 5개·tmux 판 전부·emacs·syncthing·user@1000, 그리고 호스트 uid가
  # 1000이던 컨테이너 3개(openclaw-gateway/forge/aions-cloudflared)가 동시에
  # 죽었다. `kill(-1, SIGTERM)`의 서명인데 발신자를 특정할 수단이 없었다 —
  # auditd 꺼짐, 셸 이력 0건, 크론/타이머 무발화, 코어덤프 없음.
  # 재발 시 `ausearch -k sig_term` 한 줄로 발신 pid/comm/uid를 잡기 위한 설비다.
  security.auditd.enable = true;
  security.audit = {
    enable = true;
    # 커널이 백로그를 못 비울 때 syscall을 막지 않는다. printk 경고만 남긴다.
    # ("panic"은 원격 VM에서 곧 사망이므로 절대 쓰지 않는다.)
    failureMode = "printk";
    backlogLimit = 8192;
    rules = [
      # tkill/tgkill은 제외한다 — glibc raise()/pthread_kill이 이걸 쓰기 때문에
      # 스레드 내부 신호까지 다 걸려 로그가 폭주한다. uid 전체 브로드캐스트는
      # 오직 kill(2)로만 오므로 kill 하나면 충분하다.
      #
      # signal 0(생존 probe)도 제외된다 — a1로 9/15만 잡는다. prime-agent와
      # entwurf가 process.kill(pid, 0)을 상시 쏘므로 이걸 안 거르면 잡음이 지배한다.
      "-a always,exit -F arch=b64 -S kill -F a1=15 -k sig_term"
      "-a always,exit -F arch=b64 -S kill -F a1=9 -k sig_kill"
    ];
  };
  # auditd 기본값에 의존하지 않고 디스크 정책을 명시한다. 원격 VM에서
  # halt/single 계열 동작은 곧 복구 불가이므로 SUSPEND(로깅만 중단)로 고정한다.
  security.auditd.settings = {
    max_log_file = 16;          # MiB
    num_logs = 4;               # 총 상한 64MiB
    max_log_file_action = "ROTATE";
    space_left = 512;
    space_left_action = "SYSLOG";
    admin_space_left = 128;
    admin_space_left_action = "SUSPEND";
    disk_full_action = "SUSPEND";
    disk_error_action = "SUSPEND";
  };

  # emacs 소켓 디렉토리를 docker보다 먼저, junghan 소유로 만들어 둔다.
  #
  # openclaw-gateway(`/run/user/1000/emacs:/run/emacs:ro`)와 geworfen이 이 경로를
  # bind mount 하는데, docker는 없는 bind source를 **root 소유로** 만든다. 부팅
  # 순서상 docker가 emacs보다 먼저 뜨면 emacs가 자기 소켓 디렉토리를 잃는다:
  #   Unable to start daemon: '/run/user/1000/emacs' is not a safe directory
  #   because it is not owned by you (owner = System administrator (0)); exiting
  # 2026-09-01 재부팅에서 실제로 터졌다. 그 전 16일은 8월에 emacs가 먼저 만들어
  # 둔 디렉토리가 남아 있어서 가려져 있었을 뿐 — 재부팅마다 재발하는 문제였다.
  #
  # /run/user/1000 은 logind가 거는 tmpfs이므로 systemd.tmpfiles로는 못 앞지른다
  # (tmpfs가 나중에 덮어쓴다). user-runtime-dir 뒤, docker 앞이 유일한 창이다.
  systemd.services.emacs-socket-dir = {
    description = "Pre-create /run/user/1000/emacs owned by junghan (before docker binds it)";
    wantedBy = [ "multi-user.target" ];
    requires = [ "user-runtime-dir@1000.service" ];
    after = [ "user-runtime-dir@1000.service" ];
    before = [ "docker.service" "docker.socket" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/install -d -o junghan -g users -m 0700 /run/user/1000/emacs";
    };
  };

  # Headless VM에 vconsole 불필요 — 물리 콘솔 없어 setfont 실패
  systemd.services.systemd-vconsole-setup.enable = false;

  # Oracle Cloud specific notes
  system.nixos.tags = [ "oracle-cloud" "arm64" ];
}
