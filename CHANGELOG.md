# Changelog

All notable changes to this NixOS configuration will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- **i3/xkb**: CapsLock → Menu 키 매핑 추가 (Emacs 한/영 토글용)
- **microsoft-edge**: 144.0.3719.115 → 145.0.3800.70 업데이트 (144 크래시 해결, pinned rev 갱신)

## [0.3.2] - 2026-02-22

### Added
- **fortune**: `fortune` 패키지 + Kevin Kelly advice 데이터
  - `fortunes/advice/`: *Excellent Advice for Living*, 68 Bits, 99 Additional Bits
  - `~/.fortunes`로 home-manager 배포
- **OpenClaw**: Docker 환경 강화
  - 커스텀 Dockerfile: `gh` CLI, `curl`, `ripgrep`, `fd`, `jq`, `tree` 추가
  - 스킬(skills) 설치 기능 추가
  - shared rw 폴더 + 이미지/서브에이전트 설정 동기화
  - `env_file` 지원 (GROQ_API_KEY)
  - gh CLI 인증 마운트
  - IPv6 비활성화
- **Umami**: 셀프호스팅 웹 애널리틱스 추가 (`docker/umami/`)
- **peon-ping**: NixOS shebang 패치, `peon-setup` 전역 명령어, `--langs` 옵션
- **WezTerm**: 타이틀바 활성화 및 키바인딩 문서 정비

### Changed
- **Docker**: 데이터 볼륨을 `~/docker-data/`로 분리
- **tdlib**: unstable로 전환 (telega.el >= 1.8.60 요구)
- **telegram-desktop**: 비활성화 (한글 입력 불가)
- **flake.lock**: nixpkgs 최신 업데이트

### Fixed
- **OpenClaw**: 2026.2.19 → 2026.2.17 롤백 (서브에이전트 호환성 문제)
- **OpenClaw**: Telegram 멀티계정 모드 — default 계정 `accounts`에 명시 필수
- **OpenClaw**: main 에이전트 model 미설정 수정
- **microsoft-edge**: nixpkgs-pinned(144)로 고정 (빌드 실패 해결)
- **home-manager**: GLG 스크립트 파일 충돌 해결 (force=true)
- **claude-focus.sh**: ● 대기 상태 패턴 추가
- **umami**: .env 시크릿 제거, .gitignore 추가

## [0.3.1] - 2026-02-17

### Added
- **run.sh**: Oracle VM 원격 관리 메뉴 추가 (Remote 섹션)
  - `t) OpenClaw SSH 터널 시작/종료` (`ssh -N -L 18789:127.0.0.1:18789 oracle`)
  - `r) Oracle Docker 서비스 재시작` (openclaw-gateway / caddy+mattermost / 전체)
  - `s) Oracle Docker 서비스 상태` (`docker ps`)
- **OpenClaw**: Mattermost 채널 연동 (`@openclaw` 봇, `chat.junghanacs.com`)
  - Gmail SMTP 설정 (smtp.gmail.com:587 STARTTLS)
  - 방문자 초대 링크 채널
- **OpenClaw**: 멀티 에이전트 — 힣(glg) 에이전트
  - 두 번째 Telegram 봇 (`@glg_junghanacs_bot`)
  - `agents/glg/SOUL.md`, `agents/glg/IDENTITY.md` 생성
  - 디지털 가든 안내자 페르소나 (notes.junghanacs.com)
- **OpenClaw**: Control UI (대시보드) 접속 절차 문서화
  - Docker 환경 device pairing 이슈 해결: `docker exec` 방식
  - `SETUP.org` 재현 가능한 device pairing 절차 추가

### Changed
- **README/README-KO**: Docker 서비스 테이블에 Mattermost, Caddy 추가
- **README/README-KO**: run.sh Oracle 관리 단축키 안내 추가
- **docs links**: Mattermost SETUP.org 링크 추가

## [0.3.0] - 2026-02-17

### Added
- **Docker services (Oracle VM)**
  - **Remark42**: 셀프호스팅 댓글 시스템 (`comments.junghanacs.com`)
    - Let's Encrypt 자동 SSL, GitHub/Google/Telegram/Anonymous 인증
    - `docker/remark42/` — compose, 설정 가이드
  - **OpenClaw**: AI 어시스턴트 게이트웨이 (Telegram + Claude)
    - `ghcr.io/openclaw/openclaw:latest` (ARM64 multi-arch)
    - Telegram 봇으로 모바일 상시 AI 접근
    - repos/gh, repos/work, org read-only 마운트
    - boot-md, session-memory hooks 활성화
    - `docker/openclaw/` — compose, 설정 템플릿, 상세 가이드
- **Oracle VM 방화벽**: HTTP/HTTPS (80, 443) 포트 개방 (Remark42용)
- **i3**: Claude Code 창 순환 키바인딩 (Win+Tab/Shift+Tab)
- **shell**: GLG 도구 모음 NixOS 배포
- **home-manager**: `telegram-bot-api`, `telegram-desktop` 추가
- **edge-tts**: Text-to-Speech 패키지 추가

### Changed
- **README**: Docker 서비스 섹션, 문서 링크 추가 (영/한)
- **EXTERNAL_PACKAGES.md**: OpenClaw을 Docker 배포로 이전

### Fixed
- **greview**: 2단계 디렉토리 스캔 지원
- **whisper**: `/usr/bin/pass`를 `pass`로 변경 (NixOS 호환)

## [0.2.0] - 2026-02-02

### Added
- **thinkpad host** - ThinkPad P16s Gen 2 AMD 지원 추가
  - autorandr 시스템 서비스 활성화 및 수동 전환 스크립트
  - 워크스페이스-모니터 매핑 설정
  - i3 디스플레이 및 resume 개선
- **qwen-code** - Qwen AI code assistant CLI tool (from nixpkgs-unstable)

### Changed
- **i3/dunst**: 폰트명 통일 (D2Coding ligature)
- **i3status**: 모듈에 min_width 추가로 레이아웃 안정화
- **i3status**: 디스크/시간 모듈 여백 추가
- **ghostty**: copy-on-select를 clipboard로 변경
- **gpg**: pinentry-curses로 전환 (SSH 터미널 호환성)

### Fixed
- **gpg**: GPG 캐시 동작 설명 주석 추가 (nixos-rebuild 후 첫 입력 필요)
- **home-manager**: google-chrome을 aarch64-linux(Oracle)에서 제외

## [0.1.0] - 2025-11-17

### Added

#### AI CLI Tools (from nixpkgs-unstable)
- **gemini-cli** - Google Gemini CLI interface for AI-powered assistance
- **codex** - OpenAI Codex CLI for code generation and completion
- **opencode** - Open source code assistant tool
- **claude-code** - Anthropic Claude Code CLI for AI-powered development
- **claude-code-monitor** - Monitoring tool for Claude Code sessions
- **claude-code-acp** - Claude Code ACP (Agent Communication Protocol) integration
- **claude-code-router** - Routing utility for Claude Code requests

All AI CLI tools are sourced from `nixpkgs-unstable` via overlay configuration to ensure access to the latest versions.

#### Configuration Changes
- Added overlay configuration in `flake.nix` for AI CLI tools from unstable channel
- Updated user packages in `users/junghan/home-manager.nix` with AI CLI tools

### Technical Details
- **Modified files**:
  - `flake.nix` (lines 39-46): Added AI CLI tools to overlays
  - `users/junghan/home-manager.nix` (lines 71-78): Added packages to user environment
- **Channel**: nixpkgs-unstable (for latest versions)
- **Scope**: User packages (home-manager)

---

## Version History

### Version Naming Convention
- Major version (X.0.0): Significant configuration restructuring or breaking changes
- Minor version (0.X.0): New features, packages, or modules added
- Patch version (0.0.X): Bug fixes, minor tweaks, configuration updates

### Tags
- [Added] for new features, packages, or configurations
- [Changed] for changes in existing functionality
- [Deprecated] for soon-to-be removed features
- [Removed] for now removed features
- [Fixed] for any bug fixes
- [Security] for vulnerability fixes

---

## How to Use This Changelog

When making changes to the configuration:

1. **Add entry under [Unreleased]** section with appropriate tag
2. **Include date** when releasing a version
3. **Move [Unreleased] items** to a new version section when ready
4. **Update version number** following semantic versioning
5. **Commit with meaningful message** referencing the changelog

### Example Entry Format

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- Feature description with technical details
- File locations and line numbers if relevant

### Changed
- What changed and why
- Impact on existing configuration

### Fixed
- What was broken
- How it was fixed
```

---

## Previous Configurations

Notable configuration state before changelog tracking:

### NixOS Base Configuration
- **NixOS Version**: 25.11
- **Architecture Support**: x86_64-linux, aarch64-linux
- **Systems**: oracle (ARM VM), nuc (Intel NUC), laptop (Samsung NT930SBE)
- **Window Manager**: i3wm (default), GNOME (specialization)
- **Home Manager**: Integrated for user configuration

### Key Features Already Configured
- Disk management with disko
- Korean language support (input methods, fonts)
- Development environment (Python, Node.js, Emacs)
- Syncthing for file synchronization
- Tailscale for networking
- Docker for containerization
- Claude Desktop with MCP support

### Package Management
- Flake-based configuration
- Overlay system for unstable packages
- Ghostty terminal from unstable
- Comprehensive CLI tools (bat, eza, fd, ripgrep, fzf, etc.)
