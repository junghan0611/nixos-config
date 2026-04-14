#!/bin/sh
set -eu

SERVER_FILE="$(grep -rl 'mcp loopback listening' /app/dist/*.js 2>/dev/null | head -n 1 || true)"

if [ -n "$SERVER_FILE" ] && ! grep -q '__GLUECLAW_MCP_PORT' "$SERVER_FILE"; then
  python3 - "$SERVER_FILE" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()
needle = "logDebug(`mcp loopback listening"
replacement = "process.env.__GLUECLAW_MCP_PORT = String(address.port); process.env.__GLUECLAW_MCP_TOKEN = token; logDebug(`mcp loopback listening"

if "__GLUECLAW_MCP_PORT" not in s:
    if needle not in s:
        raise SystemExit(f"glueclaw patch needle not found in {p}")
    s = s.replace(needle, replacement, 1)
    p.write_text(s)
    print(f"[glueclaw] patched {p}")
else:
    print(f"[glueclaw] already patched {p}")
PY
fi

exec node openclaw.mjs gateway --bind lan --port 18789
