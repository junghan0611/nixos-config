{ config, lib, pkgs, ... }:

{
  imports = [
    ./shared.nix
    # Import the existing hardware configuration
    ../hosts/oracle/hardware-configuration.nix
    # Oracle-specific disk configuration
    ../hosts/oracle/disk-config.nix
  ];

  # Oracle Cloud specific configuration
  networking.hostName = "oracle";

  # Boot configuration for Oracle Cloud ARM VM
  boot = {
    initrd.systemd.enable = true;
    kernelParams = [
      "nls=utf8"
      "console=tty1"
      "console=ttyAMA0,115200n8"  # ARM serial console
    ];
  };

  # Oracle Cloud ARM specific hardware settings
  hardware = {
    enableRedistributableFirmware = true;

    # No bluetooth on cloud VM
    bluetooth.enable = false;
  };

  # Power management not needed for cloud VM
  powerManagement.enable = false;

  # Audio support - minimal for remote environment
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = false;  # ARM64, no 32-bit support needed
    pulse.enable = true;
  };

  # Graphics support for remote desktop
  # Note: Limited OpenGL support in cloud environment
  hardware.graphics = {
    enable = true;
    enable32Bit = false;  # ARM64 only
  };

  # Remote desktop services
  # Starting with TigerVNC for stability
  services.displayManager.autoLogin = {
    enable = false;  # No auto-login for security
  };

  # TigerVNC server configuration
  services.xserver.displayManager.sessionCommands = ''
    # Set display resolution for VNC (can be adjusted)
    ${pkgs.xorg.xrandr}/bin/xrandr --output Virtual-1 --mode 1920x1080 2>/dev/null || true
    ${pkgs.xorg.xrandr}/bin/xrandr --output default --mode 1920x1080 2>/dev/null || true
  '';

  # VNC Server (TigerVNC)
  systemd.services.vncserver = {
    description = "TigerVNC Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "forking";
      User = "junghan";
      WorkingDirectory = "/home/junghan";

      # VNC on display :1, port 5901
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /home/junghan/.vnc";
      ExecStart = "${pkgs.tigervnc}/bin/vncserver :1 -geometry 1920x1080 -depth 24 -localhost";
      ExecStop = "${pkgs.tigervnc}/bin/vncserver -kill :1";

      Restart = "on-failure";
      RestartSec = "10s";
    };

    environment = {
      HOME = "/home/junghan";
      USER = "junghan";
    };
  };

  # Generate VNC password file (user needs to set password with vncpasswd)
  system.activationScripts.vncSetup = ''
    mkdir -p /home/junghan/.vnc
    chown junghan:users /home/junghan/.vnc

    # Create xstartup for i3
    cat > /home/junghan/.vnc/xstartup << 'EOF'
    #!/bin/sh
    unset SESSION_MANAGER
    unset DBUS_SESSION_BUS_ADDRESS

    # Start i3 window manager
    exec ${pkgs.i3}/bin/i3 &
    EOF

    chmod +x /home/junghan/.vnc/xstartup
    chown junghan:users /home/junghan/.vnc/xstartup
  '';

  # Oracle Cloud specific packages
  environment.systemPackages = with pkgs; [
    # VNC tools
    tigervnc

    # Cloud utilities
    cloud-utils

    # Remote desktop utilities
    x11vnc
    novnc  # Web-based VNC client

    # Monitoring for cloud environment
    htop
    iotop
    nethogs
    iftop

    # Reduced graphics packages for remote environment
    glxinfo
    mesa-demos
  ];

  # Networking - Oracle Cloud specific
  networking.firewall = {
    enable = true;

    # Allow VNC only from localhost (SSH tunnel required)
    # Users connect via: ssh -L 5901:localhost:5901 oracle
    allowedTCPPorts = [
      22     # SSH
      22000  # Syncthing sync
    ];

    allowedUDPPorts = [
      21027  # Syncthing discovery
      22000  # Syncthing QUIC
    ] ++ (lib.range 60000 61000);  # mosh

    # VNC ports (5901-5910) NOT exposed externally for security
    # Access only via SSH tunnel
  };

  # Oracle Cloud Volume management
  # Auto-resize root partition on boot
  boot.growPartition = true;

  # Disable unnecessary services for cloud VM
  services.avahi.enable = false;
  services.printing.enable = false;
  services.libinput.enable = false;  # No touchpad in cloud

  # ZRAM swap for better memory management
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;  # Use up to 50% of RAM for compressed swap
  };

  # System-wide performance tuning for remote desktop
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 87380 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
  };

  # Oracle Cloud specific notes
  system.nixos.tags = [ "oracle-cloud" "arm64" "remote-desktop" ];
}