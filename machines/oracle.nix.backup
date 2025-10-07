{ config, lib, pkgs, ... }:

let
  vars = import ../hosts/oracle/vars.nix;
in
{
  imports = [
    # NO shared.nix - keep Oracle VM minimal and independent
    ../hosts/oracle/hardware-configuration.nix
    ../hosts/oracle/disk-config.nix
    ../users/junghan/nixos.nix
  ];

  # Oracle specific configuration
  networking.hostName = vars.hostname;
  networking.networkmanager.enable = true;

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
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [ "nls=utf8" ];
  };

  # Nix configuration
  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
    settings = {
      substituters = ["https://cache.nixos.org"];
      trusted-public-keys = ["cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Multi-user target (headless server)
  systemd.targets.multi-user.enable = true;

  # ARM-specific settings
  hardware.enableRedistributableFirmware = true;

  # Timezone and locale
  time.timeZone = "Asia/Seoul";
  i18n.defaultLocale = "en_US.UTF-8";

  # Console
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # No GUI on Oracle VM
  services.xserver.enable = false;

  # Disable documentation for minimal install
  documentation.enable = false;

  # Enable tailscale
  services.tailscale.enable = true;

  # SSH
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;
  services.openssh.settings.PermitRootLogin = "no";

  # Don't require password for sudo
  security.sudo.wheelNeedsPassword = false;

  # Oracle-specific packages (minimal for server)
  environment.systemPackages = with pkgs; [
    # Essential tools
    vim
    git
    wget
    curl
    htop
    tmux

    # Cloud tools
    cloud-utils
  ];

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  system.stateVersion = "25.05";
}