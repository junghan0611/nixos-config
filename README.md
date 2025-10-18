# nixos-config

**Declarative, reproducible computing environment with NixOS and home-manager**

[한국어 문서](./README-KO.md)

---

## Overview

A comprehensive NixOS configuration for building **identical computing environments anywhere**, designed for seamless collaboration between humans and AI agents.

### Goals

- **Reproducibility**: Declarative configuration as code
- **Scalability**: From Oracle Cloud Free Tier VMs to local machines
- **Consistency**: Regolith Linux i3wm workflow with Doom Emacs integration
- **Transparency**: AI-agent friendly declarative systems

---

## Features

### Window Manager

**i3wm** (default)
- Regolith 3 style: gaps, borders, custom colors
- py3status + Emacs org-clock integration
- Declarative config via home-manager
- picom compositor

**GNOME** (specialisation)
- Alternative desktop environment
- Boot menu selection

### Emacs Integration

- [dotdoom-starter](https://github.com/junghan0611/dotdoom-starter) integration
- mu4e email client (mbsync)
- org-mode task tracking on status bar
- edit-input: Edit web forms with Emacs
- rofi-pass integration

### Development Environment

**Modular per-language configs:**
- Python, Nix, C/C++, LaTeX, Shell, Elisp
- Tools: gh, lazygit, aider-chat, direnv

### home-manager Modules

```
users/junghan/modules/
├── shell.nix, i3.nix, dunst.nix, picom.nix
├── emacs.nix, email.nix, fonts.nix
└── development/  # Per-language
```

**Before:** 341 lines → **After:** 118 lines (-65%)

---

## Installation

### Prerequisites

- NixOS 25.05+
- Flakes enabled

### Quick Start

```bash
git clone https://github.com/junghan0611/nixos-config.git
cd nixos-config

# Edit configuration
vim hosts/nuc/configuration.nix

# Build
sudo nixos-rebuild switch --flake .#nuc
```

### Oracle Cloud VM

Based on [mtlynch.io Oracle Cloud NixOS Guide](https://mtlynch.io/notes/nix-oracle-cloud/) (with modifications)

See `templates/nixos-oracle-vm/`

---

## Usage

```bash
# Rebuild
sudo nixos-rebuild switch --flake .#nuc

# Update
nix flake update

# Email sync
mbsync -a
```

### Keybindings (i3)

| Key | Action |
|-----|--------|
| `Mod+d` | rofi launcher |
| `Mod+p` | rofi-pass |
| `Mod+i` | edit-input (Emacs) |
| `Mod+c` | Toggle picom |
| `Mod+n` | Close notification |

---

## Philosophy

### Reproducibility: The Blacksmith's Forge

> "A computer is not a black box—it's the **blacksmith's forge**.
> The master controls the tools, the apprentice (agent) assists, but tool selection remains under the master's command."

**Core Insight**: Reproducible computing environments are essential for human-AI collaboration.

**Key Principles**:

**1. Reproducibility = Trust**
```
Traditional OS:
  - "What's installed?" → Unknown
  - "What version?" → Unclear
  - Agent: Guesses, trial-and-error

NixOS:
  - configuration.nix = Single source of truth
  - Agent: Precise, reproducible actions
```

**2. Master's Control**
```
Blacksmith (Human):
  - Selects tools (nixos-config)
  - Controls environment
  - Final judgment

Tools (Computer):
  - Keyboard, editor, languages
  - Extended body

Apprentice (AI Agent):
  - Assists, but doesn't choose tools
  - Tool selection = Master's domain
```

**3. Scale: Desktop → Data Center**
```
Same syntax, infinite scale:
  - Desktop: configuration.nix
  - Server: configuration.nix (same pattern)
  - Cluster: flake.nix (same philosophy)

→ Learn once, apply everywhere
```

**4. Transparency for Agents**
```yaml
What agents need to know:
  - Your tools? (environment.systemPackages)
  - Your editor? (programs.emacs)
  - Your languages? (pkgs.python311)

nixos-config provides:
  - Complete environment specification
  - Exact versions (flake.lock)
  - Full transparency

→ Agents generate precise, working code
```

**Read More**: [NixOS: Reproducibility and the Blacksmith's Philosophy](./docs/20251018T184200--nixos-재현성과-대장장이의-도구철학__nixos_philosophy_reproducibility_master.md)

---

## References

### Inspiration

- [hlissner/dotfiles](https://github.com/hlissner/dotfiles) - Doom Emacs maintainer's NixOS config
- [ElleNajt/nixos-config](https://github.com/ElleNajt/nixos-config) - home-manager patterns
- [mtlynch.io Oracle Cloud NixOS](https://mtlynch.io/notes/nix-oracle-cloud/) - Oracle VM guide (modified for templates/)

### Related

- [dotdoom-starter](https://github.com/junghan0611/dotdoom-starter) - My Doom Emacs config

---

## Documentation

See `docs/` (denote format):
- Analysis documents
- Integration plans
- Strategy guides

---

## License

MIT License

## Author

**Jung Han (junghanacs)**
- [힣's Digital Garden](https://notes.junghanacs.com)
- [@junghan0611](https://github.com/junghan0611)
