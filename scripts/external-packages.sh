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

# ── preflight ────────────────────────────────────────────────────────────────
# pnpm 은 global-bin-dir(~/.config/pnpm/rc) 이 PATH 에 없으면 `add -g`/`list -g` 를
# 전부 거부한다: "The configured global bin directory ... is not in PATH".
# 이게 설치 실패처럼 보여서 레지스트리·캐시를 의심하게 만드는데, 원인은 PATH 다.
# (2026-07-13: ~/.env.local 이 v10 시절 PATH 스냅샷을 통째로 export 해서
#  $PNPM_HOME/bin 을 부모 $PNPM_HOME 으로 밀어내고 있었다. 시크릿 파일에 PATH 를
#  박지 않는다 — PATH SSOT 는 shell.nix 의 home.sessionPath.)
# 여기서는 진단만 하고 이 스크립트 실행 동안만 교정한다. 쉘 자체는 사용자가 고친다.
ensure_pnpm_bin_on_path() {
    local pnpm_bin="${PNPM_HOME:-$HOME/.local/share/pnpm}/bin"
    case ":$PATH:" in
        *":$pnpm_bin:"*) return 0 ;;
    esac
    warn "PATH 에 pnpm global-bin-dir 이 없다: $pnpm_bin"
    warn "  이 상태면 pnpm 은 모든 -g 명령을 거부한다. 이 스크립트 실행 동안만 PATH 에 붙인다."
    warn "  항구 수정: 로그인 쉘 PATH 를 통째로 덮어쓰는 곳이 없는지 확인(예: ~/.env.local 의 export PATH=)."
    # 뒤에 붙인다 — pnpm 은 "PATH 안에 있기만" 하면 된다. 앞에 붙이면 pnpm 글로벌의
    # 묵은 shim(예: @anthropic-ai/claude-code)이 curl 하네스(~/.local/bin/claude)를
    # 가려서, check 가 엉뚱한 바이너리의 버전을 보고한다.
    export PATH="$PATH:$pnpm_bin"
}

# ── install ──────────────────────────────────────────────────────────────────
# pnpm 메타데이터 캐시만 삭제한다. 패키지 tarball(store)은 건드리지 않으므로
# 잃는 것은 재다운로드 수십 초뿐이다. pnpm 에는 npm 의 --prefer-online 에 해당하는
# 플래그가 없어서(11.x 기준 add 는 이를 거부한다) 캐시를 직접 비우는 게 유일한 수단.
purge_pnpm_metadata() {
    local cache_dir
    cache_dir=$(pnpm config get cache-dir 2>/dev/null || true)
    [[ -z "$cache_dir" || "$cache_dir" == "undefined" ]] && cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/pnpm"
    if [[ ! -d "$cache_dir" ]]; then
        warn "pnpm 캐시 디렉토리를 못 찾음: $cache_dir"
        return 1
    fi
    # v11/metadata, v11/metadata-full — major 버전 디렉토리는 pnpm 이 바뀌면 달라진다.
    find "$cache_dir" -mindepth 2 -maxdepth 2 -type d -name 'metadata*' -exec rm -rf {} + 2>/dev/null || true
    info "pnpm 메타데이터 캐시 삭제 (store 는 무사): $cache_dir"
}

install_pnpm() {
    ensure_pnpm_bin_on_path
    info "pnpm global (SSOT ${#PNPM_PACKAGES[@]}개) 설치/업그레이드..."
    if pnpm add -g "${PNPM_PACKAGES[@]}"; then
        success "pnpm global updated"
        return 0
    fi

    # 1차 폴백 — 묵은 메타데이터 캐시. pnpm 이 실제로 존재하는 하위 의존성 버전을
    #   "없는 버전"(ERR_PNPM_NO_MATCHING_VERSION)으로 오판해 설치 전체를 세우는 일이 있다.
    echo ""
    warn "일괄 설치 실패 — 메타데이터 캐시가 묵었을 수 있다. 캐시 비우고 1회 재시도."
    if purge_pnpm_metadata && pnpm add -g "${PNPM_PACKAGES[@]}"; then
        success "pnpm global updated (메타데이터 갱신 후)"
        return 0
    fi

    # 2차 폴백 — pnpm 은 패키지마다 별도 디렉토리에 설치하지만 `add -g A B C` 는 한 프로세스라
    #   첫 실패에서 뒤 패키지는 시작조차 못 한다. harness 와 같은 원칙으로 개별로 돌려
    #   한 놈의 upstream 사정이 나머지(codex 등)를 막지 않게 한다.
    echo ""
    warn "여전히 실패 — 패키지별 개별 설치로 폴백 (나머지는 계속 진행)"
    local fails=""
    for pkg in "${PNPM_PACKAGES[@]}"; do
        if pnpm add -g "$pkg"; then
            success "$pkg"
        else
            warn "$pkg 실패"; fails+=" $pkg"
        fi
    done

    echo ""
    if [[ -z "$fails" ]]; then
        success "pnpm global updated (개별 폴백)"
    else
        warn "pnpm 실패:$fails — upstream 레지스트리의 일시적 상태일 수 있다(재시도 가능)"
    fi
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
    ensure_pnpm_bin_on_path
    # `pnpm list -g` 는 한 번만 부른다. 실패하면 그 사실을 삼키지 않는다 —
    # 예전엔 실패 출력이 비면서 전 패키지가 "not installed" 로 오탐되고,
    # 그 분기가 has_update 를 세우지 않아 마지막에 "패키지 최신" 이라는
    # 거짓 성공까지 찍혔다.
    local glist
    if ! glist=$(pnpm list -g 2>&1); then
        error "pnpm list -g 실패 — 아래가 진짜 원인이다(레지스트리 문제가 아니다):"
        echo "$glist" | sed 's/^/      /'
        has_update=1
    fi
    for label in netlify-cli clawhub summarize codex typescript-language-server pi-coding-agent; do
        local pkg="${PNPM_CHECK[$label]}" cur lat
        cur=$(grep "$label" <<< "$glist" | grep -oP '[\d.]+$' || true)
        lat=$(npm view "$pkg" version 2>/dev/null || true)
        if [[ -z "$cur" ]]; then
            echo -e "  ${RED}✗${NC} $label: not installed (latest: ${lat:-?})"
            has_update=1
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
