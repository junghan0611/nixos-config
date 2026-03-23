# nixos-config AGENTS.md

## Project Overview

**Layer 1** - Reproducible OS foundation for human-AI collaboration.

### Purpose

- Declarative, reproducible computing environment
- Same config anywhere: laptop, server, cloud
- AI-agent friendly transparency

### Core Stack

| Component | Technology |
|-----------|------------|
| OS | NixOS 25.11 |
| WM | i3wm (Regolith style) |
| Editor | Doom Emacs + Org-mode |
| Config | home-manager + flakes |

### Device Profiles

| Profile | Device | Usage |
|---------|--------|-------|
| `laptop` | Samsung NT930SBE | Personal laptop |
| `nuc` | Intel NUC i7 | Home server |
| `thinkpad` | ThinkPad P16s | Work laptop |
| `oracle` | Oracle Cloud VM | Remote server |

### Key Commands

```bash
# Rebuild system
sudo nixos-rebuild switch --flake .#<profile>

# Update flake
nix flake update

# Check current device
cat ~/.current-device
```

### Directory Structure

```
hosts/           # Per-device configs
users/junghan/   # User configs + modules
modules/         # Shared NixOS modules
templates/       # Oracle VM etc.
docs/            # Documentation (denote)
```

---

<!-- bv-agent-instructions-v1 -->

## Beads Workflow Integration

This project uses [beads_rust](https://github.com/Dicklesworthstone/beads_rust) for issue tracking. Issues are stored in `.beads/` and tracked in git.

**Note:** `br` is non-invasive and never executes git commands. After `br sync --flush-only`, you must manually run `git add .beads/ && git commit`.

### Essential Commands

```bash
# View issues (launches TUI - avoid in automated sessions)
bv

# CLI commands for agents (use these instead)
br ready              # Show issues ready to work (no blockers)
br list --status=open # All open issues
br show <id>          # Full issue details with dependencies
br create --title="..." --type=task --priority=2
br update <id> --status=in_progress
br close <id> --reason="Completed"
br close <id1> <id2>  # Close multiple issues at once
br sync --flush-only  # Export to JSONL (no git)
git add .beads/
git commit -m "sync beads"
```

### Workflow Pattern

1. **Start**: Run `br ready` to find actionable work
2. **Claim**: Use `br update <id> --status=in_progress`
3. **Work**: Implement the task
4. **Complete**: Use `br close <id>`
5. **Sync**: Always run sync and commit at session end:
   ```bash
   br sync --flush-only
   git add .beads/
   git commit -m "sync beads"
   ```

### Key Concepts

- **Dependencies**: Issues can block other issues. `br ready` shows only unblocked work.
- **Priority**: P0=critical, P1=high, P2=medium, P3=low, P4=backlog (use numbers, not words)
- **Types**: task, bug, feature, epic, question, docs
- **Blocking**: `br dep add <issue> <depends-on>` to add dependencies

### Session Protocol

**Before ending any session, run this checklist:**

```bash
git status              # Check what changed
git add <files>         # Stage code changes
br sync --flush-only    # Export beads changes
git add .beads/
git commit -m "..."     # Commit code and beads
git push                # Push to remote
```

<!-- end-bv-agent-instructions -->

## OpenClaw 봇 구성 (Oracle VM)

> **SSOT**: `oracle:~/openclaw/` (private 리포). 이 공개 리포에는 Dockerfile/docker-compose.yml 구조만 백업.
> `openclaw.json`은 API 키 포함이라 git 추적하지 않음 (`.gitignore`).
> 상세 운영 문서: `oracle:~/openclaw/README.md`

| 항목 | SSOT | 이 리포 |
|------|------|---------|
| openclaw.json | oracle (실행) | ❌ gitignore |
| Dockerfile | oracle | `docker/openclaw/` (백업, 롤백용) |
| docker-compose.yml | oracle | `docker/openclaw/` (백업, 롤백용) |
| .env (API 키) | oracle | ❌ 절대 포함 안 함 |

| 에이전트 | 모델 | 텔레그램 봇 | 인증 | 호스트 workspace 경로 |
|---------|------|------------|------|----------------------|
| main | anthropic/claude-opus-4-6 | @junghan_openclaw_bot | Anthropic 정액제 | `config/workspace/` |
| glg | anthropic/claude-opus-4-6 | @glg_junghanacs_bot | Anthropic 정액제 | `config/workspace-glg/` |
| gpt | openrouter/openai/gpt-5.4 | @glg_gpt_bot | OpenRouter | `config/workspace-gpt/` |
| gemini | openrouter/google/gemini-3.1-pro-preview | @glg_gemini_bot | OpenRouter | `config/workspace-gemini/` |

- 서브에이전트: Claude Sonnet 4.6 (전 에이전트 공통)
- workspace 독립, skills 공유 (glg 기준 복사)
- 프레이밍 없음 — 각 모델이 대화하며 자리잡음
- **현재 버전: 2026.3.22**
- **Memory Search: Gemini Embedding 2** (768d, hybrid+MMR+temporalDecay)

### Workspace 경로 매핑 (필수 숙지)

Docker 볼륨: `./config:/home/node/.openclaw`

| 에이전트 | 호스트 경로 | Docker 내 경로 |
|---------|------------|---------------|
| **main** | `~/openclaw/config/workspace/` | `/home/node/.openclaw/workspace/` |
| **glg** | `~/openclaw/config/workspace-glg/` | `/home/node/.openclaw/workspace-glg/` |
| **gpt** | `~/openclaw/config/workspace-gpt/` | `/home/node/.openclaw/workspace-gpt/` |
| **gemini** | `~/openclaw/config/workspace-gemini/` | `/home/node/.openclaw/workspace-gemini/` |

> ⚠️ **main은 `workspace/`** (기본 경로). `workspace-main/` 폴더는 존재하지 않는다.
> `openclaw.json`에서 main은 workspace를 오버라이드하지 않으므로 defaults의 `/home/node/.openclaw/workspace`를 사용한다.

### 스킬 경로 구조

```
~/repos/gh/agent-config/          # SSOT 리포
├── skills/                       # 스킬 디렉토리 (SSOT)
│   ├── dictcli/                  # dictcli 바이너리 + graph.edn + SKILL.md
│   ├── knowledge-search/         # LanceDB org 시맨틱 검색
│   ├── agenda/, botlog/, ...     # 기타 스킬
│   └── (총 25개)
├── pi-extensions/
│   └── semantic-memory/          # Gemini Embedding 2 + LanceDB (pi 전용)
└── run.sh                        # setup/build/index 통합 커맨드

~/.pi/agent/skills/pi-skills → ~/repos/gh/agent-config/skills  (심링크)
~/.pi/agent/memory/
├── sessions.lance                # 세션 JSONL 임베딩 (pi 전용)
└── org.lance                     # ~/org 3000+ 노트 임베딩 (봇도 공유)
```

**배포 흐름**: `agent-config/skills/` (SSOT) → rsync → `oracle:~/openclaw/config/workspace{,-glg,-gpt,-gemini}/skills/`
> 주의: main은 `workspace/`이다. `workspace-main/`이 아님. 4개 경로 모두 동기화할 것.

**pi vs 봇 차이**:
- pi 에이전트: `pi-extensions/semantic-memory`가 `session_search` + `knowledge_search` 제공
- OpenClaw 봇: `knowledge-search` 스킬이 LanceDB를 직접 쿼리 (Docker ro 마운트)
- `dictcli`: 양쪽 모두 동일 바이너리 사용

## OpenClaw 작업 체크리스트

`docker/openclaw/` 또는 원격 `~/openclaw/` 변경 시 확인:

- [ ] **채널/플러그인 추가** → `stignore/local-family`에 `openclaw/config/<새경로>` 추가 + `~/sync/family/.stignore` 배포
- [ ] **Dockerfile 변경** → `~/openclaw/Dockerfile`과 `docker/openclaw/Dockerfile` 양쪽 동기화
- [ ] **docker-compose.yml 변경** → 양쪽 동기화
- [ ] **새 스킬에 SQLite 사용** → `docker-compose.yml`에 해당 데이터 경로 rw 마운트 추가
- [ ] **Go 바이너리 추가** → `CGO_ENABLED=0` 정적 빌드, 양쪽 workspace 동기화
- [ ] **버전 업데이트** → FROM 태그 고정, 서브에이전트 + announce 테스트
- [ ] **openclaw-config 커밋** → 별도 리포(`junghan0611/openclaw-config`)에도 push
- [ ] **스킬 SKILL.md 변경** → agent-config/skills(SSOT)에서 봇 4개 workspace(`workspace/`, `workspace-glg/`, `workspace-gpt/`, `workspace-gemini/`)로 동기화. 재시작 불필요

### OpenClaw 재시작 판단 기준

**재시작 필요:**
- 새 스킬 디렉토리 추가/삭제 (Telegram 슬래시 커맨드 등록 변경)
- `openclaw.json` 설정 변경
- Dockerfile / docker-compose.yml 변경
- 버전 업데이트

**재시작 불필요:**
- SKILL.md 내용 수정 — 에이전트가 매 호출 시 `read` 도구로 동적 로딩
- workspace 파일 수정 (AGENTS.md, SOUL.md, USER.md, MEMORY.md 등)
- 스킬 내 스크립트/바이너리 교체 (경로 동일하면)
