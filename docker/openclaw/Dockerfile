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
# 롤백용: FROM ghcr.io/openclaw/openclaw:2026.6.5
FROM ghcr.io/openclaw/openclaw:2026.6.6

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

# pi-shell-acp 런타임 (Phase 1.8 β host passthrough 경로)
# - pi: child process 호출 entrypoint
# - codex-acp / gemini: backend ACP executables
# - claude-code: 5.22 base가 더 이상 binary 번들하지 않음 (5.20까지 @anthropic-ai/claude-agent-sdk 번들,
#   5.22는 raw @anthropic-ai/sdk만) → claude-cli provider가 spawn할 `claude` binary를 별도 install.
# pi-shell-acp 자체는 host ~/.pi/agent bind-mount로 노출 (compose 참조)
RUN npm install -g \
      @earendil-works/pi-coding-agent \
      @zed-industries/codex-acp \
      @google/gemini-cli \
      @anthropic-ai/claude-code

USER node
