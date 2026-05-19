# 5.12 → 5.18 (2026-05-19): Node 22.19 minimum + Pi packages 0.75.1 + Telegram polling
# 안정성 다수 (isolated polling guard / hot-reload restart / HTTP 421 retry / forum-topic) +
# Memory-core L199 incremental sync fix + Codex OAuth fallback 강화 (L164/L121/L122) +
# stuck-recovery L59 강화 + ACP wire 정리 (L165/L168).
# 5.12 정공법 (openai/* + agentRuntime.id=codex) 그대로 유지. plugin pi-shell-acp d4f5772.
# 롤백용: FROM ghcr.io/openclaw/openclaw:2026.5.12
FROM ghcr.io/openclaw/openclaw:2026.5.18

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
# - codex-acp / gemini: backend ACP executables (Claude는 pi-shell-acp 내부 require.resolve)
# pi-shell-acp 자체는 host ~/.pi/agent bind-mount로 노출 (compose 참조)
RUN npm install -g \
      @earendil-works/pi-coding-agent \
      @zed-industries/codex-acp \
      @google/gemini-cli

USER node
