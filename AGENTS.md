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

Important invariant:
- main uses `workspace/`, not `workspace-main/`

Current model routing (2026-04-06):
- Anthropic flat-rate access blocked for third-party apps (OpenClaw)
- All Claude models routed through GitHub Copilot Pro+ tokens
- glg (힣봇): `github-copilot/claude-sonnet-4.6` — family life-support, fast response
- main: `github-copilot/claude-opus-4.6` — deep work
- Parallel strategy: pi-telegram based persistent pi bot on Oracle under evaluation

## OpenClaw change policy

When changing OpenClaw behavior, prioritize continuity over elegance.

Rules:
- change the default model only when that is the real need
- do not silently delete old model entries just because the default changed
- preserve manual reversibility for the operator
- avoid introducing failover unless explicitly requested
- test real execution, not just config syntax

For family-facing bots:
- avoid workflows that require manual model switching
- prefer the least surprising behavior
- optimize for stable replies

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
Deployment and synchronization are handled via `agent-config` and runtime
workspace copies.

When that context matters, verify the current source of truth before changing
runtime workspaces.

Examples:
- `agent-config` for skills and semantic memory tooling
- `~/openclaw/config/workspace*` for deployed runtime copies

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
