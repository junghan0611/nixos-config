{
  description = "Junghan's NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Disk management
    disko = {
      url = "github:nix-community/disko/v1.11.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager for user environment management
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, home-manager, ... }@inputs:
  let
    # 26.05 이관: 모든 커스텀 오버레이 제거.
    # ghostty/google-chrome/bun/scrcpy/microsoft-edge/tdlib/pnpm 전부 26.05
    # 네이티브가 종전 unstable/pinned 이상으로 커버(tdlib 1.8.65, edge 145 URL
    # 수정, chrome 148). 죽은 AI CLI 오버레이(codex/claude-code 등, 소비처는
    # 이미 pnpm global로 이전)와 claude-desktop(미사용) 삭제. zmx는 zig15↔26.05
    # zig16 충돌 우려로 이 브랜치에서 제외 — 별도 후속(NEXT). 이력은 ROADMAP.md.
    overlays = [ ];

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

      # ThinkPad P16s Gen 2 (AMD) - full configuration with home-manager
      thinkpad = mkSystem "thinkpad" {
        system = "x86_64-linux";
        user = "junghan";
      };

    };
  };
}
