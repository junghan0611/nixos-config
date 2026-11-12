# Pre-install baseline. Replace with nixos-generate-config output from the machine.
{ config, lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usb_storage" "uas" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  fileSystems."/" = { device = "/dev/disk/by-label/cyborg-root"; fsType = "ext4"; };
  fileSystems."/boot" = { device = "/dev/disk/by-label/CYBORG-BOOT"; fsType = "vfat"; };
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
