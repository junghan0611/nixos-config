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

    # tdlib/zmx 전용 unstable 채널. telega.el은 릴리스 채널보다 빠르게 TDLib
    # 하한을 올리고, zmx 0.7.0은 26.05에 아직 없다. 이 input은 아래 두 패키지만
    # 끌어온다 — 다른 패키지를 여기서 가져오지 말 것.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, disko, home-manager, ... }@inputs:
  let
    # 26.05 이관: 커스텀 오버레이 제거.
    # ghostty/google-chrome/bun/scrcpy/microsoft-edge/pnpm 전부 26.05
    # 네이티브가 종전 unstable/pinned 이상으로 커버(edge 145 URL 수정,
    # chrome 148). 죽은 AI CLI 오버레이(codex/claude-code 등, 소비처는
    # 이미 pnpm global로 이전)와 claude-desktop(미사용) 삭제. zmx는 26.05에
    # 미등록이라 unstable 예외로 다시 추가했다. 이력은 ROADMAP.md.
    #
    # 예외는 tdlib/zmx 둘뿐이다. telega.el은 TDLib 하한을 릴리스 주기보다 빠르게
    # 올린다. telega 0.8.660은 telega-tdlib-min-version = 1.8.66을 요구하지만
    # 26.05는 1.8.65에서 멈춰 있어 telega가 아예 뜨지 않는다. unstable에는
    # 1.8.66이 있고 x86_64/aarch64 둘 다 cache.nixos.org에 있어 로컬 빌드가
    # 없다. zmx 0.7.0도 26.05에는 없지만 unstable에 등록됐으며, 종전 upstream
    # flake의 Zig 0.15 빌드가 아닌 cache.nixos.org 바이너리를 쓴다. 26.05가
    # 따라잡으면 이 오버레이와 nixpkgs-unstable input을 함께 지운다. TDLib 요구
    # 버전은 telega.el 의 telega-tdlib-min-version 으로 확인.
    overlays = [
      (final: prev: let
        unstable = import inputs.nixpkgs-unstable {
          inherit (prev.stdenv.hostPlatform) system;
        };
      in {
        inherit (unstable) tdlib zmx;
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

      # ThinkPad P16s Gen 2 (AMD) - full configuration with home-manager
      thinkpad = mkSystem "thinkpad" {
        system = "x86_64-linux";
        user = "junghan";
      };

    };
  };
}
