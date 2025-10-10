# XRDP Remote Desktop Server
# Simple configuration for Oracle Cloud GUI access
{ config, lib, pkgs, currentSystemName, ... }:

let
  # Only enable on oracle system
  isOracle = currentSystemName == "oracle";
in {
  # XRDP service configuration (SSH tunnel only - most secure)
  services.xrdp = lib.mkIf isOracle {
    enable = true;
    port = 3389;
    openFirewall = false;  # Don't open firewall - SSH tunnel only!

    # Use i3 as default window manager for RDP sessions
    defaultWindowManager = "i3";

    # SSL certificates (auto-generated)
    sslCert = "/var/lib/xrdp/cert.pem";
    sslKey = "/var/lib/xrdp/key.pem";

    # Bind to localhost only for SSH tunneling (secure) + Resolution settings
    extraConfDirCommands = ''
      substituteInPlace $out/xrdp.ini \
        --replace "port=3389" "address=127.0.0.1\nport=3389" \
        --replace "max_bpp=32" "max_bpp=24" \
        --replace "#xserverbpp=24" "xserverbpp=24"

      # Enable dynamic resolution (limited support)
      echo "" >> $out/xrdp.ini
      echo "# Resolution settings" >> $out/xrdp.ini
      echo "enable_dynamic_resizing=true" >> $out/xrdp.ini
      echo "use_rdp_monitor_layout=true" >> $out/xrdp.ini

      # Sesman configuration for better resolution handling
      substituteInPlace $out/sesman.ini \
        --replace "KillDisconnected=false" "KillDisconnected=true"

      # Add common resolution options
      cat >> $out/sesman.ini <<EOF

      # Resolution options
      [Xvnc]
      param=-geometry
      param=1920x1080
      param=-depth
      param=24
      EOF
    '';
  };

  # Disable automatic startup - require manual start
  systemd.services.xrdp = lib.mkIf isOracle {
    wantedBy = lib.mkForce [];  # Don't auto-start
  };

  systemd.services.xrdp-sesman = lib.mkIf isOracle {
    wantedBy = lib.mkForce [];  # Don't auto-start
  };

  # Helper scripts and required packages
  environment.systemPackages = lib.mkIf isOracle (with pkgs; [
    # Helper scripts for manual control
    (writeShellScriptBin "xrdp-start" ''
      echo "Starting XRDP services (localhost only)..."
      sudo systemctl start xrdp xrdp-sesman
      echo "✅ XRDP started on localhost:3389"
      echo ""
      echo "🔒 SECURE CONNECTION via SSH Tunnel:"
      echo "1. On your local machine, create SSH tunnel:"
      echo "   ssh -L 3389:localhost:3389 junghan@168.107.2.68"
      echo "   (or: ssh -L 3389:localhost:3389 oracle)"
      echo ""
      echo "2. Then connect RDP to: localhost:3389"
      echo ""
      echo "📝 This is MORE SECURE than opening port 3389!"
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

    # Required packages
    xorg.xhost
    xorg.xauth
  ]);
}
