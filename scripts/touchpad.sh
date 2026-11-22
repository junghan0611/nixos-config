#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'touchpad: %s\n' "$*" >&2; exit 1; }

case ${1:-toggle} in
	-h|--help) echo 'Usage: touchpad [on|off|toggle|status] [device name]'; exit 0 ;;
	on|off|toggle|status) action=${1:-toggle} ;;
	*) fail 'expected on, off, toggle, or status' ;;
esac
[[ $# -le 2 ]] || fail 'pass the device name as one quoted argument'
[[ -n ${DISPLAY:-} && ${XDG_SESSION_TYPE:-x11} != wayland ]] || fail 'run inside an X11 session'
command -v xinput >/dev/null || fail 'xinput not found'

name=${2:-}
if [[ -z $name ]]; then
	devices=$(xinput list --name-only) || fail 'cannot list X11 input devices'
	matches=()
	while IFS= read -r device; do
		device=${device#∼ }
		[[ ${device,,} == *touchpad* ]] && matches+=("$device")
	done <<< "$devices"
	[[ ${#matches[@]} == 1 ]] || fail 'expected one touchpad; use xinput list and pass its exact name as the second argument'
	name=${matches[0]}
fi
id=$(xinput list --id-only "$name") || fail "cannot resolve device: $name"
[[ $id =~ ^[0-9]+$ ]] || fail "ambiguous device: $name"
props=$(xinput list-props "$id") || fail "cannot read device properties: $name"
pattern='Device Enabled \([0-9]+\):[[:space:]]*([01])'
[[ $props =~ $pattern ]] || fail "cannot read enabled state: $name"
state=${BASH_REMATCH[1]}
if [[ $action == toggle ]]; then
	if [[ $state == 1 ]]; then action=off; else action=on; fi
fi
case $action in
	on) xinput enable "$id"; state=1 ;;
	off) xinput disable "$id"; state=0 ;;
esac
if [[ $state == 1 ]]; then echo "$name: on"; else echo "$name: off"; fi
