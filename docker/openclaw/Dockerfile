# 5.20 → 5.22 (2026-05-26): Codex OAuth sidecar 자동화 (#83312 refresh-and-rewrite migration,
# sub-agent lane 포함) + ACP sessions_spawn orphan cleanup (#68916) + Telegram isolated polling
# pollingStallThresholdMs honor (#83950) + plugin metadata snapshot reuse / /models prewarm (#84816).
# claude-cli provider는 5.20에서 검증 통과 (Anthropic Max 20x rate tier, native first-class path).
# 주의 자리: retired catalog prune + doctor migration (#84718) — 우리 picker entries에 retired 모델 0건.
# subagent bootstrap context 축소 (#85283) — active-memory recall lane 영향 측정 후속.
# 5.18 → 5.20 (2026-05-22): Codex harness @openai/codex 0.132.0 bump + 5.19 거대 리팩토링 +
# 5.20 안정화. 핵심: #354 openai/* auto-Codex resolve + OAuth bootstrap / #310 doctor --fix
# legacy oauthRef → inline 자동 / #148 Codex app-server scope 분리 (우리 AGENTS.md §2 stance와 align) /
# #156 /codex plugins 채팅 토글 / #332 oversized thread 자동 rotation / #366-367 Telegram /verbose
# Codex tool 가시성 / #125 config.auth.order > stale lastGood / #247-248 Docker sandbox 호환성 개선.
# config 보강 2건: top-level auth.order 명시 + plugins.entries.codex.config.appServer.sandbox=danger-full-access
# (Cloud VM + Docker namespace 1차 boundary 안에서 bwrap 무력화, conservative).
# 5.12 정공법 (openai/* + agentRuntime.id=codex) 그대로 유지. plugin pi-shell-acp 8b25c1e.
# 5.22 → 5.27 (2026-05-29): Codex OAuth compaction을 OpenAI-Codex 경로로 라우팅 (host-native 레퍼런스가 맞은
# `No_API_key_found_for_provider_openai during compaction` 수정 — glg/gpt/subagents/active-memory recall lane 영향) +
# Codex runtime model 선해결 / app-server client 생존성 (startup·spawned-helper failure 후에도 shared client 보존) /
# gateway hot path cache 보강. 신규 strict 검증: gateway timeout / model limit / directory limit / message option /
# webhook 의 loose·malformed numeric 거부 (우리 config 스캔 결과 string-numeric 0건 — 통과). memory embedding provider
# registration deprecated(compat) — memorySearch qwen3-embedding-8b 업글 후 검증. codex plugin은 stock(번들)이라
# 베이스 이미지 bump와 함께 자동 5.27 (host-native 레퍼런스의 별도 @openclaw/codex 버전 정합 함정 비해당).
# 5.27 → 5.28 (2026-05-31): Claude Opus 4.8 정식 카탈로그 추가 (anthropic/claude-opus-4-8, default+alias:opus) +
# doctor 가 non-canonical api_key auth profile 을 canonical 로 재작성 + per-agent auth health 라벨 (#label auth health by
# agent) + Codex model migration 시 explicit agentRuntime pin 보존 + Claude CLI transcript probe retry / live tool
# progress watchdog 가시성. Breaking: Haiku 4.5 → Sonnet 자동 migrate 중단 (우리 비해당). workspace dotenv provider
# credential 무시 (우리는 docker env_file 경로라 비해당). 정공법 전환 근거: legacy claude-cli/* → anthropic/* +
# agentRuntime claude-cli (provider prefix 는 카탈로그 식별자, 과금은 runtime 이 결정 — claude-cli=구독). codex plugin
# stock(번들)이라 base bump 와 함께 자동 5.28.
# 5.28 → 6.1 (2026-06-04): host-native 레퍼런스 3봇 GREEN 선검증 후 oracle 적용. 핵심 breaking:
# "public OpenAI API-key profiles 를 native Codex app-server auth 로 취급하지 않음" → codex lane(glg/gpt)
# 이 api.openai.com 401 로 깨졌다가 `openclaw doctor --fix`(legacy OpenAI Codex auth profile → canonical
# 마이그레이션)로 복구 = 업그레이드 후 doctor --fix 의무. 신규: SecretRefs advisory(평문 secret-bearing
# config → `openclaw secrets configure` 권고, action 아닌 WARN) + doctor disk-space health check + post-upgrade
# JSON probe 안정화 + vector-disabled FTS index 가 sync 중 embedding provider resolve 안 함(우리 memorySearch
# vector enabled 라 영향 적음). tokenjuice/Copilot 이 official npm plugin 으로 externalize(우리 미설치 무관).
# codex plugin stock(번들)이라 base bump 와 함께 자동 6.1 — host-native 의 `plugins update @openclaw/codex`
# 동시 업글 함정(버전 mismatch) 비해당. mattermost 컨테이너 주소 churn(그 레퍼런스 고유) 비해당.
# 6.1 → 6.5 (2026-06-10): 릴리즈 트레인 월별 patch 넘버링 전환(6.2~6.4 stable 없음, 6.1 다음 stable=6.5).
# 우리 직접 이득: Anthropic/Codex/ACP/agent recovery 대거 수정(stream start를 message_start까지 대기 → prompt-cache
# 만료·Gateway restart 후 복구, compaction stale thinking signature 제거, 빈 completion handoff 거부, Codex
# 세션/스레드 마이그레이션 엣지케이스) + MCP tool-result 강제 coercion(Anthropic 400·세션 오염 방지) +
# message-tool send 가 delivery 로 카운트. Breaking/마이그레이션: auth profiles → SQLite 이전(#89102) →
# 업그레이드 후 doctor --fix 의무 + 3봇(main/bbot/mini) Anthropic auth GREEN 재확인(공유 ~/.claude mount 함정과
# 겹침). cron legacy JSON → SQLite 는 doctor preflight 자동 마이그레이션. 안심: 위험한 session-metadata SQLite
# 마이그레이션은 6.5 에서 의도적 보류(JSON-backed 유지). codex plugin stock(번들)이라 base bump 와 함께 자동 6.5.
# 6.5 → 6.6 (2026-06-13): 보안 경계 강화 위주 patch. 핵심 주의: "host 환경 상속 / MCP stdio / sandbox
# bind / Codex HTTP 접근" 경계가 조여짐 — emacs-agent.sh 의 env·소켓 주입 경로가 유일한 우리쪽 리스크
# (recreate 후 emacs-agent 동작 스모크 필수). 직접 이득: Telegram 라우팅/스트리밍/콜백 신뢰성 수정(주 채널)
# + 무단 DM 텍스트가 캐시/프롬프트 컨텍스트 미포함(cross-DM 사건 계열 하드닝) + 세션 재바인드 후 stale
# approval followup 제거 + 동일모델 호출 짧은 레이트리밋 재시도. 운영 변경: compaction 기본 타임아웃 180s
# 단축(명시 설정은 존중 — 우리 config 미명시면 짧아짐) + config.patch 배열 명시적 대체 + Gateway RPC timeout
# 입력검증 강화. provider: OpenRouter OAuth 온보딩 + Claude Fable 5 adaptive thinking + Ollama 선언 thinking
# 기본값 존중. Breaking/마이그레이션: "SQLite 인증 마이그레이션 검증 후 정리" → 업그레이드 후 doctor --fix
# 의무 유지(6.5 SQLite 이전의 연장) + 3봇 Anthropic auth GREEN 재확인(공유 ~/.claude mount 함정). gemini
# OAuth 스코프-403 는 base bump 무관(별도 device-code 재로그인 — ORACLE.md per-agent auth 함정 참조). codex
# plugin stock(번들)이라 base bump 와 함께 자동 6.6.
# 6.6 → 6.8 (2026-06-17): 유지보수·견고화 patch (6.7 stable 없음, 6.6 다음 stable=6.8 / 6.6→6.8=373 commits).
# 직접 이득: Telegram rich delivery(표/리스트/expandable blockquote/의도된 줄바꿈 보존 — 주 채널, 전 가족봇)
# + memory 견고화(과대 임베딩 배치 431 분할·full reindex rollback/cache 복구·QMD transient 유지) + Codex/Claude
# replay 복구(OpenAI reasoning-sig·Anthropic thinking-sig recovery, heartbeat dedupe, auto-reply final reply,
# unknown OpenAI selector 거부) + OAuth image-default를 Codex로 라우팅(우리 gpt-image-2 정합) + Hono 4.12.25 패치.
# 주의(post 검증): ① provider-prefix 정규화(OpenRouter/Vertex 경로) — gemini agy 드리프트와 겹침, 업글 후 6봇
# 모델 prefix 전수 재확인 의무(단 agy 이관 자체는 6.8에 없음 → gemini 403 DOWN 유지). ② web search auto-select
# 폐기(key-free provider 명시 opt-in 화) — perplexity 구성이라 영향 낮으나 검색 1회 확인. ③ tool schema quarantine
# (읽기불가/post-hook OpenAI·Anthropic schema 격리) — 스킬 도구 오격리 주시. SQLite auth 마이그레이션 연장선 →
# doctor --fix + 3봇(main/bbot/mini) Anthropic auth GREEN 재확인 유지. 비해당: Copilot tool-streaming/LM Studio
# binary-thinking/NFS WAL/WhatsApp·Slack·Discord·Feishu. codex plugin stock(번들)이라 base bump 와 함께 자동 6.8.
# 6.8 → 6.9 (2026-06-22): 유지보수·견고화 patch. 방침(GLG): gemini-cli 안 쫓음(403 DOWN 유지 수용), claude-cli+codex
# 서빙 유지가 목표, doctor --fix 는 조심 — 설정 통째 재작성 위험이라 read-only `doctor`만 보고 surgical config set/unset.
# 직접 이득: ① agent recovery 추가(session history repair, reply reconciliation, thinking-only·empty post-tool turn
# 재시도, partial JSON/history artifact 복구 — main/bbot/mini claude-cli + compaction 경로에 정확히 듣는 fix) +
# ② 보안 하드닝(secret redaction from debug/config output, open-DM tool exposure audit, HTTP session override 차단 —
# 가족봇 노출면) + ③ CJK IME composition preservation(한국어). 주의(post 검증): ④ Standalone official provider
# plugins(npm 외부화) + Gateway plugin discovery at startup — provider 로딩 구조 변경. codex/claude-cli 는 stock(번들)
# 이라 base bump 로 따라옴(tokenjuice/Copilot externalize 전례와 동일, line 35), 단 google-gemini-cli 가 외부화로
# 빠질 수 있으나 gemini 는 이미 403 DOWN → 안 쫓음. 업글 후 6봇 모델 prefix 전수 재확인(claude/codex 정상 서빙이 핵심,
# gemini 드리프트는 이번엔 revert 안 함). ⑤ Codex 자동 plugin 승인(SecretRefs)·remote-node exec dynamic tool —
# 승인/exec 동작 변화, 라이브 reply+exec 테스트 필수. GPT-5.3 Spark OAuth 라우팅은 우리 5.5/5.4 라 무관. 비해당:
# SQLite WAL on NFS(로컬 fs)/iOS Watch·Android/Dashboard session rail/OpenTelemetry export/StepFun. codex plugin
# stock(번들)이라 base bump 와 함께 자동 6.9.
# 6.9 → 6.10 (2026-06-24): 유지보수·견고화 patch (250 commits, 대부분 CI/test/chore(deadcode)/crabbox·parallels
# 빌드 격리 — 운영 영향 4그룹뿐). 방침(GLG) 동일: gemini-cli 안 쫓음(403 DOWN 유지), claude-cli+codex 서빙 유지가
# 목표, doctor --fix 미사용(read-only `doctor`만, surgical config set/unset). 직접 이득/주의: ① Fast mode for
# conversations — 짧은 대화 턴은 fast mode, 긴 런은 normal 복귀(codex/claude-cli/ACP 전반, retries·fallback·progress
# 에 fast-mode state 유지 + Codex service-tier clear & auto fast status 렌더). 유일한 사용자 가시 신기능 → 동작
# 변화라 라이브 reply 검증 필수(깨질 위험은 낮음). ② hook registry trusted-policy 보존(#94545 — before_tool_call이
# composed registry 일관 사용, approval workflow용. 우리 approval 비활성이라 영향 적음) + codex projected-context-
# after-hooks 견고화 다수. ③ provider plugin registry refresh after setup installs(#95792 — onboarding에서 외부
# provider(deepseek/groq/cerebras) 설치 후 stale registry로 auth 끊기던 것 fix. 우리 onboarding 안 함 → 직접 무관,
# 단 deepseek 부활 시 plugins install 흐름에 도움). ④ cron delivery awareness for target sessions(#93580) + 채널
# 전환 시 stale channel-origin 누수 차단. 비해당: Zai GLM-5.2 reasoning levels / StepFun ClawHub / Gemini schema
# deadcode 제거. Breaking 없음(릴리즈 노트 명시 + compare에 schema/migration breaking commit 부재). codex plugin
# stock(번들)이라 base bump 와 함께 자동 6.10. gemini 는 google-gemini-cli/gemini-3.1-pro-preview 유지(403 DOWN,
# agy 이관 대기) — doctor --fix 미사용으로 드리프트 0 예상, 단 업글 후 `agents list` 로 gemini prefix 전수 재확인.
# 6.10 → 6.11 (2026-06-30 릴리즈, 2026-07-01 적용): 순수 신뢰성/버그픽스 patch. 신규 provider 0, breaking 0,
# 필수 마이그레이션은 세션키 자동 정규화뿐 — 가장 순한 hop. 방침(GLG) 동일: gemini-cli 안 쫓음(403 DOWN),
# claude-cli+codex 서빙 유지, doctor --fix 미사용(read-only `doctor`만, surgical config set/unset). 직접 이득:
# ① Telegram 채널 전달 신뢰성(DM 라우팅 교정·재접속 컨텍스트 보존·세션 변경 후 대화 맥락 유지 — 주 채널, 전
# 가족봇) ② QMD memory search 가 설정 임베딩 차원 존중 → 우리 4096d(qwen3-8b) 정합 픽스 ③ Codex 구독 한도
# 처리 개선(fallback 지원 — 단 우리 fallbacks:[] 정공법 유지, 업글 후 glg/gpt fallbacks 빈 상태 확인) ④ 세션/
# 메모리 재접속 연속성 + 플러그인 채널 대화 바인딩 → 공유 상태 DB 이전(6.5 SQLite 계열, 저위험). 비해당(안심):
# "Gemini 3.5 Flash 1M" 은 google/ API 경로(우리 google-gemini-cli OAuth 403 DOWN 과 무관) + agy/antigravity
# provider 여전히 미등장(gemini 안 쫓음) + DeepSeek V4 ID 픽스(6.9 에 allowlist 제거, 무관). Sonnet 5
# (claude-sonnet-5, 07-01 출시)는 6.11 미포함(6/30 릴리즈)이나 claude-cli 봇은 구독 API 동적 해결이라 카탈로그
# 등록만으로 태움(재빌드 무관, opus-4-8 5.28 방식). codex plugin stock(번들)이라 base bump 와 함께 자동 6.11.
# 업글 후 `agents list` 로 6봇 모델 prefix 전수 재확인(gemini google-gemini-cli/ 유지), main/bbot/mini Anthropic
# auth GREEN, memory 4096d, glg/gpt fallbacks 빈 상태.
# 6.11 → 7.1 (2026-07-14): 월간 대형 롤업(2,018 PR / 3,063 기여). breaking 섹션 없음, 릴리즈 자체가 "안전한
# 업그레이드" 기조. 핵심: GPT-5.6 세 티어 진입 — `openai/gpt-5.6-{sol,terra,luna}` (sol=flagship 이자 bare
# `openai/gpt-5.6` 별칭, terra=균형, luna=저가·고속, 셋 다 xhigh/max reasoning). **limited preview** 라 우리
# Codex OAuth 워크스페이스 접근권은 업글 후 `models list --provider openai` 로 확인해야 안다 → **우리 워크스페이스는
# 세 티어 전부 카탈로그 등재 + 서빙 확인**(272k, text+image). 명시적 모델 핀은 대체되지 않음(fresh 설정만 5.6 기본값
# 픽업) — 업글 직후 glg/gpt `openai/gpt-5.5` 그대로였다. 비용축: Codex 크레딧 sol:terra:luna = 125:62.5:25
# (1M input), 메시지당 평균 5~40 크레딧 (기존 5.5 = 14 크레딧/msg).
# **GLG 결정(2026-07-14) — 승격 실행**: gpt → `openai/gpt-5.6-sol`, glg(가족) → `openai/gpt-5.6-terra`.
# main=opus-4-8 / bbot=fable-5 / mini=sonnet-5 현행 유지. 5.28/fable-5 원칙대로 primary 유지한 채 `--model`
# 오버라이드 격리 probe(`--deliver` 없이, 실사용자 노출 0)로 선검증 — sol/terra 둘 다 `fallbackUsed=false`
# 확인 후 promote, 승격 뒤 오버라이드 없는 라이브 턴으로 재확인(winnerModel=gpt-5.6-{sol,terra}, fallback 0).
# 5.5 는 per-agent 카탈로그에 롤백용으로 보존, allowlist catch-all 1번 자리도 `openai/gpt-5.5` 유지(정체성
# 훼손 최소 catch-all 원칙). ⚠️ **기존 DM 세션은 저장된 model(5.5)을 유지** — 신규 세션부터 5.6 픽업,
# 즉시 전환하려면 세션에서 `/model` 또는 세션 리셋.
# 주의 자리 셋: ① **컨테이너 업그레이드가 마이그레이션+플러그인 수리를 ready 보고 전에 자동 수행** → gemini
# `google-gemini-cli/` prefix 전수 재확인 필수(6.6·6.8 에서 `google/` 드리프트 2회 전력). 7.1 실측: **자동
# 마이그레이션은 gemini 를 건드리지 않았다(드리프트 0)**. 단 `doctor` changes-preview 에는 "Moved
# agents.list.gemini.model legacy runtime primary refs to canonical provider refs" 가 여전히 대기 중 —
# 즉 **`--fix` 를 돌리는 순간 `google/` 로 재작성된다. 7.1 에서도 --fix 금지 유효.** agy/antigravity provider
# 는 7.1 에도 미등장 — 기준선은 여전히 OAuth prefix, 안 쫓음. ② doctor --fix 가 "retired 모델명 병합"도 수행
# (alias/파라미터/streaming/runtime 보존은 개선됨) — 우리 롤백용 카탈로그(sonnet-4-6, opus-4-8, gpt-5.5)가
# 병합 대상이 될 수 있어 **--fix 여전히 금지**, read-only `doctor` + surgical config set/unset 만.
# ③ **mattermost 번들 externalize** (deepseek 6.9 패턴 반복) → boot Config warning "plugin not installed".
# 우리 엔트리는 `enabled:false` 죽은 설정이라 `config unset plugins.entries.mattermost` 로 제거(WARN 0 복귀).
# `channels.mattermost` 는 botToken 을 든 dead 설정으로 라이브 config 에 남아있음 — 정리는 NEXT.md.
# 메모리 마이그레이션(실측): legacy `~/.openclaw/memory/*.sqlite` → per-agent SQLite 로 통합. main/glg/gpt/bbot
# 은 이미 per-agent 저장소를 쓰고 있어 레거시 사이드카만 `.migrated` 아카이브, gemini(670 chunk)/mini(125 chunk)
# 만 실제 이관. 업글 후 검증: 4096d(qwen3-embedding-8b) 유지, main 316 / glg 3650 / gpt 862 chunk 인덱스 정상,
# `memory search` 실검색 통과. `.migrated` 아카이브(총 ~1.4G)는 롤백 대비 보존 — 회수는 NEXT.md.
# 직접 이득: ① Gateway 크래시 무한 재시작 루프 제거 — 반복 실패 시 재시작 루프 대신 검사·수리 가능한 control
# process 로 정지(우리가 autoheal 로 감싸던 실패 모드) ② 세션 pin/archive(전사 보존)/rename + active goal 이
# compaction·큐·인터럽트 넘어 생존 ③ Dashboard 재접속 메모리 급증(false rss_growth 경고) 완화 ④ 채널 메타데이터
# 캐시 bounded(장기 실행 채널 메모리 누수 차단). 비해당(안심): Bun 런타임 SQLite 차단은 우리 Node 라 무관,
# deepseek 는 6.9 에 이미 정리, Copilot/ClawRouter/LongCat/Hy3/Muse Spark 는 미사용 provider.
# 롤백용: FROM ghcr.io/openclaw/openclaw:2026.6.11
FROM ghcr.io/openclaw/openclaw:2026.7.1

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ripgrep \
    fd-find \
    jq \
    tree \
    curl \
    ffmpeg \
    python3-minimal \
    python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd

# yt-dlp (pip — GitHub binary download가 불안정)
RUN pip install --no-cache-dir --break-system-packages yt-dlp

# jsonschema — butlercli estate surface bridge(skills/butlercli/scripts/estate_surface.py).
# 봇이 viewer(map.junghanacs.com)로 IR을 post하기 전 클라이언트 fail-closed 검증에 필수
# (계약 SSOT, fallback 없음). 없으면 sample/validate/post가 "NEED: pip install jsonschema"로 정지.
RUN pip install --no-cache-dir --break-system-packages jsonschema

# summarize CLI (@steipete/summarize — URL/파일/미디어 요약)
RUN npm install -g @steipete/summarize \
    && mkdir -p /home/node/.summarize \
    && echo '{"model":{"id":"openrouter/google/gemini-3-flash-preview"}}' > /home/node/.summarize/config.json \
    && chown -R node:node /home/node/.summarize

# GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Matrix 플러그인: 3.22에서 matrix-js-sdk로 전면 교체됨.
# 현재 미사용 (plugins.entries.matrix.enabled=false)
# 추후 필요 시 새 SDK 방식으로 재설치

# claude-code: 5.22 base가 더 이상 binary 번들하지 않음 (5.20까지 @anthropic-ai/claude-agent-sdk 번들,
#   5.22는 raw @anthropic-ai/sdk만) → claude-cli provider가 spawn할 `claude` binary를 별도 install. native 0.
# ※ 6.11 (2026-07-01) 제거 3건 (unused + aarch64 node-gyp hang 회피):
#   - @earendil-works/pi-coding-agent(pi ACP entrypoint), @zed-industries/codex-acp(codex ACP backend):
#     ACP 완전 폐기(pi-shell-acp 6.9 제거, 봇 전부 OpenClaw native)로 unused. config 미참조 + GLG "안 씀".
#   - @google/gemini-cli: gemini 403 DOWN(agy 이관 대기, 안 쫓음) + node-gyp hang 진짜 범인 — 0.49.0이
#     @github/keytar + node-pty(native) 를 끌어와 buildkit에서 컴파일 hang. 부활(agy) 시 복원(libsecret-dev
#     등 build deps 필요할 수 있음).
RUN npm install -g \
      @anthropic-ai/claude-code

USER node
