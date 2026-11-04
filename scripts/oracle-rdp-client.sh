#!/usr/bin/env bash
# Oracle RDP client (#14) — run on the CLIENT device (e.g. thinkpad), not on Oracle.
#
# Opens a loopback-only local port that forwards through Cloudflare Access to the
# Oracle RDP tunnel. Authentication is the existing Access login; this script holds
# no password or token. It only connects while the server-side connector runs on
# Oracle (`run.sh` → R there, 3 hours per start).
#
# Local port: ORACLE_RDP_LOCAL_PORT (default 13389). Stop with Ctrl-C.
set -uo pipefail

# The RDP-only hostname: the Cloudflare Access application and the tunnel ingress.
# Defined here once; run.sh only calls this script.
HOST=oracle-rdp.junghanacs.com

err() { printf '✗ %s\n' "$*" >&2; }

device=$(tr '[:upper:]' '[:lower:]' < "$HOME/.current-device" 2>/dev/null | tr -d '[:space:]' | cut -d- -f1)
if [[ "$device" == oracle ]]; then
	err "이 메뉴는 클라이언트 기기용이다. Oracle 자신에서는 실행하지 않는다."
	exit 2
fi

if ! command -v cloudflared >/dev/null 2>&1; then
	err "cloudflared 가 PATH 에 없다. 이 기기 NixOS 선언에 cloudflared 가 있는지 확인한다."
	exit 2
fi

port="${ORACLE_RDP_LOCAL_PORT:-13389}"
if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1024 || port > 65535 )); then
	err "로컬 포트가 이상하다: $port (1024–65535)"
	exit 2
fi
if command -v ss >/dev/null 2>&1; then
	if [[ -n "$(ss -H -ltn "( sport = :$port )" 2>/dev/null)" ]]; then
		err "127.0.0.1:$port 를 이미 누가 쓰고 있다. 기존 프로세스는 건드리지 않는다 — 먼저 그쪽을 끝내거나 ORACLE_RDP_LOCAL_PORT 로 다른 포트를 쓴다."
		exit 1
	fi
fi

cat <<EOF
Oracle RDP — 로컬 루프백 터널을 연다 (Ctrl-C 로 종료)
  1. 브라우저에서 Cloudflare Access 로그인을 승인한다.
  2. RDP 클라이언트로 127.0.0.1:$port 에 접속한다.
     사용자: browser   암호: 본인이 정한 암호
  3. 첫 접속이면 서버 인증서 SHA256 지문을 ORACLE.md 값과 대조한다.
  Oracle 쪽 connector 가 떠 있어야 연결된다 (Oracle 에서 run.sh → R → 1, 3시간).
EOF

exec cloudflared access rdp --hostname "$HOST" --url "rdp://127.0.0.1:$port"
