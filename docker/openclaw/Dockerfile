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
# 롤백용: FROM ghcr.io/openclaw/openclaw:2026.5.20
FROM ghcr.io/openclaw/openclaw:2026.5.22

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
