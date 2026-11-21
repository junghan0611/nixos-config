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
      identify() {
        local device name path model serial
        local -a disks=()
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
      disk_id=$(identify) || fail 'Expected exactly one writable PCIe NVMe matching KLEVV C910, with a readable serial.'
      disk="''${disk_id%% *}"
      preflight() {
        [[ $(identify) == "$disk_id" ]] || fail 'Disk identity or candidate set changed.'
        local devices name label node
        devices=$(lsblk -nrpo NAME,LABEL)
        while read -r name label; do
          case "$label" in
            CYBORG-BOOT|cyborg-root)
              [[ $name == "$disk"p[0-9]* ]] || fail "Label $label already exists on $name."
              ;;
          esac
        done <<< "$devices"
        mountpoints=$(lsblk -nro MOUNTPOINTS "$disk")
        [[ -z ''${mountpoints//[[:space:]]/} ]] || fail 'Target has mounted filesystems or active swap.'
        mounts=$(findmnt -rn -o TARGET)
        if grep -E '^/mnt(/|$)' <<< "$mounts" >/dev/null; then
          fail 'Unmount /mnt and its submounts first.'
        fi
        for node in "$disk" "$disk"p*; do
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
      esp="''${disk}p1"
      root="''${disk}p2"
      [[ -b $esp && -b $root ]] || fail 'Expected NVMe partitions did not appear.'
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
  isoImage.storeContents = [ cyborgSystem ];
  # Favor faster local builds over a smaller Ventoy image.
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";
  environment.systemPackages = [ install pkgs.parted pkgs.dosfstools pkgs.e2fsprogs ];
}
