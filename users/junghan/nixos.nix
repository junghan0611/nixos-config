{ pkgs, config, currentSystemName, ... }:

let
  # Import vars for each system
  vars = if (currentSystemName == "oracle") then
    import ../../hosts/oracle/vars.nix
  else if (currentSystemName == "nuc") then
    import ../../hosts/nuc/vars.nix
  else if (currentSystemName == "laptop") then
    import ../../hosts/laptop/vars.nix
  else
    # Default values for other systems
    {
      username = "junghan";
      sshKey = "";
    };
in
{
  # Import xrdp module (oracle only)
  imports = [ ./xrdp.nix ];
  # Define user account
  users.users.${vars.username} = {
    isNormalUser = true;
    home = "/home/${vars.username}";
    description = "Junghan Kim";
    shell = pkgs.bash;
    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
      "audio"
      "video"
      "input"
      "tty"
      "lxd"
      "libvirtd"
      "users"
    ];
    # Set initial password - should be changed on first login
    initialPassword = "password";
    openssh.authorizedKeys.keys = if (vars.sshKey != "") then [ vars.sshKey ] else [];

    # User-specific system packages (not managed by home-manager)
    packages = with pkgs; [
      # These will be moved to home-manager later
    ];
  };
}