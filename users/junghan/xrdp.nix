# Oracle-only shared GUI candidate (#14). A branch build is not activation approval.
{ config, lib, pkgs, currentSystemName, ... }:

let
  cfg = config.services.xrdp;
  guiUser = "browser";
  guiHome = "/home/${guiUser}";
  # One persistent, non-default profile. Not ~/.cache/browser-tools (its launcher
  # deletes Singleton locks there) and not the default ~/.config/google-chrome.
  chromeProfile = "${guiHome}/.local/share/agent-chrome";
  # Started by the GUI user's own XFCE session. CDP stays on Chrome's default
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

    security.pam.services.xrdp-sesman.allowNullPassword = lib.mkForce false;
    users.groups.tsusers = {};
    # Own primary group: do not share the operator's `users` group-write surface.
    users.groups.${guiUser} = {};
    users.users.${guiUser} = {
      isNormalUser = true;
      group = guiUser;
      description = "Shared remote browser desktop";
      extraGroups = [ "tsusers" ];
      # No sudo/docker membership. Password: a yescrypt hash the operator made
      # with `mkpasswd` on Oracle. A runtime string path, never a Nix path, so the
      # hash stays out of the store and Git. With mutableUsers it is applied only
      # when the account is first created; a missing file creates it locked and an
      # empty file creates it passwordless, so check the file before activation.
      hashedPasswordFile = "/home/junghan/.config/oracle-rdp/browser.hash";
    };

    # Per-user autostart only: no global xdg/autostart entry, so no other
    # account's session launches Chrome. Directories are owned by the GUI user.
    systemd.tmpfiles.rules = [
      "d ${guiHome}/.config 0700 ${guiUser} ${guiUser} -"
      "d ${guiHome}/.config/autostart 0700 ${guiUser} ${guiUser} -"
      "L+ ${guiHome}/.config/autostart/agent-chrome.desktop - - - - ${agentChromeDesktop}"
    ];

    # The CF connector is a separate, later step.
    environment.systemPackages = with pkgs; [ google-chrome xrdp ];
  };
}
