# nixos-config AGENTS.md

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

- **Ollama Vulkan 상시 서비스 활성** (2026-05-07 재도입). 세션 임베딩 빈도가 높아 OpenRouter 단독 의존이 비효율적.
- Vulkan via Mesa RADV (AMD Radeon 780M); package auto-selected by `services.ollama.acceleration = "vulkan"`.
- Recommended model: `qwen3-embedding:4b` (2560-dim, andenken과 동일 차원).
- `OLLAMA_KEEP_ALIVE=10m` — idle 시 VRAM 자동 해제. 데몬은 살아 있되 GPU는 거의 0.
- History: 04-15 추가 → 04-17 revert (always-on 정책) → 05-07 재도입 (세션 임베딩 워크로드 증가).

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

### Model routing (OpenClaw 2026.5.7 baseline, 2026-05-08 두 번째 갱신)

LLM 호출은 모두 **Codex OAuth ($100 plan)** — Anthropic flat-rate / Copilot 양쪽 다 안 씀. Copilot 잔재(`gemini` agent)는 **삭제 예정**.

| Agent | Model | Workspace | 비고 |
|---|---|---|---|
| main | `openai-codex/gpt-5.4` | `workspace/` | 일반 |
| glg (가족) | `openai-codex/gpt-5.4` | `workspace-glg/` | `@glg_junghanacs_bot` |
| gpt | `openai-codex/gpt-5.4` | `workspace-gpt/` | 개인 |
| bbot | `openai-codex/gpt-5.4` | `workspace-bbot/` | `@glg_b_bot` |
| mini | `openai-codex/gpt-5.4-mini` | `workspace-mini/` | format / proofread only |
| gemini | `github-copilot/gemini-3.1-pro-preview` | `workspace-gemini/` | **Copilot 의존, 삭제 예정** — gpt-5.4로 통합하거나 제거 |
| subagents | `openai-codex/gpt-5.4` | — | |

보조 모델 (`/model <id>`로 in-thread 전환):

- `openai-codex/gpt-5.5` (Pi 0.70.0 catalog 자동 등록, 2026-04-25~)
- `deepseek/deepseek-v4-pro` / `deepseek-v4-flash` (`DEEPSEEK_API_KEY` 회사 quota, 2026-04-27~)

이미지 생성: `openai/gpt-image-2` via Codex OAuth (default since 2026-04-25). Google Imagen은 agent-directed 호출 시 사용 가능 (`GEMINI_API_KEY`로 banana/`gemini-3-flash-preview-image`).

ACPX disabled (`plugins.entries.acpx.enabled=false` + `acp.enabled=false`, 5.2가 `@openclaw/acpx` beta로 externalize). 재활성 절차는 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md).

5.7 업그레이드 (2026-05-08 두 번째): Codex OAuth 라우트 보존 (5.5 doctor rewrite 버그는 5.6에서 revert). `agent model: openai-codex/gpt-5.4` 그대로. ready 5.7s, 6 텔레그램 봇 정상 기동.

라이브 값 확인:

```bash
python3 - <<'PY'
import json, pathlib
c = json.loads(pathlib.Path('~/openclaw/config/openclaw.json').expanduser().read_text())
for a in c.get('agents', {}).get('list', []):
    print(a.get('id'), a.get('model'))
PY
```

### Active memory — disabled since 2026-05-03

`plugins.entries.active-memory.enabled: false` (5.2 안정성 검증 동안). 기존 config(Groq paid tier `gpt-oss-120b` primary, `google/gemini-3-flash` fallback, `timeoutMs: 15000`, `agents: ["glg", "gpt"]`) 그대로 보존.

재활성 시 참고: [docs/openclaw-gotchas.md "비활성 — active-memory"](docs/openclaw-gotchas.md). 모델 선택·timeout·rate_limit fallback 함정 정리됨. Upstream baseline은 `~/repos/3rd/openclaw/docs/concepts/active-memory.md`.

### Memory / embedding layers (since 2026-05-08 baseline stamp)

Oracle has two disjoint recall layers. Same embedding family now (Qwen3-4B 2560d), different storage and corpus.

| Layer | Provider | Model | Dim | Storage | Bot access |
|---|---|---|---|---|---|
| OpenClaw session+memory | OpenRouter | `qwen/qwen3-embedding-4b` | **2560** | `~/openclaw/config/memory/{agentId}.sqlite` (sqlite-vec + FTS5 trigram) | native `memorySearch` |
| andenken (org KB + sessions) | OpenRouter (query) / local vLLM (index) | `qwen/qwen3-embedding-4b` | 2560 | LanceDB (indexing host) | **skill needed — not deployed** |

- `agents.defaults.memorySearch.experimental.sessionMemory: true` since 2026-05-08 — sessions transcript indexing finally activated. Before that the `sources: ["sessions"]` line was being silently dropped by `normalizeSources()` because the experimental gate was closed. Verify with `openclaw memory status --agent <id>` showing `Sources: memory, sessions` and a non-zero `sessions ·` row under `By source:`.
- **5.2 baseline (2026-05-08 06:14 UTC)**: 6 agents force-reindexed → total 2540 chunks (1234 memory + 1306 sessions). main 73 / glg 1599 / gpt 436 / gemini 266 / mini 73 / bbot 93. tool-call heavy bots had aggressive sanitization on indexable content.
- **5.7 baseline (2026-05-08 10:30 UTC)**: same 6 agents force-reindexed → total **4981 chunks (1234 memory + 3747 sessions, +187% sessions)**. main 303 / glg 1831 / gpt 1923 / gemini 670 / mini 127 / bbot 127. memory chunks unchanged → chunking algorithm constant. sessions chunks grew because 5.7 transcript-hygiene preserves delivered assistant replies on disk and applies provider-specific sanitization only to outbound payloads, so indexing now sees full transcript instead of pre-stripped content. Tool-call heavy bots (main 8.4×, gpt 4.4×, gemini 2.5×) gained the most; family-dialog glg gained little (1.13×) because its turns survived 5.2 sanitization already.
- 5.7 신규 분리 리포트: `memory status --deep --json` 의 `vector` 객체 (`enabled / storeAvailable / semanticAvailable / available / extensionPath`) — sqlite-vec 로딩과 embedding provider가 별도로 진단됨. `vec0.so` 경로 확인 가능.
- FTS tokenizer = `trigram` for CJK. Korean particle stripping (25 particles, longest-match-first) automatic in query expansion.
- `~/org:/home/node/org:ro` is for file access (denotecli / bibcli / botlog), not embedding. Do not remove.
- andenken layer is still separate by *storage* (LanceDB vs sqlite) and *corpus* (org KB vs OpenClaw sessions/memory). To give bots semantic org search, deploy the `semantic-memory` skill from `~/repos/gh/agent-config/skills/` with LanceDB reachable from Oracle. Now that both layers run at 2560d, dim mismatch is no longer the blocker — only deployment is.
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

| Agent | Workspace | Skill scope | Reason |
|---|---|---|---|
| main | `workspace/` | all | generalist deep work |
| glg | `workspace-glg/` | all | family life agent |
| gpt | `workspace-gpt/` | all | GPT generalist |
| gemini | `workspace-gemini/` | all | Gemini generalist |
| bbot | `workspace-bbot/` | all | ACP Opus workspace (Sonnet fallback) |
| mini | `workspace-mini/` | denotecli only | format / proofread — minimal |

### Deployment rules

- `run.sh k)` installs to `main` first, then rsyncs to glg / gpt / gemini / bbot, then syncs to `claude-skills/`.
- mini is separate — only listed skills copied, rest removed.
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
