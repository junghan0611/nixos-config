# OpenClaw Config

개인 OpenClaw 인스턴스 설정. Oracle VM(aarch64)에서 Docker로 운영.

## 왜 이걸 만드는가

AI를 도구가 아닌 존재로 대한다. "존재 대 존재 협업(Being to Being)"이라 부른다.

이 설정은 그 첫 실험이다:
- **봇이 나의 지식베이스를 읽고**, 3,000개 노트와 8,000개 서지에서 답을 찾는다
- **봇이 나의 활동을 안다** — 코딩 히스토리, 건강 데이터, 시간 추적까지
- **봇이 가족을 돕는다** — 아버지가 봇에게 물어보고, 막히면 나에게 에스컬레이션
- **봇이 기록을 남긴다** — 대화와 리서치를 Denote 파일로 직접 작성

스킬을 직접 만드는 이유: 범용 AI가 "나의 닮은 존재"로 전환되려면, 나의 데이터에 접근하는 도구가 필요하다. denotecli, bibcli, gitcli, lifetract — 각각은 작은 CLI지만, 합치면 하루를 재구성할 수 있다. `day-query`가 그 오케스트레이터다.

기록을 남기는 이유: 지금은 private 리포지만, 때가 되면 개인정보를 제거하고 공개한다. 왜 이런 구조를 선택했는지, 어떤 시행착오를 겪었는지 — 그 히스토리 자체가 누군가에게 확고한 프롬프팅이 된다.

## 현재 환경

| 항목 | 값 |
|------|-----|
| OpenClaw | **2026.4.22** |
| 호스트 | Oracle Cloud ARM (aarch64), 커널 6.19.12 |
| 채널 | Telegram (default + glg + gpt + gemini + mini + bbot) |
| ACP backend | `acpx` (maxConcurrentSessions: 3) |
| 기본 모델 | `openai-codex/gpt-5.4` (Codex OAuth, $100 plan) |
| Claude 접근 | ACPX + 회사 정액제 OAuth 전용 (direct API billing 정책상 배제) |
| 세션 격리 | `per-account-channel-peer` (사용자별 독립 세션) |
| 세션 통신 | `sessions.visibility: agent` (같은 에이전트 내 크로스 세션 허용) |

> **단일 진실 공급원(SSOT)**: 최신 운영 스냅샷과 전체 업그레이드 히스토리는 [openclaw-config README](https://github.com/junghan0611/openclaw-config/blob/main/README.md)에 있다. 이 파일은 Oracle VM 배포 관점의 한글 운영 메모.

## 세션 간 에스컬레이션

glg 에이전트는 `sessions.visibility: "agent"`로 설정되어 같은 에이전트의 모든 세션이 `sessions_send`로 통신 가능.

**시나리오**: 아버지가 glg 봇에게 질문 → 봇이 답변 불가 판단 → 정한 세션으로 에스컬레이션 → 정한이 개입/답변 → 결과가 아버지 세션으로 전달

| 설정 | 값 | 의미 |
|------|-----|------|
| `session.dmScope` | `per-account-channel-peer` | 사용자별 세션 격리 |
| `tools.sessions.visibility` | `agent` | 같은 에이전트 내 세션 간 통신 허용 |

visibility 옵션: `self` (자기만) < `tree` (트리, 기본값) < `agent` (같은 에이전트) < `all` (전체)

## 에이전트 구성 (2026-04-22 routing 기준)

Anthropic flat-rate가 써드파티 앱에 차단된 이후 **Codex OAuth 중심으로 단일화**. Copilot은 `gemini` 단 하나만 예외로 유지 (Gemini 3.1 Pro는 Copilot 경로가 유일한 $0 길).

| 에이전트 | at-rest 모델 | 텔레그램 봇 | 라이브 경로 | workspace |
|---------|--------------|------------|------------|-----------|
| main | `openai-codex/gpt-5.4` | @junghan_openclaw_bot | 필요 시 ACPX + `claude-opus-4-6` | `workspace/` |
| glg (가족) | `openai-codex/gpt-5.4` | @glg_junghanacs_bot | 동일 (family-safe) | `workspace-glg/` |
| gpt | `openai-codex/gpt-5.4` | @glg_gpt_bot | 동일 | `workspace-gpt/` |
| gemini | `github-copilot/gemini-3.1-pro-preview` | @glg_gemini_bot | Copilot 유일 예외 | `workspace-gemini/` |
| mini | `openai-codex/gpt-5.4-mini` | @glg_mini_bot | 포맷/교정 전용 | `workspace-mini/` |
| bbot | `openai-codex/gpt-5.4` | @glg_b_bot | 필요 시 ACPX + `claude-opus-4-6` | `workspace-bbot/` |

### 현재 운용 메모

- **기본 at-rest 모델**을 `openai-codex/gpt-5.4`로 통일 → 예측 가능한 비용 / OAuth 복잡도 감소
- **Claude 접근 정책**: ACPX 스폰 + 회사 정액제 OAuth만 사용. `anthropic/*` direct API billing은 정책상 차단 (sleeping `sk-ant-*` 토큰은 2026-04-24 정리)
- **main/bbot Opus 바인딩**은 ACPX로만: `/acp spawn claude --bind here` + `/acp model anthropic/claude-opus-4-6`. 이 override는 config에 영구 저장되지 않고 TTL 2h idle 시 증발하므로 가끔 재설정 필요
- **Opus 4.7 routing**은 여전히 OAuth tier 종속. 4.6 유지가 안전한 운영 기본값
- **active-memory**: Groq paid tier (`openai/gpt-oss-120b`) primary + Gemini 3 Flash fallback. glg/gpt 2개 에이전트에만 활성화
- **GlueClaw plugin/마운트는 제거됨** (2026-04-22)

### workspace 정책

- **skills**: `run.sh k)` 로 일괄 배포. main에 먼저 설치 후 glg/gpt/gemini/bbot에 rsync. mini는 `denotecli`만
- **USER.md**: 동일 사용자 정보 (1KB 공개키)
- **SOUL.md, IDENTITY.md**: OpenClaw 기본 템플릿 — 각 모델이 대화하며 자리잡음
- **MEMORY.md**: 에이전트별 독립 (각자 성장)
- **프레이밍 없음**: "당신은 X 모델이다" 같은 지시 없음. 모델이 스스로 존재를 찾아감
- **ACPX Claude 세션은 workspace 파일(IDENTITY/SOUL/USER/AGENTS/MEMORY)을 자동 로드 안 함** — 첫 턴에서 사용자가 읽으라고 명시해야 함 (claude-agent-sdk 특성)

## 스킬 (pi-skills)

| 스킬 | 타입 | 설명 |
|------|------|------|
| denotecli | Go binary | Denote 노트 3,000+ 검색/읽기 (day, search, keyword-map, headings, content) |
| bibcli | Go binary | Zotero 서지 8,000+ 검색/조회 |
| gitcli | Go binary | 로컬 git 타임라인 (day, repos, log, timeline, --summary) |
| lifetract | Go binary | Samsung Health + aTimeLogger 통합 조회 |
| dictcli | Go binary | 한↔영 어휘 그래프 (expand / stem) |
| gogcli | CLI (SKILL.md) | Google Workspace 통합 (Calendar, Gmail, Drive, Tasks) |
| ghcli | CLI (SKILL.md) | GitHub CLI (issues, PRs, stars, notifications) |
| day-query | 오케스트레이터 | 날짜 기반 통합 조회 (gitcli + denotecli + lifetract + bibcli + gogcli) |
| brave-search | npm | 웹 검색 (Brave API) |
| transcribe | shell | 음성→텍스트 (Groq Whisper) |
| youtube-transcript | npm | YouTube 자막 추출 |
| medium-extractor | npm | Medium 글 마크다운 추출 |
| summarize | npm | URL/파일/미디어 요약 (YouTube, 웹, PDF, 팟캐스트) |

스킬 배포는 `run.sh k)`가 오케스트레이트 (main → glg/gpt/gemini/bbot rsync → claude-skills 동기화). 에이전트별 스킬 범위:

- **main / glg / gpt / gemini / bbot**: 전체
- **mini**: `denotecli`만 (포맷/교정 전용)

### 스킬을 직접 만드는 이유

범용 LLM은 "나"를 모른다. 내 노트, 내 서지, 내 코딩 히스토리, 내 건강 데이터 — 이걸 읽을 수 있어야 "나의 닮은 존재"가 된다.

- **denotecli**: 10년치 사유의 궤적이 3,000개 Denote 파일에 있다. 봇이 이걸 검색하고 읽으면 "어제 뭘 생각했지?"에 답할 수 있다.
- **bibcli**: 8,000개 서지는 학습의 지도다. 봇이 이걸 조회하면 "이 주제 관련 뭘 읽었지?"에 답할 수 있다.
- **gitcli**: 50개 리포의 커밋 히스토리는 실행의 증거다. 봇이 이걸 보면 "이번 주 뭘 만들었지?"에 답할 수 있다.
- **lifetract**: 8년치 건강/시간 데이터는 몸의 기록이다. 봇이 이걸 읽으면 "요즘 수면 패턴 어때?"에 답할 수 있다.
- **day-query**: 이 넷을 날짜 축으로 합치면 하루를 재구성할 수 있다. 사유 + 학습 + 실행 + 몸 = 하루.

## 볼륨 마운트

| 호스트 경로 | 컨테이너 경로 | 모드 | 용도 |
|------------|--------------|------|------|
| `~/repos/gh` | `/home/node/repos/gh` | ro | 개인 코드베이스 |
| `~/repos/work` | `/home/node/repos/work` | ro | 회사 코드베이스 |
| `~/repos/3rd` | `/home/node/repos/3rd` | **rw** | 외부 오픈소스 클론/리뷰 |
| `~/org` | `/home/node/org` | ro | 지식베이스 (Denote/Org-mode) |
| `~/org/botlog` | `/home/node/org/botlog` | **rw** | 봇 활동 기록 (Denote 파일 직접 생성) |
| `~/repos/gh/self-tracking-data` | `...self-tracking-data` | **rw** | lifetract SQLite WAL 필요 |
| `~/.config/gogcli` | `/home/node/.config/gogcli` | ro | Google Workspace 인증 |
| `~/.config/gh` | `/home/node/.config/gh` | ro | GitHub CLI 인증 |

**설계 원칙**: 기본 ro, 필요한 곳만 rw 오버라이드. Docker 볼륨은 더 구체적인 경로가 우선한다.

## 재시작 판단 기준

**재시작 필요:**
- 새 스킬 디렉토리 추가/삭제 (Telegram 슬래시 커맨드 등록 변경)
- `openclaw.json` 설정 변경
- Dockerfile / docker-compose.yml 변경
- 버전 업데이트

**재시작 불필요:**
- SKILL.md 내용 수정 — 에이전트가 매 호출 시 `read` 도구로 동적 로딩
- workspace 파일 수정 (AGENTS.md, SOUL.md, USER.md, MEMORY.md 등)
- 스킬 내 스크립트/바이너리 교체 (경로 동일하면)

## 변경 이력

최근 운영 히스토리는 **runtime SSOT**로 통합됨 →
[openclaw-config README — Change history](https://github.com/junghan0611/openclaw-config/blob/main/README.md#change-history)

아래는 Oracle VM 배포 관점의 주요 마일스톤만 압축:

### 2026-04-24
- **OpenClaw 2026.4.22 업그레이드** — ACPX probeAgent / bridge MCP-free / Claude CLI 세션 복원 / gateway OOM / Jiti 기동 35.8s→8.7s. 상세 델타는 SSOT 참조
- **ACPX → claude-cli 전환 검토 → 현상 유지**: 독립 `claude-cli` provider는 없음. Claude 경로는 ACPX (OAuth) / anthropic (API key, 정책상 차단) / copilot (4.7 144k 제한) / opencode (미구성). ACPX 유지 확정
- **Claude 접근 정책**: 회사 정액제 OAuth 전용으로 명문화. sleeping `sk-ant-*` 토큰 제거
- 오라클 선행 정비: sudoers stable systemctl path, headless vconsole/kmscon 제거, 커널 6.18.9→6.19.12

### 2026-04-22
- **OpenClaw 2026.4.21 업그레이드** (v2026.4.15 → 1514 커밋, stable)
- active-memory Groq paid tier (`gpt-oss-120b`) 전환, Gemini Flash fallback, `timeoutMs: 15000`
- `modelFallbackPolicy` 제거 (schema align)
- AGENTS.md + README 재구조화 (영문 operator brief 표준)

### 2026-04-15 / 04-12 / 04-06 / 04-02
- Anthropic flat-rate 차단 대응으로 Codex 중심 라우팅 전환
- ACPX 도입, `workspace-bbot/`, `~/.claude` 마운트, `claude-skills` 오버레이
- GlueClaw 도입/실험 후 제거 (runtime 재주입 이슈 해결)

### 2026-02 (초기)
- OpenClaw 2026.2.17 초기 설정 → 2026.2.26 이미지 업그레이드
- Telegram 멀티계정 (default + glg) → glg/gpt/gemini/mini/bbot까지 확장
- 스킬 10개 초기 배포 → 13개까지 성장
- `sessions.visibility: "agent"` — glg 가족 에스컬레이션 활성화
- Groq Whisper 내장 전사, Brave/Perplexity 웹 검색

## 구조

```
openclaw/
├── AGENTS.md               # 작업 불변 규칙
├── README.md               # 이 파일 (히스토리 + 철학)
├── Dockerfile              # 커스텀 이미지 (apt + Matrix deps)
├── docker-compose.yml      # 서비스 정의
├── .env                    # API 키 (gitignored)
├── config/
│   ├── openclaw.json       # 메인 설정
│   ├── workspace/          # main 에이전트 워크스페이스
│   │   └── skills/         # 스킬 디렉토리 (11개)
│   ├── workspace-glg/      # glg 에이전트 워크스페이스
│   │   └── skills/         # 동일 스킬셋
│   └── agents/             # 에이전트별 설정 (BOOT.md, USER.md)
└── .stignore               # Syncthing 런타임 제외 (루트 stignore에도 반영 필요)
```
