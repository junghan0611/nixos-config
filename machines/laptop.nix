{ config, lib, pkgs, ... }:

{
  imports = [
    ./shared.nix
    # Import the existing hardware configuration
    ../hosts/laptop/hardware-configuration.nix
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

  # TLP for better battery life
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;
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

  # ZRAM swap
  zramSwap.enable = true;
}