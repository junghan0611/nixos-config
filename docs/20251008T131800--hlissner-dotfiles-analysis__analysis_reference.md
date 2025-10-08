# hlissner dotfiles 분석

**분석 대상**: https://github.com/hlissner/dotfiles
**분석 일자**: 2025-10-08
**목적**: Doom Emacs maintainer의 NixOS 설정 구조 파악 및 적용 가능한 패턴 탐색

---

## 1. 전체 구조 개요

### 핵심 철학
- **Nix의 선언적 설정** + **Janet 스크립트의 유연한 관리 도구** 결합
- NixOS 기본 도구의 복잡성을 단일 CLI(`hey`)로 통합

### 디렉토리 구조

```
hlissner-dotfiles/
├── flake.nix              # 플레이크 진입점
├── default.nix            # 공통 모듈 설정
├── bin/
│   └── hey                # Janet 기반 통합 CLI (핵심!)
│   └── hey.d/             # hey 서브커맨드 (Janet)
├── lib/
│   ├── *.nix              # Nix 헬퍼 함수
│   └── hey/               # Janet 라이브러리
├── modules/               # 기능별 NixOS 모듈
│   ├── desktop/           # WM, 앱, 브라우저, 미디어, 터미널
│   ├── dev/               # 개발 환경 (언어별)
│   ├── editors/           # Emacs, Vim
│   ├── profiles/          # role, hardware, network, user
│   ├── services/          # 시스템 서비스
│   ├── shell/             # Shell 도구
│   ├── themes/            # 테마 시스템
│   └── virt/              # 가상화
├── hosts/                 # 호스트별 설정
│   ├── harusame/
│   ├── ramen/
│   └── udon/
├── config/                # 앱 설정 파일 (home-manager 관리 외)
├── packages/              # 커스텀 패키지
└── overlays/              # Nixpkgs 오버레이
```

---

## 2. Janet 스크립트 역할

### 왜 Janet을 선택했나?

NixOS 도구들(`nixos-rebuild`, `nix-collect-garbage`, `nix-env`, `nix-shell` 등)의 분산된 인터페이스를 **단일 CLI로 통합**하기 위함. Guix의 직관적인 CLI를 부러워하며 제작.

### `bin/hey` 핵심 기능

```bash
# 통합 CLI
hey sync       # nixos-rebuild 래퍼
hey gc         # 가비지 컬렉션
hey pull       # flake 업데이트
hey profile    # 프로파일 관리
hey reload     # 설정 리로드
hey build      # 빌드
hey repl       # REPL 실행
```

### Janet의 역할

1. **동적 디스패처** (`lib/hey/cmd.janet:122-233`)
   - 명령어를 패턴 매칭으로 자동 라우팅
   - ZSH, Janet, 바이너리 스크립트를 투명하게 실행
   - 컨텍스트별 경로 자동 해결:
     ```
     $DOTFILES_HOME/bin
     $DOTFILES_HOME/hosts/$HOST/bin
     $DOTFILES_HOME/config/$WM/bin
     ```

2. **상태 관리** (`bin/hey.d/vars.janet`)
   - JSON 기반 변수 저장소
   - 세션/영속 상태 구분

3. **커맨드 함수** (`lib/hey/cmd.janet`)
   - `cmdfn` 매크로로 CLI 인터페이스 정의
   - 옵션 파싱 자동화
   - 드라이런, 디버그 모드 지원

4. **Rofi 통합** (`config/rofi/bin/*.janet`)
   - 동적 메뉴 생성 (Wi-Fi, 오디오, 마운트, 북마크 등)
   - `rofi-blocks` 라이브러리 활용

### 컴파일 최적화

Janet 스크립트를 **네이티브 바이너리로 컴파일** (`modules/hey.nix:59-66`):
```nix
system.userActivationScripts.initHey = ''
  jpm deps         # 의존성 설치
  jpm run deploy   # 컴파일 및 배포
'';
```
- 시작 속도 최적화 (스크립트 언어 오버헤드 제거)

---

## 3. NixOS 구성 패턴

### A. 모듈 자동 로딩

**핵심**: `mapModulesRec'` 함수로 모듈 디렉토리를 재귀 스캔

```nix
# default.nix:8
imports = mapModulesRec' ./modules import;
```

**동작 방식** (`lib/modules.nix:43-58`):
- 디렉토리 재귀 탐색
- `.nix` 파일 자동 임포트
- **제외 규칙**:
  - `_`로 시작하는 파일/디렉토리
  - `.noload` 파일이 있는 디렉토리
  - `default.nix`, `flake.nix`

**장점**:
- 모듈 추가 시 수동 import 불필요
- 구조만 맞추면 자동 인식

### B. 프로파일 기반 구성

```
modules/profiles/
├── role/          # workstation, server, vm
├── hardware/      # cpu/amd, cpu/intel, gpu/nvidia, audio, ssd, bluetooth 등
├── network/       # ca, dk, wg0
├── platform/      # linode
└── user/          # hlissner
```

**호스트 설정 예시** (`hosts/udon/default.nix:14-27`):
```nix
profiles = {
  role = "workstation";
  user = "hlissner";
  networks = [ "ca" ];
  hardware = [
    "cpu/amd"
    "gpu/nvidia"
    "audio"
    "audio/realtime"
    "ssd"
    "ergodox"
    "bluetooth"
  ];
};
```

**믹스앤매치 방식**:
- Role + Hardware + Network 조합
- 호스트별 설정 최소화
- 재사용성 극대화

### C. 옵션 체계

**네임스페이스 통일** (`modules.*`):
```nix
modules = {
  desktop.hyprland.enable = true;
  desktop.term.foot.enable = true;
  editors.emacs.enable = true;
  shell.zsh.enable = true;
  dev.cc.enable = true;
};
```

**사용자 추상화** (`default.nix:14`):
```nix
user = mkOpt attrs { name = ""; };
users.users.${config.user.name} = mkAliasDefinitions options.user;
```
- `config.user.*`로 간결하게 접근

### D. Hook 시스템

이벤트 기반 스크립트 실행 (`modules/hey.nix:77-100`):
```nix
hey.hooks = {
  reload = {
    "emacs" = ''
      systemctl --user restart emacs
    '';
  };
};
```

생성 경로: `~/.local/share/hey/hooks.d/{event}.d/{priority}-{name}`

### E. Flake 구조

**최상위 flake.nix** (`flake.nix:37-59`):
```nix
outputs = inputs @ { self, nixpkgs, ... }:
  let lib = import ./lib args;
  in mkFlake inputs {
    systems = [ "x86_64-linux" "aarch64-linux" ];
    hosts = mapHosts ./hosts;
    modules.default = import ./.;
    apps.install = mkApp ./install.zsh;
    devShells.default = import ./shell.nix;
    checks = mapModules ./test import;
    overlays = mapModules ./overlays import;
    packages = mapModules ./packages import;
  };
```

**커스텀 lib 함수**로 반복 제거 (`lib/default.nix:41-51`):
- `mapModules`, `mapModulesRec`, `mapHosts`
- callPackage 패턴으로 의존성 자동 주입

---

## 4. 특이사항 및 장점

### ✅ 장점

1. **통합 관리 도구**
   - Janet CLI(`hey`)로 모든 NixOS 작업 단일화
   - 직관적인 명령어 체계 (vs. Nix 기본 도구)
   - dry-run, debug 모드 내장

2. **동적 모듈 시스템**
   - `mapModulesRec'`로 파일 추가만 하면 자동 로드
   - 모듈 의존성 자동 해결 (callPackage 패턴)

3. **프로파일 조합**
   - Role + Hardware + Network 믹스앤매치
   - 호스트별 설정 최소화
   - 새 머신 추가 시 조합만 변경

4. **성능 최적화**
   - Janet 스크립트 컴파일 → 네이티브 바이너리
   - 빠른 CLI 응답속도

5. **일관된 구조**
   - 모든 모듈이 `modules.*` 네임스페이스 사용
   - enable 패턴 통일

6. **확장성**
   - 새 모듈 추가 시 자동 인식
   - Hook 시스템으로 커스텀 로직 주입

### ⚠️ 주의사항

1. **학습 곡선**
   - Janet 언어 추가 학습 필요
   - 커스텀 추상화 레이어 이해 필요
   - README에 "over-engineered hackery" 명시

2. **복잡성**
   - 일반 사용자에게 비추천
   - 커뮤니티 프레임워크 아님 (개인 실험)

3. **유지보수**
   - Janet 의존성 관리 (`project.janet`)
   - 업스트림 Nix 변경에 추가 대응 필요

4. **문서화**
   - 공식 문서 부족 (README와 코드 주석만)
   - 사용자는 스스로 코드 분석 필요

---

## 5. 적용 가능한 패턴

### 당신의 nixos-config에 적용할 만한 것

#### ✅ 우선순위 높음

1. **모듈 자동 로딩** (`lib/modules.nix`)
   - 복잡도: 낮음
   - 효과: 큼
   - `mapModulesRec'` 함수 도입
   - `imports = mapModulesRec' ./modules import;`

2. **프로파일 시스템** (`modules/profiles/`)
   - 복잡도: 중간
   - 효과: 큼 (호스트 5개 관리에 유용)
   - 구조:
     ```
     profiles/
     ├── role/       # laptop, server
     ├── hardware/   # audio, bluetooth, cpu, gpu
     └── network/    # work, home
     ```

3. **호스트 분리** (`hosts/`)
   - 복잡도: 낮음
   - 효과: 중간
   - 각 호스트별 디렉토리 생성
   - `default.nix`에 프로파일 조합만 명시

#### ⚠️ 선택적 적용

4. **통합 CLI**
   - Janet 대신 **ZSH 스크립트**로 대체 가능
   - `bin/mynix` 같은 래퍼 스크립트
   - 장점: Janet 학습 부담 없음
   - 단점: 컴파일 최적화 불가

5. **Hook 시스템**
   - systemd activation scripts 활용
   - `system.userActivationScripts.*`
   - 재빌드 시 자동 실행되는 스크립트

6. **커스텀 lib 함수**
   - `lib/attrs.nix`, `lib/options.nix` 등
   - 반복 작업 헬퍼 함수화

#### ❌ 적용 보류

7. **Janet 생태계**
   - 학습 비용 대비 효용 낮음
   - 기존 Bash/ZSH로 충분

---

## 6. 참고 자료

### hlissner의 README FAQ

**Q: Should I use NixOS?**
> Short answer: no.
> Long answer: no really. Don't.

**왜 안 된다는가?**
- 학습 곡선 매우 가파름
- 문서화 부족 (공식 문서는 방대하지만 얕음)
- Nix 언어 난해함
- 3대 미만 시스템은 오버헤드 > 이득

**그럼에도 사용하는 이유:**
- 100대 이상 서버 관리에는 필수
- 선언적, 세대별, 불변 설정의 매력
- 롤백 가능, 재현 가능

### 주요 파일 위치

- **flake 진입점**: `flake.nix`
- **모듈 로더**: `lib/modules.nix`
- **hey CLI**: `bin/hey` (Janet)
- **hey 서브커맨드**: `bin/hey.d/*.janet`
- **모듈 디렉토리**: `modules/`
- **호스트 설정**: `hosts/*/default.nix`
- **프로파일**: `modules/profiles/`

---

## 7. 결론

hlissner의 dotfiles는:
- **고급 사용자**를 위한 **실험적 구성**
- **Janet 기반 CLI**로 NixOS 도구 통합
- **모듈 자동 로딩** + **프로파일 시스템**으로 유지보수성 확보

**적용 권장 사항:**
1. 모듈 자동 로딩 (`mapModulesRec'`)
2. 프로파일 시스템 (role/hardware/network)
3. 호스트 분리 구조
4. (선택) ZSH 기반 통합 CLI

**적용 지양 사항:**
- Janet 생태계 전체 도입
- 과도한 추상화

---

**분석자**: junghanacs
**날짜**: 2025-10-08
**상태**: ✅ 분석 완료
