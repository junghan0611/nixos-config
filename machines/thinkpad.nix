{ config, lib, pkgs, ... }:

{
  imports = [
    ./shared.nix
    # Import the existing hardware configuration
    ../hosts/thinkpad/hardware-configuration.nix
    # Note: disk-config.nix is only needed for fresh installations with disko
    # ../hosts/thinkpad/disk-config.nix
  ];

  # ThinkPad specific configuration
  networking.hostName = "thinkpad";

  # thinkpad 전용 방화벽 포트 (shared.nix 공통 목록에 머지됨)
  # SK 테스트베드용, thinkpad에서만 개방:
  #   8883  : 허브 MQTT/TLS broker (sks-smoke, mTLS)
  #   18080 : 앱↔서버 REST (sks-server, 폰이 WiFi로 직결)
  networking.firewall.allowedTCPPorts = [ 8883 18080 ];

  # Boot configuration
  boot = {
    initrd.systemd.enable = true;
    kernelParams = [
      "nls=utf8"
      # AMD-specific optimizations
      "amd_pstate=active"  # AMD P-State driver for better power management
    ];
  };

  # ThinkPad P16s Gen 2 hardware settings (AMD Ryzen 7 PRO 7840U)
  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;

    # Bluetooth support (Qualcomm)
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    # AMD GPU (Radeon 780M - Phoenix1)
    amdgpu = {
      initrd.enable = true;  # Early KMS
    };
  };

  # Power management for laptop (AMD)
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave";
  };

  # TLP power management for laptop battery optimization
  # Disable power-profiles-daemon (conflicts with TLP)
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      # Battery Care - Charge Thresholds (ThinkPad specific)
      # Start charging when below 40%, stop at 80%
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;

      # CPU Scaling Governor (AMD)
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # AMD CPU Energy/Performance Preference
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # AMD CPU Boost
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # PCI Express Active State Power Management
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # WiFi Power Saving
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      # Runtime Power Management for PCI(e) devices
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # USB Autosuspend
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_BTUSB = 1;
      USB_EXCLUDE_PHONE = 1;

      # AMD GPU Power Management
      RADEON_DPM_STATE_ON_AC = "performance";
      RADEON_DPM_STATE_ON_BAT = "battery";
    };
  };

  # Audio support (PipeWire)
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # 내장 마이크가 빈 3.5mm 잭에 묶여 "not available"이 되는 문제 (alsa-ucm-conf #785).
  #
  # 이 기기(Realtek ALC257 + AMD ACP)에는 'Input Source' 셀렉터가 없어서 UCM이
  # HDA/HiFi-mic.conf 의 fallback 분기를 탄다. 그 분기는 내장 아날로그 마이크
  # (HiFi__Mic2, "Stereo Microphone")에 외부 잭 컨트롤 'Mic Jack'을 붙인다.
  # 잭이 비어 있으면 Mic Jack=off → 포트가 "not available" → WirePlumber가
  # 기본 소스 후보에서 제외 → 대신 AMD ACP 'Digital Microphone'(HiFi__Mic1)을
  # 고르는데, 이쪽은 열거만 되고 캡처는 완전 무음이다(실측 최대진폭 0.000000,
  # 정상인 Mic2는 0.999969). 결과: 화상회의마다 마이크가 죽는다.
  #
  # 이 기기에는 'Internal Mic Phantom Jack' 컨트롤이 없어 upstream 수정안을
  # 그대로 쓸 수 없다. 그래서 fallback 분기의 잭 바인딩만 걷어낸 UCM 트리를
  # 따로 만들고, PipeWire 쪽에만 ALSA_CONFIG_UCM2 로 그 트리를 물린다.
  #
  # alsa-ucm-conf 를 overlay 로 직접 패치하면 alsa-lib 체인이 딸려와
  # 로컬 빌드가 764개로 불어난다(2026-08-25 dry-build 실측). 그래서 패키지를
  # 건드리지 않고 복사본을 쓴다 — 빌드는 이 트리 하나뿐.
  #
  # 통하지 않은 것들 (2026-08-25 실측, 다시 시도하지 말 것):
  #   - wpctl set-default    → default.configured 만 바뀌고 활성 default 는 Mic1 유지
  #   - priority.session 하향 → availability 가 우선이라 무효
  #   - api.acp.auto-port=false → availability 보고 자체는 그대로
  #   - node.disabled on Mic1 → UCM이 두 마이크를 한 HiFi 프로파일로 묶어서
  #                             Mic2 까지 죽었다 ("Samples read: 0")
  #   - api.alsa.use-ucm=false → 아날로그 마이크 라우팅이 통째로 사라져 캡처 0
  #
  # 되돌리기: 이 블록을 지우고 rebuild. UCM 상류가 고쳐지면 함께 제거한다.
  systemd.user.services = let
    ucmMicFix = pkgs.runCommand "alsa-ucm-conf-thinkpad-micfix" { } ''
      cp -r ${pkgs.alsa-ucm-conf}/share/alsa/ucm2 $out
      chmod -R u+w $out
      substituteInPlace $out/HDA/HiFi-mic.conf \
        --replace-fail 'DeviceMicJack "Mic Jack"' 'DeviceMicJack ""'
    '';
  in {
    pipewire.environment.ALSA_CONFIG_UCM2 = "${ucmMicFix}";
    wireplumber.environment.ALSA_CONFIG_UCM2 = "${ucmMicFix}";
  };

  # Graphics support (AMD GPU)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # AMD VA-API driver for video acceleration
      libva
      libva-utils
      # Vulkan support
      # amdvlk # deprecated pkgs
      # ROCm OpenCL (optional, for GPU compute)
      # rocmPackages.clr
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      libva
    ];
  };

  # Enable touchpad support
  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true;
      naturalScrolling = true;
    };
  };

  # TrackPoint configuration (ThinkPad specific)
  hardware.trackpoint = {
    enable = true;
    sensitivity = 200;
    speed = 100;
    emulateWheel = true;
  };

  # Keyboard repeat rate
  services.xserver = {
    autoRepeatDelay = 500;
    autoRepeatInterval = 30;
  };

  # Java runtime (required for LibreOffice Java extensions like H2Orestart)
  programs.java = {
    enable = true;
    package = pkgs.jdk17;
  };

  # ThinkPad-specific packages
  environment.systemPackages = with pkgs; [
    # AMD GPU tools
    radeontop       # GPU monitoring
    lact            # AMD GPU control (Linux AMDGPU Controller)
    # Power management
    powertop
    acpi
    brightnessctl
    # Audio control (PipeWire)
    pavucontrol
    pulseaudio      # Provides pactl command for PipeWire
    # Network tools
    net-tools
    # Fingerprint (if available)
    fprintd
    # Office / library tools (thinkpad only)
    libreoffice-fresh
    calibre           # Provides calibredb
  ];

  # Bluetooth management
  services.blueman.enable = true;

  # Autorandr for automatic display detection on hotplug
  services.autorandr.enable = true;

  # Fwupd for firmware updates (ThinkPad LVFS support)
  services.fwupd.enable = true;

  # Fingerprint reader (optional - enable if hardware is present)
  # services.fprintd.enable = true;

  # Ollama with Vulkan for AMD 780M (qwen3-embedding:4b serving)
  # 2026-04-15 added → 2026-04-17 reverted (always-on policy)
  # 2026-05-07 revived: andenken/semantic-memory 세션 임베딩 빈도 ↑, OpenRouter 보조용
  # 2026-05-21 auto-start disabled: package/service kept, start manually when needed
  # OLLAMA_KEEP_ALIVE=10m → idle 10분 후 VRAM 언로드 (배터리 보호)
  services.ollama = {
    enable = true;
    # 26.05: `acceleration` 제거됨 → 가속 backend는 package로 선택
    package = pkgs.ollama-vulkan;
    host = "127.0.0.1";
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "10m";
    };
  };
  systemd.services.ollama.wantedBy = lib.mkForce [];

  # Disable ZRAM swap (using physical swap partition instead)
  zramSwap.enable = false;

  # ThinkPad fan control (optional)
  # services.thinkfan.enable = true;
}
