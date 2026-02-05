# i3 키바인딩 (Regolith 스타일)

> NixOS + i3wm 키바인딩 참조 문서
> 설정 파일: `users/junghan/modules/i3.nix`

**Mod 키**: `Super` (Windows 키)

## 기본

| 키 | 동작 |
|----|------|
| `Mod+Return` | 터미널 (Ghostty) |
| `Mod+Shift+q` | 창 닫기 |
| `Mod+d` | 앱 런처 (Rofi) |
| `Mod+Shift+d` | 명령어 실행 (Rofi run) |
| `Mod+Tab` | 창 전환 (Rofi window) |
| `Mod+p` | 패스워드 매니저 (rofi-pass) |

## 포커스 이동

| 키 | 동작 |
|----|------|
| `Mod+h/j/k/l` | 좌/하/상/우 포커스 (vim) |
| `Mod+←/↓/↑/→` | 좌/하/상/우 포커스 (화살표) |
| `Mod+a` | 부모 컨테이너 포커스 |
| `Mod+z` | 자식 컨테이너 포커스 |

## 창 이동

| 키 | 동작 |
|----|------|
| `Mod+Shift+h/j/k/l` | 창 이동 (vim) |
| `Mod+Shift+←/↓/↑/→` | 창 이동 (화살표) |

## 레이아웃

| 키 | 동작 |
|----|------|
| `Mod+g` | 수평 분할 (horizontal) |
| `Mod+v` | 수직 분할 (vertical) |
| `Mod+f` | 전체화면 토글 |
| `Mod+s` | 스택 레이아웃 |
| `Mod+w` | 탭 레이아웃 |
| `Mod+e` | 분할 레이아웃 토글 |

## Floating & Scratchpad (Regolith 스타일)

| 키 | 동작 |
|----|------|
| `Mod+Shift+f` | Floating 토글 |
| `Mod+Shift+t` | Tiling/Floating 포커스 전환 |
| `Mod+Ctrl+a` | Scratchpad 보기 (any) |
| `Mod+Ctrl+m` | Scratchpad로 이동 (move) |
| `Mod+m` | Emacs scratchpad 토글 |

## 워크스페이스

| 키 | 동작 |
|----|------|
| `Mod+1~9` | 워크스페이스 1~9 이동 |
| `Mod+0` | 워크스페이스 10 이동 |
| `Mod+Shift+1~9` | 창을 워크스페이스 1~9로 이동 |
| `Mod+Shift+0` | 창을 워크스페이스 10으로 이동 |

## 시스템

| 키 | 동작 |
|----|------|
| `Mod+Shift+c` | i3 설정 리로드 |
| `Mod+Shift+r` | i3 재시작 |
| `Mod+Shift+e` | i3 종료 (확인창) |
| `Mod+Shift+x` | 화면 잠금 (i3lock) |
| `Mod+r` | 리사이즈 모드 진입 |

## 리사이즈 모드

| 키 | 동작 |
|----|------|
| `h/←` | 너비 줄이기 |
| `l/→` | 너비 늘리기 |
| `k/↑` | 높이 줄이기 |
| `j/↓` | 높이 늘리기 |
| `Enter/Esc` | 리사이즈 모드 종료 |

## 알림 (Dunst)

| 키 | 동작 |
|----|------|
| `Mod+n` | 알림 닫기 |
| `Mod+Shift+n` | 모든 알림 닫기 |
| `Mod+`` ` (grave) | 알림 히스토리 보기 |
| `Mod+.` | 알림 액션 실행 |

## 미디어 & 밝기

| 키 | 동작 |
|----|------|
| `XF86AudioRaiseVolume` | 볼륨 +5% |
| `XF86AudioLowerVolume` | 볼륨 -5% |
| `XF86AudioMute` | 음소거 토글 |
| `XF86MonBrightnessUp` | 화면 밝기 +5% |
| `XF86MonBrightnessDown` | 화면 밝기 -5% |
| `XF86KbdBrightnessUp/Down` | 키보드 백라이트 조절 |

## 스크린샷

| 키 | 동작 |
|----|------|
| `Print` | 전체 화면 캡처 |
| `Mod+Print` | 현재 창 캡처 |
| `Mod+Shift+Print` | 영역 선택 캡처 |

## 기타

| 키 | 동작 |
|----|------|
| `Mod+i` | 입력 필드 Emacs로 편집 (edit-input) |
| `Mod+c` | Compositor (picom) 토글 |

---

## Regolith 주요 차이점

| 기능 | 기본 i3 | Regolith (현재) |
|------|---------|-----------------|
| Floating 토글 | `Mod+Shift+space` | `Mod+Shift+f` |
| Focus mode | `Mod+space` | `Mod+Shift+t` |
| Scratchpad show | `Mod+minus` | `Mod+Ctrl+a` |
| Move to scratchpad | `Mod+Shift+minus` | `Mod+Ctrl+m` |
| Split horizontal | `Mod+h` | `Mod+g` |
| Focus child | `Mod+Shift+a` | `Mod+z` |
