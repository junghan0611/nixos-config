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

Go CLI tools installed via go install.

| Package     | Version | Description                                                 | Installed  |
|-------------|---------|-------------------------------------------------------------|------------|
| CLIProxyAPI | latest  | Claude/Gemini 구독을 OpenAI 호환 API로 노출하는 로컬 프록시 | 2026-02-25 |

### CLIProxyAPI 설치 및 설정

Claude Max 구독($100/월)을 로컬 OpenAI 호환 API로 사용.
gptel, llm.el 등 Emacs AI 패키지에서 빠른 채팅용(1~3초).

> ⚠️ ToS: Anthropic은 2026.02.20부터 서드파티 OAuth 사용을 명시적으로 금지.
> 개인 로컬 사용 전용. 공개하지 않을 것.

```bash
# 방법 1: 커뮤니티 인스톨러 (바이너리 + systemd)
curl -fsSL https://raw.githubusercontent.com/brokechubb/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash

1. Navigate to CLIProxyAPI:
   cd /home/junghan/cliproxyapi

2. Set up authentication (choose one or more):
   ./cli-proxy-api --login           # For Gemini
   ./cli-proxy-api --codex-login     # For OpenAI
   ./cli-proxy-api --claude-login    # For Claude
   ./cli-proxy-api --qwen-login      # For Qwen
   ./cli-proxy-api --iflow-login     # For iFlow

3. Start the service:
   ./cli-proxy-api

4. Or run as a systemd service:
   systemctl --user enable cliproxyapi.service
   systemctl --user start cliproxyapi.service
   systemctl --user status cliproxyapi.service
```

Emacs 설정은 `doomemacs-config/lisp/ai-gptel-local-proxy.el` (로컬 전용, .gitignore)

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
