{
  description = "Junghan's NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Disk management
    disko = {
      url = "github:nix-community/disko/v1.11.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager for user environment management
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Unstable nixpkgs for newer packages
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, disko, home-manager, ... }@inputs:
  let
    # Overlays to apply custom packages
    overlays = [
      (final: prev: {
        # Use unstable packages where needed
        ghostty = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.ghostty;
      })
    ];

    # Helper function to create system configurations with home-manager
    mkSystem = import ./lib/mksystem.nix {
      inherit overlays nixpkgs inputs;
    };
  in {
    nixosConfigurations = {
      # Oracle Cloud ARM VM - simple configuration without home-manager
      oracle = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          { nixpkgs.overlays = overlays; }
          disko.nixosModules.disko
          ./hosts/oracle/configuration.nix
        ];
      };

      # Intel NUC x86_64 - full configuration with home-manager
      nuc = mkSystem "nuc" {
        system = "x86_64-linux";
        user = "junghan";
      };

      # Laptop configuration (future)
      # laptop = mkSystem "laptop" {
      #   system = "x86_64-linux";
      #   user = "junghan";
      # };
    };
  };
}