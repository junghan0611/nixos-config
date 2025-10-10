# XRDP Remote Desktop Server
# Simple configuration for Oracle Cloud GUI access
{ config, lib, pkgs, currentSystemName, ... }:

let
  # Only enable on oracle system
  isOracle = currentSystemName == "oracle";
in {
  # XRDP service configuration
  services.xrdp = lib.mkIf isOracle {
    enable = true;
    port = 3389;
    openFirewall = true;

    # Use i3 as default window manager for RDP sessions
    defaultWindowManager = "i3";

    # SSL certificates (auto-generated)
    sslCert = "/var/lib/xrdp/cert.pem";
    sslKey = "/var/lib/xrdp/key.pem";
  };

  # Disable automatic startup - require manual start
  systemd.services.xrdp = lib.mkIf isOracle {
    wantedBy = lib.mkForce [];  # Don't auto-start
  };

  systemd.services.xrdp-sesman = lib.mkIf isOracle {
    wantedBy = lib.mkForce [];  # Don't auto-start
  };

  # Helper scripts for manual control
  environment.systemPackages = lib.mkIf isOracle (with pkgs; [
    (writeShellScriptBin "xrdp-start" ''
      echo "Starting XRDP services..."
      sudo systemctl start xrdp xrdp-sesman
      echo "XRDP started on port 3389"
      echo "Connect using RDP client to $(hostname -I | cut -d' ' -f1):3389"
    '')

    (writeShellScriptBin "xrdp-stop" ''
      echo "Stopping XRDP services..."
      sudo systemctl stop xrdp-sesman xrdp
      echo "XRDP stopped"
    '')

    (writeShellScriptBin "xrdp-status" ''
      echo "=== XRDP Service Status ==="
      systemctl status xrdp --no-pager | head -n 5
      echo ""
      echo "=== XRDP Session Manager Status ==="
      systemctl status xrdp-sesman --no-pager | head -n 5
      echo ""
      echo "=== Active RDP Connections ==="
      ss -tnp | grep :3389 2>/dev/null || echo "No active connections"
    '')
  ]);

  # Ensure required packages are installed
  environment.systemPackages = lib.mkIf isOracle (with pkgs; [
    xorg.xhost
    xorg.xauth
  ]);
}