#!/usr/bin/env bash
# Oracle RDP connector (#14) — run ON ORACLE. Usage: oracle-rdp-connector.sh start|status|stop
#
# Starts the dedicated Cloudflare tunnel connector for the RDP hostname, bounded to
# 3 hours (timeout 10800). No auto-extension, no restart loop, no systemd unit:
# when it ends, only the network path closes. The XFCE session and Agent Chrome
# keep running (sesman KillDisconnected=false); this script never touches them.
#
# Config: ORACLE_RDP_TUNNEL_CONFIG (default ~/.cloudflared/oracle-rdp.yml, 600, kept
# private next to its credential). Nothing here talks to the Cloudflare API.
#
# A connector is "ours" when it is a cloudflared process of this user whose --config
# names the same tunnel id as CFG, whatever path or cwd it was started with. Other
# tunnels on this host (another config, another tunnel id) are never matched.
set -uo pipefail

LIMIT=10800
SESSION="${ORACLE_RDP_TMUX_SESSION:-oracle-rdp-connector}"
CFG="${ORACLE_RDP_TUNNEL_CONFIG:-$HOME/.cloudflared/oracle-rdp.yml}"
STATE="${ORACLE_RDP_STATE_DIR:-$HOME/.local/state/oracle-rdp}"
LOG="$STATE/connector.log"

err() { printf '✗ %s\n' "$*" >&2; }
kst() { TZ=Asia/Seoul date -d "@$1" '+%F %T'; }

device=$(tr '[:upper:]' '[:lower:]' < "$HOME/.current-device" 2>/dev/null | tr -d '[:space:]' | cut -d- -f1)
[[ "$device" == oracle ]] || { err "Oracle 에서만 실행한다 (현재: ${device:-unknown})."; exit 2; }

# First `tunnel:` value of a config file (the id only; nothing else is read out).
tunnel_id() { sed -n -E 's/^tunnel:[[:space:]]*([0-9A-Za-z-]+)[[:space:]]*$/\1/p' "$1" 2>/dev/null | head -n1; }
WANT=$(tunnel_id "$CFG")

# Process start time in clock ticks since boot (field 22 of /proc/PID/stat).
proc_start() { sed -E 's/^.*\) //' "/proc/$1/stat" 2>/dev/null | cut -d' ' -f20; }

# The --config path a cloudflared process was started with, resolved against its cwd.
proc_config() {
	local p=$1 cwd c="" prev="" a
	cwd=$(readlink "/proc/$p/cwd" 2>/dev/null) || return 1
	while IFS= read -r -d '' a; do
		if [[ "$prev" == --config ]]; then c=$a; fi
		if [[ "$a" == --config=* ]]; then c=${a#--config=}; fi
		prev=$a
	done < "/proc/$p/cmdline"
	[[ -n "$c" ]] || return 1
	[[ "$c" == /* ]] || c="$cwd/$c"
	printf '%s\n' "$c"
}

is_ours() {
	local p=$1 c
	c=$(proc_config "$p") || return 1
	[[ "$(readlink -f "$c")" == "$(readlink -f "$CFG")" ]] && return 0
	[[ -n "$WANT" && "$(tunnel_id "$c")" == "$WANT" ]]
}

connector_pids() {
	local p
	for p in $(pgrep -x -u "$(id -u)" cloudflared 2>/dev/null); do
		is_ours "$p" && printf '%s\n' "$p"
	done
}

# Expiry comes from the `timeout N` parent, if there is one; otherwise it is unknown.
limit_of() {
	local pp a n=""
	pp=$(ps -o ppid= -p "$1" | tr -d ' ')
	[[ "$(cat "/proc/$pp/comm" 2>/dev/null)" == timeout ]] || return 1
	while IFS= read -r -d '' a; do
		[[ "$a" =~ ^[0-9]+$ ]] && { n=$a; break; }
	done < "/proc/$pp/cmdline"
	[[ -n "$n" ]] && printf '%s\n' "$n"
}

status() {
	local p start lim
	p=$(connector_pids | head -n1)
	if [[ -z "$p" ]]; then
		echo "connector: 꺼짐"
		return 1
	fi
	start=$(date -d "$(ps -o lstart= -p "$p")" +%s)
	echo "connector: 켜짐 PID $p · config $(proc_config "$p")"
	if lim=$(limit_of "$p"); then
		echo "  시작 $(kst "$start") · 만료 ≤ $(kst $((start + lim))) KST (상한 ${lim}s, 연장 없음)"
	else
		echo "  시작 $(kst "$start") KST · 상한 미상 (timeout 부모가 없다)"
	fi
	[[ -f "$LOG" ]] && echo "  등록된 연결(이 스크립트 로그 기준): $(grep -c 'Registered tunnel connection' "$LOG")"
	return 0
}

check_config() {
	local dir
	dir=$(dirname "$CFG")
	[[ -f "$CFG" && ! -L "$CFG" ]] || { err "config 가 없거나 일반 파일이 아니다: $CFG"; return 1; }
	[[ "$(stat -c '%a %u' "$CFG")" == "600 $(id -u)" ]] || { err "config 는 600, 본인 소유여야 한다: $CFG"; return 1; }
	[[ ! -L "$dir" && "$(stat -c '%a %u' "$dir")" == "700 $(id -u)" ]] || { err "config 디렉터리는 700, 본인 소유여야 한다: $dir"; return 1; }
	[[ -n "$WANT" ]] || { err "config 에 tunnel id 가 없다: $CFG"; return 1; }
}

case "${1:-status}" in
	start)
		if [[ -n "$(connector_pids)" ]]; then
			err "같은 터널 connector 가 이미 켜져 있다. 연장·중복 시작하지 않는다."
			status
			exit 1
		fi
		check_config || exit 2
		command -v cloudflared >/dev/null 2>&1 || { err "cloudflared 가 PATH 에 없다."; exit 2; }
		tmux has-session -t "=$SESSION" 2>/dev/null && { err "tmux 세션 $SESSION 이 이미 있다. 먼저 확인한다."; exit 1; }
		install -d -m 700 "$STATE"
		(umask 077; : >> "$LOG")
		tmux new-session -d -s "$SESSION" \
			"echo \"start \$(TZ=Asia/Seoul date -Is) limit=${LIMIT}s\" >> '$LOG'; timeout $LIMIT cloudflared tunnel --no-autoupdate --config '$CFG' run >> '$LOG' 2>&1; echo \"exit=\$? end=\$(TZ=Asia/Seoul date -Is)\" >> '$LOG'"
		for _ in $(seq 1 20); do [[ -n "$(connector_pids)" ]] && break; sleep 1; done
		status
		;;
	status)
		status
		;;
	stop)
		mapfile -t pids < <(connector_pids)
		(( ${#pids[@]} )) || { echo "connector: 이미 꺼짐"; exit 0; }
		declare -A born
		for p in "${pids[@]}"; do born[$p]=$(proc_start "$p"); done
		for p in "${pids[@]}"; do
			# Same process as a moment ago (start time unchanged) and still this tunnel.
			if [[ -n "${born[$p]}" && "$(proc_start "$p")" == "${born[$p]}" ]] && is_ours "$p"; then
				echo "TERM → $p (connector 만 끈다. XFCE·Chrome 세션은 그대로)"
				kill -TERM "$p"
			fi
		done
		for _ in $(seq 1 40); do [[ -z "$(connector_pids)" ]] && { echo "connector: 꺼짐"; exit 0; }; sleep 1; done
		err "40초 뒤에도 남아 있다: $(connector_pids | tr '\n' ' ')"
		exit 1
		;;
	*)
		err "usage: $0 start|status|stop"
		exit 2
		;;
esac
