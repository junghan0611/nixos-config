---
title:      "i3에서 Sway로 전환 가이드"
date:       2025-10-10T09:43:10+09:00
tags:       ["nixos", "sway", "wayland", "i3", "windowmanager"]
identifier: "20251010T094310"
---

# i3에서 Sway로 전환 가이드

**작성일**: 2025-10-10
**목적**: 현재 i3 설정을 유지하면서 Sway(Wayland)를 병행 사용할 수 있는 방법 제시

## 1. 현재 상황 분석

### 현재 구성
- **Window Manager**: i3 (X11)
- **한글 입력**: kime
- **Display Manager**: LightDM
- **구조**:
  - 시스템: `/modules/wm/i3.nix`
  - 사용자: `/users/junghan/modules/i3.nix` (home-manager)

### 주요 특징
- i3 설정은 home-manager와 시스템 레벨로 분리
- py3status를 사용한 상태바
- 커스텀 색상 테마 (cyan/orange 강조)
- rofi를 런처로 사용

## 2. Sway 개요

### Sway란?
- i3의 **Wayland 구현체** (drop-in replacement)
- i3 설정 파일 대부분 호환
- X11 의존성 제거, 더 나은 보안과 성능

### i3와의 차이점
| 구분 | i3 (X11) | Sway (Wayland) |
|------|----------|----------------|
| 디스플레이 서버 | X.org | Wayland |
| 한글 입력 | kime, ibus, fcitx | fcitx5 권장 |
| 스크린샷 | scrot, flameshot | grim + slurp |
| 클립보드 | xclip, xsel | wl-clipboard |
| 런처 | rofi, dmenu | rofi-wayland, wofi |
| 상태바 | i3status, i3blocks | waybar, i3status |
| 화면 잠금 | i3lock | swaylock |

## 3. 전환 전략

### 옵션 1: NixOS Specialization 활용 (권장)
**장점**: 부팅 시 선택 가능, 설정 완전 분리, 롤백 용이

```nix
# /modules/specialization/sway.nix
{ config, lib, pkgs, ... }: {
  specialisation.sway.configuration = {
    imports = [
      ../wm/sway.nix  # Sway 시스템 설정
    ];

    # i3 비활성화
    services.xserver.windowManager.i3.enable = lib.mkForce false;
    services.displayManager.defaultSession = lib.mkForce "sway";

    # greetd로 전환 (Wayland 친화적)
    services.greetd.enable = lib.mkForce true;
    services.xserver.displayManager.lightdm.enable = lib.mkForce false;
  };
}
```

### 옵션 2: 병렬 설치 (세션 선택)
**장점**: 로그인 화면에서 선택, 설정 공유 가능

```nix
# machines/laptop.nix에 추가
{
  imports = [
    ../modules/wm/i3.nix
    ../modules/wm/sway.nix  # 둘 다 import
  ];

  # LightDM에서 세션 선택 가능
  services.displayManager.sessionPackages = with pkgs; [
    sway
  ];
}
```

### 옵션 3: Home-Manager만으로 전환
**장점**: 사용자별 설정, 시스템 변경 최소화

## 4. Sway 시스템 모듈 구성

### `/modules/wm/sway.nix`

```nix
{ pkgs, lib, ... }: {
  # XDG 포털 설정 (Wayland용)
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr  # 화면 공유
      xdg-desktop-portal-gtk
    ];
  };

  # 한글 입력 - fcitx5 (Wayland 최적화)
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-gtk
        fcitx5-hangul
        fcitx5-configtool
      ];
    };
  };

  # Sway 활성화
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      # 터미널
      foot          # 경량 Wayland 네이티브
      alacritty     # GPU 가속

      # 런처
      rofi-wayland  # rofi의 Wayland 포크
      wofi          # Wayland 네이티브 런처

      # 상태바
      waybar        # Wayland 네이티브 바

      # 유틸리티
      swaylock-effects  # 화면 잠금
      swayidle         # idle 관리
      grim             # 스크린샷
      slurp            # 영역 선택
      wl-clipboard     # 클립보드
      mako             # 알림 데몬
      swaybg           # 배경화면
      kanshi           # 디스플레이 자동 설정
      brightnessctl    # 밝기 조절
    ];
  };

  # 세션 관리
  services.greetd = {
    enable = lib.mkDefault true;
    settings.default_session = {
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --sessions ${pkgs.sway}/share/wayland-sessions";
      user = "greeter";
    };
  };

  # 환경 변수
  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";  # Firefox Wayland
    QT_QPA_PLATFORM = "wayland";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
  };

  # PipeWire (Wayland 오디오/화면공유)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
```

## 5. Home-Manager Sway 설정

### `/users/junghan/modules/sway.nix`

```nix
{ config, lib, pkgs, ... }:
let
  # 기존 i3 설정 재사용
  mod = "Mod4";
  fontName = "D2CodingLigature Nerd Font";
  fontSize = 9;
in {
  wayland.windowManager.sway = {
    enable = true;

    config = {
      modifier = mod;

      # i3 설정 대부분 호환
      fonts = {
        names = [ fontName ];
        size = fontSize * 1.0;
      };

      # 기존 i3 gaps 설정 그대로
      gaps = {
        inner = 12;
        outer = 8;
      };

      # 기존 색상 테마 재사용 가능
      colors = {
        focused = {
          border = "#00E5FF";
          background = "#00E5FF";
          text = "#000000";
          indicator = "#FF8C00";
          childBorder = "#00E5FF";
        };
        # ... 나머지 색상
      };

      # 키바인딩 (거의 동일, 일부 수정 필요)
      keybindings = lib.mkMerge [
        # 기존 i3 키바인딩 대부분 재사용
        {
          "${mod}+Return" = "exec foot";  # ghostty 대신 foot
          "${mod}+d" = "exec wofi --show drun";  # rofi 대신 wofi

          # Wayland 전용 명령
          "${mod}+Shift+s" = "exec grim -g \"$(slurp)\" - | wl-copy";  # 스크린샷
        }
      ];

      # Waybar 사용
      bars = [{
        command = "waybar";
        position = "top";
      }];

      # 시작 프로그램
      startup = [
        { command = "mako"; }  # 알림 데몬
        { command = "fcitx5 -d"; }  # 한글 입력
        { command = "swaybg -i ~/.config/nixos-wallpaper.png -m fill"; }
      ];
    };

    # 추가 Sway 설정
    extraConfig = ''
      # XWayland 활성화 (X11 앱 호환)
      xwayland enable

      # 터치패드 설정 (노트북)
      input type:touchpad {
        tap enabled
        natural_scroll enabled
      }

      # 모니터 설정 예시
      # output HDMI-A-1 resolution 1920x1080 position 0,0
      # output eDP-1 resolution 1920x1080 position 1920,0
    '';
  };

  # Waybar 설정
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;

        modules-left = [ "sway/workspaces" "sway/mode" ];
        modules-center = [ "clock" ];
        modules-right = [ "network" "memory" "cpu" "battery" "tray" ];

        # 모듈 설정...
      };
    };
    style = ''
      /* 기존 i3 테마 색상 재활용 */
      * {
        font-family: "${fontName}";
        font-size: ${toString fontSize}pt;
      }

      window#waybar {
        background: #0f0f23;
        color: #ffffff;
      }

      #workspaces button.focused {
        background: #00E5FF;
        color: #000000;
      }
    '';
  };

  # foot 터미널 설정 (ghostty 대체)
  programs.foot = {
    enable = true;
    settings = {
      main = {
        term = "xterm-256color";
        font = "${fontName}:size=${toString fontSize}";
      };
      colors = {
        # Solarized 색상 적용
        background = "002b36";
        foreground = "839496";
      };
    };
  };
}
```

## 6. 전환 체크리스트

### 사전 준비
- [ ] 현재 i3 설정 백업
- [ ] 중요 키바인딩 목록 작성
- [ ] 사용 중인 X11 전용 앱 확인

### 시스템 설정
- [ ] Sway 모듈 생성 (`/modules/wm/sway.nix`)
- [ ] Specialization 설정 추가 (옵션 1 선택 시)
- [ ] 또는 병렬 설치 설정 (옵션 2 선택 시)

### Home-Manager 설정
- [ ] Sway 설정 파일 생성 (`/users/junghan/modules/sway.nix`)
- [ ] i3 설정에서 키바인딩/색상 마이그레이션
- [ ] Waybar 설정 작성
- [ ] foot/alacritty 터미널 설정

### 테스트
- [ ] 새 세션으로 로그인 테스트
- [ ] 한글 입력 확인
- [ ] 주요 애플리케이션 실행 확인
- [ ] 스크린샷, 클립보드 등 기능 테스트

## 7. 주의사항 및 팁

### X11 앱 호환성
- XWayland 통해 대부분 X11 앱 실행 가능
- 일부 앱은 성능 저하나 기능 제한 가능
- Electron 앱: `--enable-features=UseOzonePlatform --ozone-platform=wayland` 플래그 추가

### 한글 입력
- fcitx5가 Wayland에서 가장 안정적
- kime은 아직 Wayland 지원 제한적
- 환경변수 설정 필수

### 디스플레이 설정
- `xrandr` 대신 `wlr-randr` 또는 `kanshi` 사용
- kanshi로 디스플레이 프로파일 자동 전환 가능

### 성능
- 일반적으로 Wayland가 더 부드러운 애니메이션
- 배터리 수명 개선 (특히 노트북)
- GPU 가속 더 효율적

## 8. 롤백 방법

### Specialization 사용 시
```bash
# 부팅 메뉴에서 기본 프로파일 선택
# 또는 설정에서 specialization 제거
```

### 병렬 설치 시
```bash
# 로그인 화면에서 i3 세션 선택
# 또는 Sway 모듈 import 제거
```

## 9. 참고 자료

- [NixOS Wiki - Sway](https://wiki.nixos.org/wiki/Sway)
- [Home-Manager Sway Options](https://nix-community.github.io/home-manager/options.xhtml#opt-wayland.windowManager.sway.enable)
- [Sway Wiki](https://github.com/swaywm/sway/wiki)
- [i3 to Sway Migration Guide](https://github.com/swaywm/sway/wiki/i3-Migration-Guide)

---

**작성자**: junghanacs / Claude
**상태**: ✅ 분석 완료
**다음 단계**: 옵션 선택 후 실제 구현