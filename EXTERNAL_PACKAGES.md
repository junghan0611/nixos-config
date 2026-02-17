# External Packages (Non-NixOS)

Packages installed outside of NixOS declarative configuration.
These are managed by external tools (uv, cargo install, go install, etc.)
and must be reinstalled manually on new systems or after NixOS rebuilds.

> For NixOS-managed packages, see [PACKAGE_GUIDE.md](./PACKAGE_GUIDE.md)

## uv tool install

Python CLI tools installed via [uv](https://docs.astral.sh/uv/).
Installed to `~/.local/share/uv/tools/` with isolated virtualenvs.

| Package | Version | Description | Installed |
|---------|---------|-------------|-----------|
| orchat | 1.4.5 | OpenRouter CLI chat client | 2025-02-11 |

### Commands

```bash
# List installed tools
uv tool list

# Install
uv tool install <package>

# Upgrade
uv tool upgrade <package>

# Uninstall
uv tool uninstall <package>
```

## cargo install

Rust CLI tools installed via cargo. (None yet)

## go install

Go CLI tools installed via go install. (None yet)

## pnpm add -g

Node.js CLI tools installed via [pnpm](https://pnpm.io/).
Installed to `~/.local/share/pnpm/global/`.

| Package | Version | Description | Installed |
|---------|---------|-------------|-----------|
| cline | 2.0.5 | Autonomous coding agent CLI (terminal) | 2025-02-11 |
| openclaw | latest | AI Gateway (Telegram + Claude Code) | 2025-02-12 → Docker로 이전 |

### Commands

```bash
# List installed tools
pnpm list -g --depth=0

# Install
pnpm add -g <package>

# Upgrade
pnpm add -g <package>@latest

# Uninstall
pnpm remove -g <package>
```

## OpenClaw (Oracle VM - Docker)

Oracle VM에서 지식베이스 탐구용 AI 에이전트. Docker로 운영.

> 상세 설정: [`docker/openclaw/SETUP.org`](../docker/openclaw/SETUP.org)

```bash
# 배포
cd ~/openclaw && docker compose up -d openclaw-gateway

# SSH 터널 (로컬에서)
ssh -N -L 18789:127.0.0.1:18789 junghan@<oracle-vm-ip>
# → http://127.0.0.1:18789/
```

- Telegram으로 모바일 상시 접근 (Galaxy Fold4)
- 코드베이스/지식베이스 탐구
- 포트 18789 (localhost only, 방화벽 변경 불필요)

---

## Maintenance

- Review this list when setting up a new device
- Periodically check for updates: `uv tool upgrade --all`, `pnpm add -g <pkg>@latest`
- If a package becomes available in nixpkgs, migrate it to NixOS config
