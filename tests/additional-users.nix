# Evaluation-only fixture: not exported as a deployable flake configuration.
let
  flake = builtins.getFlake (toString ../.);
  inputs = flake.inputs;
  mkSystem = import ../lib/mksystem.nix {
    inherit inputs;
    inherit (inputs) nixpkgs;
    overlays = [ ];
  };
  args = { system = "x86_64-linux"; user = "junghan"; };
  base = (mkSystem "thinkpad" args).config;
  example = (mkSystem "thinkpad" (args // {
    additionalUsers.visitor = import ../lib/additional-user.nix {
      username = "visitor";
      stateVersion = "26.05";
    };
  })).config;
  v = example.users.users.visitor;
  hm = example.home-manager.users.visitor;
  duplicate = builtins.tryEval (mkSystem "thinkpad" (args // {
    additionalUsers.junghan = import ../lib/additional-user.nix {
      username = "junghan";
      stateVersion = "26.05";
    };
  }));
in
assert !duplicate.success;
assert v.isNormalUser;
assert v.initialPassword == null;
assert v.hashedPassword == null;
assert !(builtins.elem "wheel" v.extraGroups);
assert !(builtins.elem "visitor" example.nix.settings.trusted-users);
assert example.nix.settings.trusted-users == base.nix.settings.trusted-users;
assert example.services.syncthing.user == base.services.syncthing.user;
assert example.services.syncthing.enable == base.services.syncthing.enable;
assert example.security.sudo.wheelNeedsPassword == base.security.sudo.wheelNeedsPassword;
assert builtins.hasAttr "junghan" example.home-manager.users;
assert hm.home.username == "visitor";
assert hm.home.homeDirectory == "/home/visitor";
assert hm.home.stateVersion == "26.05";
{
  users = builtins.attrNames example.home-manager.users;
  visitorGroups = v.extraGroups;
  trustedUsers = example.nix.settings.trusted-users;
  inherit (example.services.syncthing) enable user;
}
