{ config, lib, pkgs, inputs, ... }:

let
  # Reuse the newer locked unstable snapshot without moving other packages.
  teamsPkgs = inputs.nixpkgs-herdr.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in

{
  imports = [
    ./shared.nix
    ../modules/embedded.nix
    # Import the existing hardware configuration
    ../hosts/laptop/hardware-configuration.nix
    # Note: disk-config.nix is only needed for fresh installations with disko
    # ../hosts/laptop/disk-config.nix
  ];

  # Laptop specific configuration
  networking.hostName = "laptop";
  specialisation = lib.mkForce {
    xfce.configuration = {
      services.xserver.desktopManager.xfce.enable = true;
      services.displayManager.defaultSession = lib.mkForce "xfce";
    };
  };
  services.openssh.settings.PasswordAuthentication = lib.mkForce false;
  services.openssh.settings.KbdInteractiveAuthentication = lib.mkForce false;
  services.autorandr.enable = true;
  services.fwupd.enable = true;
  programs.java = { enable = true; package = pkgs.jdk17; };

  # Boot configuration
  boot = {
    initrd.systemd.enable = true;
    kernelParams = [ "nls=utf8" ];
  };

  # Laptop-specific hardware settings
  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;

    # Bluetooth support
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # Power management for laptop (powersave for battery life)
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
      # Battery Care - Charge Thresholds (80% rule for longevity)
      # Start charging when below 40%, stop at 80%
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;

      # CPU Scaling Governor
      # Performance on AC, power-saving on battery
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # Intel CPU Energy/Performance Policies (HWP)
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Intel CPU Turbo Boost
      # Enable on AC, disable on battery for better battery life
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # PCI Express Active State Power Management
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # WiFi Power Saving
      WIFI_PWR_ON_AC = "off";    # Full performance when plugged in
      WIFI_PWR_ON_BAT = "on";    # Save power on battery

      # Runtime Power Management for PCI(e) devices
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # USB Autosuspend
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_BTUSB = 1;     # Don't suspend Bluetooth
      USB_EXCLUDE_PHONE = 1;     # Don't suspend phone connections
    };
  };

  # Audio support
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Graphics support (formerly hardware.opengl)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # Enable 32-bit support for compatibility
    extraPackages = with pkgs; [
      intel-media-driver  # VA-API driver for Broadwell+ iGPUs
      libvdpau-va-gl     # VDPAU driver with OpenGL/VA-API backend
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

  # Keyboard repeat rate (laptop keyboard sensitivity fix)
  services.xserver = {
    autoRepeatDelay = 500;    # 500ms delay before repeat starts
    autoRepeatInterval = 30;  # 30ms between repeats
  };

  # Laptop-specific packages
  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    powertop
    thermald
    acpi
    brightnessctl
    # Audio control (PipeWire)
    pavucontrol      # GUI volume control
    pulseaudio       # Provides pactl command for PipeWire
    # Network tools
    net-tools        # ifconfig, netstat, etc.
    libreoffice-fresh
    calibre
    teamsPkgs.teams-for-linux
    python3Packages.markitdown
  ];

  # Enable thermald for Intel CPU thermal management
  services.thermald.enable = true;

  # Bluetooth management (blueman applet for i3)
  services.blueman.enable = true;

  # Disable ZRAM swap (using physical swap partition instead)
  zramSwap.enable = false;
}
