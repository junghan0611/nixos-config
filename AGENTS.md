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

- Default to OpenRouter. Do not keep Ollama serving unless explicitly needed.
- Vulkan via Mesa RADV works (AMD Radeon 780M; validated `ollama-vulkan` + `qwen3-embedding:4b`).
- Enable local embedding intentionally; disable after use.

### Oracle is different

Oracle is a lean cloud runtime dedicated to keeping OpenClaw alive. Treat Oracle work as service reliability work. Real users depend on it including family members who cannot recover from config mistakes manually. Storage is limited — prioritize OpenClaw continuity, clean old generations, be conservative with disk growth.

---

## 2. Ownership model

### Two repos

| Repo | Path | Role |
|---|---|---|
| Private runtime SSOT | `~/openclaw/` | live `openclaw.json`, auth state, workspaces, runtime Docker files |
| Public operator / backup | `~/repos/gh/nixos-config/` | Dockerfile / compose backups, host NixOS context, this brief |

Live truth lives in `~/openclaw/`. Public backup / reference lives here. Never leak secrets or auth state into this repo. Do not assume the public copy is live, and do not assume the live copy is publishable.

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

### Model routing (as of 2026-04-22)

- Anthropic flat-rate blocked for third-party apps. GitHub Copilot removed except for `gemini`. Primary path is `openai-codex/gpt-5.4` (Codex OAuth via the $100 plan).
- **main**: at-rest `openai-codex/gpt-5.4`; preferred live = ACPX + `claude-opus-4-6` bound to `workspace/`.
- **bbot** (`@glg_b_bot`): at-rest `openai-codex/gpt-5.4`; preferred live = ACPX + `claude-opus-4-6` bound to `workspace-bbot/`.
- **glg** (가족 라이프): `openai-codex/gpt-5.4`.
- **gpt**: `openai-codex/gpt-5.4`.
- **gemini**: `github-copilot/gemini-3.1-pro-preview` — sole Copilot exception, until gemini-cli credit path returns.
- **mini** (`@glg_mini_bot`): `openai-codex/gpt-5.4-mini` — format / proofread only.
- **subagents**: `openai-codex/gpt-5.4`.
- **active-memory plugin**: `groq/openai/gpt-oss-120b` primary (paid tier), `google/gemini-3-flash` fallback. See below.

Check live values when identity matters:

```bash
python3 - <<'PY'
import json, pathlib
c = json.loads(pathlib.Path('~/openclaw/config/openclaw.json').expanduser().read_text())
for a in c.get('agents', {}).get('list', []):
    print(a.get('id'), a.get('model'))
PY
```

ACPX bind (when needed): `/acp spawn claude --bind here` then `/acp model anthropic/claude-opus-4-6`. The model override does not persist — see Gotchas.

### Active memory operational config (v2026.4.21)

`plugins.entries.active-memory.config` in `~/openclaw/config/openclaw.json` (gitignore):

| Key | Value | Note |
|---|---|---|
| `enabled` | `true` | |
| `agents` | `["glg", "gpt"]` | glg for family, gpt for self |
| `allowedChatTypes` | `["direct"]` | DM only |
| `model` | `groq/openai/gpt-oss-120b` | Groq **paid tier (2026-04-23 전환)**. 응답 ~11s, summary ~120자. free tier는 TPM=8K에 막혀 사용 불가 — Gotchas 참고 |
| `modelFallback` | `google/gemini-3-flash` | resolves to `gemini-3-flash-preview`. **주의**: `rate_limit` 케이스에서는 자동 승계되지 않음 (`decision=surface_error` 관측). 실질 활용은 `timeout`/장애 등 다른 실패 시에만 |
| `queryMode` | `"recent"` | upstream default; 2 user + 1 assistant turns as context |
| `thinking` | `"off"` | OpenClaw remaps per model — Gemini Flash → `minimal`, Pro → strip |
| `promptStyle` | `"balanced"` | |
| `timeoutMs` | `15000` | upstream `DEFAULT_TIMEOUT_MS`; schema ceiling 120000 |
| `maxSummaryChars` | `220` | upstream default |
| `persistTranscripts` | `false` | |
| `logging` | `true` | keep on while tuning |

Reference: `~/repos/3rd/openclaw/docs/concepts/active-memory.md` — "Paste This Into Your Agent".

### Memory / embedding layers

Oracle has two disjoint recall layers. Different dimensions, no auto-sync.

| Layer | Provider | Model | Dim | Storage | Bot access |
|---|---|---|---|---|---|
| OpenClaw session memory | Gemini API | `gemini-embedding-2-preview` | 768 | `~/openclaw/config/workspace*/memory/` + sessions | native `memorySearch` |
| andenken (org KB) | OpenRouter (query) / local vLLM (index) | `qwen/qwen3-embedding-4b` | 2560 | LanceDB (indexing host) | **skill needed — not deployed** |

- `agents.defaults.memorySearch` embeds only session + `memory/*.md`. `extraPaths: []`.
- `~/org:/home/node/org:ro` is for file access (denotecli / bibcli / botlog), not embedding. Do not remove.
- Native `memorySearch` is single-provider; it cannot blend the 2560d andenken index (dim mismatch). To give bots semantic org search, deploy the `semantic-memory` skill from `~/repos/gh/agent-config/skills/` with LanceDB reachable from Oracle and `OPENROUTER_API_KEY` exposed in the container.
- Today bots reach org via `denotecli` / `bibcli`. No semantic path yet.

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

### Secret inventory

| Var | Use | Source |
|---|---|---|
| `GEMINI_API_KEY` | active-memory fallback, memorySearch embedding (all bots), dreaming | `~/.env.local` SSOT |
| `GROQ_API_KEY` | active-memory primary | `~/.env.local` SSOT |
| `TELEGRAM_BOT_TOKEN_*` | per-bot Telegram | `~/openclaw/.env` (gitignore) |
| `OPENAI_CODEX_*` | Codex OAuth | `~/openclaw/.env` (gitignore) |

---

## 5. Operational workflow

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

### active-memory — model choice matters

- `openai-codex/gpt-5.4-mini` hits a 31.5s Codex CLI subprocess cold-start. Plugin `timeoutMs` is not honored across the subprocess boundary. Do not use Codex models in blocking hot-path plugins.
- `timeoutMs=8000` is too tight for groq — saw 9.7s boundary timeouts. Use 15000 (upstream default).
- Upstream `3f90d9266` (v2026.4.21) graceful degrade keeps replies alive on timeout; active-memory is an assist layer, not a critical path.
- **Groq free tier TPM=8K로 `gpt-oss-120b` 실사용 불가** (2026-04-23 관측). active-memory 프롬프트는 queryChars 1K라도 전체 input이 ~35K tok이라 매 호출 `413 Request too large`. 해결책: Groq Console에서 **paid tier 전환** ($10 선불, pay-per-use). 전환 후 호출당 ~7원, 응답 ~11s.
- **`modelFallback`은 `rate_limit` 케이스에서 자동 승계되지 않음** — 관측상 `decision=surface_error reason=rate_limit profile=-`로 끝나고 fallback 모델로 재시도하지 않음. 에러 메시지 본문이 그대로 summary로 노출되어 `summaryChars=50` 같은 작은 값으로 찍힘. `timeout`이나 일반 장애에서만 fallback이 탄다.
- **Gemini 3 Flash Lite는 Flash보다 느릴 수 있다** (2026-04-23 관측: Flash 13.4s vs Flash Lite 17.9s→timeout). 이름과 달리 active-memory의 input-heavy 워크로드(input:output ≈ 500:1)에서는 Lite의 TTFT가 더 길었음. Groq LPU의 decode 강점도 이 워크로드에서는 prefill이 지배적이라 제한적.

### ACPX — model override does not persist

As of 2026.4.15 + acpx 0.5.3, the ACP session model cannot be written into config. Schema strict fields on `AcpBindingSchema.acp` (`mode, label, cwd, backend`) and `AgentRuntimeAcpSchema` (`agent, backend, mode, cwd`) have no `model`. Only path: the in-chat slash command.

```
/acp spawn claude --bind here --cwd /home/node/.openclaw/workspace
/acp model anthropic/claude-opus-4-6
```

No host bypass exists. `openclaw acp` is only a bridge to external ACP clients; `message send` is one-way; editing `thread-bindings` files cannot substitute for spawn.

TTL recycles every 2h idle (`acp.runtime.ttlMinutes: 120`) and the model override evaporates. Active threads need manual re-set a few times per day until upstream acpx version bump.

2026-04-19 observation: `/acp model anthropic/claude-opus-4-7` CLI says "session ids resolved" but the actual served model is `claude-opus-4-6` — Anthropic flat-rate OAuth silently downgrades. Use `anthropic/claude-opus-4-6` explicitly; 4.7 needs separate billing.

2026-04-24 re-check on v2026.4.22: catalog now normalizes `anthropic/claude-opus-4-7` to 1M context (display-only fix), but routing is still OAuth-tier gated. **Policy: Claude access is company flat-rate OAuth only** — no direct Anthropic API billing. Stale `sk-ant-*` profile removed from `auth-profiles.json` (`openclaw capability model auth logout --provider anthropic`). 4.7 live routing is therefore out of our fixable scope; stay on 4.6 until tier changes.

Inspect truth from the host — never from inside an already-bound thread (text there may be forwarded to the Claude session as a user turn):

```bash
cd ~/openclaw && docker exec openclaw-gateway sh -lc 'node openclaw.mjs sessions --all-agents'
cd ~/openclaw && docker exec openclaw-gateway sh -lc 'sed -n "1,200p" /home/node/.openclaw/telegram/thread-bindings-default.json'
cd ~/openclaw && docker exec openclaw-gateway sh -lc 'sed -n "1,200p" /home/node/.openclaw/telegram/thread-bindings-bbot.json'
```

### ACPX — sessions do not auto-load workspace identity

A fresh `/acp spawn claude --bind here` Claude session does not read `workspace/IDENTITY.md / SOUL.md / USER.md / AGENTS.md / MEMORY.md`. Direct-runtime agents did (GlueClaw path historically), ACPX Claude sessions do not — claude-agent-sdk does not scan the workspace.

Fix on first turn after spawn:

```
workspace의 IDENTITY.md, SOUL.md, USER.md, AGENTS.md, MEMORY.md를 순서대로 읽고 시작하세요
```

Longer term: put a `CLAUDE.md` in workspace, or inject "read workspace/IDENTITY.md first" into `agents.list[].systemPromptOverride`, or use an ACPX bootstrap script when upstream enables it.

### ACPX — sessions do not know their own runtime

Asking an ACPX Claude session "what runtime are you on" returns whatever `workspace/MEMORY.md` claims — pure doc-driven inference, not ground truth. In 2026-04-19 testing the binding was explicitly `agent:claude:acp:...` on Anthropic Opus 4.6, but the bot reported "not acpx, I am on direct runtime" because MEMORY.md described GlueClaw as default.

Do not trust bot self-introspection. Verify from the host with `/acp status` outside the thread, or `docker exec ... sessions --all-agents`. Long-term: remove "default runtime" prose from workspace docs, or inject a systemPromptOverride like "you cannot know your own runtime; tell the user to check `/acp status`".

### ACPX — direct vs ACP-bound session confusion in host inspection

`openclaw sessions --all-agents` interleaves two kinds of rows:

- `agent:<id>:telegram:*` — **direct session** for the Telegram DM. Its `Model` column shows the agent's at-rest/fallback model (or a stale state from before the thread was ever `/acp spawn`-ed).
- `agent:claude:acp:*` — **ACP-bound session** actually serving the live bound conversation. This row's `Model` reflects the active `/acp model` override.

The live serving model is the ACP row, not the direct row. 2026-04-24 misread: interpreted a stale `claude-sonnet-4.6` on a `bbot direct` row as the live bbot state, and reported bbot as "fallback-mode" in a commit message. bbot was in fact on `claude-opus-4-6` via ACPX the whole time, confirmed by the bot's own self-reference ("acpx 임시 거처") in the user's Telegram reply.

Verification path (least effort first):

1. Ask the bot itself in-thread — it knows its runtime label now that the MEMORY.md GlueClaw prose is gone.
2. Read `/home/node/.openclaw/telegram/thread-bindings-<account>.json` → `targetSessionKey`. If it starts with `agent:claude:acp:`, the live path is ACPX and the serving model lives in that ACP session, not in any `direct` row.

### GlueClaw — runtime auto-injected providers from repo presence

OpenClaw plugin discovery walks mounted volumes. Any `openclaw.plugin.json` in a mounted path is a candidate provider. `~/repos/gh/glueclaw/openclaw.plugin.json` was re-injecting `glueclaw` / `sc` providers into every agent's `models.json` on container start, even though `641d497` had removed them at config level. Deleting the local repo broke the injection path. The GitHub fork (`junghan0611/glueclaw`) is preserved as history. See `openclaw-config@8243b3b`.

Lesson: if a provider is not wanted, the source directory must leave the mount, not just the config.

### ACP common failures

- `Authentication required` — confirm `~/.claude` is mounted; a simple `restart` after mount changes is not enough, recreate is.
- Only a few skills visible — broken absolute symlinks inside `~/.claude` pointing at `/home/junghan/repos/gh/...`. Add `~/repos/gh` as a compatibility mount; overlay `claude-skills` to `/home/node/.claude/skills`.
- `session-env ... ENOENT` — `~/.claude` must be **rw**.
- `ACP max concurrent sessions reached` — raise `acp.maxConcurrentSessions` or close stale sessions. Current setting: 3.
- `docker compose restart` alone insufficient after mount or env change — use `up -d --force-recreate`.

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
