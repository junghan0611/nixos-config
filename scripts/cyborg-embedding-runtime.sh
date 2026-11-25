#!/usr/bin/env bash
# Temporary loopback-only CUDA Ollama; never switches the default service.
set -euo pipefail

unit=cyborg-embedding-cuda.service
base=http://127.0.0.1:11435
case "${1:-}" in
  start)
    [[ $(< "$HOME/.current-device") == cyborg ]] || { echo 'Cyborg only' >&2; exit 1; }
    bin=$(readlink -e "${OLLAMA_CUDA_BIN:-/tmp/cyborg-ollama-cuda/bin/ollama}")
    [[ -x "$bin" ]] || exit 1
    systemctl is-active --quiet ollama.service || {
      echo 'Start the existing ollama.service first so its model-store identity is active.' >&2
      exit 1
    }
    sudo systemd-run --unit="$unit" --collect \
      -p User=ollama -p Group=ollama -p DynamicUser=yes -p StateDirectory=ollama \
      -p RuntimeMaxSec=20min \
      -E HOME=/var/lib/ollama -E OLLAMA_MODELS=/var/lib/ollama/models \
      -E OLLAMA_HOST=127.0.0.1:11435 -E OLLAMA_NOPRUNE=true -E OLLAMA_NO_CLOUD=true \
      -E OLLAMA_MAX_LOADED_MODELS=1 -E OLLAMA_CONTEXT_LENGTH=2048 "$bin" serve
    for (( i=0; i<15; i++ )); do
      if systemctl is-active --quiet "$unit" && curl -fs --max-time 1 "$base/api/version" >/dev/null; then
        printf '%s\n' "$base"
        exit 0
      fi
      sleep 1
    done
    sudo systemctl stop "$unit" || true
    echo "CUDA Ollama did not become ready; inspect journalctl -u $unit" >&2
    exit 1
    ;;
  stop) sudo systemctl stop "$unit" ;;
  status) systemctl status --no-pager "$unit" ;;
  *) echo "Usage: $0 start|stop|status" >&2; exit 2 ;;
esac
