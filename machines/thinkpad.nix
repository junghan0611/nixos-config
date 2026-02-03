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
    # Office suite (optional, thinkpad only)
    libreoffice-fresh
  ];

  # Bluetooth management
  services.blueman.enable = true;

  # Autorandr for automatic display detection on hotplug
  services.autorandr.enable = true;

  # Fwupd for firmware updates (ThinkPad LVFS support)
  services.fwupd.enable = true;

  # Fingerprint reader (optional - enable if hardware is present)
  # services.fprintd.enable = true;

  # Disable ZRAM swap (using physical swap partition instead)
  zramSwap.enable = false;

  # ThinkPad fan control (optional)
  # services.thinkfan.enable = true;
}
