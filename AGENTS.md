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
| `thinkpad` | work GUI machine + local AI | Ollama Vulkan (AMD 780M), home-manager GUI/user environment |

GUI-oriented user configuration is mainly relevant on:
- `laptop`
- `thinkpad`
- `nuc`

Those machines may need attention to i3, desktop tooling, fonts, editor setup,
and home-manager behavior.

`oracle` is different: it is primarily a minimal cloud runtime focused on
keeping OpenClaw and related services alive.

`thinkpad` also runs **Ollama with Vulkan** for local embedding inference.

## Ollama (ThinkPad)

ThinkPad runs `ollama-vulkan` as a NixOS service for local embedding.

| Item | Value |
|---|---|
| Package | `ollama-vulkan` (v0.12.11+) |
| GPU | AMD Radeon 780M (RADV PHOENIX), Vulkan 1.4 |
| Model | `qwen3-embedding:4b` (Q4, 2.5GB, 2560-dim) |
| Endpoint | `http://127.0.0.1:11434` |
| GPU offload | 100% (~3.7GB loaded) |
| Auto-start | yes (NixOS service, enabled) |

### Usage

```bash
# Check status
systemctl status ollama
ollama ps

# Embedding API
curl http://127.0.0.1:11434/api/embed -d '{"model":"qwen3-embedding:4b","input":"test"}'

# Pull/update model
ollama pull qwen3-embedding:4b
```

### Notes
- Vulkan driver provided by Mesa RADV (already in `hardware.graphics`)
- `OLLAMA_KEEP_ALIVE=10m` — model unloads after 10min idle
- Model stored in `/var/lib/ollama/models/` (NixOS default)
- gpu2i has same model but Q5_K_M quantization (different blob hash), not interchangeable

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

Current model routing (2026-04-15):
- Anthropic flat-rate access blocked for third-party apps (OpenClaw, pi)
- **default/main/bbot/glg fallback**: `github-copilot/claude-sonnet-4.6`
- **main**: at-rest/fallback is Copilot Sonnet 4.6, but preferred live mode is **ACPX + `claude-opus-4-6`** bound to `workspace/`
- **bbot** (`@glg_b_bot`): at-rest/fallback is Copilot Sonnet 4.6, but preferred live mode is **ACPX + `claude-opus-4-6`** bound to `workspace-bbot/`
- glg (힣봇): `github-copilot/claude-sonnet-4.6` — 가족 라이프 에이전트
- gpt: `openai-codex/gpt-5.4`
- gemini: `github-copilot/gemini-3.1-pro-preview`
- mini (힣봇미니, @glg_mini_bot): `github-copilot/gpt-5-mini` — 문서 포맷팅/교정 전담, 프로바이더 비종속 경량 봇
- subagents: `github-copilot/gpt-5.4`
- ACPX is enabled again; bind only the conversations that need Opus
- This keeps normal fallback on Sonnet to reduce cost/account risk while preserving Opus for deep-work threads

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
