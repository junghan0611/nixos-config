#!/usr/bin/env bash
# Oracle quarterly maintenance: collect evidence only, never clean/activate/reboot.
set -uo pipefail

NIX_PLAN=false
for arg in "$@"; do
    case "$arg" in
        --nix-plan) NIX_PLAN=true ;;
        -h|--help)
            printf '%s\n' 'Usage: bash scripts/oracle-maintenance-preflight.sh [--nix-plan]' \
                'Default: system facts + diskclean deep --dry-run; no deletion or activation.' \
                '--nix-plan: also evaluate the pinned flake (may fetch/store input sources).' \
                'Reports: .agent-reports/oracle-maintenance/ (private, persistent).'
            exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

if [[ -n "${DEVICE:-}" ]]; then
    device="$DEVICE"
elif [[ -f "$HOME/.current-device" ]]; then
    device=$(< "$HOME/.current-device")
else
    printf '%s\n' 'Device unknown: ~/.current-device missing.' >&2; exit 2
fi
device=$(printf '%s' "$device" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
[[ "${device%%-*}" == oracle ]] || { printf '%s\n' 'Oracle only; no checks run.' >&2; exit 2; }

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P) || exit 2
umask 077
BASE="$REPO/.agent-reports/oracle-maintenance"
mkdir -p -- "$BASE" || exit 2
chmod 700 "$BASE" || exit 2
R=$(mktemp -d "$BASE/$(TZ=Asia/Seoul date +%Y%m%dT%H%M%S).XXXXXX") || exit 2
LOG="$R/preflight.log"
failed=0
# Preserve exactly the public procedure bytes used, even before they are committed.
mkdir "$R/source" || exit 2
for relative in scripts/oracle-maintenance-preflight.sh scripts/diskclean.sh run.sh docs/oracle-maintenance.md .claude/skills/oracle-reboot/SKILL.md docs/data-retirement.md ORACLE.md docs/openclaw-automations.md; do
    source_file="$REPO/$relative"
    if [[ ! -f "$source_file" ]]; then
        printf 'Procedure source missing: %s\n' "$relative" >&2
        exit 2
    fi
    cp -- "$source_file" "$R/source/$(basename "$source_file")" || exit 2
    chmod 600 "$R/source/$(basename "$source_file")" || exit 2
done

step() {
    printf '\n=== %s ===\n' "$1" | tee -a "$LOG"
    shift
    "$@" 2>&1 | tee -a "$LOG"
    local statuses=("${PIPESTATUS[@]}")
    if [[ "${statuses[0]}" -ne 0 || "${statuses[1]}" -ne 0 ]]; then
        failed=1
        printf 'COLLECTION_ERROR command=%s exit=%s log_exit=%s\n' "$1" "${statuses[0]}" "${statuses[1]}" | tee -a "$LOG"
    fi
}

gc_roots() {
    nix-store --gc --print-roots | awk 'index($0,"/proc/")==0'
}

long_processes() {
    ps -u "$(id -u)" -o user,pid,ppid,etimes,comm --sort=-etimes | awk 'NR<=80'
}

compare_desired() {
    local desired current booted
    desired=$(nix eval --offline --no-update-lock-file --raw "$REPO#nixosConfigurations.oracle.config.system.build.toplevel.outPath") || return $?
    current=$(readlink -e /run/current-system) || return $?
    booted=$(readlink -e /run/booted-system) || return $?
    printf 'desired=%s\n' "$desired"
    if [[ "$desired" == "$current" ]]; then echo 'desired/current=SAME'; else echo 'desired/current=DIFF'; fi
    if [[ "$desired" == "$booted" ]]; then echo 'desired/booted=SAME'; else echo 'desired/booted=DIFF'; fi
}

printf 'Persistent report: %s\n' "$R"
step 'Time (KST)' env TZ=Asia/Seoul date --iso-8601=seconds
step 'Boot age' python3 -c 'import datetime,pathlib,zoneinfo; s=float(pathlib.Path("/proc/uptime").read_text().split()[0]); n=datetime.datetime.now(zoneinfo.ZoneInfo("Asia/Seoul")); print("boot_kst="+(n-datetime.timedelta(seconds=s)).isoformat(timespec="seconds")); print("uptime_days="+str(round(s/86400,1)))'
step 'Repository state (no optional index refresh)' git --no-optional-locks -C "$REPO" status -sb
step 'Repository revision' git --no-optional-locks -C "$REPO" rev-parse HEAD
step 'Procedure snapshot hashes' sha256sum "$R/source/"*
step 'Disk space' df -hT / "$HOME" /tmp
step 'User-available bytes (not logical/shared reclaimable sizes)' df -B1 / "$HOME"
step 'Inodes' df -i / "$HOME"
step 'Memory' free -h
step 'Running kernel' uname -r
step 'Current system' readlink -e /run/current-system
step 'Booted system' readlink -e /run/booted-system
step 'Default system profile' readlink -e /nix/var/nix/profiles/system
step 'Boot loader default' python3 -c 'from pathlib import Path; print(Path("/boot/loader/loader.conf").read_text())'
step 'Nix GC roots (no collection)' gc_roots
step 'Failed units (inspect the rows, not just exit status)' systemctl --failed --no-pager --plain
step 'Failed user units' systemctl --user --failed --no-pager --plain
step 'Emacs server probe (no automatic startup)' timeout 8 emacsclient -s server --alternate-editor=false --eval '(+ 1 1)'
step 'Long-running user process metadata (top80, no command arguments)' long_processes
step 'Docker disk accounting (shared sizes are not freed-space guarantees)' docker system df
step 'Dangling images (no deletion)' docker images --filter dangling=true --no-trunc
step 'Containers' docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
step 'Gateway image/state' docker inspect openclaw-gateway --format 'image={{.Image}} init={{.HostConfig.Init}} running={{.State.Running}} health={{.State.Health.Status}} restart={{.RestartCount}}'
printf '%s\n' 'ESTIMATE_UNAUDITED: diskclean hides some du/find errors; exit0 does not prove the estimate complete or approve all its targets.' | tee -a "$LOG"
step 'Cleanup estimate only; partial errors may be hidden (no pnpm/docker)' env DEVICE=oracle bash "$REPO/scripts/diskclean.sh" deep --dry-run
if $NIX_PLAN; then
    step 'Nix build plan only; input sources may enter store' nix build --offline --no-update-lock-file --dry-run --no-link "$REPO#nixosConfigurations.oracle.config.system.build.toplevel"
    step 'Desired system (compare with current/booted)' compare_desired
fi

printf '%s\n' 'DATA_REVIEW_PENDING: this collection does not scan/classify all home data or approve retirement. Follow oracle-reboot section1.1 and source/data-retirement.md; record scope, restore sources, shared/readonly/active references and provider pauses in storage-review.md (including explicit unchanged/deferred decisions).' | tee -a "$LOG"
printf '\nReport: %s\n' "$R" | tee -a "$LOG"
if [[ "$failed" -ne 0 ]]; then
    printf '%s\n' 'COLLECTION_INCOMPLETE: inspect command errors. No cleanup/activation/reboot performed.' | tee -a "$LOG"
    exit 2
fi
printf '%s\n' 'COLLECTION_COMPLETE: evidence collected, NOT health/cleanup/reboot approval. No cleanup/activation/reboot performed.' | tee -a "$LOG"
