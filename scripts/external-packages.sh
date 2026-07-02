#!/usr/bin/env bash
# external-packages.sh — non-NixOS 외부 패키지 SSOT (설치 / 버전체크)
#
# 배경: pnpm 글로벌 패키지가 여러 곳(pnpm10 global/5, .tools, parent orphan shim)에
#   흩어져 있던 것을, 25.11→26.05 이관 + 오버레이 대청소와 함께 "한 곳"으로 일원화했다.
#   pnpm은 이제 NixOS가 소유한 단일 버전(26.05 네이티브 11.x)만 쓰고, 글로벌 shim은
#   ~/.local/share/pnpm/bin 에만 생성된다(~/.config/pnpm/rc: global-bin-dir 고정 +
#   manage-package-manager-versions=false 로 버전 스위칭 차단).
#
#   이 스크립트가 외부 패키지 목록의 SSOT다. 구 EXTERNAL_PACKAGES.md / ~/update-claude.sh
#   는 폐기(2026-07-02) — 문서는 썩는다. 목록은 코드 바로 옆 주석으로 산다.
#   run.sh 의 e)/E) 는 이 스크립트만 호출한다(목록을 run.sh 에 두지 않는다).
#
# 사용:
#   external-packages.sh check                # 설치/버전 상태 표시   (run.sh e)
#   external-packages.sh install <target>     # 설치/업그레이드        (run.sh E)
#     target = pnpm | harness | gog | uv | all
#
# ── 패키지 SSOT ──────────────────────────────────────────────────────────────
# [pnpm global]  nix pnpm 11.x. 설치: pnpm add -g <PNPM_PACKAGES>
#   netlify-cli                               netlify / ntl
#   clawhub                                   OpenClaw hub CLI
#   @steipete/summarize                       URL/미디어 요약 (summarize)
#   @openai/codex                             codex — curl 인스톨러가 GitHub API rate limit
#                                             (무인증 60/시간)에 걸려 403 나므로 pnpm으로 안전하게.
#   typescript-language-server + typescript   TS LSP (Claude Code typescript-lsp 플러그인)
#   @earendil-works/pi-coding-agent           pi — 최초 1회만. 이후 `pi update` 로 self-update.
#
# [curl harness]  벤더 인스톨러 → 설치 후 self-update (우리가 버전에 관여하지 않음).
#   claude        https://claude.ai/install.sh            → ~/.local/bin/claude
#   antigravity   https://antigravity.google/cli/install.sh → ~/.local/bin/agy (바이너리 이름 agy)
#
# [go install]
#   gog (gogcli)  go install github.com/steipete/gogcli/cmd/gog@latest
#     upstream(steipete/gogcli)에 내 구현이 모두 반영됨 → 포크 로컬빌드 불필요.
#     GOBIN=~/.local/bin 으로 고정해 다른 바이너리와 같은 자리에 둔다.
#
# 제거됨(2026-07-02, 쓰레기 정리 — 이제 안 씀):
#   gt/bd/bv/br (gastown+beads, 멀티에이전트/이슈트래킹) — plane/incidentcli 로 대체
#   CLIProxyAPI (Anthropic ToS 위반 소지) / gemini / ccr / copilot / cline /
#   @mariozechner gccli·gdcli·gmcli / grammy(라이브러리, 실행 bin 없음)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}ℹ ${NC}$1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1"; }

# pnpm global SSOT — 이 배열이 곧 `pnpm add -g` 대상 집합이다.
PNPM_PACKAGES=(
    netlify-cli
    clawhub
    @steipete/summarize
    @openai/codex
    typescript-language-server typescript
    @earendil-works/pi-coding-agent
)

# check 표시용: "표시 라벨 → npm 패키지명" (버전 비교에 npm view 사용)
declare -A PNPM_CHECK=(
    [netlify-cli]="netlify-cli"
    [clawhub]="clawhub"
    [summarize]="@steipete/summarize"
    [codex]="@openai/codex"
    [typescript-language-server]="typescript-language-server"
    [pi-coding-agent]="@earendil-works/pi-coding-agent"
)

# ── install ──────────────────────────────────────────────────────────────────
install_pnpm() {
    info "pnpm global (SSOT ${#PNPM_PACKAGES[@]}개) 설치/업그레이드..."
    pnpm add -g "${PNPM_PACKAGES[@]}"
    success "pnpm global updated"
}

install_harness() {
    # 벤더 curl 인스톨러 (설치 후 self-update). 벤더별 독립 실행 —
    # 하나가 실패(네트워크/일시적 오류)해도 나머지는 계속 진행한다.
    # (다운로드→실행 2단계로 나눠 `curl|sh` 의 pipe 성공 마스킹도 방지.)
    info "harness(curl): claude / antigravity — 벤더별 독립 설치·업데이트..."
    local fails=""
    _harness_one() {
        local name="$1" url="$2" runner="${3:-bash}" tmp
        tmp=$(mktemp)
        if curl -fsSL "$url" -o "$tmp" && [[ -s "$tmp" ]]; then
            if "$runner" "$tmp"; then success "$name updated"; else warn "$name 인스톨러 실행 실패"; fails+=" $name"; fi
        else
            warn "$name 다운로드 실패 (건너뜀)"; fails+=" $name"
        fi
        rm -f "$tmp"
    }
    _harness_one claude      https://claude.ai/install.sh              bash
    _harness_one antigravity https://antigravity.google/cli/install.sh bash
    echo ""
    if [[ -z "$fails" ]]; then success "harness 전체 완료"; else warn "harness 실패:$fails (일시적일 수 있음 — 재시도 가능)"; fi
}

install_gog() {
    # gogcli upstream (포크 불필요 — 내 구현 upstream 반영 완료)
    info "gog (gogcli upstream) 설치..."
    if GOBIN="$HOME/.local/bin" go install github.com/steipete/gogcli/cmd/gog@latest; then
        success "gog $(gog --version 2>/dev/null | head -1)"
    else
        warn "gog 설치 실패 (go / 네트워크 확인)"
    fi
}

install_uv() {
    if command -v uv >/dev/null 2>&1; then
        info "uv tools 업그레이드..."
        uv tool upgrade --all 2>/dev/null || warn "uv tool upgrade 실패"
        success "uv tools updated"
    else
        warn "uv 없음 — 건너뜀"
    fi
}

# ── check ────────────────────────────────────────────────────────────────────
check() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}External Packages — Version Check${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local has_update=0

    echo ""
    echo -e "${YELLOW}[pnpm global]${NC}"
    for label in netlify-cli clawhub summarize codex typescript-language-server pi-coding-agent; do
        local pkg="${PNPM_CHECK[$label]}" cur lat
        cur=$(pnpm list -g 2>/dev/null | grep "$label" | grep -oP '[\d.]+$' || true)
        lat=$(npm view "$pkg" version 2>/dev/null || true)
        if [[ -z "$cur" ]]; then
            echo -e "  ${RED}✗${NC} $label: not installed (latest: ${lat:-?})"
        elif [[ "$cur" == "$lat" ]]; then
            echo -e "  ${GREEN}✓${NC} $label: $cur (up to date)"
        else
            echo -e "  ${YELLOW}⬆${NC} $label: $cur → ${lat:-?}"
            has_update=1
        fi
    done

    echo ""
    echo -e "${YELLOW}[curl harness] (self-update — 버전만 표시)${NC}"
    # 라벨 → 실제 바이너리명 (antigravity 의 바이너리는 agy)
    declare -A HARNESS_BIN=( [claude]="claude" [antigravity]="agy" )
    for label in claude antigravity; do
        local bin="${HARNESS_BIN[$label]}"
        if command -v "$bin" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $label ($bin): $("$bin" --version 2>/dev/null | head -1)"
        else
            echo -e "  ${RED}✗${NC} $label ($bin): not installed"
        fi
    done

    echo ""
    echo -e "${YELLOW}[go install]${NC}"
    if command -v gog >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} gog: $(gog --version 2>/dev/null | head -1)"
    else
        echo -e "  ${RED}✗${NC} gog: not installed"
    fi

    echo ""
    echo -e "${YELLOW}[uv tools]${NC}"
    if command -v uv >/dev/null 2>&1; then
        uv tool list 2>/dev/null | grep -E '^\w' | while read -r line; do
            echo -e "  ${GREEN}✓${NC} $line"
        done || echo "  (설치된 uv tool 없음)"
    else
        echo -e "  ${RED}✗${NC} uv not found"
    fi

    echo ""
    if [[ $has_update -eq 1 ]]; then
        warn "업데이트 가능한 pnpm 패키지가 있습니다: install pnpm"
    else
        success "pnpm 패키지 최신."
    fi
}

# ── dispatch ─────────────────────────────────────────────────────────────────
case "${1:-}" in
    check) check ;;
    install)
        case "${2:-}" in
            pnpm)    install_pnpm ;;
            harness) install_harness ;;
            gog)     install_gog ;;
            uv)      install_uv ;;
            all)     install_pnpm; install_harness; install_gog; install_uv
                     echo ""; success "전체 설치/업그레이드 완료" ;;
            *) error "사용법: external-packages.sh install <pnpm|harness|gog|uv|all>"; exit 1 ;;
        esac
        ;;
    *)
        error "사용법: external-packages.sh <check|install <target>>"
        exit 1
        ;;
esac
