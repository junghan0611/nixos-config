#!/usr/bin/env bash
# diskclean.sh — 디바이스 인식 디스크 정리 루틴
#
# 왜 스크립트인가: 정리 대상은 디바이스마다 다르다. oracle은 headless라 휴지통·브라우저
# 캐시가 없고 OpenClaw 컨테이너가 살아있어 docker/GC를 보수적으로 다뤄야 한다.
# laptop/thinkpad는 정반대로 GUI 캐시와 repo 빌드 캐시가 용량의 대부분이다.
# 디바이스 SSOT는 ~/.current-device (run.sh와 동일 규칙: 'oracle-nixos' → 'oracle').
#
# 사용법:
#   scripts/diskclean.sh                    # safe 레벨, 확인 프롬프트
#   scripts/diskclean.sh deep               # 공격적
#   scripts/diskclean.sh safe --dry-run     # 계산만, 삭제 안 함
#   scripts/diskclean.sh deep --yes         # 무인 실행
#   scripts/diskclean.sh deep --with-docker --with-pnpm
#
# 레벨:
#   safe — 재생성/재다운로드만 필요한 것. 작업 손실 없음.
#   deep — safe + store optimise + repo 빌드 캐시 + 브라우저/툴 캐시.
#          빌드 캐시가 날아가므로 다음 빌드가 느려진다.
#
# opt-in (기본 제외 — 이유가 있다):
#   --with-pnpm   pnpm store prune. store는 repo node_modules와 하드링크라
#                 라이브 node/pi 세션이 돌고 있으면 건드리지 않는다.
#   --with-docker dangling 이미지 + 빌드 캐시. oracle에서는 OpenClaw 런타임이라
#                 실행 중 컨테이너 이미지 보존 필터에만 의존하지 말고 눈으로 확인.

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

LEVEL="safe"
DRY_RUN=false
ASSUME_YES=false
WITH_PNPM=false
WITH_DOCKER=false

for arg in "$@"; do
    case "$arg" in
        safe|deep)     LEVEL="$arg" ;;
        --dry-run)     DRY_RUN=true ;;
        --yes|-y)      ASSUME_YES=true ;;
        --with-pnpm)   WITH_PNPM=true ;;
        --with-docker) WITH_DOCKER=true ;;
        -h|--help)     sed -n '2,30p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) error "알 수 없는 인자: $arg"; exit 1 ;;
    esac
done

# ── 디바이스 감지 (run.sh와 동일 규칙) ────────────────────────────────
DEVICE_FILE="$HOME/.current-device"
if [[ -n "${DEVICE:-}" ]]; then
    :  # run.sh가 export한 값을 그대로 쓴다
elif [[ -f "$DEVICE_FILE" ]]; then
    DEVICE=$(tr '[:upper:]' '[:lower:]' < "$DEVICE_FILE" | tr -d '[:space:]' | cut -d'-' -f1)
else
    error "디바이스를 알 수 없습니다: $DEVICE_FILE 없음"
    echo "  echo 'thinkpad' > ~/.current-device"
    exit 1
fi

# ── 디바이스 프로파일 ──────────────────────────────────────────────────
# GC_RETAIN: nix 세대 보존 기간. oracle은 봇 런타임이라 롤백 여지를 길게 둔다.
# GUI_CACHE: 휴지통 + 브라우저 캐시 (headless에는 없음)
# REPO_CACHE: ~/repos 하위 빌드 캐시 (.zig-cache/.direnv/result)
case "$DEVICE" in
    oracle)
        GC_RETAIN=14; GUI_CACHE=false; REPO_CACHE=false
        DEVICE_NOTE="OpenClaw 런타임 호스트 — GC 보존 14일, docker는 수동 확인" ;;
    nuc)
        GC_RETAIN=7;  GUI_CACHE=false; REPO_CACHE=true
        DEVICE_NOTE="홈서버 — headless, repo 빌드 캐시 정리 대상" ;;
    laptop|thinkpad)
        GC_RETAIN=7;  GUI_CACHE=true;  REPO_CACHE=true
        DEVICE_NOTE="GUI 디바이스 — 휴지통·브라우저·repo 빌드 캐시가 용량의 대부분" ;;
    *)
        error "알 수 없는 디바이스: $DEVICE (유효: oracle nuc laptop thinkpad)"; exit 1 ;;
esac

# ── 유틸 ───────────────────────────────────────────────────────────────
disk_used_mb() { df -BM --output=used / | tail -1 | tr -dc '0-9'; }
START_MB=$(disk_used_mb)
TOTAL_FREED=0

# 경로 크기(MB). 없으면 0.
path_mb() { [[ -e "$1" ]] && du -sm "$1" 2>/dev/null | cut -f1 || echo 0; }

# reclaim <라벨> <경로...> — 크기 재고 삭제, dry-run 존중
reclaim() {
    local label="$1"; shift
    local total=0 found=()
    for p in "$@"; do
        [[ -e "$p" ]] || continue
        total=$(( total + $(path_mb "$p") ))
        found+=("$p")
    done
    if [[ ${#found[@]} -eq 0 ]]; then
        echo "    · $label — 없음"
        return
    fi
    if $DRY_RUN; then
        printf "    · %-32s %6sM  (dry-run)\n" "$label" "$total"
    else
        rm -rf "${found[@]}" 2>/dev/null
        printf "    · %-32s %6sM  삭제\n" "$label" "$total"
        TOTAL_FREED=$(( TOTAL_FREED + total ))
    fi
}

run() {
    if $DRY_RUN; then echo "    \$ $* (dry-run)"; else eval "$@"; fi
}

# ── 브리핑 ─────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}diskclean${NC} — ${BLUE}${DEVICE^^}${NC} / 레벨 ${YELLOW}${LEVEL}${NC}$($DRY_RUN && echo ' (DRY-RUN)')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  $DEVICE_NOTE"
echo ""
df -h / | tail -1 | awk '{printf "  디스크: %s 중 %s 사용 (%s), 여유 %s\n", $2, $3, $5, $4}'
echo ""
echo "  대상:"
[[ "$LEVEL" == "deep" ]] && $REPO_CACHE && \
echo "    0. repo 빌드 캐시 — .zig-cache / .direnv / result (GC root 해제)"
echo "    1. nix GC — ${GC_RETAIN}일 이상 오래된 세대 + dead path"
echo "    2. /tmp — 7일 이상 방치된 작업 디렉토리"
echo "    3. 에이전트 스크래치패드 — 3일 이상"
echo "    4. uv 캐시 prune (활성 링크 보존)"
$GUI_CACHE && echo "    5. 휴지통"
echo "    6. systemd 저널 → 200M"
if [[ "$LEVEL" == "deep" ]]; then
    echo "    ─ deep ─"
    echo "    7. nix-store --optimise (하드링크 중복 제거)"
    $GUI_CACHE && echo "    8. 브라우저 캐시 — chrome / mozilla"
    echo "    9. 툴 캐시 — go-build / zig / nix / pip / puppeteer"
fi
$WITH_PNPM   && echo "    + pnpm store prune  ${YELLOW}(라이브 node 세션 확인했나?)${NC}"
$WITH_DOCKER && echo "    + docker prune      ${YELLOW}(dangling 이미지 24h+ / 빌드 캐시)${NC}"
$WITH_PNPM   || echo -e "    ${YELLOW}제외${NC}: pnpm store (--with-pnpm 로 활성화)"
$WITH_DOCKER || echo -e "    ${YELLOW}제외${NC}: docker (--with-docker 로 활성화)"
echo ""

if ! $DRY_RUN && ! $ASSUME_YES; then
    read -rp "진행할까요? (y/N) > " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "취소되었습니다."; exit 0; }
fi
echo ""

# ── 0. repo 빌드 캐시 (deep) ───────────────────────────────────────────
# GC보다 먼저 돌아야 한다. .direnv/result는 nix GC root라 이것들이 남아있으면
# 뒤따르는 GC가 해당 store path를 죽은 것으로 보지 못한다. 여기 표시되는 MB는
# 디렉토리 자체 크기일 뿐이고, 실제 회수는 다음 단계 GC에서 훨씬 크게 나온다.
if [[ "$LEVEL" == "deep" ]] && $REPO_CACHE; then
    info "0. repo 빌드 캐시 (GC root 해제 — GC보다 먼저)"
    while IFS= read -r d; do
        reclaim "$(realpath --relative-to="$HOME/repos" "$d" 2>/dev/null || echo "$d")" "$d"
    done < <(find "$HOME/repos" -maxdepth 4 -type d \( -name '.zig-cache' -o -name '.direnv' \) 2>/dev/null)
    info "   result 심볼릭 링크"
    run "find '$HOME/repos' -maxdepth 3 -name result -type l -delete 2>/dev/null; true"
fi

# ── 1. nix GC ──────────────────────────────────────────────────────────
info "1. nix garbage collection (보존 ${GC_RETAIN}일)"
run "nix-collect-garbage --delete-older-than ${GC_RETAIN}d 2>&1 | tail -2"
run "sudo nix-collect-garbage --delete-older-than ${GC_RETAIN}d 2>&1 | tail -2"

# ── 2. /tmp 오래된 작업 디렉토리 ───────────────────────────────────────
# /tmp가 tmpfs가 아닌 디바이스에서는 세션 잔해가 영구 누적된다.
# 시스템/소켓 디렉토리와 활성 세션은 건드리지 않는다.
# 작은 것이 수십 개라 개별 출력은 소음이다. 50M 이상만 이름을 보이고 나머지는 합산한다.
info "2. /tmp 오래된 작업 디렉토리 (7일+)"
TMP_SMALL_N=0; TMP_SMALL_MB=0; TMP_BIG=()
while IFS= read -r d; do
    case "$(basename "$d")" in
        .*|systemd-private-*|snap*|tmux-*|ssh-*|nix-shell.*|claude-*|pi-shell-*) continue ;;
    esac
    mb=$(path_mb "$d")
    if [[ "$mb" -ge 50 ]]; then
        TMP_BIG+=("$d")
    else
        TMP_SMALL_N=$(( TMP_SMALL_N + 1 )); TMP_SMALL_MB=$(( TMP_SMALL_MB + mb ))
        $DRY_RUN || { rm -rf "$d" 2>/dev/null; TOTAL_FREED=$(( TOTAL_FREED + mb )); }
    fi
done < <(find /tmp -maxdepth 1 -mindepth 1 -type d -user "$(id -u)" -mtime +7 2>/dev/null)
for d in "${TMP_BIG[@]}"; do reclaim "$(basename "$d")" "$d"; done
[[ "$TMP_SMALL_N" -gt 0 ]] && printf "    · %-32s %6sM  (소형 %d개 합산)\n" "기타 잔해" "$TMP_SMALL_MB" "$TMP_SMALL_N"
[[ "${#TMP_BIG[@]}" -eq 0 && "$TMP_SMALL_N" -eq 0 ]] && echo "    · 정리할 것 없음"

# ── 3. 에이전트 스크래치패드 ───────────────────────────────────────────
# /tmp/claude-<uid>/<repo>/<session-uuid>/ 구조. 현재 세션은 mtime으로 자연 제외된다.
info "3. 에이전트 스크래치패드 (3일+)"
SCRATCH_ROOT="/tmp/claude-$(id -u)"
if [[ -d "$SCRATCH_ROOT" ]]; then
    SCRATCH_MB=$(find "$SCRATCH_ROOT" -maxdepth 2 -mindepth 2 -type d -mtime +3 -print0 2>/dev/null \
        | xargs -0 -r du -scm 2>/dev/null | tail -1 | cut -f1)
    SCRATCH_MB=${SCRATCH_MB:-0}
    if $DRY_RUN; then
        printf "    · %-32s %6sM  (dry-run)\n" "오래된 세션 디렉토리" "$SCRATCH_MB"
    else
        find "$SCRATCH_ROOT" -maxdepth 2 -mindepth 2 -type d -mtime +3 -print0 2>/dev/null | xargs -0 -r rm -rf
        find "$SCRATCH_ROOT" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null
        printf "    · %-32s %6sM  삭제\n" "오래된 세션 디렉토리" "$SCRATCH_MB"
        TOTAL_FREED=$(( TOTAL_FREED + SCRATCH_MB ))
    fi
else
    echo "    · 스크래치패드 없음"
fi

# ── 4. uv 캐시 ─────────────────────────────────────────────────────────
# rm -rf 대신 prune — 활성 venv가 하드링크로 참조하는 것은 남기고 고아만 회수한다.
info "4. uv 캐시 prune"
if command -v uv >/dev/null 2>&1; then
    run "uv cache prune 2>&1 | tail -1"
else
    echo "    · uv 없음"
fi

# ── 5. 휴지통 (GUI 디바이스만) ─────────────────────────────────────────
if $GUI_CACHE; then
    info "5. 휴지통 비우기"
    reclaim "Trash" "$HOME/.local/share/Trash/files" "$HOME/.local/share/Trash/info"
    $DRY_RUN || mkdir -p "$HOME/.local/share/Trash/files" "$HOME/.local/share/Trash/info"
fi

# ── 6. systemd 저널 ────────────────────────────────────────────────────
info "6. systemd 저널 vacuum → 200M"
run "sudo journalctl --vacuum-size=200M 2>&1 | tail -1"

# ── deep 레벨 ──────────────────────────────────────────────────────────
if [[ "$LEVEL" == "deep" ]]; then
    echo ""
    info "7. nix-store --optimise (시간이 걸립니다)"
    run "sudo nix-store --optimise 2>&1 | tail -1"

    if $GUI_CACHE; then
        info "8. 브라우저 캐시"
        reclaim "google-chrome" "$HOME/.cache/google-chrome"
        reclaim "mozilla"       "$HOME/.cache/mozilla"
    fi

    info "9. 툴 캐시"
    reclaim "go-build"   "$HOME/.cache/go-build"
    reclaim "zig"        "$HOME/.cache/zig"
    reclaim "nix (eval)" "$HOME/.cache/nix"
    reclaim "pip"        "$HOME/.cache/pip"
    reclaim "puppeteer"  "$HOME/.cache/puppeteer"
fi

# ── opt-in: pnpm ───────────────────────────────────────────────────────
if $WITH_PNPM; then
    echo ""
    info "+ pnpm store prune"
    if command -v pnpm >/dev/null 2>&1; then
        run "pnpm store prune 2>&1 | tail -2"
    else
        warn "pnpm 없음"
    fi
fi

# ── opt-in: docker ─────────────────────────────────────────────────────
if $WITH_DOCKER; then
    echo ""
    info "+ docker prune"
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        docker system df 2>/dev/null
        if [[ "$DEVICE" == "oracle" ]] && ! $ASSUME_YES && ! $DRY_RUN; then
            warn "oracle은 OpenClaw 런타임 호스트입니다. 실행 중 컨테이너를 확인하세요:"
            docker ps --format '  {{.Names}}\t{{.Image}}' 2>/dev/null
            read -rp "  계속? (y/N) > " dconfirm
            [[ "$dconfirm" =~ ^[Yy]$ ]] || { info "docker 정리 건너뜀."; WITH_DOCKER=false; }
        fi
        if $WITH_DOCKER; then
            run "docker image prune -a -f --filter 'until=24h' 2>&1 | tail -1"
            run "docker builder prune -a -f 2>&1 | tail -1"
        fi
    else
        warn "docker 없음 또는 미실행"
    fi
fi

# ── 결과 ───────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if $DRY_RUN; then
    info "DRY-RUN — 실제로 삭제된 것은 없습니다."
else
    END_MB=$(disk_used_mb)
    FREED=$(( START_MB - END_MB ))
    success "회수: $(( FREED / 1024 ))G (${FREED}M)"
fi
df -h / | tail -1 | awk '{printf "  디스크: %s 중 %s 사용 (%s), 여유 %s\n", $2, $3, $5, $4}'
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  오래된 부트 엔트리는 다음 nixos-rebuild boot/switch 때 정리됩니다."
[[ "$LEVEL" == "safe" ]] && echo "  더 필요하면: $0 deep --with-docker"
