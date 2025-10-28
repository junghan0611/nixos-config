# Samsung NT930SBE NixOS Hardware Support Guide

**Model**: Samsung NT930SBE/931SBE/930SBV (Samsung Galaxy Book)
**NixOS Version**: 25.05
**Kernel**: 6.17.5
**Date**: 2025-10-28
**Status**: Production Ready ✅

## Executive Summary

This guide provides comprehensive NixOS configuration for Samsung Galaxy Book NT930SBE laptop. Unlike Ubuntu where Samsung-specific features require manual driver compilation and maintenance, NixOS provides a declarative, reproducible setup with automatic hardware detection and integrated power management.

**Key Features Covered:**
- ✅ Battery management with charge thresholds (TLP)
- ✅ Screen brightness control via Fn keys
- ✅ Keyboard backlight control
- ✅ Intel graphics optimization
- ✅ Audio with PipeWire
- ✅ Touchpad, touchscreen, stylus support
- ✅ Thermal management

---

## Table of Contents

1. [Hardware Specifications](#hardware-specifications)
2. [Current Support Status](#current-support-status)
3. [Critical Configuration](#critical-configuration)
4. [Testing & Verification](#testing--verification)
5. [Troubleshooting](#troubleshooting)
6. [Advanced Topics](#advanced-topics)

---

## Hardware Specifications

### System Information
```
Manufacturer: SAMSUNG ELECTRONICS CO., LTD.
Product: 930SBE/931SBE/930SBV
Version: P06AGW
ACPI Device: SAM0426:00
```

### CPU
- **Model**: Intel Core i7-8565U (Whiskey Lake, 8th Gen)
- **Cores/Threads**: 4/8
- **Base Frequency**: 1.8GHz
- **TDP**: 15W
- **Features**: kvm-intel virtualization

### Graphics
- **GPU**: Intel UHD Graphics 620 (WhiskeyLake-U GT2)
- **Driver**: i915 (kernel module)
- **Backlight**: `intel_backlight`
- **Range**: 0-8000 (brightness levels)

### Audio
- **Controller**: Intel Cannon Point-LP HD Audio
- **Working**: PipeWire + pipewire-pulse
- **Status**: Fully functional ✅

### Wireless
- **WiFi**: Intel Cannon Point-LP CNVi [Wireless-AC]
  - Driver: iwlwifi
  - Status: Working ✅
- **Bluetooth**: Intel Bluetooth 9460/9560 Jefferson Peak
  - Status: Working ✅

### Battery
- **Manufacturer**: SAMSUNG Electronics
- **Model**: SR Real Battery
- **Device**: `/sys/class/power_supply/BAT1`
- **USB-C Charging**: 3 ports (ucsi-source-psy)
- **Charge Control**: Supported via samsung-galaxybook module

### Input Devices
- **Touchpad**: ZNT0001:00 14E5:E545
  - Working with libinput ✅
  - Tapping, natural scrolling enabled
- **Touchscreen**: Atmel maXTouch Digitizer
  - Working ✅
- **Stylus**: WCOM006D:00 2D1F:0060 (Wacom)
  - Working ✅
- **Fingerprint**: Samsung Electronics (04e8:730a)
  - Detected, not configured ⚠️

### Samsung-Specific Hardware
**Kernel Module**: `samsung_galaxybook`
- Author: Joshua Grisham <josh@joshuagrisham.com>
- Features:
  - Keyboard backlight control (4 levels: 0-3)
  - Battery charge threshold management
  - Platform profile support
  - ACPI integration via i8042

**Backlight Devices** (via `brightnessctl`):
1. `intel_backlight` (screen)
   - Class: backlight
   - Max: 8000
2. `samsung-galaxybook::kbd_backlight` (keyboard)
   - Class: leds
   - Levels: 0, 1, 2, 3

---

## Current Support Status

### ✅ Working Out of Box
| Feature | Status | Notes |
|---------|--------|-------|
| Intel UHD 620 Graphics | ✅ | i915 driver, hardware acceleration |
| PipeWire Audio | ✅ | Including volume Fn keys |
| Touchpad | ✅ | Tapping, natural scrolling configured |
| Touchscreen | ✅ | Atmel maXTouch |
| Stylus | ✅ | Wacom digitizer |
| WiFi | ✅ | Intel iwlwifi |
| Bluetooth | ✅ | Intel 9460/9560 |
| Thermal Management | ✅ | thermald enabled |
| USB-C Charging | ✅ | 3 ports |
| Webcam | ✅ | Sunplus 720p |

### ⚠️ Needs Configuration
| Feature | Device | Configuration Needed |
|---------|--------|----------------------|
| Screen Brightness Fn Keys | `intel_backlight` | i3 keybindings |
| Keyboard Backlight | `samsung-galaxybook::kbd_backlight` | i3 keybindings |
| Battery Management | `BAT1` | TLP service |
| Battery Charge Thresholds | samsung-galaxybook | TLP settings |

### 🔶 Optional Features
| Feature | Status | Priority |
|---------|--------|----------|
| Fingerprint Authentication | Detected | Low (fprintd) |
| Platform Profiles | Supported | Low (power/balanced/performance) |
| Suspend/Resume | Unknown | Test required |

---

## Critical Configuration

### 1. Battery Management with TLP

**Why TLP?**
- Samsung laptop battery optimization
- Charge threshold support (80% rule)
- Auto-tuning for AC/Battery modes
- Better than generic power-profiles-daemon

**Configuration** (`machines/laptop.nix`):

```nix
# TLP power management for laptop battery optimization
services.tlp = {
  enable = true;
  settings = {
    # Battery Care - Charge Thresholds (80% rule for longevity)
    # Start charging when below 40%, stop at 80%
    START_CHARGE_THRESH_BAT0 = 40;
    STOP_CHARGE_THRESH_BAT0 = 80;

    # CPU Scaling Governor
    # Performance on AC, power-saving on battery
    CPU_SCALING_GOVERNOR_ON_AC = "performance";
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

    # Intel CPU Energy/Performance Policies (HWP)
    CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

    # Intel CPU Turbo Boost
    # Enable on AC, disable on battery for better battery life
    CPU_BOOST_ON_AC = 1;
    CPU_BOOST_ON_BAT = 0;

    # PCI Express Active State Power Management
    PCIE_ASPM_ON_AC = "default";
    PCIE_ASPM_ON_BAT = "powersupersave";

    # WiFi Power Saving
    WIFI_PWR_ON_AC = "off";    # Full performance when plugged in
    WIFI_PWR_ON_BAT = "on";    # Save power on battery

    # Runtime Power Management for PCI(e) devices
    RUNTIME_PM_ON_AC = "on";
    RUNTIME_PM_ON_BAT = "auto";

    # USB Autosuspend
    USB_AUTOSUSPEND = 1;
    USB_EXCLUDE_BTUSB = 1;     # Don't suspend Bluetooth
    USB_EXCLUDE_PHONE = 1;     # Don't suspend phone connections
  };
};
```

**Why These Settings?**
- **40-80% Thresholds**: Extends battery lifespan by avoiding full charge/discharge cycles
- **CPU Governor**: Automatic switching based on power source
- **Turbo Boost Off on Battery**: Significant power savings with minimal performance impact
- **WiFi Power Saving**: Reduces power consumption during idle periods

**Note about existing `powerManagement.cpuFreqGovernor`:**
- TLP will dynamically override the static governor setting
- Safe to keep or remove the existing `cpuFreqGovernor = "powersave"` line

### 2. Screen Brightness Control

**Device**: `intel_backlight` (8000 levels)
**Tool**: `brightnessctl` (already installed in nixpkgs)

**Configuration** (`users/junghan/modules/i3.nix`):

Add after the audio keybindings (around line 260):

```nix
# Brightness control (Intel backlight)
"XF86MonBrightnessUp" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl set +5%";
"XF86MonBrightnessDown" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
```

**Why `brightnessctl`?**
- Works with Intel i915 driver without additional configuration
- No setuid required (uses D-Bus/logind)
- Percentage-based adjustments (smoother transitions)
- Better than `light` (requires setuid) or `xbacklight` (X11-only)

**Alternatives Considered:**
- `light`: Minimal but requires setuid permissions
- `xbacklight`: X11-only, doesn't work with modern Intel drivers
- Manual sysfs writes: Requires udev rules and is less user-friendly

### 3. Keyboard Backlight Control

**Device**: `samsung-galaxybook::kbd_backlight`
**Levels**: 0 (off), 1 (low), 2 (medium), 3 (high)

**Configuration** (`users/junghan/modules/i3.nix`):

```nix
# Keyboard backlight control (Samsung Galaxy Book)
# Note: If XF86KbdBrightness* keys don't exist, use Mod+F5/F6 instead
"XF86KbdBrightnessUp" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl --device='samsung-galaxybook::kbd_backlight' set +1";
"XF86KbdBrightnessDown" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl --device='samsung-galaxybook::kbd_backlight' set 1-";
```

**If dedicated Fn keys don't exist**, use alternative bindings:

```nix
# Alternative: Manual bindings (Mod+F5/F6)
"${mod}+F5" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl --device='samsung-galaxybook::kbd_backlight' set 1-";
"${mod}+F6" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl --device='samsung-galaxybook::kbd_backlight' set +1";
```

**Test Commands:**
```bash
# List available brightness devices
brightnessctl --list

# Test keyboard backlight (increment)
brightnessctl --device='samsung-galaxybook::kbd_backlight' set +1

# Set specific level (0-3)
brightnessctl --device='samsung-galaxybook::kbd_backlight' set 2

# Turn off keyboard backlight
brightnessctl --device='samsung-galaxybook::kbd_backlight' set 0
```

### 4. Already Working Features

These are already configured in your current setup:

**Audio (Volume Fn Keys)**:
```nix
# Already in i3.nix - no changes needed
"XF86AudioRaiseVolume" = "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +5%";
"XF86AudioLowerVolume" = "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -5%";
"XF86AudioMute" = "exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle";
"XF86AudioMicMute" = "exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle";
```

**Touchpad**:
```nix
# Already in laptop.nix - no changes needed
services.libinput = {
  enable = true;
  touchpad = {
    tapping = true;
    naturalScrolling = true;
  };
};
```

**Thermal Management**:
```nix
# Already in laptop.nix - no changes needed
services.thermald.enable = true;
```

---

## Testing & Verification

### Phase 1: Apply Configuration

```bash
# Navigate to nixos-config
cd ~/repos/gh/nixos-config

# Test configuration (doesn't make it permanent)
sudo nixos-rebuild test --flake .#laptop

# If successful, switch to new configuration
sudo nixos-rebuild switch --flake .#laptop
```

### Phase 2: Test Screen Brightness

```bash
# Manual test
brightnessctl set 50%
brightnessctl set +10%
brightnessctl set 10%-

# Test Fn keys
# Press Fn + Brightness Up/Down
# Should see brightness change
```

### Phase 3: Test Keyboard Backlight

```bash
# List devices
brightnessctl --list

# Manual test
brightnessctl --device='samsung-galaxybook::kbd_backlight' set 0  # Off
brightnessctl --device='samsung-galaxybook::kbd_backlight' set 1  # Low
brightnessctl --device='samsung-galaxybook::kbd_backlight' set 2  # Medium
brightnessctl --device='samsung-galaxybook::kbd_backlight' set 3  # High

# Test Fn keys (if configured)
# Should cycle through 0-3 levels
```

### Phase 4: Verify TLP

```bash
# Check TLP status
sudo tlp-stat -s    # System information
sudo tlp-stat -b    # Battery information
sudo tlp-stat -p    # Processor settings

# Verify battery thresholds
cat /sys/class/power_supply/BAT1/charge_control_start_threshold  # Should be 40
cat /sys/class/power_supply/BAT1/charge_control_end_threshold    # Should be 80

# Check CPU governor (should change based on AC/battery)
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### Phase 5: Power Consumption Test

```bash
# Install powertop if not already installed
# Monitor power consumption
sudo powertop

# Good battery life indicators:
# - 8-15W on idle (screen brightness 50%)
# - 20-30W under normal load
# - CPU frequency scaling properly (check "Frequency stats")
```

### Phase 6: Test Suspend/Resume

```bash
# Test suspend
systemctl suspend

# Wait 10 seconds, wake up laptop
# Verify:
# - Screen brightness restored
# - WiFi reconnects
# - Audio works
# - Touchpad responds
```

---

## Troubleshooting

### Brightness Keys Not Working

**Symptom**: Fn+Brightness keys don't respond

**Diagnosis**:
```bash
# Check if brightnessctl is installed
which brightnessctl

# Check available brightness devices
brightnessctl --list

# Check if XF86 keys are detected
xev | grep -i brightness
# Press Fn+Brightness keys and see if events appear
```

**Solutions**:

1. **If brightnessctl not found**:
   ```nix
   # Add to environment.systemPackages in laptop.nix
   environment.systemPackages = with pkgs; [
     brightnessctl
   ];
   ```

2. **If XF86 keys not detected**:
   - Use alternative keybindings (Mod+F5/F6)
   - Check BIOS/UEFI settings for Fn key mode

3. **If backlight device not found**:
   ```nix
   # Add to boot.kernelParams in laptop.nix
   boot.kernelParams = [
     "acpi_backlight=native"  # Try native ACPI backlight
     # or
     "acpi_backlight=vendor"  # Try vendor-specific
   ];
   ```

### Battery Thresholds Not Applied

**Symptom**: Thresholds remain 0/100 instead of 40/80

**Diagnosis**:
```bash
# Check TLP service status
systemctl status tlp

# Check if samsung-galaxybook module is loaded
lsmod | grep samsung

# Check sysfs paths
ls -la /sys/class/power_supply/BAT1/charge_control_*
```

**Solutions**:

1. **If TLP service not running**:
   ```bash
   sudo systemctl start tlp
   sudo systemctl enable tlp
   ```

2. **If sysfs paths don't exist**:
   - samsung-galaxybook module may not support your exact model
   - Try updating kernel: `boot.kernelPackages = pkgs.linuxPackages_latest;`

3. **Manual threshold setting (temporary)**:
   ```bash
   echo 40 | sudo tee /sys/class/power_supply/BAT1/charge_control_start_threshold
   echo 80 | sudo tee /sys/class/power_supply/BAT1/charge_control_end_threshold
   ```

### Keyboard Backlight Not Detected

**Symptom**: `brightnessctl --list` doesn't show `samsung-galaxybook::kbd_backlight`

**Diagnosis**:
```bash
# Check if module is loaded
lsmod | grep samsung_galaxybook

# Check module info
modinfo samsung_galaxybook

# Check sysfs
ls /sys/class/leds/
```

**Solutions**:

1. **Load module manually**:
   ```bash
   sudo modprobe samsung_galaxybook
   ```

2. **Add to kernel modules** (if needed):
   ```nix
   # Add to laptop.nix
   boot.kernelModules = [ "samsung_galaxybook" ];
   ```

### Poor Battery Life

**Symptom**: Battery drains faster than expected

**Diagnosis**:
```bash
# Check power consumption
sudo powertop

# Check TLP active settings
sudo tlp-stat -s | grep -i governor
sudo tlp-stat -s | grep -i boost

# Check for power-hungry processes
top
```

**Solutions**:

1. **Disable CPU Turbo Boost on battery** (already in config):
   ```nix
   CPU_BOOST_ON_BAT = 0;
   ```

2. **Reduce screen brightness** (biggest power consumer):
   ```bash
   brightnessctl set 40%  # 40% often sufficient indoors
   ```

3. **Check for runaway processes**:
   ```bash
   # Kill unnecessary background tasks
   top
   ```

4. **Tune with powertop**:
   ```bash
   sudo powertop --auto-tune  # Enable all power-saving features
   ```

### Suspend/Resume Issues

**Common Issues**:
- Black screen after resume
- WiFi doesn't reconnect
- Touchpad stops working

**Solutions**:

1. **Update firmware**:
   ```nix
   hardware.enableRedistributableFirmware = true;  # Already set
   ```

2. **Add kernel parameters**:
   ```nix
   boot.kernelParams = [
     "mem_sleep_default=deep"  # Force deep sleep (S3)
   ];
   ```

3. **Reload WiFi module on resume**:
   ```nix
   powerManagement.resumeCommands = ''
     ${pkgs.kmod}/bin/modprobe -r iwlwifi
     ${pkgs.kmod}/bin/modprobe iwlwifi
   '';
   ```

---

## Advanced Topics

### Optional: Fingerprint Authentication

**Setup fprintd** (if you want fingerprint login):

```nix
# Add to laptop.nix
services.fprintd.enable = true;
security.pam.services.login.fprintAuthentication = true;
security.pam.services.sudo.fprintAuthentication = true;

# Packages
environment.systemPackages = with pkgs; [
  fprintd
];
```

**Enroll fingerprint**:
```bash
fprintd-enroll
# Follow prompts to scan finger multiple times
```

**Test**:
```bash
# Lock screen and try fingerprint login
# Or use sudo with fingerprint
```

### Optional: Platform Profiles

The samsung-galaxybook module supports platform profiles, but manual configuration is complex. TLP is recommended instead.

If you want to experiment:

```bash
# Check available profiles
cat /sys/firmware/acpi/platform_profile_choices

# Set profile (performance/balanced/low-power)
echo "low-power" | sudo tee /sys/firmware/acpi/platform_profile
```

### Boot Parameters Reference

**Current** (your laptop.nix):
```nix
boot.kernelParams = [ "nls=utf8" ];
```

**Optional additions** (only if needed):
```nix
boot.kernelParams = [
  "nls=utf8"                        # UTF-8 support (already set)
  # "acpi_backlight=native"         # If brightness control fails
  # "i915.enable_dpcd_backlight=1"  # Alternative backlight method
  # "mem_sleep_default=deep"        # Force S3 sleep (better battery)
  # "i915.enable_fbc=1"             # Framebuffer compression (power save)
  # "i915.enable_psr=1"             # Panel self refresh (power save)
];
```

**Add only if you encounter specific issues.** Current setup is already optimal.

### Kernel Version Considerations

**Current**: Kernel 6.17.5 (excellent Samsung support)

**If issues occur**, try:
```nix
# Latest stable kernel
boot.kernelPackages = pkgs.linuxPackages_latest;

# Or specific version
boot.kernelPackages = pkgs.linuxPackages_6_6;  # LTS
```

The samsung-galaxybook module is mainlined since kernel 5.18, so any recent kernel works.

---

## Quick Reference Commands

### Battery & Power
```bash
# Battery status
acpi -b
upower -i /org/freedesktop/UPower/devices/battery_BAT1

# TLP status
sudo tlp-stat -s  # System
sudo tlp-stat -b  # Battery
sudo tlp-stat -p  # Processor

# Power consumption
sudo powertop
```

### Brightness
```bash
# List devices
brightnessctl --list

# Screen brightness
brightnessctl set 50%
brightnessctl set +10%
brightnessctl set 10%-

# Keyboard backlight
brightnessctl --device='samsung-galaxybook::kbd_backlight' set 2
```

### Hardware Info
```bash
# System info
sudo dmidecode | grep -A5 "System Information"

# CPU governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Graphics
lspci | grep -i vga
glxinfo | grep "OpenGL renderer"

# Audio
pactl list sinks short
```

### Kernel Modules
```bash
# List loaded modules
lsmod | grep -E "samsung|i915|iwl"

# Module info
modinfo samsung_galaxybook
modinfo i915

# Load/unload
sudo modprobe samsung_galaxybook
sudo modprobe -r samsung_galaxybook
```

---

## NixOS vs Ubuntu: Samsung Laptop Setup Comparison

### Ubuntu Challenges

**Manual Driver Compilation**:
```bash
# On Ubuntu, you'd need to:
git clone https://github.com/joshuagrisham/samsung-galaxybook-extras
cd samsung-galaxybook-extras
make
sudo make install
# Plus: DKMS setup, kernel module signing, auto-rebuild on kernel updates
```

**TLP Installation**:
```bash
# Multiple commands, manual configuration
sudo add-apt-repository ppa:linrunner/tlp
sudo apt update
sudo apt install tlp tlp-rdw
sudo systemctl enable tlp
# Then manually edit /etc/tlp.conf (imperative)
```

**Brightness Control**:
```bash
# Manual udev rules
sudo tee /etc/udev/rules.d/90-backlight.rules <<EOF
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF
sudo usermod -aG video $USER
# Then reboot
```

**Result**: Fragile setup that breaks on updates.

### NixOS Advantages

**Declarative Configuration**:
```nix
# One file, version controlled, reproducible
services.tlp = {
  enable = true;
  settings = { /* ... */ };
};
```

**Automatic Hardware Detection**:
- `nixos-generate-config` creates hardware-configuration.nix
- samsung-galaxybook module automatically loaded
- No manual driver compilation

**Rollback on Failure**:
```bash
# If update breaks something
sudo nixos-rebuild switch --rollback
# Instantly back to working state
```

**Reproducibility**:
- Same config = same system
- Share with other Samsung laptop users
- Easy to migrate to new laptop

**Maintenance**:
- Kernel updates: modules automatically rebuilt
- System updates: atomic, rollback-safe
- No manual intervention needed

---

## File Structure Summary

**Files Modified in This Guide**:

1. `/home/junghan/repos/gh/nixos-config/machines/laptop.nix`
   - Add TLP service configuration (~35 lines)

2. `/home/junghan/repos/gh/nixos-config/users/junghan/modules/i3.nix`
   - Add brightness keybindings (~8 lines)

**No changes needed**:
- `hosts/laptop/hardware-configuration.nix` (auto-generated)
- Other configuration files (already optimal)

**Total changes**: ~43 lines in 2 files

---

## Community & Resources

### Documentation
- **samsung-galaxybook driver**: https://github.com/joshuagrisham/samsung-galaxybook-extras
- **TLP**: https://linrunner.de/tlp/
- **NixOS Options**: https://search.nixos.org/
- **brightnessctl**: https://github.com/Hummer12007/brightnessctl

### Forums & Support
- NixOS Discourse: https://discourse.nixos.org/
- NixOS Wiki: https://nixos.wiki/
- Arch Wiki (Samsung laptops): https://wiki.archlinux.org/title/Samsung
- Reddit: r/NixOS

### Similar Models
This guide should work for:
- Samsung Galaxy Book (2018-2020 models)
- NT930SBE, NT931SBE, NT930SBV
- Similar Samsung ultrabooks with SAM0426-SAM0430 ACPI IDs

If you have success with a different model, please contribute!

---

## Changelog

### 2025-10-28 - Initial Release
- Comprehensive Samsung NT930SBE support guide
- TLP battery management configuration
- Screen and keyboard brightness control
- Based on NixOS 25.05, Kernel 6.17.5

---

## Contributing

Found an issue or improvement? This document is version controlled in:
```
~/repos/gh/nixos-config/docs/20251028T120153--samsung-nt930sbe-nixos-hardware-support-guide__samsung_laptop_nixos_hardware.md
```

Feel free to submit improvements via pull request or issues.

---

**Generated**: 2025-10-28T12:01:53+09:00
**Author**: junghan (junghanacs)
**NixOS Flake**: `github:junghanacs/nixos-config`
**License**: MIT
