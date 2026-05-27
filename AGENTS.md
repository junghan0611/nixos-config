# nixos-config AGENTS.md

> **Next steps live in [NEXT.md](NEXT.md).** 끝나지 않은 일과 후속 검증 항목은 항상 그쪽에 둔다 — 이 문서는 *현재 운영 상태*, NEXT.md는 *앞으로 할 일*. 새 작업 마무리 시 끝나지 않은 후속이 있으면 NEXT.md에 추가하고 끝난 항목은 지운다.

Operator brief for a multi-device NixOS repository across `oracle`, `nuc`, `laptop`, `thinkpad`.

## How to read this

This is not generic NixOS documentation. It is the handbook for the operator (human or agent) working inside this repo today.

Read in order:

1. **Identity & entry** — know your machine, know your time.
2. **Ownership model** — what lives here vs `~/openclaw/`, and why.
3. **Runtime shape** — the current OpenClaw bot deployment on oracle.
4. **Env / secret SSOT** — how keys flow host → container, how to avoid budget bombs.
5. **Operational workflow** — change / upgrade / validate / commit patterns.
6. **Skills deployment** — how pi-skills reach bot workspaces.
7. **Gotchas** — documented pitfalls to avoid repeating.
8. **Commands** — minimal reference.

When a workflow mistake recurs, record it under Gotchas so the next session does not repeat it. Operational retrieval mistakes count too (e.g. OpenClaw release tags need a `v` prefix).

---

## 1. Identity & entry

### Device profile map

| Profile | Role | Notes |
|---|---|---|
| `oracle` | remote cloud VM (aarch64) | OpenClaw runtime lives here; safety-critical |
| `nuc` | home server | real machine, not disposable |
| `laptop` | personal GUI | home-manager GUI matters |
| `thinkpad` | work GUI | home-manager GUI matters |

### Mandatory first step

```bash
cat ~/.current-device
TZ='Asia/Seoul' date '+%Y%m%dT%H%M%S'
```

Do this even if the session hook already reported the values. Wrong host assumptions are costly here. Normalization (`run.sh`): `oracle-nixos` → `oracle`; first token before `-` is the flake profile name.

### ThinkPad local AI policy

- **Ollama Vulkan은 보존하되 자동 시작 비활성** (2026-05-21). 현재 로컬 임베딩을 상시 사용하지 않으므로 boot에 올리지 않는다.
- `services.ollama.enable = true`는 유지해 package/service를 남기고, `systemd.services.ollama.wantedBy = lib.mkForce []`로 multi-user auto-start만 막는다.
- 필요할 때 `sudo systemctl start ollama`로 수동 시작.
- Vulkan via Mesa RADV (AMD Radeon 780M); package auto-selected by `services.ollama.acceleration = "vulkan"`.
- Recommended model: `qwen3-embedding:4b` (2560-dim, andenken과 동일 차원).
- `OLLAMA_KEEP_ALIVE=10m` — idle 시 VRAM 자동 해제.
- History: 04-15 추가 → 04-17 revert (always-on 정책) → 05-07 재도입 (세션 임베딩 워크로드 증가) → 05-21 자동 시작 비활성.

### Oracle is different

Oracle is a lean cloud runtime dedicated to keeping OpenClaw alive. Treat Oracle work as service reliability work. Real users depend on it including family members who cannot recover from config mistakes manually. Storage is limited — prioritize OpenClaw continuity, clean old generations, be conservative with disk growth.

---

## 2. Ownership model

### Repos in the orbit

| Repo | Path | Role |
|---|---|---|
| Private runtime SSOT | `~/openclaw/` | live `openclaw.json`, auth state, workspaces, runtime Docker files |
| Public operator / backup (this) | `~/repos/gh/nixos-config/` | Dockerfile / compose backups, host NixOS context, this brief — **mother repo** |
| Public companion | `~/repos/gh/openglg-config/` | portable service stack (Caddy/Authelia/Postgres/...) + portable home-manager (`home/`) that lands on any Debian/Ubuntu host without NixOS |

Live truth lives in `~/openclaw/`. Public backup / reference lives here. Never leak secrets or auth state into this repo. Do not assume the public copy is live, and do not assume the live copy is publishable.

**Companion boundary (openglg-config)**: anything that must run on a non-NixOS host (cloud VPS, AVF VM, foreign machine) belongs in `openglg-config`. Anything tied to the NixOS host itself (kernel, system services, system home-manager, hardware) belongs here. Do not duplicate state across the two — pick one home for each setting.

### What lives where

| Item | Runtime SSOT | Public repo |
|---|---|---|
| `openclaw.json` | `~/openclaw/config/openclaw.json` | never commit |
| `.env` / secrets | `~/openclaw/.env` | never commit |
| Dockerfile | `~/openclaw/Dockerfile` | `docker/openclaw/Dockerfile` backup |
| compose file | `~/openclaw/docker-compose.yml` | `docker/openclaw/docker-compose.yml` backup |
| operational docs | `~/openclaw/README.md` | summarized guidance here |

### Why nixos-config owns openclaw operations

OpenClaw upstream is a 1-person project (steipete). Documentation left there does not survive. This repo owns the Oracle machine end-to-end — disk, security, service health, budget incident prevention — so the host-container boundary is stated here:

- Host stays hard; Docker is a replaceable runtime.
- Budget incidents (past 100k KRW Gemini embedding bomb) are blocked at the host key lifecycle, not inside the container.
- Container state can always be nuked via `--force-recreate`; SSOT paths stay clear.
- Real operational failures get recorded under Gotchas so the next agent does not repeat them.

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

Shared human+agent operator interface. If a task already has a `run.sh` path, extend it rather than duplicate. Current scope: flake updates, rebuild/switch/rollback, cleanup, Oracle service helpers, OpenClaw tunnel/restart/status/pairing, skill deploy (`k)`).

### ACP route — pi-shell-acp plugin position

bbot / gemini는 OpenClaw 안에서 [`pi-shell-acp`](https://github.com/junghan0611/pi-shell-acp) OpenClaw plugin을 통해 ACP child로 돈다. 운영 사실 (모델/streaming/active-memory)은 §3 model routing 표에 박혀있고, architectural stance는 다음:

- **Backend 자치권**: pi backend가 자기 session / ACP wire / prompt assembly를 자기 책임으로 갖는다. OpenClaw native Codex가 base/personality를 갖는 패턴 (5.19 L33)과 같은 모양.
- **OpenClaw 책임 범위**: runtime context + delivery guidance + tool surface만 contribute. visible body / final-message recovery / chat-completion tail sanitization 같은 plugin-boundary 책임은 pi-shell-acp 자체 plugin code가 진다 (issue #17 / #20 audit 영역).
- **`@openclaw/acpx`와의 차이**: acpx는 OpenClaw가 만든 ACP harness (legacy, 5.2 외부화)로 우리는 disabled (`plugins.entries.acpx.enabled=false`). pi-shell-acp는 third-party native plugin path — OpenClaw plugin SDK 위에서 자체 ACP child spawn. acpx에 의존 0.
- **운영 함의**: OpenClaw 업그레이드의 ACP/Codex 영역 fix layer는 일반 Agents/ACP child handling 자리만 우리에게 spill-over. plugin code 책임 자리는 pi-shell-acp commit chain으로 추적 (e7eefeb / 8b25c1e / cc0c033 등).

### Workflow preference

Do not use `br`. Use agenda stamps instead. This repo prefers flexible shared flow over rigid tracker workflow.

---

## 3. Runtime shape (Oracle / OpenClaw)

### Workspace mapping

- `workspace/` → main
- `workspace-glg/` → glg (힣봇)
- `workspace-gpt/` → gpt
- `workspace-gemini/` → gemini
- `workspace-mini/` → mini
- `workspace-bbot/` → bbot

Invariants: main uses `workspace/` (not `workspace-main/`); `workspace-bbot/` is a split-out B workspace.

### Model routing (OpenClaw 2026.5.22 baseline, 2026-05-26 갱신 — main `claude-cli/sonnet-4-6` 전환)

**LLM 호출 — 분기 (2026-05-26)**:
- **main**: Anthropic Max via `claude-cli` (Claude Code CLI spawn, `default_claude_max_20x` rate tier)
- **glg / gpt**: Codex OAuth ($100 plan)
- **mini**: Codex OAuth, but **직접 대화 X** — active-memory 영역 보조 lane으로 격리 (운영 정책 2026-05-26)
- **bbot / gemini**: pi-shell-acp ACP route (별도 §4)

Anthropic flat-rate / Copilot 양쪽 다 안 씀. Copilot 잔재(`gemini` agent)는 **삭제 예정**.

**Fallback 정공법 (2026-05-26)**: 모든 봇 `fallbacks: []` 비움. `agents.defaults.model.fallbacks: []` 포함. 정공법은 **안 되면 안 되는 거 — 응답 막히면 모델 자체를 바꾼다**. Codex sidecar stuck / extra usage 소진 등으로 다른 path로 자동 fallback (quota inflation / 다른 path 소진 연쇄) 차단. 5.12 baseline의 `fallbacks: ["openai/gpt-5.4"]` 명시 정책 폐기.

**5.12 model ID 정규화 — 정공법 (2026-05-15)**: `openai-codex/*` provider/model이 5.12에서 deprecate. 새 형식은 `openai/*` + `agentRuntime.id="codex"` marker. 즉 model ID는 OpenAI catalog로 통합되고, 어떤 OAuth path로 라우트할지는 별도 marker로 표시. 호스트 `codex login`으로 받은 OAuth profile은 그대로 보존되고 (`auth.profiles."openai-codex:junghanacs@gmail.com"` 키 이름 그대로), agentRuntime marker가 새 model ID와 기존 profile을 매핑. **재로그인 불필요**.

**적용 절차**:
1. `openclaw doctor --fix --force --yes --non-interactive` (in-container) — `agents.{defaults,list[]}.model` rename + 모든 `models.openai/gpt-X` 항목에 `agentRuntime.{id: "codex"}` marker 추가. atomic, 65 paths, backup 자동 생성.
2. doctor가 **놓치는 곳**:
   - per-agent `agents.list[].model`이 bare string으로 남음 → strict 검증 잡힘 ("a bare string with no fallbacks ... clobbers defaults"). 수동으로 `{primary, fallbacks}` object로 변환 필요.
   - nested plugin config (예: `plugins.entries.active-memory.config.model`)는 doctor 미발견. 수동 patch 필요.

**Fallback chain (5.12 신규)**: `agents.defaults.model.fallbacks: ["openai/gpt-5.4"]` + per-agent `agents.list[].model.fallbacks: ["openai/gpt-5.4"]` 명시. 5.12에서 default fallbacks는 per-agent에서 자동 inherit 안 됨 (clobber). 5.5(main/gpt) 봇은 5.4로 자동 fallback. 5.4 봇(glg/bbot)은 fallback도 5.4라 실효 없지만 글로벌 일관성 유지. mini는 primary 5.4-mini라 fallback이 5.4로 떨어지면 quota inflation (0.29x→1.0x) — 단 같은 OAuth 계정 quota 소진 시엔 5.4도 같이 막혀 실효 미미. gemini는 Copilot 별도 라우트라 `fallbacks: []`.

**OAuth profile secret key (5.12 신규 보안)**: 5.12에서 OAuth profile credential을 disk에 plain JSON으로 두지 않고 AES 암호화. 암호화 key는 stateDir(`~/.openclaw`) **외부**에 보관 (state backup/sync에 secret이 같이 끌려가지 않게). XDG 표준 경로 `$HOME/.config/openclaw/auth-profile-secret-key`. **Docker 추가 mount 필수**: `./auth-profile-secrets:/home/node/.config/openclaw`. 누락 시 doctor가 "OAuth profile secret key source is required to persist OAuth profile secrets" 에러를 내고 codex harness 등록 실패 → 모든 OAuth 봇 응답 불가. host의 secret key file은 별도 안전 백업 필요 — 분실 시 모든 OAuth profile 재로그인.

**plugins.allow 정공법 (5.12 codex 외부화)**: 5.12에서 codex가 `@openclaw/codex` 별도 plugin으로 외부화. `plugins.allow`가 빈 상태면 "non-bundled plugins may auto-load" WARN. 정공법은 사용 plugin 전체 명시: `["telegram","perplexity","google","anthropic","openai","github-copilot","active-memory","memory-core","deepseek","codex","browser","canvas","device-pair","file-transfer","phone-control","talk-voice"]`. **함정**: `["codex"]`만 박으면 명시 안 한 bundled (active-memory, telegram, file-transfer 등) 모두 disabled되어 봇 polling/응답 깨짐.

**Live model IDs** (provider 접두사: `openai/*`+`agentRuntime.id=codex` = Codex OAuth, `claude-cli/*` = Claude Code CLI spawn, `pi-shell-acp/*` = ACP route):

| Agent | Model | Workspace | Streaming | Active memory | 비고 |
|---|---|---|---|---|---|
| **main** | **`claude-cli/claude-opus-4-7`** | `workspace/` | off | ✓ | `@junghan_openclaw_bot`. **2026-05-26 opus 승급** (sonnet 검증 OK 후). Max 20x rate tier, 1M context |
| glg (가족) | `openai/gpt-5.4` | `workspace-glg/` | partial | ✓ | `@glg_junghanacs_bot`. Codex OAuth |
| gpt | `openai/gpt-5.5` | `workspace-gpt/` | partial | ✓ | 개인 — 5.5 단일 봇 트라이얼 (2026-05-09~) |
| **bbot** | **`pi-shell-acp/claude-opus-4-7`** | `workspace-bbot/` | **off** | **✓** (2026-05-16 추가) | `@glg_b_bot`. ACP route via pi-shell-acp 0.6.0-prerelease + plugins/openclaw. **claude-cli 검증 완료 후 native 전환 후보** (third-party harness 식별 회피) |
| **mini** | **`claude-cli/claude-sonnet-4-6`** | `workspace-mini/` | off | — | **2026-05-26 검증 lane** — sonnet 4.6 단독 동작. active-memory 빠진 baseline (대화 응답 깨끗) |
| **gemini** | **`pi-shell-acp/gemini-3.1-pro-preview`** | `workspace-gemini/` | partial (테스트) | — | `@glg_gemini_bot`. ACP route, Gemini CLI backend. claude-cli 전환 검토 후순위 |
| subagents | `openai/gpt-5.4` | — | — | — | |

> **claude-cli provider (2026-05-26 추가, 5.22 갱신)**: OpenClaw native first-class Claude path. Codex와 짝. **5.20까지** `@anthropic-ai/claude-agent-sdk` v0.3.143 (SDK + 번들 `claude` binary) 자동 install. **5.22부터** raw `@anthropic-ai/sdk@0.97.1` (API client만)로 슬림화 — `claude` binary 별도 install 필요 (`npm i -g @anthropic-ai/claude-code` Dockerfile RUN 단계). 실제 invocation은 `claude -p` 자체 (`--input-format stream-json --output-format stream-json --session-id <id> [--resume]` + `--permission-prompt-tool stdio` + `--verbose`). 세션 jsonl은 `~/.claude/projects/-<cwd-encoded>/<session-id>.jsonl` — 호스트 `~/.claude/projects/`와 컨테이너 `/home/node/.claude/projects/`가 mount 공유라 호스트 Claude Code 세션과 동일 디렉토리에 섞임 (sub-dir로 격리). OAuth는 `/home/node/.claude/.credentials.json`의 `claudeAiOauth` (refresh_token 자동 갱신). **결제 분리의 핵심**: pi-shell-acp가 같은 SDK를 wrap하면 Anthropic이 **third-party harness 식별** → extra usage 풀로 강제 (2026-05-26 KST pi 테스트: `400 You're out of extra usage`). OpenClaw native claude-cli는 same SDK를 direct import → **Pro/Max 한도로 인식** (자기인식 응답: "Anthropic의 공식 CLI 도구인 Claude Code 환경에서 작동 중", `rate_limit_event.isUsingOverage=false` + `overageStatus=rejected overageDisabledReason=org_level_disabled` 검증). 같은 SDK라도 import 깊이 한 단계 차이로 결제 풀이 달라지는 자리.
>
> **EPIPE 회피 (2026-05-26)**: 5.22 image는 `claude` binary 안 들고 옴. `command:"claude"` (dist/cli-backend-CO2SZJAY.js)가 PATH에서 못 찾으면 child 4ms 만에 exit → parent stdin EPIPE → "⚠️ Agent failed before reply". Dockerfile에 `@anthropic-ai/claude-code` 명시. → 자세한 incident는 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md).
>
> **Streaming policy 확장 (2026-05-26)**: `claude-cli` 라우트 봇도 **streaming=off 권장** — pi-shell-acp 5-16 incident 동일 패턴 (partial mode editMessageText 사이클이 active-memory diagnostic 메시지로 본문 회귀해 답변이 "보였다 사라짐"). `channels.telegram.accounts.{default,mini}.streaming.mode: off` 박음 (bbot 패턴 일관). final 1회 flush.
>
> **1M context (2026-05-26 발견)**: Claude Code 환경 (`claude-cli` provider)에선 sonnet 4.6 / opus 4.7 모두 **1M context로 잡힘** (`/status` "Context: 159k/1.0m" 검증). third-party API 직접 호출 시 200k와 대조. 즉 native claude-cli path가 결제 풀(Pro/Max 한도) + capability(1M ctx) 둘 다 third-party와 다른 자리. 큰 context 작업이 sub-agent rotate 없이 한 turn에 들어감 — Codex 라우트 200k 한도와 본질적 차이.
>
> **Workspace-aware skills (2026-05-26 검증)**: default 봇 turn이 자기 workspace (`/home/node/.openclaw/workspace/`) 안의 skills를 자체 호출. 즉 workspace-local skill 동작 정상 — claude code SDK가 workspace cwd를 root로 보고 skill discovery 진행. `~/.pi/agent/claude-plugin/skills/*` 같은 외부 mount 의존 없음.
>
> **verboseDefault full (2026-05-27)**: `agents.defaults.verboseDefault: "full"` 전역 박음. 모든 봇 새 session 시작 시 full verbose 기본 (active-memory diagnostic / sub-agent trace / provider detail 등이 텔레그램에 표시되어 운영자가 봇 내부 동작 검토 가능). 파일 변경 감지는 되었지만 hot reload 적용 로그가 애매했던 적이 있어, 이 값 변경 후에는 gateway restart로 확정 적용한다. 봇별 `/verbose off`로 session-level 토글 가능.
>
> **Tool-trace inline 해소 (2026-05-16)**: `~/.pi/agent/settings.json` 의 `piShellAcpProvider.showToolNotifications: true → false` 한 줄로 정착. 이전엔 pi backend가 final assistant text 안에 `[tool:start] Skill / [tool:done] Read File — ...` 같은 trace를 inline string으로 박았는데 (plugin `fa3b8f7` block-type filter는 통과 — 단일 `text` block 내부 inline이라 strip 불가), pi-CLI의 child가 매 turn spawn 시 settings 새로 읽는 구조라 gateway restart 없이 즉시 적용됨. workspace-local 새 파일 만들 필요 없음 — 글로벌 한 줄로 충분.
>
> **Streaming policy (2026-05-16)**: pi-shell-acp 라우트 봇은 **streaming=off 권장 기본값**. 이유: partial mode는 editMessageText 사이클이 mid-stream wrong-final 회귀 시점에 본문을 짧은 metadata로 replace해 UX 회귀 (2026-05-16 04:01 incident). off는 final 1회 flush라 plugin `fa3b8f7` role/abnormal guard와 잘 합치고 디버그도 쉽다. gemini는 turn 검증 중이라 partial 유지 — 검증 완료 후 off로 전환.
>
> **Active-memory ACP path 호환성 (2026-05-16)**: bbot 추가는 fa3b8f7 (user-role echo로의 final flip 차단 가드) 적용 후 안전성 확보. recall sub-agent는 별도 `openai/gpt-5.4-mini` lane으로 OAuth quota 격리. 메인 lane(pi-shell-acp/opus-4-7)과 충돌 없음.

보조 모델 (`/model <id>`로 in-thread 전환):

- `openai/gpt-5.5-pro` (977k 컨텍스트, pro tier — quota/속도 미검증)
- `deepseek/deepseek-v4-pro` / `deepseek-v4-flash` (`DEEPSEEK_API_KEY` 회사 quota, 2026-04-27~)

> 운영 컨텍스트 메모: catalog 표기가 `266k/1025k` 같은 "이론치/확장치"로 보여도 라이브 `/status`는 보통 200k로 잡힌다. 5.4 vs 5.5 컨텍스트 트레이드오프는 사실상 없음.

> Codex Plus ($100/mo) 메시지당 크레딧 (출처: developers.openai.com/codex/pricing): `5.4-mini` 2 / `5.4` 7 / `5.5` 14. 즉 **5.4-mini=0.29x, 5.5=2.0x** of 5.4. 우리 배치 원칙: 가벼운 turn은 5.4-mini, 가족/일반은 5.4, 신형 트라이얼은 5.5(gpt 봇 단독). active-memory recall lane은 항상 5.4-mini로 분리해 main lane quota 보호.

이미지 생성: `openai/gpt-image-2` via Codex OAuth (default since 2026-04-25). Google Imagen은 agent-directed 호출 시 사용 가능 (`GEMINI_API_KEY`로 banana/`gemini-3-flash-preview-image`).

ACPX disabled (`plugins.entries.acpx.enabled=false` + `acp.enabled=false`, 5.2가 `@openclaw/acpx` beta로 externalize). 재활성 절차는 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md).

5.7 업그레이드 (2026-05-08 두 번째): Codex OAuth 라우트 보존 (5.5 doctor rewrite 버그는 5.6에서 revert). `agent model: openai-codex/gpt-5.4` 그대로. ready 5.7s, 6 텔레그램 봇 정상 기동.

5.12 업그레이드 (2026-05-15): codex provider 외부화 + model ID 정규화 + OAuth profile 암호화 + plugins.allow 명시 — 위 정공법 4종 모두 적용. ready 8.8s, 10 plugins (5.7의 9 + codex), 6봇 polling 정상 기동. Telegram isolated polling 6 spool dir로 분리 (`/home/node/.openclaw/telegram/ingress-spool-{default,glg,gpt,gemini,mini,bbot}`) — 5.12 신규 "isolated polling, durable local spooling" 기능. memory streaming RSS 252→27 MiB, peak 부하 감소. memorySearch (`qwen3-embedding-8b` via OpenRouter, 4096d) 한글 query 정상 매칭 검증 완료. **Trip-up**: 첫 boot 후 default 봇 `getMe` fetch-timeout 1건 발생 → isolated polling cycle stuck → restart로 해소. 5.12 isolated polling은 일시적 timeout에 polling thread를 죽일 수 있어 boot 직후 fetch-timeout 발생 시 즉시 restart 필요 (per-account isolated restart는 CLI 옵션 없음).

라이브 값 확인:

```bash
python3 - <<'PY'
import json, pathlib
c = json.loads(pathlib.Path('~/openclaw/config/openclaw.json').expanduser().read_text())
for a in c.get('agents', {}).get('list', []):
    print(a.get('id'), a.get('model'))
PY
```

### Active memory — main/glg/gpt/bbot (bbot 2026-05-16 추가)

5.7+8B baseline에서 gpt 단독으로 24h 관찰 (2026-05-08 17:58 KST 시작) → 2026-05-09 12:59 KST main/glg/mini 추가 → 15:55 KST mini 제외 (mini는 5.4-mini로 되돌리고 active-memory도 빠짐 — 가벼운/빠른 turn 용도라 5–10s recall latency도 비용 0.29x→1.0x→2.0x 같은 인플레이션도 안 어울림). 그 시점 gemini(삭제 예정)/bbot(ACP path 호환성 미검증) 제외. **2026-05-16 bbot 추가** — Phase 1.8 β 통과 + plugin fa3b8f7 (user-role echo final flip 차단) 적용 후 ACP path 호환성 확보. recall sub-agent는 별도 `openai/gpt-5.4-mini` lane이라 메인 lane(pi-shell-acp/opus-4-7)과 OAuth/path 격리.

운영 config:
- `agents: ["main", "glg", "gpt", "bbot"]` — 4개 활성
- `model: "openai/gpt-5.4-mini"` — recall lane을 mini로 분리 (5.12 정공법: `openai-codex/*` → `openai/*` + `agentRuntime.id="codex"`). main lane과 OAuth quota 경합 회피
- `queryMode: "message"` + `promptStyle: "strict"` — 응답성 우선, false-positive 최소화
- `timeoutMs: 5000` + `setupGraceTimeoutMs: 30000` — Oracle ARM resource-tight cold-start 보호
- `maxSummaryChars: 220` — docs default. 한국어→영어 요약 가능
- `thinking: "off"`, `persistTranscripts: false`, `logging: true` — 유지

24h 관찰 결과 (2026-05-08 08:58 ~ 2026-05-09 03:45 UTC, gpt 봇 14 invocation):
- status: ok 4회 (28.6%) / empty 10회 (71.4%) / timeout 0회
- elapsedMs: min 5388 / max 13256 / 평균 ~8.3s. 13.2s spike 1건은 동시 발생한 `event_loop_delay 1678ms` liveness warning과 상관 (Oracle ARM 일시 부하)
- summaryChars (ok 호출): 164 / 178 / 203 / 216 — 모두 220 한도 내, 한국어→영어 요약 정상
- 해석: codex OAuth path는 모델 크기와 무관하게 5–10s latency 본질. timeout 0건 — `setupGraceTimeoutMs=30000`이 매번 5s timeoutMs 덮음. strict promptStyle이 false-positive 차단 작동
- 적용은 hot reload (`config hot reload applied (plugins.entries.active-memory.config.agents)`) — gateway restart 불필요했지만 안전 차원에서 추가 restart 수행

비활성 절차 / 함정은 [docs/openclaw-gotchas.md "비활성 — active-memory"](docs/openclaw-gotchas.md) 그대로 유지.

### Memory / embedding layers (since 2026-05-08 baseline stamp)

Oracle has two disjoint recall layers. Same embedding family (Qwen3-Embedding) but model size differs since 2026-05-08 16:00 — OpenClaw moved to 8B native 4096d, andenken still on 4B 2560d (separate migration cycle).

| Layer | Provider | Model | Dim | Storage | Bot access |
|---|---|---|---|---|---|
| OpenClaw session+memory | OpenRouter | `qwen/qwen3-embedding-8b` | **4096** | `~/openclaw/config/memory/{agentId}.sqlite` (sqlite-vec + FTS5 trigram) | native `memorySearch` |
| andenken (org KB + sessions) | OpenRouter (query) / local vLLM (index) | `qwen/qwen3-embedding-4b` | 2560 | LanceDB (indexing host) | **skill needed — not deployed** |

- `agents.defaults.memorySearch.experimental.sessionMemory: true` since 2026-05-08 — sessions transcript indexing finally activated. Before that the `sources: ["sessions"]` line was being silently dropped by `normalizeSources()` because the experimental gate was closed. Verify with `openclaw memory status --agent <id>` showing `Sources: memory, sessions` and a non-zero `sessions ·` row under `By source:`.
- **5.2 baseline (2026-05-08 06:14 UTC)**: 6 agents force-reindexed → total 2540 chunks (1234 memory + 1306 sessions). main 73 / glg 1599 / gpt 436 / gemini 266 / mini 73 / bbot 93. tool-call heavy bots had aggressive sanitization on indexable content.
- **5.7 baseline (2026-05-08 10:30 UTC)**: same 6 agents force-reindexed → total **4981 chunks (1234 memory + 3747 sessions, +187% sessions)**. main 303 / glg 1831 / gpt 1923 / gemini 670 / mini 127 / bbot 127. memory chunks unchanged → chunking algorithm constant. sessions chunks grew because 5.7 transcript-hygiene preserves delivered assistant replies on disk and applies provider-specific sanitization only to outbound payloads, so indexing now sees full transcript instead of pre-stripped content. Tool-call heavy bots (main 8.4×, gpt 4.4×, gemini 2.5×) gained the most; family-dialog glg gained little (1.13×) because its turns survived 5.2 sanitization already.
- 5.7 신규 분리 리포트: `memory status --deep --json` 의 `vector` 객체 (`enabled / storeAvailable / semanticAvailable / available / extensionPath`) — sqlite-vec 로딩과 embedding provider가 별도로 진단됨. `vec0.so` 경로 확인 가능.
- **8B baseline (2026-05-08 16:43 UTC)**: 4B → 8B 전환. OpenRouter 가격 4B $0.02/M → 8B **$0.01/M (절반)**. native dim 2560 → **4096** (matryoshka truncate 안 함, 모델 풀 활용). 절차: `agents.defaults.memorySearch.model: "qwen/qwen3-embedding-8b"` + `~/openclaw/config/memory/*.sqlite{,-shm,-wal}` 삭제 + gateway restart → schema 자동 4096d 재생성. **Reindex 필수** (4B와 8B 임베딩 공간은 직교: 같은 텍스트 cos(4B,8B)≈0). 6 agents force reindex 결과: total **4982 chunks (1234 memory + 3748 sessions)** — 5.7+4B의 4981과 거의 동일 (chunking 알고리즘은 모델 독립). 분포도 그대로 (main 303 / glg 1832 / gpt 1923 / gemini 670 / mini 127 / bbot 127). reindex 소요 1290s (~21분, glg 362s + gpt 616s). storage 621M → **975M (1.57×)**. OpenRouter privacy 설정에서 8B endpoint 허용 필요 (default 차단되며 "No endpoints available matching your guardrail restrictions" 에러).
- FTS tokenizer = `trigram` for CJK. Korean particle stripping (25 particles, longest-match-first) automatic in query expansion.
- `~/org:/home/node/org:ro` is for file access (denotecli / bibcli / botlog), not embedding. Do not remove.
- andenken layer is still separate by *storage* (LanceDB vs sqlite), *corpus* (org KB vs OpenClaw sessions/memory), and **since 2026-05-08 16:00 also by *model*** (4B vs 8B) until andenken follows. To give bots semantic org search, deploy the `semantic-memory` skill from `~/repos/gh/agent-config/skills/` with LanceDB reachable from Oracle — but cross-store retrieval will be slightly miscalibrated until both layers share a model again.
- This baseline is the comparison point for andenken bake-off (first-result precision, freshness, CJK short query, operator trust). OpenClaw is SSOT; andenken follows.

### Mount permission model (since 2026-04-25)

The `ro`/`rw` boundary was widened to reduce host-hop friction for agent edits. Rollback safety relies on git, not on filesystem enforcement.

| Area | Mode | Rollback surface |
|---|---|---|
| `~/repos/gh` | **rw** | git (each repo). `git status` surfaces unintended writes immediately. |
| `~/repos/3rd` | rw | git + "third-party, disposable" nature |
| `~/repos/work` | ro | intentional — company code never modified through bot hand |
| `~/org` (root) | ro | protects `diary.org`, `archives/`, `authinfo.gpg`, etc. |
| `~/org/botlog`, `~/org/llmlog` | rw | bot activity output — always rw |
| `~/org/meta`, `~/org/bib`, `~/org/notes` | **rw** | new; git-managed (`~/org` is a Denote git repo). |

**Post-deploy habit**: after a rw-expanding change, monitor each affected repo's `git status` for the first hour. Unintended writes in `~/org/diary.org` or other `:ro` regions should be impossible — if you see one, the mount config regressed.

---

## 4. Env / secret SSOT

Budget-safe key lifecycle is part of host survival. Past incident: 100k KRW Gemini embedding bomb.

### Key flow

```
~/.env.local              ← host SSOT (export form, budget-controlled)
    ↓  (value sync)
~/openclaw/.env           ← Docker env_file
    ↓  (container start)
openclaw-gateway env
```

`~/.env.local` is the master. Only budget-capped keys go there. On compromise: revoke in Google Cloud Console → clear from `.env.local` → sync to `~/openclaw/.env`.

### docker compose env precedence

When `docker-compose.yml` has `GEMINI_API_KEY=${GEMINI_API_KEY}`:

1. **shell env wins** — if the shell that ran `docker compose` has it set, that value is injected.
2. Otherwise the `env_file:` file is used.
3. Else, empty.

Implication: if `docker compose up` runs from a shell that never sourced `.env.local`, the `~/openclaw/.env` value is used. Shell-state dependence is fragile, so **keep `~/openclaw/.env` identical to `.env.local`** at all times.

### Reflection rules

| Action | Picks up new env? |
|---|---|
| `docker compose restart` | **No** — reuses existing container env |
| `docker compose up -d --force-recreate` | **Yes** — required when env changed |

### Bomb prevention

- Set a Google Cloud billing cap (e.g. $10/month) before putting a new Gemini key in `.env.local`.
- Keep only budget-controlled keys in `.env.local`.
- Do not leave a revoked key in `~/openclaw/.env` while the new key lives only in `.env.local` — shell state will silently flip the container between the two on restart. Sync both files.
- **Same variable name does not mean same value.** `~/.env.local` and `~/openclaw/.env` can both have `OPENROUTER_API_KEY=...` with *different* values pointing at different OpenRouter accounts or different privacy policies. Verify with suffix-4 comparison (no secret leak), e.g. `${KEY:0:8}...${KEY: -4}` from each source. 2026-05-08 incident: host `~/.env.local` had a working key (...0304) but `~/openclaw/.env` had a different key (...5fe4) blocked by OpenRouter privacy policy → all six agents failed `memory index` with `404 No endpoints available matching your guardrail restrictions`. Sync both *and* sanity `curl /embeddings` from inside the container before reindex.

### Secret inventory

| Var | Use | Source |
|---|---|---|
| `OPENROUTER_API_KEY` | memorySearch embedding (Qwen3-Embedding-4B 2560d, all agents), web search (perplexity) | `~/.env.local` SSOT → `~/openclaw/.env` (sync values, not just names) |
| `GEMINI_API_KEY` | image generation only (banana / `gemini-3-flash-preview-image`). **Not** memorySearch since 2026-05-08 (replaced by OpenRouter Qwen3) | `~/.env.local` SSOT |
| `GROQ_API_KEY` | active-memory primary (currently disabled) | `~/.env.local` SSOT |
| `TELEGRAM_BOT_TOKEN_*` | per-bot Telegram | `~/openclaw/.env` (gitignore) |
| `OPENAI_CODEX_*` | Codex OAuth — actual LLM serving for all agents (Anthropic flat-rate blocked, Copilot disabled) | `~/openclaw/.env` (gitignore) |

---

## 5. Operational workflow

### Warn = Error — every gateway warning must be investigated

Treat **every** OpenClaw gateway WARN as an Error until proven harmless. Silent retry loops have no log signature and look identical to "idle" CPU activity from the outside. The cost of investigating a warn is minutes; the cost of letting one ride through an upgrade can be hours of family-bot downtime.

Concrete cases observed in this deployment:

- `Failed to restore task registry` (`code:"ERR_SQLITE_ERROR" errcode:779 errstr:"database disk image is malformed"`) — appeared on every gateway start from 4.21 onward, was treated as "tolerable startup noise" for 11 days. 4.24 then routed restart-continuation through the same task registry; the malformed `runs.sqlite` flipped from background warning into a 100% CPU silent retry loop that froze inbound message processing. Fix: stop gateway, move `~/openclaw/config/tasks/runs.sqlite` to a backup folder, start gateway — new DB is auto-created (in-flight task state only, no user data).
- `bonjour: watchdog detected non-announced service` — repeating warn from 4.23 onward, ignored as "ARM cloud LAN noise". 4.24 promoted bonjour to a default-on plugin, the same probe failure became `Unhandled promise rejection: CIAO PROBING CANCELLED` and took the gateway into a ~30s restart loop. Fix: `plugins.entries.bonjour: { enabled: false }`.
- Any `database disk image is malformed` on **any** SQLite under `~/openclaw/config/`: do not assume a single corruption. Run integrity check across the set:

  ```bash
  for f in ~/openclaw/config/tasks/runs.sqlite \
           ~/openclaw/config/memory/*.sqlite \
           ~/openclaw/config/flows/registry.sqlite; do
    [ -f "$f" ] && echo "$(basename $f): $(sqlite3 "$f" 'PRAGMA integrity_check;' 2>&1 | head -1)"
  done
  ```

  `runs.sqlite` and `flows/registry.sqlite` are ephemeral — safe to delete. Per-bot `memory/*.sqlite` carry workspace recall and should be repaired (`.dump` + reload) rather than deleted if possible.

Operational rule:

1. On any gateway WARN, before declaring the gateway "ready", re-read the WARN line aloud in the upgrade log.
2. Decide explicitly: harmless / suspect / critical. No "we'll see" answers.
3. If suspect or critical, file a TODO in `~/sync/org/llmlog/` with the exact warn text and a hypothesis — do not just close the terminal.

The 4.24 cycle paid in user-visible bot downtime for two warns ignored over the prior cycles. The cost of this rule is one extra minute per upgrade.

### Change policy for OpenClaw behavior

Prioritize continuity over elegance.

- Change the default model only when that is the real need.
- Do not silently delete old model entries because the default changed.
- Preserve manual reversibility for the operator.
- Do not introduce failover unless explicitly requested.
- Test real execution, not just config syntax.

Family-facing bots: avoid workflows that require manual model switching unless the operator explicitly chose ACP for that conversation. Prefer the least-surprising behavior. Optimize for stable replies.

### Approval / exec policy

NixOS host + Docker isolation already provide the safety boundary. Disabling approval prompts that block normal operation is acceptable. Keep bot interaction smooth; verify post-change behavior with real bot tests. Do not stop at `docker ps` for behavior-sensitive changes — a live reply test is required.

### Upgrade workflow

Discussion-first. Do not upgrade blindly.

1. Inspect current live version.
2. Read `~/openclaw/README.md` change history.
3. Fetch upstream release / compare pages.
   - `https://github.com/openclaw/openclaw/releases/tag/v<version>`
   - `https://github.com/openclaw/openclaw/compare/v<from>...v<to>`
4. Identify what matters for this deployment: embeddings, memory search, Telegram, sessions, auth, approval prompts, runtime compatibility.
5. Predict likely breakage before touching anything.
6. Update runtime files in `~/openclaw/`.
7. Validate the bots with real prompts.
8. Sync public-safe Dockerfile / compose into `nixos-config/docker/openclaw/`.
9. Commit both repos.

### Restart vs recreate

| Change | Action |
|---|---|
| `openclaw.json` | restart |
| Dockerfile content | rebuild + recreate |
| `docker-compose.yml` service config | restart (usually) |
| OpenClaw version (base image) | `docker compose build --pull` + `up -d --force-recreate` |
| Volume mounts (`~/.claude`, compatibility symlinks, skill overlays) | **recreate required** |
| Env variables | **recreate required** |
| Adding / removing skill directories | restart |
| workspace text files (`AGENTS.md`, `SOUL.md`, `USER.md`, `MEMORY.md`) | none |
| SKILL.md content only | none |

Recreate command:

```bash
cd ~/openclaw && docker compose up -d --force-recreate openclaw-gateway
```

### Validation after any OpenClaw change

- container health (`docker ps` + `docker inspect ... Health.Status`)
- gateway ready line in logs
- real-prompt tests against affected agents
- Telegram-facing bots still answer
- family-facing bots still behave as expected

### Commit policy

Commit both layers when work spans them:
- `~/openclaw/` for live operational changes (runtime docs, Dockerfile, compose — never `openclaw.json` / `.env`)
- `nixos-config/` for public structure / docs / backups

Stamp every commit with agenda and Google Chat notification per the convention in `~/.pi/agent/skills/pi-skills/agenda/scripts/agenda-stamp.sh`.

---

## 6. Skills deployment

```
agent-config (SSOT)
  └── pi-skills/ (source + build)
        ↓ git pull on Oracle
~/pi-skills/ (Oracle local)
        ↓ run.sh k)
~/openclaw/config/workspace*/skills/ (per-bot deploy)
```

Operator entrypoint: `run.sh k)` (Oracle only).

### Inventory

| Class | Skills | Notes |
|---|---|---|
| npm (bundled `node_modules`) | brave-search, youtube-transcript, medium-extractor, transcribe, summarize | copy whole tree |
| CLI (binary / shell) | denotecli, ghcli, bibcli, gogcli, gitcli, lifetract, dictcli | exclude `node_modules` |

### Per-agent policy

모든 봇 동일 스킬 (2026-05-09부터). 봇 직관 우선 — agenda/commit/botlog 같은 turn-routine 스크립트는 모든 봇이 자기 `workspace/skills/`에서 찾을 수 있어야 한다. mini 최소 정책(`MINI_SKILLS=(denotecli)`)은 issue #6에서 보고된 mini 봇 stamp 실패 사례로 폐기.

| Agent | Workspace | Skill scope |
|---|---|---|
| main | `workspace/` | all |
| glg | `workspace-glg/` | all |
| gpt | `workspace-gpt/` | all |
| gemini | `workspace-gemini/` | all |
| mini | `workspace-mini/` | all |
| bbot | `workspace-bbot/` | all |

### Deployment rules

- `run.sh k)` installs to `main` first, then rsyncs to glg / gpt / gemini / mini / bbot, then syncs to `claude-skills/`.
- Adding or removing skill directories requires a gateway restart.
- SKILL.md content-only changes load dynamically (no restart).
- Go binaries are built for arm64 in pi-skills and deployed outside git.

### Workspace skills vs Claude native skills

Two separate systems that do not auto-sync.

- `workspace*/skills/` — OpenClaw workspace skill system.
- `~/.claude/skills` — Claude ACP sessions discover skills here.

Current workaround on Oracle: `config/claude-skills/` is mounted to `/home/node/.claude/skills` for ACP sessions. `claude-skills/` is a union of `agent-config/skills` and `workspace-bbot/skills`. `~/.claude` must be **rw** (Claude writes `session-env/` and `projects/`). Long-term path: MCP bridge exposing workspace skills as tools so the overlay becomes unnecessary.

---

## 7. Gotchas

운영 중 자주 부딪히는 함정 + incident 정책 근거는 별도 파일로 분리:

→ [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md)

활성 (현재 5.2 deployment에 적용) / 비활성 (재활성 시 참고) / 역사 (resolved/superseded) 카테고리.

대표 항목:

- **활성**: bonjour disable, 비-default 모델 추가 절차, rw mount 롤백, Codex catalog drift, dreaming heartbeat decoupling, ACP common failures, **키 매핑 함정 (같은 변수명·다른 값)**
- **비활성**: active-memory (disabled since 5.2), ACPX 4건 (disabled since 5.2)
- **역사**: 4.24→4.26/4.29 lazy-staging (resolved on 5.2), 4.24→4.26 latency regression (superseded), GlueClaw injection (provider deleted)

---

## 8. Commands

```bash
# device & time — every session
cat ~/.current-device
TZ='Asia/Seoul' date '+%Y%m%dT%H%M%S'

# rebuild current profile
sudo nixos-rebuild switch --flake .#<profile>

# operator menu
./run.sh

# live OpenClaw agent models
python3 - <<'PY'
import json, pathlib
c = json.loads(pathlib.Path('~/openclaw/config/openclaw.json').expanduser().read_text())
for a in c.get('agents', {}).get('list', []):
    print(a.get('id'), a.get('model'))
PY

# restart vs recreate
cd ~/openclaw && docker compose restart openclaw-gateway
cd ~/openclaw && docker compose up -d --force-recreate openclaw-gateway   # env / mount changes

# OpenClaw upgrade (image rebuild + recreate)
cd ~/openclaw && docker compose build --pull openclaw-gateway && docker compose up -d --force-recreate openclaw-gateway

# upstream release / compare
# https://github.com/openclaw/openclaw/releases/tag/v<version>
# https://github.com/openclaw/openclaw/compare/v<from>...v<to>
```

---

Correctness starts with location awareness. On `oracle`, that awareness extends to bot survival.
