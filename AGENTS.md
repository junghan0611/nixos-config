# nixos-config AGENTS.md

## Project identity

`nixos-config` is a multi-device NixOS repository for four real machines:

- `oracle` — Oracle Cloud VM
- `nuc` — Intel NUC home server
- `laptop` — Samsung personal laptop
- `thinkpad` — ThinkPad work laptop

This repo is not a generic single-host config. The first task is always to know which device you are operating on.

## Mandatory first step

Before making any change in this repo, explicitly verify the current device and current Korea time:

```bash
cat ~/.current-device
TZ='Asia/Seoul' date '+%Y%m%dT%H%M%S'
```

Do this even if the session hook already reported `device=` and `time_kst=`.
In `nixos-config`, wrong host assumptions are costly.

Normalization rule used by `run.sh`:
- `oracle-nixos` → `oracle`
- first token before `-` is the flake profile name

Valid profiles:
- `oracle`
- `nuc`
- `laptop`
- `thinkpad`

## Device profile map

| Profile | Role | Notes |
|---|---|---|
| `oracle` | remote cloud VM | OpenClaw runtime lives here; safety-critical |
| `nuc` | home server | real machine, not disposable |
| `laptop` | personal GUI machine | home-manager GUI/user environment matters |
| `thinkpad` | work GUI machine | home-manager GUI/user environment matters |

GUI-oriented user configuration is mainly relevant on:
- `laptop`
- `thinkpad`
- `nuc`

Those machines may need attention to i3, desktop tooling, fonts, editor setup,
and home-manager behavior.

`oracle` is different: it is primarily a minimal cloud runtime focused on
keeping OpenClaw and related services alive.

`thinkpad` has working **Vulkan** support on AMD Radeon 780M, but local Ollama
is **not enabled as a persistent default service**.

## Local AI policy (ThinkPad)

Current preference on ThinkPad:
- use **OpenRouter** by default
- do not keep Ollama serving all the time unless explicitly needed
- if local embedding is needed temporarily, enable it intentionally and disable
  it again after use

Notes:
- Vulkan driver is available via Mesa RADV in `hardware.graphics`
- previous validation confirmed `ollama-vulkan` + `qwen3-embedding:4b` works on
  AMD Radeon 780M
- gpu2i may have similarly named embedding models, but quantization/blob hashes
  can differ from Ollama registry models

## Directory model

```text
hosts/           per-device configs
users/junghan/   user configs + home-manager modules
modules/         shared NixOS modules
templates/       VM / infra templates
docs/            documentation
run.sh           operator entrypoint for recurring tasks
```

## run.sh

`run.sh` is the shared human+agent operator interface for this repo.
Do not ignore it.

Use it as the first-class entrypoint for recurring operational tasks when it
already supports them. If a repeatable workflow needs a stable interface, adding
it to `run.sh` is preferred over relying on memory.

Current scope includes things like:
- flake updates
- rebuild / switch / rollback
- cleanup
- Oracle service helpers
- OpenClaw tunnel / restart / status / pairing helpers

Rule:
- if a task already has a `run.sh` path, prefer using or extending that path
- do not duplicate operator workflows unnecessarily

## Workflow preference

Do not use `br` in this repository.
Use agenda-style logging/stamps instead when work should be recorded.

This repo prefers flexible shared operational flow over rigid issue-tracker
workflow.

## Oracle / OpenClaw operational context

`oracle` is not just another profile. It is the live runtime for the OpenClaw
bot ecosystem.

Treat Oracle work as service reliability work.
Real users depend on it, including family members who cannot be expected to
manually recover from configuration or model mistakes.

### Storage policy on Oracle

Oracle storage is limited.
Keep the machine lean and biased toward OpenClaw continuity.

Rules:
- prioritize OpenClaw and essential supporting services
- avoid unnecessary packages, images, caches, and bulky experiments
- clean old generations and Docker leftovers when needed
- be conservative with disk growth

## Public/private split

Two repositories matter here:

### Private runtime SSOT

`~/openclaw/`

Contains live runtime state, including:
- `config/openclaw.json`
- agent workspaces
- auth state
- runtime README/changelog
- real Docker runtime files

### Public operator/backup repo

`~/repos/gh/nixos-config/`

Contains public-safe structure, including:
- Dockerfile backups
- `docker-compose.yml` backups
- host-level NixOS context
- operator guidance
- public documentation of deployment shape

Rule:
- live runtime truth belongs to `~/openclaw/`
- public structural backup/reference belongs to `nixos-config`
- never leak secrets or runtime auth state into this repo

## OpenClaw files: what lives where

| Item | Runtime SSOT | Public repo |
|---|---|---|
| `openclaw.json` | `~/openclaw/config/openclaw.json` | never commit |
| `.env` / secrets | `~/openclaw/` | never commit |
| Dockerfile | `~/openclaw/Dockerfile` | `docker/openclaw/Dockerfile` backup |
| compose file | `~/openclaw/docker-compose.yml` | `docker/openclaw/docker-compose.yml` backup |
| operational docs | `~/openclaw/README.md` | summarized guidance in this repo |

## OpenClaw runtime shape

Oracle currently hosts the OpenClaw bot system.
The exact active models may change operationally, so do not trust stale prose.
Check live config when model identity matters:

```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path('~/openclaw/config/openclaw.json').expanduser()
c = json.loads(p.read_text())
for a in c.get('agents', {}).get('list', []):
    print(a.get('id'), a.get('model'))
PY
```

Known workspace mapping:
- `workspace/` → main
- `workspace-glg/` → glg
- `workspace-gpt/` → gpt
- `workspace-gemini/` → gemini
- `workspace-mini/` → mini
- `workspace-bbot/` → bbot

Important invariant:
- main uses `workspace/`, not `workspace-main/`
- `workspace-bbot/` is a split-out B(비) workspace

Current model routing (2026-04-19):
- Anthropic flat-rate access blocked for third-party apps (OpenClaw, pi)
- GitHub Copilot 계정은 전면 제거 — openai-codex(GPT Pro)로 일원화
- **default/main/bbot/glg fallback**: `openai-codex/gpt-5.4`
- **main**: at-rest/fallback is `openai-codex/gpt-5.4`, preferred live mode is **ACPX + `claude-opus-4-6`** bound to `workspace/`
- **bbot** (`@glg_b_bot`): at-rest/fallback is `openai-codex/gpt-5.4`, preferred live mode is **ACPX + `claude-opus-4-6`** bound to `workspace-bbot/`
- glg (힣봇): `openai-codex/gpt-5.4` — 가족 라이프 에이전트
- gpt: `openai-codex/gpt-5.4`
- gemini: `github-copilot/gemini-3.1-pro-preview` — Copilot 유일한 예외, gemini-cli 크레딧 재연동 전까지 유지
- mini (힣봇미니, @glg_mini_bot): `openai-codex/gpt-5.4-mini` — 문서 포맷팅/교정 전담
- subagents: `openai-codex/gpt-5.4`
- active-memory plugin: `groq/openai/gpt-oss-120b` (primary), `google/gemini-3-flash` (fallback). 상세는 아래 "Active memory operational config" 참조
- ACPX bind 필요 시 `/acp spawn --bind here` — 모델 수동 지정 가능(`acpx claude set -s <sess> model claude-opus-4-7` 형태). 4.19 정식 릴리스에서 acpx 기본이 opus 4.7로 bump 예정

### Active memory operational config

v2026.4.21 기준 운영값 (`plugins.entries.active-memory.config`, `~/openclaw/config/openclaw.json`, gitignore):

| key | 값 | 비고 |
|-----|----|------|
| `enabled` | `true` | |
| `agents` | `["glg", "gpt"]` | glg는 가족용, gpt는 본인용 |
| `allowedChatTypes` | `["direct"]` | DM만 |
| `model` | `groq/openai/gpt-oss-120b` | primary. 20b와 가격 차이 미미, 품질 ↑ |
| `modelFallback` | `google/gemini-3-flash` | groq 장애 시. OpenClaw alias가 `gemini-3-flash-preview`로 자동 변환 (`extensions/google/model-id.ts`) |
| `queryMode` | `"recent"` | upstream 기본. 최근 2 user + 1 assistant 턴 컨텍스트 사용 |
| `thinking` | `"off"` | OpenClaw가 모델별 재해석 — Gemini Flash에선 `minimal` 매핑, Pro에선 strip |
| `promptStyle` | `"balanced"` | |
| `timeoutMs` | `15000` | upstream `DEFAULT_TIMEOUT_MS=15_000`과 동일. 상한 120000 |
| `maxSummaryChars` | `220` | upstream 기본 |
| `persistTranscripts` | `false` | |
| `logging` | `true` | 튜닝 단계라 ON |

Reference 문서: `~/repos/3rd/openclaw/docs/concepts/active-memory.md` ("Paste This Into Your Agent" 섹션).

삽질 이슈 (2026-04-22):
- `openai-codex/gpt-5.4-mini`로 시도 → **31.5s timeout** (Codex CLI subprocess cold-start 병목). `timeoutMs=8000` plugin cutoff를 embedded runner가 subprocess 생성 구간까지 전파 못 함. → `groq/openai/gpt-oss-120b`로 복귀. Codex subprocess 기반 모델은 active-memory 같은 blocking hot path에 부적합.
- 과거 `timeoutMs=8000` 유지 시 groq에서도 9.7s 경계 timeout 발생 → 15000으로 상향. groq 평균 레이턴시 고려한 합리적 상한.
- upstream `3f90d9266` graceful degrade 덕에 timeout이 나도 reply는 유지. active-memory는 보조 레이어.
- openrouter 대안은 회사 계정 크레딧 변동 리스크로 제외. groq가 외부 API지만 cold-start 없어 운영 적합.

## Environment / secret SSOT

호스트 단단함이 openclaw 도커 관리의 전제. 특히 API 키는 예산 사고(과거 Gemini 임베딩 10만원 폭탄)를 호스트 레벨에서 차단해야 한다.

### 키 경로 계층

```
~/.env.local              ← 호스트 SSOT (export 형식, shell용)
    ↓ (값만 동기)
~/openclaw/.env           ← Docker env_file (docker-compose.yml의 env_file:)
    ↓ (컨테이너 기동 시 로드)
openclaw-gateway 환경변수
```

`~/.env.local`이 마스터. 예산 통제되는 키만 여기에 둔다. 폭탄 맞은 키는 즉시 Google Console에서 revoke하고 `.env.local`에서 제거 → `~/openclaw/.env`에도 동기.

### docker compose env 해석 규칙

`docker-compose.yml`에 `GEMINI_API_KEY=${GEMINI_API_KEY}` 형식이 있으면:
1. **shell env 우선** — `docker compose` 실행 당시 shell에 값 있으면 그것 사용
2. shell에 없으면 `env_file:`의 `.env` 파일에서 찾음
3. 둘 다 없으면 빈 값

즉 **`.env.local`을 source하지 않은 shell에서 `docker compose up`을 돌리면 `openclaw/.env` 값이 주입됨**. shell 상태에 의존하는 것은 깨지기 쉬운 구조라 **`openclaw/.env`가 항상 `.env.local`과 같은 값을 들고 있어야** restart 시 일관성 보장.

### 반영 규칙

- 단순 `docker compose restart` — **env 변경 반영 안 됨** (기존 컨테이너 env 유지)
- `docker compose up -d --force-recreate` — env 새로 읽어서 재생성 → **env 변경 시 필수**

### 폭탄 방지

- 새 Gemini 키 발급 시 Google Cloud Console에서 **빌링 한도 설정** (예: 월 $10) 필수
- `.env.local`에는 **예산 통제된 키만** 둔다
- 과거 키가 `openclaw/.env`에 잔존한 채 새 키를 `.env.local`에만 넣으면, shell이 새 키를 가진 상태에서만 컨테이너가 새 키를 쓰고 그 외엔 폭탄 키로 롤백 → sync는 양쪽 파일 모두 갱신

### 현재 사용 중인 비밀

| 변수 | 용도 | 소스 |
|------|------|------|
| `GEMINI_API_KEY` | active-memory fallback, memorySearch embedding (모든 봇), dreaming | `~/.env.local` SSOT |
| `GROQ_API_KEY` | active-memory primary | `~/.env.local` SSOT |
| `TELEGRAM_BOT_TOKEN_*` | 각 봇 텔레그램 연결 | `~/openclaw/.env` (gitignore) |
| `OPENAI_CODEX_*` | Codex OAuth | `~/openclaw/.env` (gitignore) |

### nixos-config가 openclaw 운영 담당인 이유

OpenClaw upstream은 피터(steipete) 1인 유지로 우리 문서가 그쪽에 살아남지 못한다. 반면 nixos-config는 Oracle 머신 전체를 담당 — 디스크, 보안, 서비스 건강, 예산 사고 방지까지. 그래서 **호스트-컨테이너 경계 원칙**은 여기서 기술되어야 한다:

- 호스트가 견고 → 도커는 교체 가능한 runtime으로 간주
- 예산 폭탄 같은 사고는 호스트 레벨(API 키 라이프사이클)에서 차단
- 컨테이너 내부 상태는 언제든 `force-recreate`로 날릴 수 있도록 SSOT 경로 명확
- 실제 운영 실패(오늘의 31.5s timeout, 폭탄 키, GlueClaw auto-inject 등)는 이 문서에 삽질 기록으로 쌓아 다음 세션이 반복하지 않도록

## OpenClaw change policy

When changing OpenClaw behavior, prioritize continuity over elegance.

Rules:
- change the default model only when that is the real need
- do not silently delete old model entries just because the default changed
- preserve manual reversibility for the operator
- avoid introducing failover unless explicitly requested
- test real execution, not just config syntax

For family-facing bots:
- avoid workflows that require manual model switching unless the operator explicitly chose ACP mode for that conversation
- prefer the least surprising behavior
- optimize for stable replies

## ACP / ACPX operational notes

OpenClaw ACP sessions are conversation-bound overlays, not permanent replacements for `agents.list`.
Treat `/acp spawn ... --bind here` as rebinding one chat thread to an ACP harness session.

Important corrections learned from real work:
- **`workspace/skills` != Claude native skills.** OpenClaw workspace skills are for OpenClaw's own workspace snapshot/prompt system.
- Claude ACP sessions primarily discover skills from **`~/.claude/skills`**.
- Therefore, if a Claude ACP session must see OpenClaw bot skills today, you need either:
  - a Claude-side skill overlay/sync (current workaround), or
  - a future MCP bridge that exposes workspace skills as tools (preferred long-term)
- Current runtime workaround on Oracle: `config/claude-skills/` is mounted to `/home/node/.claude/skills` for all ACP sessions.
- `~/.claude` must be **rw**, not ro, because Claude writes `session-env/` and `projects/` during ACP sessions.
- If ACP says `Authentication required`, check that `~/.claude` is actually mounted inside the container.
- If Claude skills suddenly disappear, check broken absolute symlinks inside `~/.claude` and ensure `/home/junghan/repos/gh` is mounted for compatibility.
- If ACP says `max concurrent sessions reached`, either close stale sessions or raise `acp.maxConcurrentSessions` in `openclaw.json`.
- **Do not trust `/acp list` inside an already-bound Telegram thread.** Once bound, that text may be forwarded into the Claude ACP session as a normal user message.
- For authoritative inspection, use host-side checks:
  - `cd ~/openclaw && docker exec openclaw-gateway sh -lc 'node openclaw.mjs sessions --all-agents'`
  - `cd ~/openclaw && docker exec openclaw-gateway sh -lc 'sed -n "1,200p" /home/node/.openclaw/telegram/thread-bindings-default.json'`
  - `cd ~/openclaw && docker exec openclaw-gateway sh -lc 'sed -n "1,200p" /home/node/.openclaw/telegram/thread-bindings-bbot.json'`
  - `cd ~/openclaw && docker exec openclaw-gateway sh -lc 'for f in /home/node/.openclaw/workspace/state/sessions/agent%3Aclaude%3Aacp%3A*.json; do echo "--- $f"; sed -n "1,80p" "$f"; done'`

### ACPX model override — 당분간 반복 입력 필요 (삽질 이슈)

OpenClaw 2026.4.15 + acpx 0.5.3 기준으로 ACPX 세션 model을 config 파일로 **영구화할 수 없다**. 스키마 직접 확인 결과:

- `AcpBindingSchema.acp` strict 필드: `mode, label, cwd, backend` — **model 없음**
- `AgentRuntimeAcpSchema` strict 필드: `agent, backend, mode, cwd` — **model 없음**

즉 `openclaw.json`의 `bindings[].acp.model`이나 `agents.list[].runtime.acp.model`은 config validation에서 거부됨.

**유일한 설정 경로 — 대화 안 슬래시 커맨드:**
```
/acp spawn claude --bind here
/acp model anthropic/claude-opus-4-7
```

호스트 바이패스 경로 없음:
- `openclaw acp`는 외부 ACP 클라이언트 bridge일 뿐 (spawn 아님)
- `message send`는 송신 전용 (사용자 입력 시뮬레이션 불가)
- thread-bindings 파일 수동 편집으로 spawn 대체 불가

**TTL 리사이클 부담**: `acp.runtime.ttlMinutes: 120` — 2시간 idle 시 세션 리사이클, model override 증발 → 재입력.

**대응 전략 (현재):**
- main, bbot 각각 활성 사용 중인 스레드에서 **하루 수 회 수동 재세팅** 감수
- 혹은 ACPX 제거하고 fallback 모델(gpt-5.4)만 사용 — 단순하지만 opus 4.7 포기
- 장기: OpenClaw 2026.4.19 정식 릴리스의 acpx 버전 bump 대기 (기본값이 opus 4.7로 바뀌면 override 불필요)

**감지 방법**: 텔레그램 스레드에서 응답이 이상해지면 `/acp status`로 현재 model 확인. sonnet-4.6으로 돌아가 있으면 리사이클된 것.

**실전 관찰 (2026-04-19)**:
- `/acp model anthropic/claude-opus-4-7` 실행 → CLI는 "session ids resolved"로 수락하지만 **실제 응답 모델은 claude-opus-4-6**. Anthropic flat-rate OAuth 토큰이 4.7을 허용하지 않아 silently downgrade된 것으로 추정. 4.7 정식 사용은 별도 계정/billing 필요.
- 현시점 실용적 선택: **`anthropic/claude-opus-4-6`으로 지정**하면 검증된 경로.

### ACPX claude 세션은 workspace identity를 자동 로드하지 않는다 (삽질 이슈)

`/acp spawn claude --bind here`로 ACPX 세션을 새로 붙이면, 해당 Claude 세션은 **OpenClaw workspace의 IDENTITY.md / SOUL.md / USER.md / AGENTS.md / MEMORY.md 등을 자동으로 읽지 않는다**. Direct runtime(GlueClaw) 에이전트는 workspace를 기본 읽기 경로로 갖지만, ACPX Claude 세션은 claude-agent-sdk 표준 진입점이라 workspace scan 부재.

**결과**: 새로 스폰한 ACPX 세션은 힣봇 정체성을 모른 채 대답함. 가족/사용자 식별도 안 되고 톤도 생소함.

**대응**: 스폰 직후 대화 첫 턴에 **명시적 지시** 필요:

```
workspace의 아이덴티티를 읽어주세요
```

또는 더 강하게:

```
workspace의 IDENTITY.md, SOUL.md, USER.md, AGENTS.md, MEMORY.md를 순서대로 읽고 시작하세요
```

**장기 해결 후보**:
- workspace에 `CLAUDE.md` 두고 claude-agent-sdk가 자동 로드하는지 확인 (native skills와 별개 경로)
- systemPromptOverride 활용 — `agents.list[].systemPromptOverride`에 "always read workspace/IDENTITY.md first" 주입
- ACPX 기본 bootstrap 스크립트 경로가 열리면 거기에 identity preload 삽입

### ACPX 세션은 자기 런타임을 모른다 — 봇 자기소개 신뢰 금지 (삽질 이슈)

ACPX Claude 세션에게 "지금 어떤 runtime이냐"고 물으면 **workspace 문서 서술을 그대로 읊는다**. 실제 `/acp status`와 다를 수 있다.

**실제 관찰 (2026-04-19)**:
- 바인딩은 `agent:claude:acp:...` (명시적 ACPX)
- 모델은 Anthropic Opus 4.6 (1M context, flat-rate 특성)
- 그런데 봇은 "지금은 acpx가 아닌 direct runtime으로 동작하고 있다"고 답함 — workspace MEMORY.md가 "GlueClaw direct가 기본 런타임"이라 적어둔 것을 **문서 기반 추론으로 그대로 진술**한 것

**신뢰할 수 있는 확인 경로 (사람이 체크)**:
1. 텔레그램에서 `/acp status` — backend/model/session id 실제 값
2. 호스트에서 `docker exec openclaw-gateway sh -lc 'node openclaw.mjs sessions --all-agents'` grep 해당 스레드
3. 봇 자기소개는 참고용, 확정값 아님

**장기 대응**:
- workspace 문서(MEMORY.md/AGENTS.md)에서 "기본 런타임" 서술을 실제 현행값으로 갱신, 또는 삭제
- systemPromptOverride에 "당신은 자신의 runtime을 직접 알 수 없습니다. 사용자가 runtime을 물으면 '확인 불가, `/acp status`로 조회 필요'라 답하세요" 지침 주입

## Approval / exec policy

If OpenClaw introduces approval prompts that harm normal operation, disabling
that friction is acceptable when the safety boundary is already provided by the
NixOS host + Docker isolation model.

Current operational preference on Oracle:
- keep bot interaction smooth
- avoid approval UX that blocks routine use
- verify post-change behavior with real bot tests

## OpenClaw update workflow

OpenClaw upgrades are discussion-first changes.
Do not upgrade blindly.

Preferred flow:
1. inspect current live version
2. read `~/openclaw/README.md` change history and notes
3. fetch upstream release/compare context before touching anything
   - release page pattern: `https://github.com/openclaw/openclaw/releases/tag/v<version>`
   - compare page pattern: `https://github.com/openclaw/openclaw/compare/v<from>...v<to>`
   - GitHub API compare also uses `v`-prefixed tags
4. discuss what changed since the current version
5. identify what matters for this deployment
   - embeddings / memory search
   - Telegram behavior
   - sessions
   - auth
   - approval prompts
   - runtime compatibility
6. predict likely breakage before touching anything
7. update runtime files in `~/openclaw/`
8. validate the bots
9. sync public-safe Dockerfile/compose changes back into `nixos-config`
10. commit both repos when appropriate

## Required validation after OpenClaw changes

After changing OpenClaw config, version, Dockerfile, compose, or model routing:

- confirm container health
- confirm gateway is up
- test affected agents with real prompts
- verify Telegram-facing bots still answer
- verify family-facing bots still behave as expected

Do not stop at `docker ps` if the change was behavior-sensitive.
A live reply test is required.

## Restart policy

Restart required when changing:
- `openclaw.json`
- Dockerfile
- `docker-compose.yml`
- OpenClaw version
- adding/removing skill directories that affect command registration

**Recreate (not simple restart) is required when changing volume mounts**, especially:
- `~/.claude` auth/runtime mount
- compatibility mounts for broken absolute symlinks
- Claude skill overlay mounts

Use:
```bash
cd ~/openclaw && docker compose up -d --force-recreate openclaw-gateway
```

Restart usually not required when changing:
- workspace text files like `AGENTS.md`, `SOUL.md`, `USER.md`, `MEMORY.md`
- SKILL.md content only
- scripts/binaries behind unchanged paths

## Documentation sync discipline

Keep these aligned intentionally:
- runtime docs in `~/openclaw/README.md`
- runtime files in `~/openclaw/`
- public Docker backups in `nixos-config/docker/openclaw/`
- operator guidance in `nixos-config/AGENTS.md`

Do not assume the public copy is live.
Do not assume the live copy is publishable.

When a workflow mistake is discovered during real work, record the correction in
`AGENTS.md` if it is likely to recur. Operational retrieval mistakes count too
(e.g. OpenClaw release tags requiring `v` prefixes).

## Skills and related repos

OpenClaw skills and related agent tooling are maintained outside this repo.
Not every tool available in `pi` is deployed into OpenClaw bot workspaces.

### Skill deployment flow

```text
agent-config (SSOT)
  └── pi-skills/ (스킬 소스 + 빌드)
        ↓ git pull on Oracle
~/pi-skills/ (Oracle 로컬)
        ↓ run.sh k)
~/openclaw/config/workspace*/skills/ (봇별 배포)
```

Operator entrypoint: `run.sh k)` (Oracle 전용)

### Skill inventory

| 분류 | 스킬 | 비고 |
|------|------|------|
| npm (node_modules 포함) | brave-search, youtube-transcript, medium-extractor, transcribe, summarize | 통째 복사 |
| CLI (바이너리/쉘) | denotecli, ghcli, bibcli, gogcli, gitcli, lifetract, dictcli | node_modules 제외 |

### Per-agent skill policy

| 에이전트 | workspace | 스킬 범위 | 이유 |
|---------|-----------|-----------|------|
| main | `workspace/` | 전체 | 범용 deep work |
| glg | `workspace-glg/` | 전체 | 가족 라이프 에이전트 |
| gpt | `workspace-gpt/` | 전체 | GPT 범용 |
| gemini | `workspace-gemini/` | 전체 | Gemini 범용 |
| bbot | `workspace-bbot/` | 전체 | B(비) ACP Opus workspace (fallback model is Sonnet) |
| mini | `workspace-mini/` | denotecli만 | 포맷팅/교정 전담 — 최소 도구 |

Note:
- `workspace*/skills`는 OpenClaw workspace skill system이다.
- Claude ACP 세션이 실제로 보는 native skills는 `~/.claude/skills`다.
- 두 체계는 자동 동기화되지 않는다.

### Deployment rules

- `run.sh k)`가 main workspace에 먼저 설치 → glg, gpt, gemini, bbot에 rsync → claude-skills에도 동기화
- mini는 별도 — 지정 스킬만 개별 복사, 나머지 삭제
- 스킬 디렉토리 추가/삭제 시 gateway 재시작 필요
- SKILL.md 내용만 변경 시 재시작 불필요 (동적 로딩)
- Go 바이너리는 pi-skills에서 arm64 빌드 후 배포 (git에 넣지 않음)

## Memory / embedding layers (분리된 체계)

Oracle 호스트에는 임베딩 기반 회상이 **두 개의 분리된 레이어**로 존재한다.
차원/프로바이더가 달라 서로 섞이지 않으며, 자동 동기화되지 않는다.

| 레이어 | 프로바이더 | 모델 | 차원 | 저장소 | 봇 접근 |
|--------|-----------|------|------|--------|---------|
| **OpenClaw 세션 메모리** | Gemini API | `gemini-embedding-2-preview` | 768 | `~/openclaw/config/workspace*/memory/` + session transcripts | 네이티브 `memorySearch` |
| **andenken (org 지식)** | OpenRouter (쿼리) / 로컬 vLLM (인덱싱) | `qwen/qwen3-embedding-4b` | 2560 | LanceDB (인덱싱 호스트) | **skill 배포 필요 — 현재 미배포** |

### 현재 상태 (2026-04-21 확인)

- `openclaw.json` `agents.defaults.memorySearch`는 **자기 세션 + memory/*.md만** 임베딩. `extraPaths: []`, `sources: ["memory", "sessions"]`.
- andenken은 **별도 레이어** — OpenClaw는 직접 참조하지 않는다.
- `~/org:/home/node/org:ro` 볼륨 마운트는 **파일 접근용**(denotecli/bibcli/botlog)이지 임베딩 경로가 아니다. 제거 금지.

### 봇이 org를 semantic으로 검색하려면 (미래 작업)

native `memorySearch`는 **단일 프로바이더** 구조라 andenken 인덱스와 섞을 수 없다 (768d vs 2560d 차원 mismatch). 유일한 경로는 **skill 배포**:

1. `~/repos/gh/agent-config/skills/semantic-memory`가 andenken CLI 래퍼로 존재 (cf. `c86fad1 refactor: semantic-memory → andenken 분리 완료`)
2. 배포 전제:
   - `run.sh k)`에 `semantic-memory` 추가
   - andenken LanceDB가 Oracle에서 접근 가능 (Syncthing 동기화 또는 원격 API — **현재 미확인**)
   - `OPENROUTER_API_KEY`를 openclaw-gateway 컨테이너에 노출

### 당장 봇이 org에 닿는 경로

- `denotecli` — exact/tag/title/full-text search
- `bibcli` — bibliography entries
- semantic search는 **아직 없음**

## Commit policy

When work spans both runtime and public backup layers, commit both sides as
needed:
- `~/openclaw/` for live operational changes
- `nixos-config/` for public-safe structure/docs/backups

Do not commit secrets, tokens, auth files, or runtime memory/session data.

## Practical command hints

Check device and current Korea time:
```bash
cat ~/.current-device
TZ='Asia/Seoul' date '+%Y%m%dT%H%M%S'
```

Rebuild current profile:
```bash
sudo nixos-rebuild switch --flake .#<profile>
```

Use operator menu:
```bash
./run.sh
```

Check live OpenClaw agent models:
```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path('~/openclaw/config/openclaw.json').expanduser()
c = json.loads(p.read_text())
for a in c.get('agents', {}).get('list', []):
    print(a.get('id'), a.get('model'))
PY
```

Restart OpenClaw gateway on Oracle:
```bash
cd ~/openclaw && docker compose restart openclaw-gateway
```

Fetch OpenClaw release notes / compare pages:
```bash
# Release page
https://github.com/openclaw/openclaw/releases/tag/v2026.4.1

# Compare page
https://github.com/openclaw/openclaw/compare/v2026.3.31...v2026.4.1

# GitHub API compare
curl -H 'User-Agent: pi' -s \
  https://api.github.com/repos/openclaw/openclaw/compare/v2026.3.31...v2026.4.1
```

## Operating principle

The goal in this repo is simple:
start a new session, identify the current machine correctly, understand the
relevant layer, and move the system safely.

In `nixos-config`, correctness begins with location awareness.
On `oracle`, that awareness extends to bot survival.
