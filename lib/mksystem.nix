# This function creates a NixOS system based on our setup for a
# particular architecture.
{ nixpkgs, overlays, inputs }:

name:
{
  system,
  user,
  # Additional accounts do not replace the machine's primary operator.
  # Each value supplies NixOS and Home Manager modules, respectively.
  additionalUsers ? { }
}:

let
  # The config files for this system.
  machineConfig = ../machines/${name}.nix;
  userOSConfig = ../users/${user}/nixos.nix;
  userHMConfig = ../users/${user}/home-manager.nix;

  # NixOS system function
  systemFunc = nixpkgs.lib.nixosSystem;
  home-manager = inputs.home-manager.nixosModules;
in assert !(builtins.hasAttr user additionalUsers); systemFunc rec {
  inherit system;

  # specialArgs: imports 단계에서 사용 가능 (_module.args 는 config 단계 이후)
  specialArgs = {
    currentSystem = system;
    currentSystemName = name;
    currentSystemUser = user;
    inherit inputs;
  };

  modules = [
    # Apply our overlays. Overlays are keyed by system type so we have
    # to go through and apply our system type. We do this first so
    # the overlays are available globally.
    {
      nixpkgs.overlays = overlays ++ nixpkgs.lib.optionals
        (builtins.elem name [ "nuc" "laptop" "thinkpad" "cyborg" ]) [
          # Ghostty만 독립 패키지 세트에서 공급한다. Oracle에는 이 overlay도 없다.
          # useGlobalPkgs로 시스템 패키지와 HM의 i3 실행 경로가 함께 바뀐다.
          (final: prev: {
            ghostty = inputs.nixpkgs-ghostty.legacyPackages.${system}.ghostty;
          })
        ];
    }

    # Allow unfree packages.
    { nixpkgs.config.allowUnfree = true; }

    # Shared agent tooling: make bb available system-wide on every host.
    ({ pkgs, ... }: { environment.systemPackages = [ pkgs.babashka ]; })

    # Disko for disk management
    inputs.disko.nixosModules.disko

    machineConfig
    userOSConfig
  ] ++ map (account: account.osModule) (builtins.attrValues additionalUsers) ++ [
    home-manager.home-manager {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "hm-backup";
      home-manager.users = {
        ${user} = import userHMConfig {
          inherit inputs;
          currentSystemName = name;  # Pass system name to home-manager config
        };
      } // builtins.mapAttrs (_: account: account.homeModule) additionalUsers;
    }

    # We expose some extra arguments so that our modules can parameterize
    # better based on these values.
    {
      config._module.args = {
        currentSystem = system;
        currentSystemName = name;
        currentSystemUser = user;
        inputs = inputs;
      };
    }
  ];
}