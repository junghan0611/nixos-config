FROM ghcr.io/openclaw/openclaw:latest

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ripgrep \
    fd-find \
    jq \
    tree \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd

# Google Workspace CLI (gccli, gdcli, gmcli)
RUN npm install -g @mariozechner/gccli @mariozechner/gdcli @mariozechner/gmcli

USER node
