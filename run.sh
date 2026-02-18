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
    echo ""
    echo -e "  ${YELLOW}Cleanup${NC}"
    echo "    c) Cleanup (7일 이상 오래된 세대 삭제 + GC)"
    echo "    C) Cleanup ALL (모든 캐시 + 휴지통 + Nix GC)"
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
    check_device

    while true; do
        show_menu
        read -p "선택하세요 (0-9, p/P, c/C/d, t/r/s): " choice

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
                echo ""
                info "현재 디스크 사용량:"
                df -h /
                echo ""
                info "세대 목록:"
                sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
                echo ""
                warn "7일 이상 오래된 세대를 삭제하고 GC를 실행합니다. 계속하시겠습니까? (y/N)"
                read -p "> " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    execute_cmd "sudo nix-collect-garbage --delete-older-than 7d"
                    echo ""
                    info "정리 후 디스크 사용량:"
                    df -h /
                else
                    info "취소되었습니다."
                fi
                ;;
            C)
                echo ""
                info "현재 디스크 사용량:"
                df -h /
                echo ""
                info "/nix 폴더 크기:"
                du -sh /nix 2>/dev/null || echo "측정 중..."
                echo ""
                info "GC roots 개수:"
                nix-store --gc --print-roots 2>/dev/null | grep -v '/proc/' | wc -l
                echo ""
                info "Home-manager 세대 수:"
                ls ~/.local/state/nix/profiles/home-manager-*-link 2>/dev/null | wc -l
                echo ""
                info "정리 대상:"
                echo "  - Nix 시스템: 7일 이상 오래된 세대"
                echo "  - Home-manager: 7일 이상 오래된 세대"
                echo "  - result 심볼릭 링크: ~/repos 하위"
                echo "  - direnv 캐시: ~/repos 하위 .direnv/"
                echo "  - 휴지통: ~/.local/share/Trash"
                echo "  - 캐시: uv, pip, puppeteer, go-build, zig, nix"
                echo "  - npm 캐시"
                echo ""
                warn "모든 Nix 관련 캐시를 정리합니다. 계속하시겠습니까? (y/N)"
                read -p "> " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    info "1/8 휴지통 비우기..."
                    rm -rf ~/.local/share/Trash/* 2>/dev/null && success "휴지통 정리 완료" || warn "휴지통이 비어있음"

                    info "2/8 일반 캐시 정리..."
                    rm -rf ~/.cache/uv ~/.cache/pip ~/.cache/puppeteer ~/.cache/go-build ~/.cache/zig ~/.cache/nix 2>/dev/null
                    success "캐시 정리 완료"

                    info "3/8 npm 캐시 정리..."
                    npm cache clean --force 2>/dev/null && success "npm 캐시 정리 완료" || warn "npm 없음"

                    info "4/8 result 심볼릭 링크 삭제..."
                    find ~/repos -maxdepth 3 -name "result" -type l -delete 2>/dev/null
                    success "result 링크 삭제 완료"

                    info "5/8 direnv 캐시 정리..."
                    find ~/repos -maxdepth 3 -type d -name ".direnv" -exec rm -rf {} + 2>/dev/null
                    success "direnv 캐시 정리 완료"

                    info "6/8 Home-manager 이전 세대 정리..."
                    if [[ -d ~/.local/state/nix/profiles ]]; then
                        # home-manager 프로파일에서 오래된 세대 삭제 (최근 3개만 유지)
                        nix-env --delete-generations +3 -p ~/.local/state/nix/profiles/home-manager 2>/dev/null && success "Home-manager 세대 정리 완료 (최근 3개 유지)" || warn "Home-manager 프로파일 없음"
                    else
                        warn "Home-manager 프로파일 디렉토리 없음"
                    fi

                    info "7/8 사용자 Nix 프로파일 GC..."
                    nix-collect-garbage --delete-older-than 7d 2>/dev/null
                    success "사용자 프로파일 GC 완료"

                    info "8/8 시스템 Nix GC 실행..."
                    execute_cmd "sudo nix-collect-garbage --delete-older-than 7d"

                    echo ""
                    info "정리 후 디스크 사용량:"
                    df -h /
                    echo ""
                    info "정리 후 /nix 폴더 크기:"
                    du -sh /nix 2>/dev/null || echo "측정 중..."
                else
                    info "취소되었습니다."
                fi
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
