#!/usr/bin/env bash
set -euo pipefail

NIXPKGS_ALLOW_UNFREE=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEVICE_FILE="$HOME/.current-device"
FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALID_HOSTS=("oracle" "nuc" "laptop" "thinkpad")

# Helper functions
info() { echo -e "${BLUE}ℹ ${NC}$1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

# Fix SSH ControlMaster socket conflict for GitHub multi-account
# See: ~/org/llmlog/ SSH GitHub 멀티계정 ControlMaster 충돌 해결
fix_ssh_github() {
    local socket="$HOME/.ssh/sockets/git@github.com-22"
    if [[ -S "$socket" ]]; then
        rm -f "$socket"
        info "SSH GitHub 소켓 캐시 제거 (멀티계정 충돌 방지)"
    fi
}

# Check current device
check_device() {
    if [[ ! -f "$DEVICE_FILE" ]]; then
        error "파일이 없습니다: $DEVICE_FILE"
        echo ""
        echo "다음 명령어로 현재 디바이스를 설정하세요:"
        echo "  echo 'oracle' > ~/.current-device        # Oracle Cloud VM"
        echo "  echo 'oracle-nixos' > ~/.current-device  # Oracle Cloud VM (하이픈 포함)"
        echo "  echo 'nuc' > ~/.current-device           # Intel NUC"
        echo "  echo 'laptop' > ~/.current-device        # Samsung Laptop"
        echo "  echo 'thinkpad' > ~/.current-device      # ThinkPad P16s"
        exit 1
    fi

    local raw_device=$(cat "$DEVICE_FILE" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

    # Extract first word before hyphen (e.g., oracle-nixos -> oracle)
    DEVICE=$(echo "$raw_device" | cut -d'-' -f1)

    # Validate device
    local valid=false
    for host in "${VALID_HOSTS[@]}"; do
        if [[ "$DEVICE" == "$host" ]]; then
            valid=true
            break
        fi
    done

    if [[ "$valid" == false ]]; then
        error "유효하지 않은 디바이스: $raw_device (추출: $DEVICE)"
        echo "유효한 디바이스: ${VALID_HOSTS[*]}"
        echo ""
        echo "하이픈(-)으로 구분된 경우 첫 번째 단어를 사용합니다."
        echo "예: oracle-nixos → oracle"
        exit 1
    fi

    if [[ "$raw_device" != "$DEVICE" ]]; then
        info "디바이스: $raw_device → flake: $DEVICE"
    else
        success "현재 디바이스: ${DEVICE^^}"
    fi
}

# Show menu
show_menu() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}NixOS Flake Management${NC} - ${BLUE}${DEVICE^^}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "  ${YELLOW}Update${NC}"
    echo "    1) Flake update (모든 inputs)"
    echo "    2) Flake update nixpkgs만"
    echo "    3) Flake update home-manager만"
    echo ""
    echo -e "  ${YELLOW}Build & Apply${NC}"
    echo "    4) Test (재부팅 없이 테스트, 롤백 가능)"
    echo "    5) Switch (영구 적용)"
    echo "    6) Boot (다음 부팅 시 적용)"
    echo ""
    echo -e "  ${YELLOW}Info${NC}"
    echo "    7) Flake show (구성 확인)"
    echo "    8) List generations (세대 목록)"
    echo "    9) Rollback (이전 세대로)"
    echo ""
    echo -e "  ${YELLOW}Peon-ping${NC}"
    echo "    p) Preview packs (팩별 소리 미리듣기)"
    echo "    P) Install peon-ping (사운드 설치)"
    echo ""
    echo -e "  ${YELLOW}Remote (Oracle VM)${NC}"
    echo "    t) OpenClaw 터널 시작/종료 (→ http://127.0.0.1:18789/)"
    echo "    r) Oracle Docker 서비스 재시작"
    echo "    s) Oracle Docker 서비스 상태"
    echo "    a) OpenClaw 페어링 승인"
    echo "    k) OpenClaw 스킬 심볼릭 배포 (agent-config SSOT → workspace/claude-skills)"
    echo "    w) OpenClaw 턴 감시 (turnwatch — 자율 트리거/턴 원장/실패 한 화면)"
    echo "    W) 모델 강등 점검 (봇이 몰래 다른 모델로 갈아탄 자리 — refusal fallback)"
    echo ""
    echo -e "  ${YELLOW}Syncthing${NC}"
    echo "    i) stignore 배포 (~/sync/*/.stignore)"
    echo "    I) stignore 상태 확인"
    echo ""
    echo -e "  ${YELLOW}External Packages${NC}"
    echo "    e) 외부 패키지 버전 체크"
    echo "    E) 외부 패키지 업그레이드"
    echo ""
    echo -e "  ${YELLOW}Cleanup${NC}"
    echo "    c) Cleanup safe (GC + /tmp + 스크래치패드 + 캐시 — 작업 손실 없음)"
    echo "    C) Cleanup deep (+ repo 빌드 캐시 + optimise + 브라우저/툴, docker·pnpm 선택)"
    echo "    d) Disk usage (디스크 사용량 확인)"
    echo ""
    echo "    0) Exit"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Execute command
execute_cmd() {
    local cmd="$1"
    echo ""
    info "실행: $cmd"
    echo ""
    eval "$cmd"
    local status=$?
    echo ""
    if [[ $status -eq 0 ]]; then
        success "완료!"
    else
        error "실패 (exit code: $status)"
    fi
    return $status
}

# Main loop
main() {
    cd "$FLAKE_DIR"
    fix_ssh_github
    check_device

    while true; do
        show_menu
        read -p "선택하세요 (0-9, p/P, e/E, i/I, c/C/d, t/r/s/k): " choice

        case $choice in
            1)
                execute_cmd "nix flake update"
                ;;
            2)
                execute_cmd "nix flake lock --update-input nixpkgs"
                ;;
            3)
                execute_cmd "nix flake lock --update-input home-manager"
                ;;
            4)
                execute_cmd "sudo nixos-rebuild test --flake .#${DEVICE}"
                ;;
            5)
                warn "영구 적용됩니다. 계속하시겠습니까? (y/N)"
                read -p "> " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    execute_cmd "sudo nixos-rebuild switch --flake .#${DEVICE}"
                else
                    info "취소되었습니다."
                fi
                ;;
            6)
                execute_cmd "sudo nixos-rebuild boot --flake .#${DEVICE}"
                ;;
            7)
                execute_cmd "nix flake show"
                ;;
            8)
                execute_cmd "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system"
                ;;
            9)
                warn "이전 세대로 롤백합니다. 계속하시겠습니까? (y/N)"
                read -p "> " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    execute_cmd "sudo nixos-rebuild switch --rollback"
                else
                    info "취소되었습니다."
                fi
                ;;
            c)
                # 정리 로직 SSOT는 scripts/diskclean.sh — 디바이스별 프로파일이 거기 있다.
                execute_cmd "DEVICE='$DEVICE' bash '$FLAKE_DIR/scripts/diskclean.sh' safe"
                ;;
            C)
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo -e "${GREEN}Disk Cleanup - Deep${NC} (${BLUE}${DEVICE^^}${NC})"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                echo "  deep = safe + repo 빌드 캐시 + store optimise + 브라우저/툴 캐시"
                echo "  pnpm store는 repo node_modules와 하드링크를 공유한다."
                echo "  라이브 node/pi 세션이 돌고 있으면 3번을 고르지 않는다."
                echo ""
                echo "  1) deep"
                echo "  2) deep + docker prune (dangling 이미지 24h+ / 빌드 캐시)"
                echo "  3) deep + docker + pnpm store prune"
                echo "  4) dry-run (계산만, 삭제 없음)"
                echo "  0) 취소"
                echo ""
                read -p "선택: " clean_choice

                DISKCLEAN="DEVICE='$DEVICE' bash '$FLAKE_DIR/scripts/diskclean.sh'"
                case $clean_choice in
                    1) execute_cmd "$DISKCLEAN deep" ;;
                    2) execute_cmd "$DISKCLEAN deep --with-docker" ;;
                    3) execute_cmd "$DISKCLEAN deep --with-docker --with-pnpm" ;;
                    4) execute_cmd "$DISKCLEAN deep --with-docker --with-pnpm --dry-run" ;;
                    0) info "취소" ;;
                    *) error "잘못된 선택" ;;
                esac
                ;;
            p)
                echo ""
                PEON_SH="$HOME/.claude/hooks/peon-ping/peon.sh"
                if [[ ! -f "$PEON_SH" ]]; then
                    error "peon-ping이 설치되지 않았습니다. 먼저 'P'로 설치하세요."
                else
                    # Get pack list
                    info "설치된 사운드 팩:"
                    echo ""
                    PACK_NAMES=()
                    while IFS= read -r line; do
                        # Parse: "  pack_name    Description *"
                        name=$(echo "$line" | awk '{print $1}')
                        [[ -n "$name" ]] && PACK_NAMES+=("$name")
                    done < <(bash "$PEON_SH" packs list 2>/dev/null)

                    if [[ ${#PACK_NAMES[@]} -eq 0 ]]; then
                        error "설치된 팩이 없습니다."
                    else
                        for i in "${!PACK_NAMES[@]}"; do
                            printf "    %2d) %s\n" "$((i+1))" "${PACK_NAMES[$i]}"
                        done
                        echo ""
                        echo "     a) 전체 팩 순서대로 미리듣기"
                        echo "     0) 돌아가기"
                        echo ""

                        CATEGORIES=("session.start" "task.complete" "input.required")
                        ORIGINAL_PACK=$(bash "$PEON_SH" packs list 2>/dev/null | grep '\*' | awk '{print $1}')

                        preview_pack() {
                            local pack="$1"
                            bash "$PEON_SH" packs use "$pack" >/dev/null 2>&1
                            echo ""
                            info "▶ [$pack]"
                            for cat in "${CATEGORIES[@]}"; do
                                printf "    %-20s " "$cat"
                                bash "$PEON_SH" preview "$cat" 2>/dev/null
                                sleep 0.5
                            done
                        }

                        read -p "선택 (번호/a/0): " pack_choice
                        case $pack_choice in
                            0)
                                info "취소"
                                ;;
                            a|A)
                                for pack in "${PACK_NAMES[@]}"; do
                                    preview_pack "$pack"
                                done
                                echo ""
                                # Restore original
                                if [[ -n "$ORIGINAL_PACK" ]]; then
                                    bash "$PEON_SH" packs use "$ORIGINAL_PACK" >/dev/null 2>&1
                                    success "원래 팩 복원: $ORIGINAL_PACK"
                                fi
                                ;;
                            [0-9]|[0-9][0-9])
                                idx=$((pack_choice - 1))
                                if [[ $idx -ge 0 && $idx -lt ${#PACK_NAMES[@]} ]]; then
                                    preview_pack "${PACK_NAMES[$idx]}"
                                    echo ""
                                    read -p "이 팩을 기본으로 설정? (y/N): " keep
                                    if [[ "$keep" =~ ^[Yy]$ ]]; then
                                        success "기본 팩: ${PACK_NAMES[$idx]}"
                                    elif [[ -n "$ORIGINAL_PACK" ]]; then
                                        bash "$PEON_SH" packs use "$ORIGINAL_PACK" >/dev/null 2>&1
                                        info "원래 팩 복원: $ORIGINAL_PACK"
                                    fi
                                else
                                    error "잘못된 번호입니다."
                                fi
                                ;;
                            *)
                                error "잘못된 선택입니다."
                                ;;
                        esac
                    fi
                fi
                ;;
            P)
                execute_cmd "bash '$FLAKE_DIR/scripts/install-peon-ping.sh'"
                ;;
            t)
                echo ""
                TUNNEL_PID=$(pgrep -f "ssh.*-L 18789" 2>/dev/null || true)
                if [[ -n "$TUNNEL_PID" ]]; then
                    warn "OpenClaw 터널 실행 중 (PID: $TUNNEL_PID)"
                    read -p "종료하시겠습니까? (y/N): " kill_it
                    if [[ "$kill_it" =~ ^[Yy]$ ]]; then
                        pkill -f "ssh.*-L 18789" && success "터널 종료됨"
                    else
                        info "유지됩니다."
                    fi
                else
                    info "SSH 터널 시작: oracle → localhost:18789"
                    ssh -f -N -L 18789:127.0.0.1:18789 oracle
                    sleep 1
                    NEW_PID=$(pgrep -f "ssh.*-L 18789" 2>/dev/null || true)
                    success "터널 시작됨 (PID: $NEW_PID)"
                    info "대시보드: http://127.0.0.1:18789/"
                fi
                ;;
            r)
                echo ""
                echo "재시작할 서비스 선택:"
                echo "  1) openclaw-gateway"
                echo "  2) caddy + mattermost"
                echo "  3) 전체 Oracle Docker 서비스"
                echo "  0) 취소"
                read -p "> " svc_choice
                case $svc_choice in
                    1)
                        execute_cmd "ssh oracle 'cd ~/openclaw && docker compose restart openclaw-gateway'"
                        ;;
                    2)
                        execute_cmd "ssh oracle 'cd ~/nixos-config/docker && docker compose -f caddy/docker-compose.yml -f mattermost/docker-compose.yml restart'"
                        ;;
                    3)
                        execute_cmd "ssh oracle 'cd ~/openclaw && docker compose restart openclaw-gateway'"
                        execute_cmd "ssh oracle 'cd ~/nixos-config/docker && docker compose -f caddy/docker-compose.yml restart && docker compose -f mattermost/docker-compose.yml restart'"
                        ;;
                    0)
                        info "취소됩니다."
                        ;;
                    *)
                        error "잘못된 선택입니다."
                        ;;
                esac
                ;;
            s)
                execute_cmd "ssh oracle 'docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\"'"
                ;;
            a)
                echo ""
                info "=== OpenClaw 페어링 pending 목록 ==="
                echo ""
                echo "  1) default 봇 (Telegram)"
                echo "  2) glg 봇 (Telegram)"
                echo "  3) Mattermost"
                echo "  0) 취소"
                echo ""
                read -p "채널 선택: " PAIR_CHANNEL
                case $PAIR_CHANNEL in
                    1)
                        PAIR_ACCOUNT_OPT=""
                        PAIR_LABEL="Telegram default"
                        ;;
                    2)
                        PAIR_ACCOUNT_OPT="--account glg"
                        PAIR_LABEL="Telegram glg"
                        ;;
                    3)
                        PAIR_ACCOUNT_OPT="--channel mattermost"
                        PAIR_LABEL="Mattermost"
                        ;;
                    0)
                        info "취소됩니다."
                        break
                        ;;
                    *)
                        error "잘못된 선택입니다."
                        break
                        ;;
                esac

                if [[ "$PAIR_CHANNEL" == "3" ]]; then
                    PAIR_CMD="docker exec openclaw-gateway node openclaw.mjs pairing list --channel mattermost"
                else
                    PAIR_CMD="docker exec openclaw-gateway node openclaw.mjs pairing list --channel telegram $PAIR_ACCOUNT_OPT"
                fi

                info "$PAIR_LABEL 페어링 요청 목록:"
                ssh oracle "$PAIR_CMD"

                echo ""
                read -p "승인할 코드 입력 (빈값=취소): " PAIR_CODE
                if [[ -n "$PAIR_CODE" ]]; then
                    if [[ "$PAIR_CHANNEL" == "3" ]]; then
                        APPROVE_CMD="docker exec openclaw-gateway node openclaw.mjs pairing approve mattermost $PAIR_CODE"
                    else
                        APPROVE_CMD="docker exec openclaw-gateway node openclaw.mjs pairing approve telegram $PAIR_CODE $PAIR_ACCOUNT_OPT"
                    fi
                    execute_cmd "ssh oracle '$APPROVE_CMD'"
                else
                    info "취소됩니다."
                fi
                ;;
            k)
                echo ""
                if [[ "$DEVICE" != "oracle" ]]; then
                    error "이 기능은 Oracle VM에서만 사용 가능합니다."
                    break
                fi
                # SSOT = agent-config/skills (pi-skills는 여기로 가는 심볼릭 모음)
                # 배포 = workspace*/skills + claude-skills 에 절대경로 심볼릭 (복사 금지)
                # gog 바이너리 SSOT = openclaw-config/bin/gog (스킬 트리 밖 — rsync 순환 방지)
                AGENT_SKILLS_SSOT="$HOME/repos/gh/agent-config/skills"
                OPENCLAW_DIR="$HOME/openclaw"
                CLAUDE_SKILLS="$OPENCLAW_DIR/config/claude-skills"
                GOG_BIN_SSOT="$OPENCLAW_DIR/bin/gog"

                if [[ ! -d "$AGENT_SKILLS_SSOT" ]]; then
                    error "agent-config skills SSOT 없음: $AGENT_SKILLS_SSOT"
                    break
                fi

                # 보안/대상 사용자상 봇에 배포하지 않을 스킬
                #   telegram/slack-latest/jiracli: 사용자 계정 권한 위임 위험
                #   memory-sync: oracle에서 임베딩 비용
                #   punchout: 사용자 본인 일일 마무리 도구
                #   browser-tools: 봇 컨테이너에 무거운 puppeteer 불필요
                #   entwurf-peek: pi-shell-acp 분신 호출자 전용
                SKILL_EXCLUDE=(telegram slack-latest jiracli memory-sync punchout browser-tools entwurf-peek)
                SKILL_DEPLOY=()
                for d in "$AGENT_SKILLS_SSOT"/*/; do
                    [[ -e "$d" ]] || continue
                    name=$(basename "$d")
                    skip=0
                    for ex in "${SKILL_EXCLUDE[@]}"; do
                        [[ "$name" == "$ex" ]] && { skip=1; break; }
                    done
                    [[ $skip -eq 1 ]] && continue
                    SKILL_DEPLOY+=("$name")
                done

                # 모든 봇 동일 스킬 + Claude ACP 오버레이(claude-skills)
                AGENTS_FULL=(workspace workspace-glg workspace-gpt workspace-gemini workspace-mini workspace-bbot)

                info "=== OpenClaw 스킬 배포 (심볼릭 → agent-config SSOT) ==="
                echo ""
                echo "  SSOT: $AGENT_SKILLS_SSOT"
                echo "  배포 (${#SKILL_DEPLOY[@]}): ${SKILL_DEPLOY[*]}"
                echo "  제외 (${#SKILL_EXCLUDE[@]}): ${SKILL_EXCLUDE[*]}"
                echo "  대상: ${AGENTS_FULL[*]} + claude-skills"
                echo "  gog bin: $GOG_BIN_SSOT"
                echo ""
                warn "workspace/claude-skills를 심볼릭으로 재작성합니다. 계속하시겠습니까? (y/N)"
                read -p "> " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    # gog 바이너리 보존 (스킬 트리 밖). agent-config/gogcli/gog 가 여길 가리킴.
                    mkdir -p "$OPENCLAW_DIR/bin"
                    if [[ ! -f "$GOG_BIN_SSOT" || -L "$GOG_BIN_SSOT" ]]; then
                        if [[ -x "$HOME/.local/bin/gog" ]]; then
                            cp -a "$HOME/.local/bin/gog" "$GOG_BIN_SSOT"
                            success "gog bin seeded from ~/.local/bin"
                        else
                            warn "gog bin missing and no ~/.local/bin/gog — gogcli may break"
                        fi
                    fi
                    if [[ -e "$AGENT_SKILLS_SSOT/gogcli" ]]; then
                        ln -sfn "$GOG_BIN_SSOT" "$AGENT_SKILLS_SSOT/gogcli/gog"
                    fi

                    deploy_skill_symlinks() {
                        local dest="$1"
                        mkdir -p "$dest"
                        find "$dest" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
                        local n
                        for n in "${SKILL_DEPLOY[@]}"; do
                            ln -sfn "$AGENT_SKILLS_SSOT/$n" "$dest/$n"
                        done
                    }

                    info "1/2 workspace* 심볼릭 배포..."
                    for ws in "${AGENTS_FULL[@]}"; do
                        deploy_skill_symlinks "$OPENCLAW_DIR/config/$ws/skills"
                        success "$ws ($(ls -1 "$OPENCLAW_DIR/config/$ws/skills" | wc -l))"
                    done

                    echo ""
                    info "2/2 claude-skills 심볼릭 배포 (ACP ~/.claude/skills 마운트)..."
                    deploy_skill_symlinks "$CLAUDE_SKILLS"
                    success "claude-skills ($(ls -1 "$CLAUDE_SKILLS" | wc -l))"

                    echo ""
                    info "샘플 resolve:"
                    ls -la "$OPENCLAW_DIR/config/workspace-glg/skills/autholog-mend" 2>/dev/null || true
                    if [[ -x "$OPENCLAW_DIR/config/workspace/skills/gogcli/gog" ]]; then
                        echo -n "  gog: "
                        "$OPENCLAW_DIR/config/workspace/skills/gogcli/gog" --version 2>/dev/null | head -1 || true
                    fi
                    echo ""
                    success "스킬 심볼릭 배포 완료. 디렉터리 추가/삭제·allowSymlinkTargets 변경 시 gateway restart/recreate 필요: r) 메뉴"
                else
                    info "취소되었습니다."
                fi
                ;;
            w)
                echo ""
                if [[ "$DEVICE" == "oracle" ]]; then
                    "$FLAKE_DIR/scripts/turnwatch.sh" "${TURNWATCH_HOURS:-24}"
                else
                    execute_cmd "ssh oracle '~/repos/gh/nixos-config/scripts/turnwatch.sh ${TURNWATCH_HOURS:-24}'"
                fi
                ;;
            W)
                echo ""
                if [[ "$DEVICE" == "oracle" ]]; then
                    "$FLAKE_DIR/scripts/model-demotion-check.sh" --days "${DEMOTION_DAYS:-7}" || true
                else
                    execute_cmd "ssh oracle '~/repos/gh/nixos-config/scripts/model-demotion-check.sh --days ${DEMOTION_DAYS:-7}'"
                fi
                ;;
            i)
                execute_cmd "bash '$FLAKE_DIR/scripts/setup-stignore.sh' deploy"
                ;;
            I)
                execute_cmd "bash '$FLAKE_DIR/scripts/setup-stignore.sh' diff"
                ;;
            d|D)
                echo ""
                info "디스크 사용량:"
                df -h /
                echo ""
                info "/nix 폴더 크기:"
                du -sh /nix 2>/dev/null || echo "측정 중..."
                echo ""
                info "현재 시스템 클로저 크기:"
                nix path-info -Sh /run/current-system 2>/dev/null || echo "측정 실패"
                echo ""
                info "GC roots 개수:"
                nix-store --gc --print-roots 2>/dev/null | grep -v '/proc/' | wc -l
                echo ""
                info "시스템 세대 목록:"
                sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
                echo ""
                info "Home-manager 세대 수:"
                ls ~/.local/state/nix/profiles/home-manager-*-link 2>/dev/null | wc -l
                echo ""
                info "result 심볼릭 링크:"
                find ~/repos -maxdepth 3 -name "result" -type l 2>/dev/null || echo "없음"
                ;;
            e)
                # 목록은 run.sh 에 두지 않는다 — SSOT는 scripts/external-packages.sh
                execute_cmd "bash '$FLAKE_DIR/scripts/external-packages.sh' check"
                ;;
            E)
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo -e "${GREEN}External Packages - Install/Upgrade${NC}"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                echo "  1) pnpm global (netlify/clawhub/summarize/codex/ts/pi)"
                echo "  2) harness (curl: claude/antigravity)"
                echo "  3) gog (gogcli upstream go install)"
                echo "  4) uv tools"
                echo "  a) ALL (전부)"
                echo "  0) 취소"
                echo ""
                read -p "선택: " up_choice

                EXT_PKG="$FLAKE_DIR/scripts/external-packages.sh"
                case $up_choice in
                    1) execute_cmd "bash '$EXT_PKG' install pnpm" ;;
                    2) execute_cmd "bash '$EXT_PKG' install harness" ;;
                    3) execute_cmd "bash '$EXT_PKG' install gog" ;;
                    4) execute_cmd "bash '$EXT_PKG' install uv" ;;
                    a) execute_cmd "bash '$EXT_PKG' install all" ;;
                    0) info "취소" ;;
                    *) error "잘못된 선택" ;;
                esac
                ;;
            0)
                info "종료합니다."
                exit 0
                ;;
            *)
                error "잘못된 선택입니다."
                ;;
        esac

        echo ""
        read -p "계속하려면 Enter를 누르세요..."
    done
}

main "$@"
