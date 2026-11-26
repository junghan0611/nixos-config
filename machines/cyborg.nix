{ config, lib, pkgs, ... }:
{
  imports = [ ./shared.nix ../hosts/cyborg/hardware-configuration.nix ../modules/embedded.nix ];
  networking.hostName = "cyborg";
  # Keep i3 as the default boot; replace the shared GNOME variant with XFCE.
  specialisation = lib.mkForce {
    xfce.configuration = {
      services.xserver.desktopManager.xfce.enable = true;
      services.displayManager.defaultSession = lib.mkForce "xfce";
    };
  };
  users.users.junghan.initialPassword = lib.mkForce null;
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
  # Keep the Intel iGPU as the primary renderer; offload selected apps to Ada.
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
      offload.enable = true;
      offload.enableOffloadCmd = true;
    };
  };
  services.xserver = {
    # PRIME supplies the Intel modesetting device; do not claim NVIDIA with it.
    videoDrivers = [ "nvidia" ];
    autoRepeatDelay = 500;
    autoRepeatInterval = 30;
  };
  services.blueman.enable = true;
  services.autorandr.enable = true;
  services.fwupd.enable = true;
  programs.java = { enable = true; package = pkgs.jdk17; };
  environment.systemPackages = with pkgs; [ powertop acpi brightnessctl pavucontrol pulseaudio net-tools libreoffice-fresh calibre teams-for-linux gerbv poppler-utils ];
  # Local Andenken endpoint: boot the server, load models on demand, keep them warm.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    host = "127.0.0.1";
    port = 11435;
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "8h";
      OLLAMA_CONTEXT_LENGTH = "2048";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NO_CLOUD = "true";
      OLLAMA_NOPRUNE = "true";
    };
  };
}
