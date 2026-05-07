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

### Model routing (as of 2026-05-03, OpenClaw 2026.5.2 — upgraded from 4.23 after 4.29 lazy-staging reproduction; ACPX disabled)

- Anthropic flat-rate blocked for third-party apps. GitHub Copilot removed except for `gemini`. Primary path is `openai-codex/gpt-5.4` (Codex OAuth via the $100 plan).
- **ACPX disabled** as of 2026-05-03: `plugins.entries.acpx.enabled=false` + `acp.enabled=false`. 5.2 externalized ACPX behind `@openclaw/acpx` beta package; we do not install it. The "preferred live = ACPX + claude-opus-4-6" path is retired until needed again. All bots run on at-rest model only.
- **main**: `openai-codex/gpt-5.4` (workspace `workspace/`).
- **bbot** (`@glg_b_bot`): `openai-codex/gpt-5.4` (workspace `workspace-bbot/`).
- **glg** (가족 라이프): `openai-codex/gpt-5.4`.
- **gpt**: `openai-codex/gpt-5.4`.
- **gemini**: `github-copilot/gemini-3.1-pro-preview` — sole Copilot exception, until gemini-cli credit path returns.
- **mini** (`@glg_mini_bot`): `openai-codex/gpt-5.4-mini` — format / proofread only.
- **subagents**: `openai-codex/gpt-5.4`.
- **active-memory plugin**: disabled. Original config preserved (`groq/openai/gpt-oss-120b` primary, `google/gemini-3-flash` fallback) but `enabled: false` while we verify 5.2 stability.
- **Auxiliary `openai-codex/gpt-5.5`** (since 2026-04-25, OpenClaw 2026.4.23): auto-registered via Pi 0.70.0 catalog metadata. Not a default; use `/model openai-codex/gpt-5.5` in-thread for a single-session switch. Base models unchanged.
- **Auxiliary `deepseek/deepseek-v4-pro` / `deepseek-v4-flash`** (since 2026-04-27, OpenClaw 2026.4.24): registered in `agents.defaults.models`. Authenticated via `DEEPSEEK_API_KEY` env (company key, generous quota). Use `/model deepseek/deepseek-v4-pro` inside `main` (`@junghan_openclaw_bot`) to switch. Base remains `openai-codex/gpt-5.4`.
- **Image generation default**: `openai/gpt-image-2` via Codex OAuth (since 2026-04-25). Google Imagen (~50 KRW/image) remains available through provider catalog for agent-directed calls. Two paths coexist; agents pick per request.

Check live values when identity matters:

```bash
python3 - <<'PY'
import json, pathlib
c = json.loads(pathlib.Path('~/openclaw/config/openclaw.json').expanduser().read_text())
for a in c.get('agents', {}).get('list', []):
    print(a.get('id'), a.get('model'))
PY
```

ACPX bind (currently disabled — re-enable steps if revived): set `plugins.entries.acpx.enabled=true` + `acp.enabled=true`, restart gateway, then `/acp spawn claude --bind here` and `/acp model anthropic/claude-opus-4-6`. 5.2 requires `npm i @openclaw/acpx` because it externalized the package; verify via `node openclaw.mjs plugins list`. The model override does not persist — see Gotchas.

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

### Secret inventory

| Var | Use | Source |
|---|---|---|
| `GEMINI_API_KEY` | active-memory fallback, memorySearch embedding (all bots), dreaming | `~/.env.local` SSOT |
| `GROQ_API_KEY` | active-memory primary | `~/.env.local` SSOT |
| `TELEGRAM_BOT_TOKEN_*` | per-bot Telegram | `~/openclaw/.env` (gitignore) |
| `OPENAI_CODEX_*` | Codex OAuth | `~/openclaw/.env` (gitignore) |

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

### 4.24 → 4.26 / 4.29 lazy-staging incident — resolved on 5.2 (2026-05-03)

**RESOLVED on 5.2.** 4.23 → 4.29 attempt on 2026-05-03 reproduced the same lazy-staging hot-path incident — first inbound message triggered `[plugins] alibaba/runway/tts-local-cli staging bundled runtime deps` mid-hot-path with `eventLoopDelayMaxMs=17213.4` and `[telegram] sendChatAction failed`. Same incident class as 4.26. 4.29 brought the diagnostic timeline + slow-host-startup fixes but no structural fix for "scope of plugin runtime preloads". Jumped directly to **5.2** which carries the structural fix:

- `Plugins/runtime: scope broad runtime preloads to the effective plugin ids derived from config, startup planning, configured channels, slots, and auto-enable rules instead of importing every discoverable plugin`
- `Tools/plugins: cache plugin tool descriptors captured from api.registerTool(...) so repeated prompt-time planning can skip plugin runtime loading while execution still loads the live plugin tool` (#76079)

5.2 verified: ready 7.3s first boot / 5.3s warm boot, CPU 0.23% idle, MEM 246 MiB, **zero `staging bundled runtime deps` lines on hot path**. Family-bot smoke test passed (10:55 KST, glg_gpt_bot replied intact). Single 24s liveness spike on first cold-message only (Codex OAuth + 49k context hydration), idle thereafter. Full operational record in `~/openclaw/README.md` Change history (entry dated 2026-05-03 / version 5.2).

**Operational lessons retained from the incident** (these still apply for any future jump where structural fix is unproven):

- *No more two-version jumps on family-traffic gateway* unless the target version has a verified structural fix and we have a no-traffic window. The 5.2 jump was a 6-version skip but justified by the explicit `scope broad runtime preloads` fix and zero family traffic during deploy.
- *Stage on a non-family agent first* when uncertain. For 5.2 we used the entire deploy as a no-traffic-window test instead.
- *Family responsiveness is the SLO.* If the operator notices latency, that is a P0 — investigate before the next upgrade ships, not after.
- *Trust the structural-fix release tag* but bench-test on a no-traffic window first. "Latest is best" was wrong for 4.24/4.25/4.26/4.29 (no fix), correct for 5.2 (fix shipped).

Historical record (kept for context — do not relax the policy without re-reading):

### 4.24 → 4.26 latency regression — wait-and-watch policy (2026-04-28, superseded by 5.2 fix above)

A two-version jump from 4.24 to 4.26 produced a service-quality incident on the family-traffic gateway. Symptoms operators care about:

- Operator and family reported "responses that used to come instantly now take all day."
- `[diagnostic] stuck session: state=processing age=164s queueDepth=1` — multiple agents (`gpt`, `glg`) on Telegram direct chats stayed pinned in *processing* for 2~3 minutes per turn.
- Gateway PID showed **102% CPU** on a single node thread with no child spawns — main loop hot-spinning while inbound queue stalled.
- 4.26 boot itself stretched to ~88 s (vs ~11 s on 4.23) due to OpenRouter + LiteLLM pricing fetches both hitting their 60 s timeout.
- The same stuck-session signature appeared on a fresh 4.26 boot **before** any TTS config was added, so this was *not* operator config error.

Most likely root cause (post-incident, not yet upstream-confirmed):

- 4.25's cold-persisted plugin registry collides with `doctor --fix` in our deployment. The registry rebuild dropped the active plugin set from 7 (acpx, browser, device-pair, memory-core, phone-control, talk-voice, telegram) to 3 (acpx, memory-core, telegram). The remaining plugins moved to *lazy on-demand stage*, which is fine for cold paths but ruinous on warm family chat — the first inbound message after that point triggers `npm install` of `node-edge-tts`, `pdfjs-dist`, `@mozilla/readability`, `linkedom` mid-hot-path, and that is what `[diagnostic] stuck session` reflects.
- 4.24 already showed perceptible latency drift that we under-weighted at the time (the 11-day silent `runs.sqlite` malformed retry was the *visible* symptom; latency drift was the unrecorded one).

Resolution executed: emergency rollback to **4.23** (latest known-good for *both* response latency and `gpt-image-2` Codex-OAuth image generation, which the operator's father uses; 4.22 would lose image generation since it requires a separate `OPENAI_API_KEY`). Verified post-rollback: ready in 11.3 s, 6 plugins loaded including `talk-voice`, CPU 0.07 % idle, all 6 Telegram providers up, no stuck-session diagnostics. Full operational record in `~/openclaw/README.md` Change history (entry dated 2026-04-28 / version 4.23).

**Standing policy from this incident (operator-stamped, do not relax silently):**

- *No more two-version jumps on the family-traffic gateway.* `4.24 → 4.26` was the violation. Every minor bump goes one step at a time.
- *Wait-and-watch on 4.24 / 4.25 / 4.26.* Re-evaluate only when **4.27+ ships with the lazy-staging pre-warmer fix** or after community confirmation of stable family deployments. "Latest is best" no longer applies to this gateway.
- *Stage on a non-family agent first* (e.g. `bbot` or `gpt`) for ≥24 h before promoting to `glg` / `default`. Watch `[diagnostic] stuck session` lines as the canary; even one is grounds to pause.
- *Family responsiveness is the SLO.* If the operator notices latency, that is a P0 — investigate before the next upgrade ships, not after.

Counter-temptation note: 4.26 carries genuinely useful fixes (ACP idle-wakes #72080, Codex token cache #69298, WAL checkpoint #72774, Anthropic prefill stripping #72739/#72556). The policy above is *not* a verdict that those fixes are wrong; it's a verdict that the cold-registry + lazy-staging delivery in 4.25/4.26 is incompatible with our deployment shape today. Do not lose sight of those fixes — re-test them when 4.27+ lands.

### bonjour plugin — disable on Oracle Cloud + Docker (since 2026-04-24)

OpenClaw 2026.4.24 split bonjour LAN discovery into a default-on plugin (`@homebridge/ciao`). On Oracle Cloud + Docker with IPv6 disabled (our setup), the mDNS probe fails and emits `Unhandled promise rejection: CIAO PROBING CANCELLED` every ~30s, taking gateway down with it (restart loop). LAN discovery has no value to us — we reach gateway via SSH tunnel, not Bonjour.

Fix: set `plugins.entries.bonjour: { enabled: false }` in `openclaw.json`. Plugin count drops from 9 back to 8 (matching 4.23 behavior). No functional loss.

### Adding non-default models (since 2026-04-27)

OpenClaw 2026.4.24 narrowed default `openclaw models list` to *configured* rows only, and 4.24's `/models add` slash command is deprecated. To make a new model usable from `/model <id>` slash command:

1. Sync the provider API key from `~/.env.local` to `~/openclaw/.env` (preserves the SSOT pairing rule).
2. Add `provider/model-id: {}` under `agents.defaults.models` in `openclaw.json`.
3. `docker compose restart openclaw-gateway`.
4. Verify with `node openclaw.mjs models` (note: no subcommand) — look for the model in the `Configured models` line.

`models list --all` exists but is slow (>60s timeout in our container) — don't rely on it for verification.

### rw mount expansion — git is the rollback surface (2026-04-25)

Since the 4.23 upgrade, `~/repos/gh:rw` and `~/org/{meta,bib,notes}:rw` are open. There is no filesystem enforcement against unintended writes — rollback relies on `git status` / `git diff` / `git restore`.

- Monitor the first hour after any rw-expanding mount change.
- An unintended write into `~/org/diary.org` (or anything else under `~/org:ro`) means the mount config regressed.
- `~/repos/work` remains ro deliberately — never widen this without consulting the company code-safety policy.
- `nixos-config` is a symlink inside `~/repos/gh/` (→ `~/nixos-config`). Container cannot follow it. Agent edits to nixos-config must route through the host, not the bot runtime.

### Codex catalog — models.json drift on upgrade is expected (2026-04-25)

OpenClaw 2026.4.23 synthesizes the `openai-codex/gpt-5.5` OAuth row automatically. After the upgrade, `git diff config/agents/*/agent/models.json` shows `gpt-5.4 → gpt-5.5` in the Codex provider block. This is catalog-layer drift; the **serving model** is still `openai-codex/gpt-5.4` because `agents.list[].model` pins it explicitly. Verify with:

```bash
python3 - <<'PY'
import json, pathlib
c = json.loads(pathlib.Path('/home/junghan/openclaw/config/openclaw.json').read_text())
for a in c['agents']['list']:
    print(a['id'], a.get('model'))
PY
```

### Dreaming — decoupled from heartbeat (since 2026.4.23)

Upstream #70737 moves dreaming into an isolated lightweight agent turn. It now runs even when `heartbeat` is off for the default agent and is no longer skipped by `heartbeat.activeHours`. `openclaw doctor --fix` migrates stale main-session dreaming jobs in persisted cron configs to the new shape. Our deployment had no stale entries at 4.22 → 4.23 upgrade.

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
