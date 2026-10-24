# nixos-config

**A reproducible place to live and work — NixOS, home-manager, and the host boundary for human–AI collaboration.**

This is a personal, actively used configuration, not a distribution or a turnkey agent platform. It declares the operating systems and user environments beneath the editor, development tools, and self-hosted services. Desktop and cloud profiles share a vocabulary without pretending to be identical machines.

## What this repository owns

- **Hosts:** four NixOS profiles spanning x86_64 desktops and an aarch64 cloud VM.
- **User environment:** home-manager modules for i3wm, shells, terminals, Doom Emacs integration, fonts, and language tooling.
- **Package policy:** Nix first; one explicit list for tools that must live outside Nix; per-repository devShells for project-specific versions.
- **Operations:** a shared `run.sh` entrypoint, device-aware disk cleanup, rollback procedures, and service-operation handbooks.
- **Public service references:** Docker definitions and operational lessons, with private runtime state and credentials deliberately outside this repository.

The editor's own configuration belongs to [doomemacs-config](https://github.com/junghan0611/doomemacs-config). Shared agent skills and profiles belong to [agent-config](https://github.com/junghan0611/agent-config); sibling-session connections to [entwurf](https://github.com/junghan0611/entwurf); searchable memory to [andenken](https://github.com/junghan0611/andenken). This repository provides their operating ground, not a replacement for them.

## Current baseline

The flake follows **NixOS 26.05** and **home-manager release-26.05**, pinned by `flake.lock`. Narrow overlays supply packages whose requirements exceed the stable channel, with reasons and retirement conditions documented beside the declarations. The configured Emacs package is **31.1**; deployed generations still need verification on each host.

| Flake profile | Architecture | Role |
|---|---|---|
| `oracle` | aarch64-linux | Cloud host and self-hosted service operations |
| `nuc` | x86_64-linux | Home server |
| `laptop` | x86_64-linux | Personal desktop environment |
| `thinkpad` | x86_64-linux | Mobile development environment |

These names are flake selectors. A shared module is not evidence that every host has already switched to the same generation.

### Desktop and development

- **i3wm** with home-manager-managed keybindings, py3status, dunst, picom, and rofi; GNOME is an alternative specialisation.
- **Doom Emacs integration:** package selection, launchers, daemon-related configuration, and Org clock integration with the desktop. Editor behavior remains in the separate editor repository.
- **Language modules:** Python, Nix, C/C++, LaTeX, Shell, and Elisp, alongside Git and CLI tooling.
- **Optional local AI:** Ollama/Vulkan remains available in the mobile profile but does not auto-start. See [THINKPAD.md](THINKPAD.md) before enabling it.

### One package policy, three layers

| Layer | Authority | Purpose |
|---|---|---|
| 1 | Nix declarations → `/nix/store` | System and home packages, including Node and pnpm |
| 2 | [`scripts/external-packages.sh`](scripts/external-packages.sh) | Explicit external tools, npm globals, and vendor-managed binaries |
| 3 | A consuming repository's flake/devShell | Project-specific versions, still supplied through Nix |

Do not install a second global pnpm or use Corepack to compete with the Nix-provided version. The shared pnpm policy and PATH live in [`users/junghan/modules/shell.nix`](users/junghan/modules/shell.nix). A project that genuinely needs a different version should isolate it in its devShell.

A `broken` package marker is a reason to investigate, not automatically to bypass Nix. Any local exception must state the broken path, the permitted use, and when the exception can be removed; the Datasette overlay in `flake.nix` is one such scoped exception.

### Cloud services and OpenClaw

The cloud host supports services such as Caddy, Authelia, Remark42, Umami, Home Assistant, Forgejo, and OpenClaw. Files under `docker/` are service definitions or references, **not an inventory proving every directory is deployed**.

OpenClaw operations are owned here because upgrades cross the host–container boundary: disk capacity, mounts, networking, authentication, and recovery all affect service continuity. The operational handbook records a **2026.10.4** baseline and six bot workspaces. The former ACP route has been retired in this deployment; do not follow old ACP installation instructions as the current architecture.

**Private live state is not the public configuration.** OpenClaw's live configuration, credentials, conversations, and workspaces live outside this public repository. Public Dockerfile/Compose copies are references, not permission to overwrite that state. Model routing changes frequently; consult the current baseline at the top of [ORACLE.md's routing section](ORACLE.md#model-routing-현재-openclaw-2026104-baseline), not an old model list copied into a README.

Operations distinguish:

- **Configuration changes** from **environment/mount changes** when choosing restart versus recreation.
- **Schema-compatible image swaps** from **state migrations** when choosing upgrade and rollback procedures.
- **HTTP health** from **authenticated UI, WebSocket, and actual message delivery** when judging recovery.

Read [ORACLE.md](ORACLE.md) and the [OpenClaw update skill](.claude/skills/openclaw-update/SKILL.md) before touching that runtime. This README is not a deployment runbook.

## Start here

Review the host and hardware declarations before using them. These configurations contain personal paths and operational assumptions; do not switch an unrelated machine to a profile unchanged.

```bash
git clone https://github.com/junghan0611/nixos-config.git
cd nixos-config

# Review hosts/<profile>/ and users/junghan/ first.
# Build without activating (example profile):
sudo nixos-rebuild build --flake .#nuc

# Activate only on the intended host, after inspecting the result:
sudo nixos-rebuild switch --flake .#nuc

# Shared operator menu:
./run.sh
```

Use the existing `run.sh` paths for recurring operations instead of inventing parallel scripts. Inspect changes to `flake.lock` before rebuilding after `nix flake update`. NixOS generations provide a rollback surface, but do not roll back external databases or private container state.

### Disk cleanup starts with measurement

```bash
bash scripts/diskclean.sh deep --dry-run
# Oracle: collect a persistent, private maintenance baseline without deleting anything.
bash scripts/oracle-maintenance-preflight.sh
```

Nix GC cannot reclaim paths still rooted by repository `.direnv` or `result` links, and it does not own browser, compiler, or application caches. The cleanup script accounts for device roles, but `safe` and `deep` execute whole bundles: partial approval requires individual commands. Age-based GC does not guarantee a previous rollback generation. pnpm-store and Docker cleanup are separate opt-ins: live Node sessions and service containers make indiscriminate pruning unsafe.

### Planned Oracle reboot and recovery

The repository-local **[oracle-reboot skill](.claude/skills/oracle-reboot/SKILL.md)** owns the quarterly manual procedure: agree on scope, collect evidence, reclaim only approved paths, verify command-specific privileges and the live Gateway idle gate, then reboot once and inspect recovery. It is not an automatic reboot, update, or model-prewarming service.

`run.sh d)` on Oracle collects system facts and a deletion-free estimate into private `.agent-reports/oracle-maintenance/` receipts, including copies and hashes of the procedure used. Nix target evaluation is opt-in; even offline evaluation can write input sources and caches. Oracle journal retention and known Emacs temporary paths are preserved, but these exclusions are not a general active-use detector.

**Menu behavior change on all four profiles:** opening `run.sh` no longer clears the GitHub SSH control socket. Choose **g** explicitly when that repair is needed. Other hosts retain their existing **d** disk-inspection path.

## Layout

```text
hosts/                    Per-device declarations
users/junghan/            home-manager and user modules
modules/                  Shared NixOS modules
lib/                      System construction helpers
docker/                   Public service definitions and references
scripts/                  Package and maintenance operations
templates/                Installation / infrastructure templates
docs/                     Guides and operational lessons
run.sh                    Shared human-and-agent entrypoint
```

## Why keep the environment in text?

A computer is not an opaque appliance; it is a workshop that can be inspected and repaired. When a person and an AI agent work together, neither should have to guess which executable, package source, or service boundary is in play.

**Reproducibility is not sameness.** A desktop and a cloud server need different services. What they can share is an explicit account of where software comes from, who owns each setting, and how to return after a failed change. Agents can help maintain that account without inheriting permission to deploy, spend, or publish.

See the [archived blacksmith's workshop essay](docs/deprecated/20251018T184200--nixos-재현성과-대장장이의-도구철학__nixos_philosophy_reproducibility_master.md) and the [steward's narrative](https://notes.junghanacs.com/botlog/20260615T100659).

## Reading map

| Question | Source |
|---|---|
| What is the current operating baseline? | [AGENTS.md](AGENTS.md) |
| What should the next session do? | [NEXT.md](NEXT.md) |
| Why were operational choices made? | [ROADMAP.md](ROADMAP.md) |
| What changed in released snapshots? | [CHANGELOG.md](CHANGELOG.md) |
| How is the cloud runtime operated? | [ORACLE.md](ORACLE.md) |
| How is a planned Oracle reboot performed and verified? | [oracle-reboot skill](.claude/skills/oracle-reboot/SKILL.md) |
| What recurring runtime failures should not be repeated? | [OpenClaw gotchas](docs/openclaw-gotchas.md) |
| What runs without a human turn? | [Automation SSOT](docs/openclaw-automations.md) |
| How are packages added? | [Package policy](AGENTS.md) · [external package list](scripts/external-packages.sh) |
| What are the desktop keybindings? | [i3 home-manager module](users/junghan/modules/i3.nix) |

## Related and inspiration

- [openglg-config](https://github.com/junghan0611/openglg-config) — companion for portable service stacks and home-manager on non-NixOS hosts. This repository owns the NixOS host; the companion addresses environments where only a user shell is available.
- [hlissner/dotfiles](https://github.com/hlissner/dotfiles) · [ElleNajt/nixos-config](https://github.com/ElleNajt/nixos-config) — configuration and home-manager patterns.
- [Oracle Cloud NixOS guide](https://mtlynch.io/notes/nix-oracle-cloud/) — installation reference, adapted under `templates/nixos-oracle-vm/`.
- [Digital garden](https://notes.junghanacs.com) — connected notes rather than an operational runbook.

## License

MIT. Maintained by [Junghan Kim](https://github.com/junghan0611).
