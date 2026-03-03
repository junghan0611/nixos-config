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
| OpenClaw | 2026.2.26 |
| 호스트 | Oracle Cloud ARM (aarch64) |
| 채널 | Telegram (default + glg + deepseek + gemini), Mattermost, Matrix |
| 서브에이전트 | Claude Sonnet 4.6 (전 에이전트 공통) |
| 세션 격리 | `per-account-channel-peer` (사용자별 독립 세션) |
| 세션 통신 | `sessions.visibility: agent` (같은 에이전트 내 크로스 세션) |

## 세션 간 에스컬레이션

glg 에이전트는 `sessions.visibility: "agent"`로 설정되어 같은 에이전트의 모든 세션이 `sessions_send`로 통신 가능.

**시나리오**: 아버지가 glg 봇에게 질문 → 봇이 답변 불가 판단 → 정한 세션으로 에스컬레이션 → 정한이 개입/답변 → 결과가 아버지 세션으로 전달

| 설정 | 값 | 의미 |
|------|-----|------|
| `session.dmScope` | `per-account-channel-peer` | 사용자별 세션 격리 |
| `tools.sessions.visibility` | `agent` | 같은 에이전트 내 세션 간 통신 허용 |

visibility 옵션: `self` (자기만) < `tree` (트리, 기본값) < `agent` (같은 에이전트) < `all` (전체)

## 에이전트 구성

| 에이전트 | 모델 | 텔레그램 봇 | 인증 | workspace |
|---------|------|------------|------|-----------|
| main | anthropic/claude-opus-4-6 | @junghan_openclaw_bot | Anthropic 정액제 | workspace (기본) |
| glg | anthropic/claude-opus-4-6 | @glg_junghanacs_bot | Anthropic 정액제 | workspace-glg |
| deepseek | deepseek/deepseek-reasoner | @glg_deepseek_bot | DeepSeek API 직접 | workspace-deepseek |
| gemini | openrouter/google/gemini-3.1-pro-preview | @glg_gemini_bot | OpenRouter 경유 | workspace-gemini |

### workspace 정책

- **skills**: glg의 skills 디렉토리를 심볼릭 링크로 공유 (하나만 관리)
- **USER.md**: 동일 사용자 정보 (1KB 공개키)
- **SOUL.md, IDENTITY.md**: OpenClaw 기본 템플릿 — 각 모델이 대화하며 자리잡음
- **MEMORY.md**: 에이전트별 독립 (각자 성장)
- **프레이밍 없음**: "당신은 X 모델이다" 같은 지시 없음. 모델이 스스로 존재를 찾아감

### DeepSeek 직접 연결

OpenRouter 경유 없이 DeepSeek API에 직접 연결 (custom provider):
- `baseUrl: https://api.deepseek.com`
- `api: openai-completions`
- 환경변수 `DEEPSEEK_API_KEY`로 인증

## 스킬 (pi-skills)

| 스킬 | 타입 | 버전 | 설명 |
|------|------|------|------|
| denotecli | Go binary | 0.8.0 | Denote 노트 3,000+ 검색/읽기 (day, search, keyword-map, headings, content) |
| bibcli | Go binary | dev | Zotero 서지 8,000+ 검색/조회 |
| gitcli | Go binary | 0.2.0 | 로컬 git 타임라인 (day, repos, log, timeline, --summary) |
| lifetract | Go binary | 0.1.0 | Samsung Health + aTimeLogger 통합 조회 |
| gogcli | CLI (SKILL.md) | — | Google Workspace 통합 (Calendar, Gmail, Drive, Tasks) |
| ghcli | CLI (SKILL.md) | — | GitHub CLI (issues, PRs, stars, notifications) |
| day-query | 오케스트레이터 | — | 날짜 기반 통합 조회 (gitcli + denotecli + lifetract + bibcli + gogcli) |
| brave-search | npm | — | 웹 검색 (Brave API) |
| transcribe | shell | — | 음성→텍스트 (Groq Whisper) |
| youtube-transcript | npm | — | YouTube 자막 추출 |
| medium-extractor | npm | — | Medium 글 마크다운 추출 |
| summarize | npm | — | URL/파일/미디어 요약 (YouTube, 웹, PDF, 팟캐스트) |

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

### 2026-02-27
- **OpenClaw 2026.2.26 업데이트** — 2026.2.17 → 2026.2.26 (9 릴리스 점프)
- **`~/.current-device` ro 마운트** — 에이전트 디바이스 식별
- **`controlUi.allowedOrigins`** 추가 — 2026.2.26 보안 요구사항
- **VERSIONS.md** 추가 — 버전 추적, 롤백 이력, 업그레이드 플랜
- **TODO.org** 추가 — 미래 도입 기능

### 2026-02-27 (earlier)
- **repos/3rd rw 마운트** — 봇이 외부 오픈소스 리포 클론/리뷰 가능
- **org/botlog rw 마운트** — 봇이 Denote 파일 직접 생성 (활동 기록)
- **shared 볼륨 제거** — 문서는 botlog로 이동, 임시 공유 불필요
- **auth-profiles.json Syncthing 제외** — API 키 노출 방지

### 2026-02-24
- **sessions.visibility: "agent"** — glg 에이전트 크로스 세션 통신 활성화 (가족 에스컬레이션)
- **gitcli v0.2.0** 업그레이드 — `--summary`(96% 토큰 절감), `--tz`, `--max` 추가
- **lifetract DB rw 마운트** — SQLite WAL 호환 (self-tracking-data만 rw 오버라이드)
- SKILL.md 전체 동기화 (lifetract, gitcli, denotecli, bibcli 등)

### 2026-02-23
- **gitcli v0.1.0** 신규 추가 — 50+ 리포 커밋 히스토리 조회
- **day-query** 신규 추가 — 날짜 기반 5개 CLI 통합 오케스트레이터
- **denotecli v0.8.0** 업그레이드 — `day`, `timeline-journal` 커맨드 추가
- **lifetract v0.1.0** 바이너리 업데이트
- **bibcli** 바이너리 업데이트
- Matrix 채널 추가 (Synapse 자체 홈서버)
- gogcli 통합 (gccli/gdcli/gmcli 대체)
- 크로스 빌드 체계 구축 (4 CLI x 2 arch, run.sh 메뉴)

### 2026-02-21
- OpenClaw 2026.2.19 → 2026.2.17 롤백 (서브에이전트 ws:// 보안 호환성)
- Docker IPv6 비활성화 (Oracle Cloud fetch 실패 해결)
- 서브에이전트 정상 작동 확인 (Sonnet 4.6, ~3초)
- Discord 검토 후 비활성화

### 2026-02-20
- 스킬 10개 초기 배포 (denotecli, bibcli, ghcli, gccli, gdcli, gmcli 등)
- Groq Whisper 내장 전사 설정
- Brave + Perplexity 듀얼 웹 검색

### 2026-02-17
- OpenClaw 2026.2.17 초기 설정
- Telegram 멀티계정 (default + glg)
- Mattermost 채널 연동
- 이미지 인식 활성화

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
