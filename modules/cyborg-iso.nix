{ pkgs, modulesPath, cyborgSystem, ... }:
let
  install = pkgs.writeShellApplication {
    name = "cyborg-install";
    runtimeInputs = with pkgs; [ coreutils gnugrep util-linux parted dosfstools e2fsprogs systemd nixos-install-tools ];
    text = ''
      fail() { echo "$*" >&2; exit 1; }
      [[ $EUID == 0 && -t 0 ]] || fail 'Run sudo cyborg-install in the live terminal.'
      [[ -d /sys/firmware/efi/efivars ]] || fail 'Boot in UEFI mode first.'
      shopt -s nullglob
      requested=""
      if [[ $# != 0 ]]; then
        [[ $# == 2 && $1 == --disk && $2 == /dev/* ]] || fail 'Usage: cyborg-install [--disk /dev/DEVICE]'
        requested=$2
      fi
      identify() {
        local device name path model serial
        local -a disks=()
        if [[ -n $requested ]]; then
          device=$(realpath -e "$requested") || return 1
          [[ $device =~ ^/dev/(sd[a-z]+|nvme[0-9]+n[0-9]+)$ && -b $device ]] || return 1
          case $(lsblk -dnro TYPE,TRAN,RM,RO "$device") in
            'disk sata 0 0'|'disk ata 0 0'|'disk nvme 0 0') ;;
            *) return 1 ;;
          esac
          path=$(realpath -e "/sys/class/block/''${device##*/}") || return 1
          [[ $path =~ ^/sys/devices/pci[^/]+/ && $path != */usb* && $path != */thunderbolt* ]] || return 1
          serial=$(lsblk -dnro SERIAL "$device") || return 1
          [[ -n $serial ]] || return 1
          printf '%s %s %s\n' "$device" "$path" "$serial"
          return
        fi
        for device in /sys/class/block/nvme*; do
          name="''${device##*/}"
          [[ $name =~ ^nvme[0-9]+(c[0-9]+)?n[0-9]+$ ]] || continue
          [[ -b /dev/$name ]] || return 1
          disks+=("/dev/$name")
        done
        [[ ''${#disks[@]} == 1 ]] || return 1
        device="''${disks[0]}"
        [[ $(lsblk -dnro TYPE,TRAN,RM,RO "$device") == 'disk nvme 0 0' ]] || return 1
        path=$(realpath -e "/sys/class/block/''${device##*/}") || return 1
        [[ $path =~ ^/sys/devices/pci[^/]+/ && $path != */usb* && $path != */thunderbolt* ]] || return 1
        model=$(lsblk -dno MODEL "$device") || return 1
        [[ ''${model^^} == *KLEVV*C910* ]] || return 1
        serial=$(lsblk -dnro SERIAL "$device") || return 1
        [[ -n $serial ]] || return 1
        printf '%s %s %s %s\n' "$device" "$path" "$serial" "$(lsblk -dnro MAJ:MIN "$device")"
      }
      disk_id=$(identify) || fail 'Target not eligible: use the default KLEVV C910 NVMe or explicitly pass a writable SATA/NVMe disk with a readable serial via --disk.'
      disk="''${disk_id%% *}"
      part_prefix=$disk
      [[ $disk != /dev/nvme* ]] || part_prefix="''${disk}p"
      preflight() {
        [[ $(identify) == "$disk_id" ]] || fail 'Disk identity or candidate set changed.'
        local devices name label node
        devices=$(lsblk -nrpo NAME,LABEL)
        while read -r name label; do
          case "$label" in
            CYBORG-BOOT|cyborg-root)
              [[ $name == "$part_prefix"[0-9]* ]] || fail "Label $label already exists on $name."
              ;;
          esac
        done <<< "$devices"
        mountpoints=$(lsblk -nro MOUNTPOINTS "$disk")
        [[ -z ''${mountpoints//[[:space:]]/} ]] || fail 'Target has mounted filesystems or active swap.'
        mounts=$(findmnt -rn -o TARGET)
        if grep -E '^/mnt(/|$)' <<< "$mounts" >/dev/null; then
          fail 'Unmount /mnt and its submounts first.'
        fi
        for node in "$disk" "$part_prefix"[0-9]*; do
          holders=(/sys/class/block/"''${node##*/}"/holders/*)
          [[ ''${#holders[@]} == 0 ]] || fail "Active device mapping on $node."
        done
      }
      preflight
      lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS "$disk"
      printf 'ERASE ALL DATA ON %s and install NixOS? Type YES: ' "$disk"
      read -r answer
      [[ $answer == YES ]] || fail 'Cancelled; disk unchanged.'
      preflight

      trap 'echo "Installation interrupted after erase was authorized. Check disk and /mnt state before recovery; do not blindly rerun." >&2' EXIT
      wipefs --all --lock=yes "$disk"
      parted -s "$disk" mklabel gpt mkpart ESP fat32 1MiB 1025MiB set 1 esp on mkpart root ext4 1025MiB 100%
      partprobe "$disk"
      udevadm settle
      esp="''${part_prefix}1"
      root="''${part_prefix}2"
      [[ -b $esp && -b $root ]] || fail 'Expected target partitions did not appear.'
      mkfs.fat -F 32 -n CYBORG-BOOT "$esp"
      mkfs.ext4 -F -L cyborg-root "$root"
      mount "$root" /mnt
      mkdir -p /mnt/boot
      mount "$esp" /mnt/boot
      nixos-install --root /mnt --system ${cyborgSystem} --no-root-passwd --no-channel-copy
      until nixos-enter --root /mnt --command 'passwd junghan'; do
        echo 'Password setup failed; retry or press Ctrl+C to stop.' >&2
      done
      trap - EXIT
      echo 'Installed. Reboot and remove the Ventoy USB.'
    '';
  };
in {
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-graphical-base.nix") ];
  services.xserver.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.displayManager.defaultSession = "xfce";
  services.displayManager.autoLogin = { enable = true; user = "nixos"; };
  # Live installer only: keep the screensaver, but do not lock on idle or sleep.
  # This module is not imported by the installed cyborg configuration.
  environment.etc."xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-screensaver" version="1.0">
      <property name="lock" type="empty">
        <property name="saver-activation" type="empty">
          <property name="enabled" type="bool" value="false"/>
        </property>
        <property name="sleep-activation" type="bool" value="false"/>
      </property>
    </channel>
  '';
  isoImage.storeContents = [ cyborgSystem ];
  # Build on a remote worker to keep the Ventoy payload smaller.
  isoImage.squashfsCompression = "zstd -Xcompression-level 19";
  environment.systemPackages = [ install pkgs.parted pkgs.dosfstools pkgs.e2fsprogs ];
}
