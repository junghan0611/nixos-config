{
  description = "Junghan's NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Disk management
    disko = {
      url = "github:nix-community/disko/v1.11.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager for user environment management
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Unstable nixpkgs for newer packages
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Claude Desktop for Linux (unofficial)
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, home-manager, ... }@inputs:
  let
    # Create unstable pkgs with allowUnfree for each system
    mkUnstablePkgs = system: import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

    # Overlays to apply custom packages
    overlays = [
      (final: prev: let
        unstable = mkUnstablePkgs prev.stdenv.hostPlatform.system;
      in {
        # Use unstable packages where needed
        ghostty = unstable.ghostty;
        # Claude Desktop with MCP support
        claude-desktop = inputs.claude-desktop.packages.${prev.stdenv.hostPlatform.system}.claude-desktop-with-fhs;

        # AI CLI tools from unstable
        gemini-cli = unstable.gemini-cli;
        codex = unstable.codex;
        opencode = unstable.opencode;
        claude-code = unstable.claude-code;
        claude-monitor = unstable.claude-monitor;
        claude-code-acp = unstable.claude-code-acp;
        claude-code-router = unstable.claude-code-router;
        qwen-code = unstable.qwen-code;
      })
    ];

    # Helper function to create system configurations with home-manager
    mkSystem = import ./lib/mksystem.nix {
      inherit overlays nixpkgs inputs;
    };
  in {
    nixosConfigurations = {
      # Oracle Cloud ARM VM - full configuration with home-manager
      oracle = mkSystem "oracle" {
        system = "aarch64-linux";
        user = "junghan";
      };

      # Intel NUC x86_64 - full configuration with home-manager
      nuc = mkSystem "nuc" {
        system = "x86_64-linux";
        user = "junghan";
      };

      # Samsung NT930SBE Laptop - full configuration with home-manager
      laptop = mkSystem "laptop" {
        system = "x86_64-linux";
        user = "junghan";
      };

    };
  };
}
