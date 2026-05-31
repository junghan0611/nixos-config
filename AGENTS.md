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

## 3. Commands (공통)

```bash
# device & time — every session
cat ~/.current-device
TZ='Asia/Seoul' date '+%Y%m%dT%H%M%S'

# rebuild current profile
sudo nixos-rebuild switch --flake .#<profile>

# operator menu
./run.sh
```

> oracle/openclaw 명령(live models, restart/recreate, 업그레이드)은 [ORACLE.md](ORACLE.md) §7 Commands.

---

Correctness starts with location awareness. 어느 디바이스에 있는지 먼저 알고, `oracle`이면 그 앎이 봇 생존으로 확장된다 — 그땐 [ORACLE.md](ORACLE.md).
