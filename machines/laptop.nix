{ config, lib, pkgs, ... }:

{
  imports = [
    ./shared.nix
    # Import the existing hardware configuration
    ../hosts/laptop/hardware-configuration.nix
    # Note: disk-config.nix is only needed for fresh installations with disko
    # ../hosts/laptop/disk-config.nix
  ];

  # Laptop specific configuration
  networking.hostName = "laptop";

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
  ];

  # Enable thermald for Intel CPU thermal management
  services.thermald.enable = true;

  # Bluetooth management (blueman applet for i3)
  services.blueman.enable = true;

  # Disable ZRAM swap (using physical swap partition instead)
  zramSwap.enable = false;
}
