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
VALID_HOSTS=("oracle" "nuc" "laptop")

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
    echo -e "  ${YELLOW}Cleanup${NC}"
    echo "    c) Cleanup (7일 이상 오래된 세대 삭제 + GC)"
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
        read -p "선택하세요 (0-9, c, d): " choice

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
            c|C)
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
                    execute_cmd "sudo nix-collect-garbage -d --delete-older-than 7d"
                    echo ""
                    info "정리 후 디스크 사용량:"
                    df -h /
                else
                    info "취소되었습니다."
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
                info "세대 목록:"
                sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
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
