{ config, lib, pkgs, ... }:

{
  imports = [
    ./shared.nix
    # Future: Import hardware configuration when available
    # ../hosts/laptop/hardware-configuration.nix
  ];

  # Laptop specific configuration
  networking.hostName = "laptop";

  # Laptop-specific hardware settings
  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
  };

  # Power management for laptop
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
    acpi
    brightnessctl
    powertop
  ];
}