# i3 키바인딩 (Regolith 스타일)

> NixOS + i3wm 키바인딩 참조 문서
> 설정 파일: `users/junghan/modules/i3.nix`

**Mod 키**: `Super` (Windows 키)

## 기본

| 키 | 동작 |
|----|------|
| `Mod+Return` | 터미널 (Ghostty) |
| `Mod+Alt+Return` | 터미널 (WezTerm) |
| `Mod+Shift+Return` | 기본 브라우저 (Firefox) |
| `Mod+Ctrl+Return` | Microsoft Edge |
| `Mod+Shift+q` | 창 닫기 |
| `Mod+d` | 앱 런처 (Rofi) |
| `Mod+Shift+d` | 명령어 실행 (Rofi run) |
| `Mod+Tab` | 워크스페이스 순환 (다음, 현재 출력) |
| `Mod+Shift+Tab` | 워크스페이스 순환 (이전, 현재 출력) |
| `Mod+p` | 패스워드 매니저 (rofi-pass) |
| `F1` (누르고 떼기) | Whisper 워키토키 (PTT) 음성 입력 |
| `Mod+e` | Emacs Everywhere 팝업 편집창 |

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
| `Mod+Shift+.` | 알림 액션 실행 |

## 포커스 토글 (i3-swap-focus)

| 키 | 동작 |
|----|------|
| `Mod+.` | 마지막 두 창 사이 포커스 토글 |

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

## WezTerm

> 설정 파일: `users/junghan/configs/wezterm.lua`

| 키 | 동작 |
|----|------|
| `Ctrl+Shift+X` | Copy Mode 진입 (vim 키바인딩으로 선택/복사) |
| `Ctrl+Shift+C` | 선택 영역 복사 |
| `Ctrl+Shift+V` | 붙여넣기 |
| 마우스 드래그 | 텍스트 선택 → 자동 복사 |
| `ALT+Return` | 비활성화 (WezTerm 전체화면 충돌 방지) |

## tmux

> 설정 파일: `users/junghan/configs/tmux.conf`
> `tm` 명령: `~/org/setup/.bashrc.local`

**Prefix**: `Ctrl+b` 또는 `Alt+c` — 둘 다 동작. 아래 표의 `prefix`는 이 둘 중 하나.

층위가 셋이고 서로 다른 것이다. 헷갈리면 키를 잘못 건다:

| 층 | 무엇 | 주력 키 |
|----|------|---------|
| **세션** | `tm`이 디렉토리마다 하나씩 여는 것 | `prefix+s` |
| **창(window)** | 그 세션 안의 창. 에이전트 하나에 창 하나 | `Alt+[` `Alt+]` |
| **분할(pane)** | 창 안을 쪼갠 것 | `prefix+\|` `prefix+-` |

먼저 손에 붙일 것 세 개: **`tm`** → **`prefix+c`** (창 추가) → **`Alt+]`** (창 넘기기).

### 세션 — 시작과 복귀

| 키 | 동작 |
|----|------|
| `tm` | 현재 디렉토리 이름으로 세션 열기 (이미 있으면 그리로 들어감) |
| `tm 이름` | 세션 이름을 직접 지정 |
| `prefix+d` | 떼어놓기(detach) — 세션은 계속 살아있다 |
| `tm` (다시) | 떼어놓은 세션으로 복귀 |
| `prefix+s` | 세션 목록 fzf 팝업 → 골라서 이동 |
| `prefix+$` | 세션 이름 바꾸기 |

상태바 맨 왼쪽 색 배지가 **어느 디바이스인지** 알려준다 (`oracle`=주황, `nuc`=파랑, `laptop`=초록, `thinkpad`=보라).

### 창(window) — 에이전트 하나에 창 하나

| 키 | 동작 |
|----|------|
| `prefix+c` | 새 창 (현재 경로 유지) |
| **`Alt+[` / `Alt+]`** | **이전 / 다음 창** — prefix 불필요 |
| `prefix+1`~`9` | 번호로 바로 이동 |
| `prefix+,` | 창 이름 바꾸기 |
| `prefix+&` | 창 닫기 (확인창) |

### 분할(pane)

| 키 | 동작 |
|----|------|
| `prefix+\|` | 좌우 분할 (`\|`는 `Shift+\`) |
| `prefix+-` | 상하 분할 |
| `prefix+h/j/k/l` | 좌/하/상/우 이동 |
| **`prefix+z`** | **줌 토글** — 한 pane을 창 전체로 폈다 되돌린다 |
| `prefix+x` | pane 닫기 (확인창) |
| `Alt+방향키` | 크기 조절 5칸 — prefix 불필요 |

분할은 둘 다 **현재 경로를 유지**한다. tmux 기본인 `prefix+"` / `prefix+%`는 홈으로 가버리니 쓰지 말 것.

### 복사 (마우스 없이)

**진입** — `Alt` 계열은 진입과 첫 동작을 한 방에 한다.

| 키 | 동작 |
|----|------|
| **`Alt+u` / `Alt+v`** | 반쪽 위 / 아래 스크롤 — copy mode 자동 진입 |
| **`Alt+/`** | copy mode 진입 + 위로 검색 프롬프트 |
| `prefix+Enter` | copy mode 진입 |
| `Esc` / `q` / `C-g` | copy mode 나가기 |

**한글 입력 상태에서 살아남는 키가 따로 있다.** 입력기(두벌식)가 삼키는 것은
*알파벳 26자뿐*이라, 아래 표의 오른쪽 두 열은 한영 전환 없이 그대로 된다.
`v`/`y` 같은 글자 키를 쓰려면 한영 전환이 필요하지만, **대안이 다 있으므로
전환할 일이 거의 없다.**

| 동작 | 영문 키 | 한글에서도 되는 키 |
|------|--------|------------------|
| 선택 시작 | `v` | **`Space`** |
| 줄 단위 선택 | `V` | **`C-v`** / **`M-V`** |
| 사각형 선택 토글 | `C-q` | **`C-q`** |
| 복사 + 종료 | `y` | **`C-y`** / **`M-y`** 또는 **`Enter`** |
| 커서 이동 (1칸) | `h j k l` | **`C-h C-j C-k C-l`** / 방향키 |
| 커서 이동 (5칸) | — | **`M-h M-j M-k M-l`** |
| 단어 앞뒤 | `b` / `e w` | **`M-b`** / **`M-f`** |
| 줄 처음/끝 | `0` `$` `^` | `0` `$` `^` (그대로 됨) |
| 문서 처음/끝 | `g` / `G` | **`M-<`** / **`M->`** |
| 반쪽 스크롤 | `C-u` `C-d` | **`M-u`** / **`M-v`** |
| 검색 | `/` `?` | `/` `?` (그대로 됨) |
| 검색 반복 | `n` / `N` | **`M-n`** / **`M-N`** |
| 선택 반대편으로 | `o` | **`M-o`** |
| 문단 이동 | `{` `}` | `{` `}` (그대로 됨) |

복사는 OSC-52라 SSH 너머에서도 로컬 클립보드로 들어온다.

> **왜 `V` 대신 `ㅍ`를 바인딩할 수 없나** — 설정 문제가 아니라 원리상 불가하다.
> 홑자모는 조합 중(preedit) 버퍼에 갇혀 확정되지 않으므로 애초에 tmux까지
> 도달하지 않고, 두벌식은 치환표가 아니라 상태를 가진 조합기라 키와 글자
> 사이에 1:1 대응이 없다 (`hjkl` 4타 → "허" 한 글자 + 조합 중 "애"). tmux 쪽은
> 결백하다 — 한글 바이트를 직접 주입하면 정상 처리된다. 자세한 계보는
> `users/junghan/configs/tmux.conf`의 해당 주석에 있다.

### 기타

| 키 | 동작 |
|----|------|
| `prefix+r` | 설정 리로드 |

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
