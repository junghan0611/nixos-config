# home-manager 통합 계획

**작성일**: 2025-10-08
**목적**: ElleNajit 패턴을 현재 flake 구조에 충돌 없이 점진적으로 적용

---

## 1. 현재 구조 분석

### A. 기존 구조

```
nixos-config/
├── flake.nix                          # ✅ home-manager 이미 input
├── lib/mksystem.nix                   # ✅ home-manager 통합 헬퍼
├── users/junghan/
│   ├── home-manager.nix               # 📝 진입점 (341줄)
│   ├── nixos.nix                      # ✅ 사용자 계정 정의
│   ├── i3                             # ⚠️ 파일 참조 방식
│   ├── i3status                       # (미사용, programs.i3status 사용)
│   ├── rofi                           # ⚠️ 파일 참조 방식
│   ├── ghostty.linux                  # ⚠️ 파일 참조 방식
│   ├── kitty                          # ⚠️ 파일 참조 방식
│   ├── inputrc                        # ⚠️ 파일 참조 방식
│   └── Xresources                     # ⚠️ 파일 참조 방식
└── modules/specialization/
    ├── i3.nix                         # ✅ 시스템 레벨 (WM 활성화, 패키지)
    └── gnome.nix                      # ✅ 시스템 레벨
```

### B. 현재 방식

**i3 설정** (`home-manager.nix:99`):
```nix
home.file.".config/i3/config".text = builtins.readFile ./i3;
```

**i3status** (`home-manager.nix:287-340`):
```nix
programs.i3status = {
  enable = true;
  # ... (이미 선언적!)
};
```

### C. 장점
- ✅ home-manager 이미 통합
- ✅ flake 기반 의존성 관리
- ✅ i3status 선언적 관리
- ✅ specialization으로 WM 분리

### D. 개선 필요
- ⚠️ i3 설정 파일 참조 방식 → 선언적으로 전환
- ⚠️ 개발 환경 미분리 → 언어별 모듈화
- ⚠️ dunst 미설정 → 선언적 추가
- ⚠️ py3status 미사용 → 도입 검토

---

## 2. ElleNajit 패턴과 비교

| 항목 | 현재 (junghanacs) | ElleNajit | 권장 |
|------|------------------|-----------|------|
| **i3 설정** | `builtins.readFile ./i3` | `xsession.windowManager.i3.config` | ElleNajit |
| **i3status** | `programs.i3status` ✅ | `py3status` + custom | ElleNajit |
| **dunst** | 미설정 | `services.dunst` | ElleNajit |
| **개발 환경** | 단일 파일 | 언어별 분리 | ElleNajit |
| **rofi** | 파일 참조 | 파일 참조 | 현재 유지 |
| **emacs** | 패키지만 | Desktop 항목 + 스크립트 | 선택 |

---

## 3. 제안 디렉토리 구조

### A. 최종 목표 구조

```
users/junghan/
├── home-manager.nix          # 진입점 (imports만)
├── nixos.nix                 # 사용자 계정 (기존 유지)
├── modules/                  # ⭐ 새로 추가
│   ├── default.nix          # 모듈 통합
│   ├── i3.nix               # i3 선언적 설정
│   ├── dunst.nix            # dunst 설정
│   ├── shell.nix            # bash, tmux, git 등
│   ├── emacs.nix            # Emacs 설정
│   └── development/
│       ├── default.nix      # 개발 환경 통합
│       ├── python.nix
│       ├── rust.nix
│       └── nix.nix
└── configs/                  # 기존 파일 이동
    ├── ghostty.linux
    ├── kitty
    ├── rofi                 # 유지
    ├── inputrc
    └── Xresources
```

### B. home-manager.nix 리팩토링

**기존** (341줄):
```nix
{ inputs, ... }:
{ config, lib, pkgs, ... }:

let
  vars = import ../../hosts/nuc/vars.nix;
in {
  home.username = vars.username;
  home.packages = [ ... ];  # 50줄
  home.file = { ... };      # 10줄
  programs.git = { ... };   # 40줄
  programs.bash = { ... };  # 60줄
  programs.tmux = { ... };  # 35줄
  programs.i3status = { ... }; # 50줄
  # ...
}
```

**개선** (~50줄):
```nix
{ inputs, ... }:
{ config, lib, pkgs, ... }:

let
  vars = import ../../hosts/nuc/vars.nix;
in {
  imports = [
    ./modules
  ];

  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
  xdg.enable = true;

  # 기본 패키지만 (개발 환경은 modules/development/로)
  home.packages = with pkgs; [
    neofetch
    ncdu
    duf
    procs
  ];
}
```

**modules/default.nix** (새로 생성):
```nix
{
  imports = [
    ./shell.nix
    ./i3.nix
    ./dunst.nix
    ./emacs.nix
    ./development
  ];
}
```

---

## 4. 점진적 마이그레이션 로드맵

### Phase 1: 구조 준비 (1일)

**목표**: 디렉토리 생성 및 모듈 분리 시작

**작업:**
1. `users/junghan/modules/` 디렉토리 생성
2. `users/junghan/configs/` 디렉토리 생성 및 기존 파일 이동
3. `modules/default.nix` 생성 (빈 imports)
4. `home-manager.nix`에 `./modules` import 추가

**테스트:**
```bash
nixos-rebuild build --flake .#nuc
# 변경 없음 확인
```

### Phase 2: Shell 모듈 분리 (1일)

**목표**: git, bash, tmux 등 shell 관련 설정 분리

**작업:**
1. `modules/shell.nix` 생성
2. `home-manager.nix`에서 다음 이동:
   - `programs.git`
   - `programs.bash`
   - `programs.tmux`
   - `programs.direnv`
   - `programs.fzf`
   - `programs.neovim`

**예시** (`modules/shell.nix`):
```nix
{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    userName = "Jung Han";
    # ... (기존 설정 복사)
  };

  programs.bash = {
    enable = true;
    # ... (기존 설정 복사)
  };

  programs.tmux = {
    enable = true;
    # ... (기존 설정 복사)
  };
}
```

**테스트:**
```bash
home-manager build --flake .#nuc
diff -u ~/.bashrc /nix/store/.../home-files/.bashrc
```

### Phase 3: i3 선언적 전환 (2일)

**목표**: `xsession.windowManager.i3.config` 사용

**작업:**
1. `modules/i3.nix` 생성
2. 기존 `users/junghan/i3` 파일 분석
3. ElleNajit 패턴으로 전환
4. `home-manager.nix`에서 `home.file.".config/i3/config"` 제거

**예시** (`modules/i3.nix`):
```nix
{ pkgs, lib, ... }:
let
  mod = "Mod4";
in {
  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = mod;

      fonts = {
        names = [ "D2CodingLigature Nerd Font" ];
        size = 9.0;
      };

      keybindings = lib.mkMerge [
        # Workspace 1-9
        (builtins.listToAttrs (map (n: {
          name = "${mod}+${toString n}";
          value = "workspace number ${toString n}";
        }) (lib.range 1 9)))

        # 기본 키바인딩
        {
          "${mod}+Return" = "exec ${pkgs.ghostty}/bin/ghostty";
          "${mod}+Shift+q" = "kill";
          "${mod}+d" = "exec ${pkgs.rofi}/bin/rofi -show drun";

          # Vim 스타일 포커스
          "${mod}+h" = "focus left";
          "${mod}+j" = "focus down";
          "${mod}+k" = "focus up";
          "${mod}+l" = "focus right";

          # 창 이동
          "${mod}+Shift+h" = "move left";
          "${mod}+Shift+j" = "move down";
          "${mod}+Shift+k" = "move up";
          "${mod}+Shift+l" = "move right";

          # 레이아웃
          "${mod}+b" = "split h";
          "${mod}+v" = "split v";
          "${mod}+f" = "fullscreen toggle";
          "${mod}+s" = "layout stacking";
          "${mod}+w" = "layout tabbed";
          "${mod}+e" = "layout toggle split";

          # ... (나머지 키바인딩)
        }
      ];

      bars = [{
        statusCommand = "${pkgs.i3status}/bin/i3status";
        position = "top";
        fonts = {
          names = [ "D2CodingLigature Nerd Font" ];
          size = 9.0;
        };
      }];

      # 색상 (Tomorrow Night 스키마)
      colors = {
        focused = {
          border = "#81A2BE";
          background = "#81A2BE";
          text = "#1D1F21";
          indicator = "#82AAFF";
          childBorder = "#81A2BE";
        };
        # ...
      };
    };
  };
}
```

**주의사항:**
- 기존 `~/.config/i3/config` 백업
- 키바인딩 하나씩 확인
- `i3-msg reload` 테스트

### Phase 4: dunst 추가 (1일)

**목표**: 알림 시스템 선언적 관리

**작업:**
1. `modules/dunst.nix` 생성
2. `modules/specialization/i3.nix`에서 dunst 패키지 제거
3. i3 키바인딩에 dunst 제어 추가

**예시** (`modules/dunst.nix`):
```nix
{ pkgs, ... }:
{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        font = "D2CodingLigature Nerd Font 12";
        allow_markup = true;
        format = "<b>%s</b>\\n%b";
        geometry = "600x15-40+40";
        idle_threshold = 120;
        padding = 8;
        horizontal_padding = 8;
      };

      urgency_low = {
        background = "#1D1F21";
        foreground = "#C5C8C6";
        timeout = 5;
      };

      urgency_normal = {
        background = "#282A2E";
        foreground = "#C5C8C6";
        timeout = 7;
      };

      urgency_critical = {
        background = "#A54242";
        foreground = "#FFFFFF";
        timeout = 0;
      };
    };
  };
}
```

**i3.nix에 키바인딩 추가**:
```nix
"${mod}+space" = "exec ${pkgs.dunst}/bin/dunstctl close";
"${mod}+Shift+space" = "exec ${pkgs.dunst}/bin/dunstctl close-all";
"${mod}+grave" = "exec ${pkgs.dunst}/bin/dunstctl history-pop";
```

### Phase 5: 개발 환경 분리 (2일)

**목표**: 언어별 모듈화

**작업:**
1. `modules/development/` 디렉토리 생성
2. `modules/development/default.nix` 생성
3. Python, Rust, Nix 환경 분리

**예시** (`modules/development/python.nix`):
```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    (python312.withPackages (ps: with ps; [
      ipython
      pytest
      black
      ruff
      isort
    ]))
    ruff-lsp
    basedpyright
  ];
}
```

**`modules/development/default.nix`**:
```nix
{
  imports = [
    ./python.nix
    ./rust.nix
    ./nix.nix
  ];

  home.packages = with pkgs; [
    gh
    lazygit
    delta
    git-lfs
  ];
}
```

### Phase 6: py3status 도입 (선택, 2일)

**목표**: Emacs org-mode 통합

**조건**: Doom Emacs 사용 중이고 org-mode로 작업 관리 시

**작업:**
1. `modules/i3.nix`에서 i3status → py3status 전환
2. Emacs Lisp 함수 추가
3. 상태바 커스터마이징

**예시**:
```nix
let
  py3status = pkgs.python3Packages.py3status;
  i3status-conf = pkgs.writeText "i3status.conf" ''
    general {
      output_format = i3bar
      colors = true
      interval = 1
    }

    order += "cpu_usage"
    order += "disk /"
    order += "time"

    cpu_usage { format = "CPU: %usage" }
    disk "/" { format = "/ %avail" }
    time { format = " %Y-%m-%d %H:%M " }
  '';
in {
  xsession.windowManager.i3.config.bars = [{
    statusCommand = "${py3status}/bin/py3status -c ${i3status-conf}";
  }];
}
```

---

## 5. 충돌 방지 전략

### A. 점진적 전환

**원칙:**
1. 한 번에 하나의 모듈만 이동
2. 각 단계마다 빌드 테스트
3. 문제 발생 시 즉시 롤백

**테스트 명령:**
```bash
# 시스템 빌드만
nixos-rebuild build --flake .#nuc

# home-manager 빌드만
home-manager build --flake .#nuc

# 전체 빌드
nixos-rebuild build --flake .#nuc
```

### B. 백업 생성

**마이그레이션 전:**
```bash
cd ~/repos/gh/nixos-config
git checkout -b home-manager-refactor
cp users/junghan/home-manager.nix users/junghan/home-manager.nix.backup
```

### C. 롤백 계획

**문제 발생 시:**
```bash
# Git 롤백
git reset --hard HEAD~1

# 또는 이전 generation 부팅
sudo nixos-rebuild switch --rollback
```

---

## 6. 검증 체크리스트

### Phase별 검증

**Phase 1 (구조 준비):**
- [ ] `nixos-rebuild build` 성공
- [ ] 빌드 결과 변경 없음

**Phase 2 (Shell 분리):**
- [ ] bash 실행 확인
- [ ] git 명령 동작
- [ ] tmux 세션 생성
- [ ] fzf 키바인딩 동작

**Phase 3 (i3 전환):**
- [ ] i3 시작 성공
- [ ] 모든 키바인딩 동작
- [ ] 워크스페이스 전환
- [ ] rofi 실행
- [ ] 스크린샷 (Mod+Print)
- [ ] 창 레이아웃 변경
- [ ] 상태바 표시

**Phase 4 (dunst):**
- [ ] 알림 표시
- [ ] dunstctl 명령 동작
- [ ] 키바인딩으로 알림 제어

**Phase 5 (개발 환경):**
- [ ] python REPL 실행
- [ ] rust cargo 명령
- [ ] nix-shell 진입

---

## 7. 예상 문제 및 해결

### 문제 1: i3 설정 파일 경로

**증상:**
```
error: cannot read file './i3'
```

**원인:** 파일 참조 경로 변경

**해결:**
```nix
# 기존 파일 유지하면서 선언적 전환
xsession.windowManager.i3 = {
  enable = true;
  # config는 modules/i3.nix에서 관리
};
```

### 문제 2: i3status vs py3status 충돌

**증상:**
```
error: option 'programs.i3status' conflicts with 'py3status'
```

**해결:**
```nix
# i3.nix에서 programs.i3status.enable = false;
# 또는 home-manager.nix에서 제거
```

### 문제 3: dunst 중복 실행

**증상:** 알림 2번 표시

**원인:** systemd + i3 autostart 중복

**해결:**
```nix
# i3 autostart에서 dunst 제거
# services.dunst.enable = true; 만 사용
```

---

## 8. 마이그레이션 후 구조

### 최종 디렉토리

```
users/junghan/
├── home-manager.nix          # 50줄 (imports만)
├── nixos.nix                 # 44줄 (변경 없음)
├── modules/
│   ├── default.nix           # 10줄
│   ├── shell.nix             # 150줄 (git, bash, tmux, etc)
│   ├── i3.nix                # 200줄 (선언적 i3 설정)
│   ├── dunst.nix             # 50줄
│   ├── emacs.nix             # 100줄 (선택)
│   └── development/
│       ├── default.nix       # 20줄
│       ├── python.nix        # 30줄
│       ├── rust.nix          # 30줄
│       └── nix.nix           # 20줄
└── configs/                   # 기존 파일들
    ├── ghostty.linux
    ├── kitty
    ├── rofi
    ├── inputrc
    └── Xresources
```

### 라인 수 비교

| 파일 | 기존 | 개선 | 차이 |
|------|------|------|------|
| `home-manager.nix` | 341줄 | 50줄 | -291줄 |
| 모듈들 합계 | 0줄 | 610줄 | +610줄 |
| **총합** | 341줄 | 660줄 | +319줄 |

**장점:**
- 각 모듈 독립적 관리
- 재사용성 증가
- 가독성 향상
- specialization별 설정 용이

---

## 9. 추가 고려사항

### A. specialization 연동

현재 `modules/specialization/i3.nix`는 시스템 레벨만 관리합니다.
home-manager i3 설정도 specialization에 따라 다르게 하려면:

**옵션 1: 조건부 import**
```nix
# users/junghan/modules/default.nix
{ config, ... }:
{
  imports = [
    ./shell.nix
    ./development
  ] ++ (if config.specialisation.i3 or false then
    [ ./i3.nix ./dunst.nix ]
  else
    [ ./gnome.nix ]
  );
}
```

**옵션 2: 별도 파일**
```
modules/
├── i3/
│   ├── i3.nix
│   └── dunst.nix
└── gnome/
    └── gnome.nix
```

### B. 호스트별 설정

현재는 nuc만 있지만, laptop 추가 시:

```nix
# lib/mksystem.nix는 그대로
# users/junghan/modules/i3.nix
{ currentSystemName, ... }:
let
  fontSize = if currentSystemName == "laptop" then 11.0 else 9.0;
  dpi = if currentSystemName == "laptop" then 144 else 96;
in {
  xsession.windowManager.i3.config.fonts.size = fontSize;
}
```

### C. 멀티 사용자

향후 다른 사용자 추가 시:

```
users/
├── junghan/
│   ├── home-manager.nix
│   └── modules/
└── another-user/
    ├── home-manager.nix
    └── modules/
```

공통 모듈은 `modules/common/`으로 분리.

---

## 10. 실행 계획

### 일정

| Phase | 작업 | 소요 시간 | 완료일 목표 |
|-------|------|-----------|-------------|
| 1 | 구조 준비 | 1일 | D+1 |
| 2 | Shell 분리 | 1일 | D+2 |
| 3 | i3 전환 | 2일 | D+4 |
| 4 | dunst 추가 | 1일 | D+5 |
| 5 | 개발 환경 분리 | 2일 | D+7 |
| 6 | py3status (선택) | 2일 | D+9 |

**총 소요**: 7-9일

### 우선순위

**필수 (P0):**
1. ✅ Phase 1: 구조 준비
2. ✅ Phase 2: Shell 분리
3. ✅ Phase 3: i3 선언적 전환

**권장 (P1):**
4. ✅ Phase 4: dunst 추가
5. ✅ Phase 5: 개발 환경 분리

**선택 (P2):**
6. ⚠️ Phase 6: py3status (Emacs 워크플로우에 따라 결정)

---

## 11. 다음 단계

### 즉시 시작

1. **Git 브랜치 생성**
   ```bash
   cd ~/repos/gh/nixos-config
   git checkout -b home-manager-refactor
   ```

2. **Phase 1 실행**
   ```bash
   mkdir -p users/junghan/modules
   mkdir -p users/junghan/configs
   touch users/junghan/modules/default.nix
   ```

3. **백업**
   ```bash
   cp users/junghan/home-manager.nix users/junghan/home-manager.nix.backup
   ```

### 진행 상황 추적

**이 문서에 체크리스트 업데이트:**
- [ ] Phase 1 완료
- [ ] Phase 2 완료
- [ ] Phase 3 완료
- [ ] Phase 4 완료
- [ ] Phase 5 완료
- [ ] Phase 6 완료 (선택)

---

**작성자**: junghanacs
**상태**: ✅ 계획 수립 완료
**다음**: Phase 1 실행
