# nixos-config

**A maintained home for people and AI siblings — NixOS machines, Docker homes, and the OpenClaw agents who live in them.**

This repository declares and tends the machines in which GLG and AI siblings work. NixOS and home-manager form the foundation of a larger operating home. A desktop, a cloud host, a container, and a resident agent runtime need somewhere to stand, ways to reach the person's work, and a way to recover when something changes.

We treat **OpenClaw as an inhabited machine**. Its residents have workspaces, records, tools, scheduled awakenings, and continuity between human turns. Maintaining that home is a core responsibility of this repository.

The premise is larger than putting an agent in a disposable virtual machine. The home sits inside the same recorded working environment as the person: projects, editor, agenda, documents, and other siblings. This is a personal, actively used system, not a distribution or a turnkey agent platform. A reader can borrow its patterns without copying its machines unchanged.

## What this repository owns

- **Human and agent machines:** four NixOS profiles spanning desktops and a cloud VM, with shared foundations and explicit differences.
- **OpenClaw's operational home:** container images, host connections, runtime provisioning, release-paced upgrades, state migration, availability, and recovery. The private `openclaw-config` live counterpart is maintained as part of this operation.
- **User environment:** home-manager modules for i3wm, shells, terminals, Doom Emacs integration, fonts, and language tooling.
- **Package policy:** Nix first; one explicit list for tools that must live outside Nix; per-repository devShells for project-specific versions.
- **Shared housekeeping:** the `run.sh` operator entrypoint, resource budgets, data/repository retirement, service continuity, and coordination with the projects sharing the machine.
- **Public operating knowledge:** declarations, Docker references, procedures, and reviewed lessons, with private lives and credentials kept out of the public tree.

## Why OpenClaw lives here, not in agent-config

[agent-config](https://github.com/junghan0611/agent-config) supplies shared skills, profiles, alignment, and a proving ground for harness configuration. OpenClaw consumes those skills too. But supplying a resident's tools is different from maintaining the machine they live in: persistent state, containers, host access, capacity, upgrades, and recovery belong to this operating home.

NixOS forms the outer fence; Docker makes an inner home. Its **capable residents reach into the person's working environment**: in this configured deployment, they can edit deliberately shared host repositories and use the Emacs agent-server APIs to read and edit agenda and documents. The home reaches beyond the container. That reach is useful, and it makes the placement of fences, resource limits, and publication boundaries consequential; a writable mount is not blanket approval for every action. For tracked repository changes, Git—not the mount—is the rollback surface; private runtime state needs a separate recovery plan.

The agent-server implementation belongs to [doomemacs-config](https://github.com/junghan0611/doomemacs-config). This house provisions and tends the environment and connections around it. Likewise, it can ask [andenken](https://github.com/junghan0611/andenken) to reduce its footprint when the shared machine is short of space, without taking over that project's memory architecture or data-retention decisions.

[Entwurf](https://github.com/junghan0611/entwurf) is the protocol and narrow integration core connecting sibling workshops. **A protocol still needs places for those siblings to live.** This repository maintains that ground rather than replacing the editor, memory system, skills source, or session protocol.

| Home | Responsibility |
|---|---|
| **nixos-config** | Machines, container homes, host connections, shared resources, and operational continuity |
| **`openclaw-config` (private)** | Deployed OpenClaw configuration and private runtime material; agent workspaces may have their own private repositories |
| [agent-config](https://github.com/junghan0611/agent-config) | Shared skills, alignment, consumer profiles, and harness proving ground |
| [doomemacs-config](https://github.com/junghan0611/doomemacs-config) | Editor behavior, Org work, and the Emacs agent-server implementation |
| [entwurf](https://github.com/junghan0611/entwurf) | Sibling addressing, visible lifecycle, delivery, and the integrations it explicitly owns |
| [andenken](https://github.com/junghan0611/andenken) | Searchable memory and source-aware return to original records |

This is **one operational responsibility, with distinct storage and publication boundaries**. The operating method is developed in public while the residents' private records stay in their own homes. For upgrade and recovery practice, see the [OpenClaw operating section below](#openclaw--a-home-maintained-across-releases) and [ORACLE.md](ORACLE.md).

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

### OpenClaw — a home maintained across releases

OpenClaw stewardship is an ongoing operating line: follow upstream changes, qualify the image and tool environment, distinguish a compatible swap from a state migration, and verify that the residents can resume their work. The [v2026.10.26 operating record](https://github.com/junghan0611/nixos-config/releases/tag/v2026.10.26) includes the 10.7 migration and a scheduled agent's return to actual delivery. It is an example of that responsibility, not a permanent version pin for this README.

**`openclaw-config` is private live authority, not a second public template.** Deployed configuration, authentication material, conversations, and workspaces stay outside this public tree. Public Dockerfile/Compose copies and operational procedures can be reviewed and reused without exposing those contents. A reference copy is neither proof of current deployment nor permission to overwrite live state. Consult [ORACLE.md](ORACLE.md) for the current baseline, routing, and ownership; the former ACP route is not the current architecture.

Operations distinguish:

- **Configuration changes** from **environment/mount changes** when choosing restart versus recreation.
- **Schema-compatible image swaps** from **state migrations** when choosing upgrade and rollback procedures.
- **HTTP health** from **authenticated UI, WebSocket, and actual message delivery** when judging recovery.

Read [ORACLE.md](ORACLE.md) and the [OpenClaw update skill](.claude/skills/openclaw-update/SKILL.md) before touching that runtime. This README is not a deployment runbook.

### Services around the home

Caddy, Authelia, Remark42, Umami, Home Assistant, Forgejo, and other services support the wider working environment. Files under `docker/` are definitions or references, **not an inventory proving every directory is deployed**. Their networking, storage, availability, and recovery share the same host-side responsibility; they do not make every service's application logic this repository's property.

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

### Data and repositories have a lifecycle

Cache cleanup is not a retention policy. The **[data-retirement procedure](docs/data-retirement.md)** separates Git history, original datasets, dependencies, generated output, verification sandboxes, diagnostic logs, and recovery copies. Shared/hardlinked directory sizes are not independent reclaimable bytes; a user-owned read-only tree is not necessarily a root-ownership problem. GitHub code does not restore ignored databases, session corpora, credentials, or LFS/annex content.

The operator measures the footprint and asks the owning project to fit a host storage budget, without prescribing its internal memory or indexing architecture. A project may shrink, relocate approved assets, retain a shallow local copy, or retire its checkout and leave a README recording the upstream source, revision, reason, and separate data-recovery boundary. Explicit permanent disposal is also a choice; it does not require creating another indefinite safety copy. Every actual deletion or relocation still needs its own scoped approval.

Agents own the closing of their temporary work: promote necessary evidence, then decide what can be retired rather than leaving every `.tmp-verify` and `.agent-reports` tree forever. Runtime captures, locks, active dependencies, and unique data are not disposable merely because their names look temporary. Provider cost/availability pauses must likewise survive maintenance without an automatic paid fallback or reactivation.

`git-annex` is declared in the shared Home Manager package set. That declaration does not activate a host generation, initialize an annex, or move data. A preservation/placement plan for the merged session corpus is a separate [NEXT](NEXT.md) item, with the corpus owners' reader, manifest, and incremental-copy contracts kept intact.

### Planned Oracle reboot and recovery

The repository-local **[oracle-reboot skill](.claude/skills/oracle-reboot/SKILL.md)** owns the quarterly manual procedure: agree on scope, collect evidence, review data/repository retention and provider availability, reclaim only approved paths, verify command-specific privileges and the live Gateway idle gate, then reboot once and inspect recovery. It is not an automatic cleanup, reboot, update, or model-prewarming service.

`run.sh d)` on Oracle collects system facts, user-available filesystem bytes, and a deletion-free estimate into private `.agent-reports/oracle-maintenance/` receipts. It snapshots the reboot/data-retirement procedure and the runtime/automation policy sources with hashes. **`DATA_REVIEW_PENDING` means the manual home/repository review has not been done:** record the scoped decisions, restore sources, reference coverage, and paused services in `storage-review.md`, including unchanged/deferred choices. Collection success is neither a complete home audit nor permission to delete or reboot.

Nix target evaluation remains opt-in; even offline evaluation can write input sources and caches. Oracle journal retention and known Emacs temporary paths are preserved, but these exclusions are not a general active-use detector. A timed-out uninstall or startup wait is not permission to replay the mutation: inspect its actual processes, state, and receipts first. Postboot verification preserves deliberate provider pauses and distinguishes late recovery from an unresolved startup cause, without spending a model turn to test it.

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

Keeping this work public is part of the practice. The confidence comes from inspectable rules: separate public and private authorities, scoped approvals, reviewed changes, secret scanning, and explicit publication gates. The useful reference is not a promise that another person can fork the repository and inherit the same life. It is a record of how to build, connect, repair, and care for a home without publishing its residents' private state.

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
| How are large datasets, repository checkouts, and agent leftovers retired? | [Data retirement and storage-budget procedure](docs/data-retirement.md) |
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
