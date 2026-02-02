# Changelog

All notable changes to this NixOS configuration will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- **NixOS Version**: 25.05
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
