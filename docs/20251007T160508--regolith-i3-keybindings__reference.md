# Regolith i3wm 키 바인딩 정리

## 기본 설정
- **Mod 키**: Super (Windows 키)
- **Alt 키**: Alt
- **터미널**: ghostty

## 런처 및 검색
| 키 조합 | 기능 | 설명 |
|---------|------|------|
| `Mod + d` | 애플리케이션 실행 | ilia 앱 런처 |
| `Mod + Shift + Space` | 명령어 실행 | 터미널 명령어 |
| `Mod + Ctrl + Space` | 윈도우 검색 | 이름으로 창 찾기 |
| `Mod + Shift + ?` | 키바인딩 도움말 | 모든 키 바인딩 보기 |

## 세션 관리
| 키 조합 | 기능 | 설명 |
|---------|------|------|
| `Mod + q` | 창 닫기 | 현재 포커스된 창 종료 |
| `Mod + Alt + q` | 강제 종료 | kill -9로 프로세스 종료 |
| `Mod + Shift + c` | 설정 새로고침 | i3 config reload |
| `Mod + Shift + r` | 세션 새로고침 | Regolith look refresh |
| `Mod + Ctrl + Escape` | 화면 잠금 | 스크린세이버 잠금 |

## 프로그램 실행
| 키 조합 | 기능 | 설명 |
|---------|------|------|
| `Mod + Enter` | 터미널 | ghostty 터미널 실행 |
| `Mod + Shift + Enter` | 브라우저 | 기본 웹 브라우저 |
| `Mod + Shift + n` | 파일 관리자 | Nautilus 실행 |
| `Mod + m` | Scratch Emacs | Emacs 스크래치패드 토글 |
| `Mod + b` | 터치패드 토글 | 터치패드 켜기/끄기 |

## 창 크기 조절
| 키 조합 | 기능 | 설명 |
|---------|------|------|
| `Mod + -` | 갭 감소 | 창 사이 간격 줄이기 (6px) |
| `Mod + +` | 갭 증가 | 창 사이 간격 늘리기 (6px) |
| `Mod + Shift + -` | 큰 갭 감소 | 창 사이 간격 크게 줄이기 (12px) |
| `Mod + Shift + +` | 큰 갭 증가 | 창 사이 간격 크게 늘리기 (12px) |

## UI 관리
| 키 조합 | 기능 | 설명 |
|---------|------|------|
| `Mod + i` | 바 토글 | 상태바 숨기기/보이기 |

## 워크스페이스 배치
- **워크스페이스 1-5**: 노트북 디스플레이 (eDP)
- **워크스페이스 6-10**: 외부 모니터 (HDMI/DisplayPort)

## 사용자 커스텀 설정
- **설정 위치**: 
  - 시스템: `/usr/share/regolith/i3/config.d/`
  - 사용자: `~/.config/regolith3/i3/config.d/`
- **스크립트 위치**: `~/.local/bin/`
  - `i3_scratchpad_show_or_create.sh` - 스크래치패드 관리
  - `toggle-touchpad.sh` - 터치패드 토글

## NixOS i3 설정 시 참고사항

### 필수 패키지
```nix
environment.systemPackages = with pkgs; [
  i3
  i3status
  i3lock
  dmenu          # 또는 rofi
  xdotool
  xorg.xdpyinfo
  dunst          # 알림
  picom          # 컴포지터
  feh            # 배경화면
];
```

### 기본 i3 설정 구조
```nix
services.xserver.windowManager.i3 = {
  enable = true;
  package = pkgs.i3;
  extraPackages = with pkgs; [
    dmenu
    i3status
    i3lock
    i3blocks
  ];
  configFile = ./i3-config;  # 또는 extraConfig 사용
};
```

### Mod 키 설정
```
# i3 config 파일에서
set $mod Mod4  # Super/Windows 키
set $alt Mod1  # Alt 키
```

### 주요 변환 사항
1. **ilia** → **dmenu/rofi**: 애플리케이션 런처 대체
2. **regolith-look** → 제거 또는 대체 스크립트
3. **gnome-session-quit** → **systemctl** 명령어로 대체
4. **regolith-control-center** → 제거 또는 다른 설정 도구

### 커스텀 스크립트 이식
- 스크래치패드 스크립트는 그대로 사용 가능
- 터치패드 토글 스크립트도 호환 가능
- 경로만 NixOS 스타일로 수정 필요

## 비활성화된 기능들
다음 기능들은 주석 처리되어 있거나 사용되지 않음:
- Session logout/reboot/shutdown (Shift+e/b/p)
- WiFi/Bluetooth 설정 (GUI 의존)
- Display 설정 (regolith-control-center 의존)
- File search (tracker 의존)
- Look selector (Regolith 전용)