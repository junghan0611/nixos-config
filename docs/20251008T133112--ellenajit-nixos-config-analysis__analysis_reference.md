# ElleNajit NixOS Config 분석

**분석 대상**: https://github.com/ElleNajt/nixos-config
**분석 일자**: 2025-10-08
**목적**: home-manager 기반 i3 설정의 정석적인 구조 파악 및 적용 가능한 워크플로우 탐색

---

## 1. 전체 구조 개요

### 핵심 철학
- **home-manager 중심 구성**: i3, emacs, 개발 환경 모두 home-manager로 선언적 관리
- **niv 기반 의존성 관리**: flake 없이 `niv`로 nixpkgs, home-manager 버전 고정
- **단순하고 명확한 모듈 구조**: 기능별 분리, 복잡한 추상화 없음

### 디렉토리 구조

```
ElleNajit-nixos-config/
├── configuration.nix          # NixOS 시스템 설정
├── hardware-configuration.nix # 하드웨어 자동 생성 설정
├── home.nix                   # home-manager 진입점
├── default.nix                # 빌드 타겟 정의
├── nix/
│   ├── sources.json           # niv 의존성 정의
│   └── sources.nix            # niv 생성 파일
├── home/
│   ├── i3.nix                 # i3 + dunst 설정
│   ├── emacs.nix              # Emacs + Doom 설정
│   ├── email.nix              # 이메일 설정
│   ├── development.nix        # 개발 환경 통합
│   ├── development/
│   │   ├── python.nix
│   │   ├── clojure.nix
│   │   ├── rust.nix
│   │   ├── haskell.nix
│   │   ├── c.nix
│   │   ├── shell.nix
│   │   ├── latex.nix
│   │   └── Claude/            # Claude AI 프롬프트 디렉토리
│   ├── computers/
│   │   └── etude.nix          # 호스트별 설정 (VM)
│   ├── platforms/
│   │   └── linux.nix          # 플랫폼별 패키지
│   └── common/
│       └── solarized.nix      # 색상 테마
├── system/
│   ├── computers/
│   │   └── etude.nix          # 시스템 레벨 호스트 설정
│   └── vms.nix                # VM 관련 설정
├── rebuild-home               # home-manager 재빌드 스크립트
└── rebuild-nixos              # NixOS 재빌드 스크립트
```

---

## 2. 의존성 관리: niv vs flake

### niv 기반 설정

**`nix/sources.json`** (niv 관리):
```json
{
  "nixpkgs": {
    "url": "https://github.com/NixOS/nixpkgs/...",
    "sha256": "..."
  },
  "home-manager": {
    "url": "https://github.com/nix-community/home-manager/...",
    "sha256": "..."
  }
}
```

**`default.nix:1-16`** (빌드 타겟):
```nix
let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { config = { allowUnfree = true; }; };
  home-manager = import sources.home-manager { };
in rec {
  nixos = pkgs.nixos ({ ... }: { imports = [ ./configuration.nix ]; });
  system = nixos.config.system.build.toplevel;

  home = ((import (home-manager.path + "/modules")) {
    inherit pkgs;
    configuration = { ... }: { imports = [ ./home.nix ]; };
  }).activation-script;
}
```

**장점:**
- Flake 없이도 재현 가능한 빌드
- `niv update nixpkgs` 명령으로 간단한 업데이트
- 진입 장벽 낮음

**단점:**
- Flake의 lock 파일 기능 부족
- 공식 NixOS 트렌드와 다름

---

## 3. home-manager 기반 i3 설정

### A. 선언적 i3 구성

**`home/i3.nix:168-307`** - 핵심 설정:

```nix
xsession.windowManager.i3 = {
  enable = true;
  config = {
    # 키바인딩
    keybindings = mkMerge [
      # Workspace 1-9 자동 생성
      (map (n: {
        "${mod}+${toString n}" = "workspace ${toString n}";
        "${mod}+Shift+${toString n}" =
          "move container to workspace ${toString n}";
      }) (range 1 9))

      # Vim 스타일 포커스 이동
      {
        "${mod}+h" = "focus left";
        "${mod}+j" = "focus down";
        "${mod}+k" = "focus up";
        "${mod}+l" = "focus right";

        # 창 이동
        "${mod}+Shift+h" = "move left";
        # ...

        # 레이아웃
        "${mod}+e" = "layout toggle split";
        "${mod}+w" = "layout tabbed";
        "${mod}+s" = "layout stacking";

        # 스크린샷 (maim + xclip)
        "${mod}+q" =
          ''exec "maim -s | xclip -selection clipboard -t image/png"'';

        # Rofi 런처
        "${mod}+u" = "exec rofi -modi combi ...";

        # 패스워드 매니저
        "${mod}+p" = "exec rofi-pass ...";
      }
    ];

    # 폰트
    fonts = {
      names = [ "MesloLGSDZ" ];
      size = 16.0;
    };

    # 색상
    colors = {
      focused = { border = "#4c7899"; ... };
      # ...
    };

    # 상태바
    bars = [{
      statusCommand = "${py3status}/bin/py3status -c ${i3status-conf}";
      position = "top";
    }];
  };
};
```

### B. py3status 커스터마이징

**`home/i3.nix:63-107`** - i3status 설정:

```conf
general {
    output_format = i3bar
    colors = true
    color_good = "#859900"
    interval = 1
}

# Emacs 현재 작업 표시
read_file emacs_task {
    format = "Current Task: %content"
    path = "/home/elle/.emacs.d/current-task"
}

cpu_usage {
    format = "CPU: %usage"
}

time {
    format = " %a %h %d  %I:%M "
}

# Emacs Lisp 함수 호출
external_script current_task {
    script_path = '${emacsclient "(elle/org-current-clocked-in-task-message)"}'
    format = 'Task: {output}'
    cache_timeout = 60
}
```

**특징:**
- Emacs와 긴밀한 통합
- `emacsclient --eval`로 Lisp 함수 호출
- org-mode 현재 작업 실시간 표시

### C. dunst 알림 시스템

**`home/i3.nix:309-354`**:

```nix
services.dunst = {
  enable = true;
  settings = {
    global = {
      font = "MesloLGSDZ 24";
      geometry = "600x15-40+40";
      format = ''
        <b>%s</b>
        %b'';
    };

    urgency_low = {
      background = solarized.base03;
      foreground = solarized.base3;
      timeout = 5;
    };
  };
};
```

**키바인딩 통합** (`home/i3.nix:248-255`):
```nix
"${mod}+space" = "exec dunstctl close";           # 현재 알림 닫기
"${mod}+Shift+space" = "exec dunstctl close-all"; # 모든 알림 닫기
"${mod}+grave" = "exec dunstctl history-pop";     # 히스토리에서 복원
"${mod}+period" = "exec dunstctl action";         # 액션 실행
```

---

## 4. 개발 환경 모듈화

### A. 언어별 분리

**`home/development.nix:1-14`**:
```nix
{
  imports = [
    ./development/nix.nix
    ./development/python.nix
    ./development/clojure.nix
    ./development/elisp.nix
    ./development/c.nix
    ./development/shell.nix
    ./development/latex.nix
  ];

  home.packages = [ gh libnotify autoconf aider-chat ];
}
```

### B. Python 환경 예시

**`home/development/python.nix:1-29`**:
```nix
{
  home.packages = with pkgs; [
    black
    isort
    basedpyright

    (python311.withPackages (ps: with ps; [
      ipdb
      ipykernel
      jupyter
      notebook
      jupyterlab
      pandas
      tabulate
      flake8
    ]))
  ];
}
```

**특징:**
- `python.withPackages`로 격리된 환경
- LSP (basedpyright), 포맷터 (black, isort) 포함
- Jupyter 통합

### C. Git 설정

**`home/development.nix:26-53`**:
```nix
programs.git = {
  enable = true;
  package = pkgs.gitFull;
  userEmail = "lnajt4@gmail.com";
  userName = "Elle Najt";

  ignores = [
    "*.sw*"
    ".stack-work-profiling"
    ".projectile"
  ];

  extraConfig = {
    merge.conflictstyle = "diff3";
    rerere.enabled = "true";
  };

  delta = {
    enable = true;
    options = {
      syntax-theme = "Solarized (light)";
      hunk-style = "plain";
    };
  };
};
```

---

## 5. Emacs 중심 워크플로우

### A. Doom Emacs 통합

**`home/emacs.nix:14-17, 51-115`**:

```nix
programs.emacs = {
  enable = true;
  extraPackages = epkgs: [ epkgs.mu4e ];
};

home.packages = [
  aspell
  mu isync offlineimap
  ripgrep fd
  pandoc nodejs_22
  libvterm cmake gnumake

  # Desktop 항목으로 Doom 관리
  (makeDesktopItem {
    name = "Doom Emacs";
    exec = "${emacs}/bin/emacs";
  })

  (makeDesktopItem {
    name = "Sync Doom";
    exec = "kitty doom sync";
  })

  (makeDesktopItem {
    name = "Doctor Doom";
    exec = "kitty doom doctor";
  })

  # 입력 필드 Emacs로 편집
  (writeShellApplication {
    name = "edit-input";
    runtimeInputs = [ xdotool xclip ];
    text = ''
      xdotool key ctrl+a ctrl+c
      xclip -out -selection clipboard > /tmp/EDIT
      emacsclient -c /tmp/EDIT
      xclip -in -selection clipboard < /tmp/EDIT
      xdotool key ctrl+v
    '';
  })
];
```

**특징:**
- Doom Emacs 외부 관리 (home-manager로 의존성만)
- Desktop 항목으로 GUI 통합
- `edit-input`: 웹 양식을 Emacs로 편집

### B. GPG 통합

**`home.nix:127-135`**:
```nix
programs.gpg.enable = true;
services.gpg-agent = {
  enable = true;
  pinentryPackage = pkgs.pinentry-qt;
  enableZshIntegration = true;
  extraConfig = ''
    allow-emacs-pinentry
  '';
};
```

---

## 6. 시스템 레벨 설정

### A. NixOS 최소 구성

**`configuration.nix:56-77`**:
```nix
services.xserver = {
  enable = true;
  windowManager.i3.enable = true;
  dpi = 120;
};

services.displayManager.defaultSession = "none+i3";
services.spice-vdagentd.enable = true;  # VM 통합

users.users.elle = {
  isNormalUser = true;
  extraGroups = [ "wheel" "audio" ];
  shell = pkgs.zsh;
};

programs.zsh.enable = true;
```

**특징:**
- 시스템은 최소한만 설정
- i3 활성화만 하고 설정은 home-manager에 위임

### B. systemd User Services

**`home/computers/etude.nix:31-61`**:

```nix
systemd.user.services.create_xrandr_modes = {
  Unit = {
    Description = "create xrandr modes";
    After = [ "display-manager.service" "graphical.target" ];
  };
  Install = { WantedBy = [ "graphical-session.target" ]; };
  Service = {
    Type = "oneshot";
    ExecStart = "${add-xrandr-modes-script}";
  };
};

systemd.user.services.set_default_resolution_at_startup = {
  Unit = {
    After = [ "create_xrandr_modes" ];
  };
  Service = {
    ExecStart = "${set-default-resolution-script}";
  };
};
```

**특징:**
- xrandr 커스텀 해상도 자동 설정
- VM 환경 최적화 (HiDPI)

---

## 7. 재빌드 워크플로우

### A. rebuild-home 스크립트

**`rebuild-home:1-9`**:
```bash
#!/usr/bin/env bash
set -euo pipefail

cwd=$(pwd)
cd /home/elle/code/nixos-config/
home_activation="$(nix build --no-link --print-out-paths -f . home)"
"$home_activation/activate"
cd "$cwd"
```

### B. rebuild-nixos 스크립트

**`rebuild-nixos:1-10`**:
```bash
#!/usr/bin/env bash
set -euo pipefail

cd /home/elle/code/nixos-config/
system="$(nix build --no-link --print-out-paths -f . system)"
sudo nix-env -p /nix/var/nix/profiles/system --set "$system"
sudo "$system/bin/switch-to-configuration" switch
```

**특징:**
- `default.nix`의 `system`/`home` 타겟 빌드
- `nixos-rebuild` 대신 직접 빌드 + 활성화
- flake 없이도 가능

---

## 8. 특이사항 및 장점

### ✅ 장점

1. **home-manager 중심 구성**
   - i3, emacs, 개발 환경 모두 home-manager로 통합
   - 시스템과 사용자 설정 명확히 분리
   - 단일 사용자 환경에 최적

2. **선언적 i3 설정**
   - `xsession.windowManager.i3.config`로 완전 제어
   - 키바인딩, 색상, 바 모두 Nix로 관리
   - 수동 설정 파일 불필요

3. **py3status로 상태바 커스터마이징**
   - Emacs 현재 작업 실시간 표시
   - `emacsclient --eval`로 Lisp 함수 호출
   - 워크플로우와 긴밀한 통합

4. **언어별 개발 환경 모듈화**
   - `development/{python,rust,clojure,haskell}.nix`
   - 필요한 것만 import
   - 각 언어의 LSP, 포맷터, 패키지 매니저 포함

5. **Emacs 워크플로우 통합**
   - `edit-input`: 웹 양식을 Emacs로 편집
   - GPG pinentry 통합
   - Desktop 항목으로 Doom 관리

6. **systemd User Services 활용**
   - xrandr 자동 설정
   - graphical-session.target 의존성 관리
   - VM 환경 자동 최적화

7. **간단한 rebuild 스크립트**
   - `rebuild-home`, `rebuild-nixos`
   - flake 없이도 재현 가능
   - 초보자 친화적

### ⚠️ 주의사항

1. **단일 호스트 구성**
   - 멀티 호스트 관리에는 구조 확장 필요
   - 프로파일 시스템 없음

2. **niv vs flake**
   - 공식 트렌드와 다름 (flake가 표준화 중)
   - Lock 파일 기능 제한적

3. **Doom Emacs 외부 관리**
   - home-manager로 Doom 자체는 관리 안 함
   - `~/.emacs.d/`, `~/.doom.d/` 수동 관리

---

## 9. 현재 설정과 비교

### 사용자 (junghanacs) vs ElleNajit

| 항목 | junghanacs | ElleNajit |
|------|-----------|-----------|
| **의존성 관리** | Flake | niv |
| **호스트 구성** | 5개 (laptop, storage, gpu×3) | 1개 (etude) |
| **i3 설정** | `~/.config/i3/config` (수동) | `xsession.windowManager.i3` (선언적) |
| **상태바** | i3status (기본) | py3status (Emacs 통합) |
| **개발 환경** | 미분리 | 언어별 모듈 분리 |
| **Emacs** | Doom (외부) | Doom (외부) + desktop 항목 |
| **재빌드** | `nixos-rebuild` | 커스텀 스크립트 |
| **specialization** | i3 / Hyprland | 없음 |
| **compositor** | 없음 | picom (GIF 녹화 시) |

---

## 10. 적용 가능한 패턴

### ✅ 우선순위 높음

1. **home-manager로 i3 선언적 관리**
   - 현재: `~/.config/i3/config` (수동)
   - 개선: `xsession.windowManager.i3.config`
   - 장점: 버전 관리, 재현 가능, 호스트별 변경 용이

2. **py3status 도입**
   - Emacs org-mode 작업 상태 표시
   - CPU, 시간, 커스텀 스크립트 통합
   - `external_script`로 확장 가능

3. **dunst 선언적 설정**
   - `services.dunst.enable = true`
   - 키바인딩 통합 (닫기, 히스토리)
   - Solarized 테마 통일

4. **언어별 개발 환경 분리**
   - `modules/development/{python,rust,nix}.nix`
   - 각 언어의 LSP, 포맷터 포함
   - 필요한 것만 import

5. **systemd User Services 활용**
   - 디스플레이 설정 자동화
   - GPU 호스트의 CUDA 초기화
   - Emacs daemon 관리

### ⚠️ 선택적 적용

6. **rebuild 스크립트**
   - `rebuild-{home,nixos}` 스크립트
   - flake에서는 불필요 (`nixos-rebuild --flake` 충분)

7. **niv 도입**
   - flake 사용 중이므로 불필요

### ❌ 적용 지양

8. **단일 호스트 구조**
   - 사용자는 5개 호스트 관리 필요
   - 현재 specialization 구조 유지

---

## 11. 적용 예시

### A. home-manager i3 설정 마이그레이션

**현재** (`~/.config/i3/config`):
```
set $mod Mod4
bindsym $mod+Return exec ghostty
```

**개선** (`modules/home-manager/i3.nix`):
```nix
xsession.windowManager.i3 = {
  enable = true;
  config = {
    modifier = "Mod4";
    keybindings = {
      "${config.modifier}+Return" = "exec ghostty";
      "${config.modifier}+h" = "focus left";
      # ...
    };
  };
};
```

### B. py3status 통합

**`modules/home-manager/i3.nix`**:
```nix
let
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
    statusCommand = "${pkgs.python3Packages.py3status}/bin/py3status -c ${i3status-conf}";
  }];
}
```

### C. 개발 환경 모듈화

**`modules/home-manager/development/python.nix`**:
```nix
{ pkgs, ... }: {
  home.packages = with pkgs; [
    (python312.withPackages (ps: with ps; [
      ipython
      pytest
      black
      ruff
    ]))
    ruff-lsp
  ];
}
```

**`modules/home-manager/default.nix`**:
```nix
{
  imports = [
    ./i3.nix
    ./emacs.nix
    ./development/python.nix
    ./development/rust.nix
  ];
}
```

---

## 12. 참고 자료

### 주요 파일 위치

- **진입점**: `home.nix`
- **i3 설정**: `home/i3.nix`
- **Emacs**: `home/emacs.nix`
- **개발 환경**: `home/development/*.nix`
- **호스트 설정**: `home/computers/etude.nix`
- **빌드 타겟**: `default.nix`
- **의존성**: `nix/sources.json`

### 학습 포인트

1. **home-manager i3 통합**
   - https://nix-community.github.io/home-manager/options.html#opt-xsession.windowManager.i3.enable

2. **py3status 문서**
   - https://py3status.readthedocs.io/

3. **dunst 설정**
   - https://dunst-project.org/documentation/

4. **systemd User Units**
   - `man systemd.unit`
   - `graphical-session.target`

---

## 13. 결론

ElleNajit의 nixos-config는:
- **home-manager 중심** 구성의 **정석적인 예시**
- **i3 선언적 관리**로 재현 가능성 확보
- **py3status**로 워크플로우 긴밀 통합
- **언어별 개발 환경 모듈화**로 유지보수성 확보

**적용 권장 사항:**
1. ✅ home-manager로 i3 선언적 관리
2. ✅ py3status 도입
3. ✅ dunst 선언적 설정
4. ✅ 언어별 개발 환경 분리
5. ✅ systemd User Services 활용

**현재 구조 유지:**
- Flake 기반 의존성 관리
- 멀티 호스트 specialization
- 프로파일 시스템 (추후 도입 고려)

---

**분석자**: junghanacs
**날짜**: 2025-10-08
**상태**: ✅ 분석 완료
**적용 우선순위**: home-manager i3 설정 → py3status → 개발 환경 모듈화
