# nixos-config AGENTS.md

> **세 문서의 분업** — 이 문서(AGENTS.md)는 *현재 운영 상태*만, [NEXT.md](NEXT.md)는 *앞으로 할 일*만, [ROADMAP.md](ROADMAP.md)는 *어떻게 여기까지 왔는가*(버전·업그레이드·운영 결정 이력)만 답한다.
>
> - 끝나지 않은 일·후속 검증 → **NEXT.md**. 새 작업 마무리 시 끝난 항목은 지우고 새 후속은 추가.
> - 본문에 날짜가 박히기 시작하면 → **ROADMAP.md**로 옮길 때다. AGENTS.md는 "지금 어떤 상태인가"만 유지.
> - NEXT.md의 ✅ 완료 항목이 쌓이면 → ROADMAP.md로 흘려보낸다.

Operator brief for a multi-device NixOS repository across `oracle`, `nuc`, `laptop`, `thinkpad`.

## How to read this

This is not generic NixOS documentation. It is the handbook for the operator (human or agent) working inside this repo today. 이 문서는 **디바이스 공통 baseline**만 담는다. 디바이스별 상세는 필요할 때만 꺼내본다:

| 작업 맥락 | 펼칠 문서 |
|---|---|
| **`oracle` 디바이스 또는 OpenClaw 관련 작업** | [ORACLE.md](ORACLE.md) — ownership, 봇 model routing, env/secret, 업그레이드/restart, skills, 함정 |
| **`thinkpad` 로컬 AI (Ollama)** | [THINKPAD.md](THINKPAD.md) |
| **`nuc` / `laptop` 일반 NixOS 작업** | 이 문서 + 표준 NixOS 흐름 |
| 함정 카탈로그 (OpenClaw) | [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) |
| **봇별 크론/heartbeat — 무엇이 사람 없이 도는가** | [docs/openclaw-automations.md](docs/openclaw-automations.md) — **자동화 SSOT**. 동기화 `./run.sh w)` |

> **핵심 분리 원칙**: nixos-config에서 `oracle`이 아니면 OpenClaw를 볼 필요가 없다. oracle/openclaw 작업이 아니라면 ORACLE.md를 열지 마라 — 이 문서만으로 충분하다.

---

## 1. Identity & entry

### Device profile map

| Profile | Role | 디바이스 핸드북 |
|---|---|---|
| `oracle` | remote cloud VM (aarch64) | OpenClaw runtime lives here; safety-critical → [ORACLE.md](ORACLE.md) |
| `nuc` | home server | real machine, not disposable |
| `laptop` | personal GUI | home-manager GUI matters |
| `thinkpad` | work GUI | home-manager GUI matters; 로컬 AI → [THINKPAD.md](THINKPAD.md) |

device / time은 SessionStart hook이 자동 제공 (`device=` / `time_kst=`). 안 보이면 `cat ~/.current-device` + `TZ='Asia/Seoul' date '+%Y%m%dT%H%M%S'`. Normalization (`run.sh`): `oracle-nixos` → `oracle`; first token before `-` is the flake profile name.

---

## 2. Repo layout & shared operation

### Directory model

```
hosts/           per-device configs
users/junghan/   user configs + home-manager modules
modules/         shared NixOS modules
templates/       VM / infra templates
docs/            documentation
run.sh           operator entrypoint for recurring tasks
```

### run.sh

Shared human+agent operator interface. If a task already has a `run.sh` path, extend it rather than duplicate. Current scope: flake updates, rebuild/switch/rollback, cleanup, Oracle service helpers, OpenClaw tunnel/restart/status/pairing, skill deploy (`k)`). oracle/openclaw helper 상세는 [ORACLE.md](ORACLE.md).

### Workflow preference

Do not use `br`. Use agenda stamps instead. This repo prefers flexible shared flow over rigid tracker workflow.

---

## 2.5 패키지 통제 모델 (3층) — JS/TS 개발 포함

**nix가 전체 통제권을 갖는다.** 버전이 나뉘어도 한 창고에 모으고, 흩어진 복제본을 만들지 않는다.

| 층 | 무엇 | 어디 |
|---|---|---|
| **1 nix store** | nix가 담을 수 있는 전부 (pnpm/node/go/cli…) | system/home-manager 선언 → `/nix/store` (버전 공존·hardlink dedup·GC 중앙 회수) |
| **2 external-packages.sh** | nix가 못 담는 것 (npm 글로벌, 벤더 self-updater, `go install`) | 단일 목록 SSOT → `run.sh E)`. 물리적으론 `~/.local/share/pnpm/bin`·`~/.local/bin`이지만 **선언은 한 곳** |
| **3 per-repo devShell** | 특정 repo가 원하는 특정 버전 | flake + direnv → 그 버전도 **nix store에서** 꺼내씀 |

원칙: **복제 없음 · 한 목록/한 창고 · 중앙 통제.**

**JS/pnpm 개발 규율 (중요)**: `package.json`의 `packageManager:` 핀으로 전역과 싸우지 않는다 — 그건 반(反)-nixos다. 전역 pnpm은 nix 단일(11.x, `manage-package-manager-versions=false` — `users/junghan/modules/shell.nix`). repo가 특정 pnpm을 꼭 원하면 **3층 devShell로 격리**, 아니면 **전역으로 이관**(핀 제거 + CI pnpm 버전 lockstep + lockfile 재생성을 한 커밋으로).

정직한 이음새 둘: (a) 2층은 물리적으로 nix store 밖 — 스크립트 규율로만 강제. (b) CI 버전은 Nix와 별도 SSOT라 수동 lockstep bump 필요.

**PATH 불변식 — 2층이 동작하기 위한 전제**: pnpm은 `global-bin-dir`(`~/.local/share/pnpm/bin`)이 PATH에 없으면 `add -g`·`list -g`를 **전부 거부**한다. 레지스트리/캐시 문제처럼 보이지만 원인은 PATH다. PATH SSOT는 `users/junghan/modules/shell.nix`의 `home.sessionPath` **하나뿐** — **`~/.env.local`(API 키 SSOT)에 `export PATH=`를 박지 않는다.** 거기 박힌 PATH는 화석이 되어 sessionPath를 통째로 덮는다. `scripts/external-packages.sh`가 이 조건을 preflight로 진단한다.

pnpm 11의 글로벌 루트는 `~/.local/share/pnpm/global/v11`이다. pnpm 10 시절의 `global/5`는 pnpm 11에서 보이지 않는다 — 거기 있는 것은 설치된 게 아니라 **화석**이다(`pnpm list -g`가 "No global packages found"라고 하면 이 상황).

---

## 2.6 디스크 정리 — `nix.gc`만으로는 안 줄어든다

정리 로직 SSOT는 **`scripts/diskclean.sh`** (진입점 `run.sh` `c)` safe / `C)` deep). 디바이스 프로파일은 `~/.current-device`로 결정된다 — oracle은 headless + OpenClaw 런타임이라 GC 보존 14일에 휴지통·브라우저·repo 캐시 단계를 건너뛰고, nuc/laptop/thinkpad는 그 반대다.

**자동 GC가 돌고 있어도 store는 줄지 않는다.** 두 가지 이유가 겹친다:

1. **`.direnv`/`result`가 GC root다.** flake input을 붙들고 있으면 `nix.gc`는 그 경로를 영원히 죽은 것으로 못 본다. 그래서 `diskclean.sh deep`은 **repo 빌드 캐시를 0단계로, GC보다 먼저** 지운다 — 순서를 뒤집으면 회수량이 통째로 사라진다.
2. **용량의 대부분이 nix 밖이다.** uv/zig/go-build/브라우저 캐시, 휴지통, `/tmp`, repo `.zig-cache`. `nix.gc`는 이들을 전혀 건드리지 않는다.

**기본 제외 두 가지 (opt-in인 이유)**:
- `--with-pnpm` — pnpm store는 repo `node_modules`와 **하드링크를 공유**한다. 라이브 node/pi 세션 중에는 건드리지 않는다.
- `--with-docker` — oracle에서는 OpenClaw 런타임이다. 스크립트가 실행 중 컨테이너를 보여주고 한 번 더 묻는다.

측정부터 하려면 `scripts/diskclean.sh deep --dry-run` (삭제 없음). 분석만 필요하면 `run.sh d)`.

---

## 3. Commands (공통)

```bash
# device & time — every session
cat ~/.current-device
TZ='Asia/Seoul' date '+%Y%m%dT%H%M%S'

# rebuild current profile
sudo nixos-rebuild switch --flake .#<profile>

# operator menu
./run.sh

# 디스크 정리 (디바이스 프로파일 자동 인식)
./scripts/diskclean.sh deep --dry-run    # 측정만
./scripts/diskclean.sh safe              # 작업 손실 없음
./scripts/diskclean.sh deep --with-docker
```

> oracle/openclaw 명령(live models, restart/recreate, 업그레이드)은 [ORACLE.md](ORACLE.md) §7 Commands.

---

Correctness starts with location awareness. 어느 디바이스에 있는지 먼저 알고, `oracle`이면 그 앎이 봇 생존으로 확장된다 — 그땐 [ORACLE.md](ORACLE.md).

---

담당자 서사(이 리포가 무엇을 선언으로 맡고 무엇을 일부러 선언 밖에 두는가) — botlog `20260615T100659` ([가든](https://notes.junghanacs.com/botlog/20260615T100659)).
