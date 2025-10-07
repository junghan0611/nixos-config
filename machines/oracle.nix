{ config, lib, pkgs, ... }:

let
  vars = import ../hosts/oracle/vars.nix;
in
{
  imports = [
    ./shared.nix
    # Import the existing hardware configuration
    ../hosts/oracle/hardware-configuration.nix
    ../hosts/oracle/disk-config.nix
  ];

  # Oracle specific configuration
  networking.hostName = vars.hostname;

  # Boot configuration for Oracle Cloud ARM VM
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    initrd.systemd.enable = true;
    # 한글 파일명 지원
    kernelParams = [ "nls=utf8" ];
  };

  # Multi-user target (headless server)
  systemd.targets.multi-user.enable = true;

  # ARM-specific settings
  hardware.enableRedistributableFirmware = true;

  # Since this is a headless server, we don't need GUI
  services.xserver.enable = lib.mkForce false;

  # Disable documentation for minimal install
  documentation.enable = false;

  # Oracle-specific packages (minimal for server)
  environment.systemPackages = with pkgs; [
    # Cloud tools
    cloud-utils
  ];
}