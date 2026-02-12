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
| openclaw | latest | AI Gateway (Telegram + Claude Code) | 2025-02-12 |

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

## OpenClaw Setup (Oracle VM)

Oracle VM에서 지식베이스 탐구용 AI 에이전트로 사용.

### 설치

```bash
# Node.js 환경 준비
nix-shell -p nodejs_22 corepack

# pnpm 활성화
corepack enable
corepack prepare pnpm@latest --activate

# OpenClaw 설치
pnpm add -g openclaw@latest
```

### 설정

**1. Telegram Bot 생성**

Telegram에서 [@BotFather](https://t.me/BotFather) 접속:

```
/newbot
Bot Name: junghan-knowledge-agent (또는 원하는 이름)
Bot Username: junghan_kb_bot (고유해야 함)
```

Bot Token 받기 (예: `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`)

**2. OpenClaw Onboarding**

```bash
# Onboarding (daemon 설치)
openclaw onboard --install-daemon
```

- **Telegram Bot Token**: 위에서 받은 토큰 입력
- **Claude Code Token**: `claude-code auth token` 실행 후 토큰 입력

### 접근 제한 설정

`~/.openclaw/config.json`:

```json
{
  "allowedPaths": [
    "/home/junghan/repos/gh",
    "/home/junghan/repos/work",
    "/home/junghan/org"
  ],
  "restrictedPaths": [
    "/home/junghan/.ssh",
    "/home/junghan/.gnupg",
    "/home/junghan/password-store"
  ],
  "capabilities": {
    "read": true,
    "write": false,
    "execute": false
  }
}
```

### SSH 터널링 (로컬 머신)

```bash
# Firefox로 접속
ssh -N -L 18789:127.0.0.1:18789 junghan@<oracle-vm-ip>
```

브라우저: `http://127.0.0.1:18789/`

### 용도

- 코드베이스 분석 (~/repos/gh, ~/repos/work)
- 지식베이스 탐구 (~/org)
- **Telegram으로 모바일 상시 접근** (Galaxy Fold4)
- 상시 대화형 AI 에이전트
- 시스템 데몬 아님 (필요시 수동 실행)

---

## Maintenance

- Review this list when setting up a new device
- Periodically check for updates: `uv tool upgrade --all`, `pnpm add -g <pkg>@latest`
- If a package becomes available in nixpkgs, migrate it to NixOS config
