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
    # 예외는 tdlib/zmx/emacs 셋이다. telega.el은 TDLib 하한을 릴리스 주기보다 빠르게
    # 올린다. telega 0.8.660은 telega-tdlib-min-version = 1.8.66을 요구하지만
    # 26.05는 1.8.65에서 멈춰 있어 telega가 아예 뜨지 않는다. unstable에는
    # 1.8.66이 있고 x86_64/aarch64 둘 다 cache.nixos.org에 있어 로컬 빌드가
    # 없다. zmx 0.7.0도 26.05에는 없지만 unstable에 등록됐으며, 종전 upstream
    # flake의 Zig 0.15 빌드가 아닌 cache.nixos.org 바이너리를 쓴다. 26.05가
    # 따라잡으면 이 오버레이와 nixpkgs-unstable input을 함께 지운다. TDLib 요구
    # 버전은 telega.el 의 telega-tdlib-min-version 으로 확인.
    # emacs 예외 사유는 오버레이 본문 주석에 있다(26.05에 emacs31 attr 부재).
    overlays = [
      (final: prev: let
        unstable = import inputs.nixpkgs-unstable {
          inherit (prev.stdenv.hostPlatform) system;
        };
      in {
        inherit (unstable) tdlib zmx;

        # Emacs 31 (2026-09-02). 26.05는 30.2에서 멈춰 있고 emacs31 attr
        # 자체가 없다(26.05 attrNames에는 emacs30* 뿐). Doom 권장 버전이 31로
        # 올라갔고 doomemacs-config도 31 채널로 갔다. 현재 lock된 unstable
        # (ac6b216)이 이미 31.1을 갖고 있어 flake update 없이 잡힌다.
        # cache.nixos.org에 x86 gtk3/nox·aarch64 nox 전부 있어 로컬 빌드 0.
        #
        # elisp 패키지 세트(emacsPackagesFor)는 26.05를 그대로 쓴다 — HM이
        # pkgs.emacsPackagesFor 를 부르므로 자동으로 그렇게 된다. unstable
        # epkgs를 끌어오면 mu4e가 1.14.3이 되어 26.05 mu(1.12.13)와 어긋난다.
        #
        # pkgs.emacs 는 일부러 두지 않는다: pkgs.mu 의 빌드 입력이라 전역
        # override 하면 mu 가 로컬 재빌드된다. emacsclient 소비처(i3.nix)는
        # programs.emacs.finalPackage 로 옮겼다.
        emacs-gtk = unstable.emacs31-gtk3;   # desktop: GTK3 + X11 (i3wm)
        emacs-nox = unstable.emacs31-nox;    # headless + machines/shared.nix

        # datasette — 로컬 sqlite를 브라우저 표로 여는 read-only 뷰어.
        # 주 소비처: Magit Forge 로컬 DB(~/doomemacs/.local/etc/forge/forge-database.sqlite).
        #
        # 왜 오버라이드가 필요한가(2026-09-04 실측): 26.05·unstable 양쪽 모두
        # `pkgs.datasette` 가 평가부터 거부된다. 의존 `asgi-csrf` 가
        # `meta.broken = python-multipart >= 0.0.26` 이고 nixpkgs의 multipart는 0.0.29다
        # (upstream simonw/asgi-csrf#38, asgi-csrf 최신도 0.11로 미해결).
        #
        # 마커를 그냥 지우지 않고 "무엇이 깨지는지"를 먼저 재봤다. asgi-csrf 테스트를
        # 돌리면 실패는 정확히 한 곳이다:
        #   asgi_csrf.py:291  TypeError: FormParser.__init__() got an unexpected keyword 'FileClass'
        # 즉 깨지는 것은 **multipart/form-data POST 파싱**뿐이다. 우리 용도(읽기 전용
        # 브라우징)는 GET 경로라 그 줄에 닿지 않는다 — forge DB 사본으로 실측 통과
        # (issue 164 rows / state='open' 57, query ~1.3ms).
        # 그래서 doCheck 을 끄고(위 한 테스트가 유일한 실패) broken 을 내린다.
        #
        # ⚠️ 경계: datasette 에서 **쓰기/폼 POST를 쓰는 순간 이 오버라이드는 부족하다**
        #    (write 플러그인, 로그인 폼 등). 그때는 오버라이드를 지우고 upstream 수정을 기다린다.
        # 회수 조건: `asgi-csrf` 의 broken 이 풀리면 이 블록을 통째로 지운다.
        datasette = prev.datasette.override {
          asgi-csrf = prev.python3Packages.asgi-csrf.overridePythonAttrs (o: {
            doCheck = false;
            meta = o.meta // { broken = false; };
          });
        };
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
