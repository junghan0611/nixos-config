# Minimal account modules. No password, privileged groups, trust, sync or personal data.
# Callers choose the state version and opt in to any extra policy separately.
{ username, stateVersion }:
{
  osModule = { pkgs, ... }: {
    users.users.${username} = {
      isNormalUser = true;
      shell = pkgs.bash;
    };
  };
  homeModule = { ... }: {
    home.username = username;
    home.homeDirectory = "/home/${username}";
    home.stateVersion = stateVersion;
    programs.home-manager.enable = true;
  };
}
