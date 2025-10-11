{ config, lib, pkgs, ... }:

{
  imports = [
    ./shared.nix
    # Import the existing hardware configuration
    ../hosts/nuc/hardware-configuration.nix
    # Note: disk-config.nix is only needed for fresh installations with disko
    # For existing systems, hardware-configuration.nix manages the filesystems
  ];

  # NUC specific configuration
  networking.hostName = "nuc";

  # Boot configuration specific to NUC
  boot = {
    initrd.systemd.enable = true;
    kernelParams = [ "nls=utf8" ];
  };

  # NUC-specific hardware settings
  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;

    # Bluetooth support
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # Power management for NUC
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "ondemand";
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

  # NUC-specific packages
  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    powertop
    thermald
  ];

  # Enable thermald for Intel CPU thermal management
  services.thermald.enable = true;

  # Bluetooth management (blueman applet for i3)
  services.blueman.enable = true;

  # Disable ZRAM swap (using physical swap partition instead)
  zramSwap.enable = false;
}
