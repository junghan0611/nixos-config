# Oracle-only shared GUI (#14): xrdp on loopback, the operator's own XFCE session, Agent Chrome.
{ config, lib, pkgs, currentSystemName, currentSystemUser, ... }:

let
  cfg = config.services.xrdp;
  # GLG logs in as themselves. Agents already run under this uid, so the desktop,
  # home, sockets and the CDP browser are one workspace. One session only.
  guiUser = currentSystemUser;
  # One persistent, non-default profile. Not ~/.cache/browser-tools (its launcher
  # deletes Singleton locks there) and not the default ~/.config/google-chrome.
  chromeProfile = "/home/${guiUser}/.local/share/agent-chrome";
  # Started by the user's own XFCE session. CDP stays on Chrome's default
  # loopback; sandbox and the default password store are left as they are.
  agentChromeDesktop = pkgs.writeText "agent-chrome.desktop" ''
    [Desktop Entry]
    Type=Application
    Name=Agent Chrome
    Comment=Shared agent browser (#14)
    Exec=${lib.getExe pkgs.google-chrome} --user-data-dir=${chromeProfile} --remote-debugging-port=9222 --no-first-run --no-default-browser-check
    NoDisplay=true
    X-GNOME-Autostart-enabled=true
  '';
in
{
  config = lib.mkIf (currentSystemName == "oracle") {
    # RDP owns its Xorg; do not enable a console X server, LightDM, or i3.
    services.xserver.desktopManager.xfce.enable = true;

    services.xrdp = {
      enable = true;
      openFirewall = false;
      defaultWindowManager = "xfce4-session";
      extraConfDirCommands = ''
        substituteInPlace "$out/sesman.ini" \
          --replace-fail 'MaxSessions=50' 'MaxSessions=1' \
          --replace-fail 'AllowRootLogin=true' 'AllowRootLogin=false' \
          --replace-fail 'AlwaysGroupCheck=false' 'AlwaysGroupCheck=true'
        substituteInPlace "$out/xrdp.ini" \
          --replace-fail '[Xorg]' $'[Xorg]\nxserverbpp=32'
      '';
    };

    # Upstream passes --port N, overriding ini port/address edits. Bind explicitly.
    systemd.services.xrdp.serviceConfig.ExecStart = lib.mkForce
      "${pkgs.xrdp}/bin/xrdp --nodaemon --port tcp://127.0.0.1:${toString cfg.port} --config ${cfg.confDir}/xrdp.ini";

    # The user's existing local password (PAM); SSH password login stays off.
    security.pam.services.xrdp-sesman.allowNullPassword = lib.mkForce false;
    users.groups.tsusers = {};
    users.users.${guiUser}.extraGroups = [ "tsusers" ];

    # Per-user autostart through Home Manager: no global xdg/autostart entry, and
    # no tmpfiles rule in the home (it would reset the existing ~/.config mode).
    home-manager.users.${guiUser}.xdg.configFile."autostart/agent-chrome.desktop".source = agentChromeDesktop;

    # The CF connector is a separate, later step.
    environment.systemPackages = with pkgs; [ google-chrome xrdp ];
  };
}
