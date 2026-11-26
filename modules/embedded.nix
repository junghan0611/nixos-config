{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ stlink openocd ];

  # Grant the active local session access to ST-LINK/V2 without sudo.
  # Avoid the upstream ST-LINK rule's world-writable device permissions.
  # The tag must be set before systemd's 73-seat-late.rules applies the ACL.
  services.udev.packages = [
    (pkgs.writeTextDir "lib/udev/rules.d/70-embedded-stlink.rules" ''
      SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="0483", ATTR{idProduct}=="3748", TAG+="uaccess"
    '')
  ];
}
