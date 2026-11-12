{ config, lib, pkgs, ... }:
{
  imports = [ ./shared.nix ../hosts/cyborg/hardware-configuration.nix ];
  networking.hostName = "cyborg";
  services.openssh.settings.PasswordAuthentication = lib.mkForce false;
  services.openssh.settings.KbdInteractiveAuthentication = lib.mkForce false;
  boot.initrd.systemd.enable = true;
  boot.kernelParams = [ "nls=utf8" ];
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [ pkgs.intel-media-driver ];
  };
  services.pipewire = { enable = true; alsa.enable = true; alsa.support32Bit = true; pulse.enable = true; };
  services.pulseaudio.enable = false;
  services.libinput = { enable = true; touchpad.tapping = true; touchpad.naturalScrolling = true; };
  services.blueman.enable = true;
  services.autorandr.enable = true;
  services.fwupd.enable = true;
  programs.java = { enable = true; package = pkgs.jdk17; };
  environment.systemPackages = with pkgs; [ powertop acpi brightnessctl pavucontrol pulseaudio net-tools libreoffice-fresh calibre ];
  # NVIDIA PRIME and Ollama acceleration require measured PCI IDs and validation.
  services.ollama = { enable = true; host = "127.0.0.1"; environmentVariables.OLLAMA_KEEP_ALIVE = "10m"; };
  systemd.services.ollama.wantedBy = lib.mkForce [];
}
