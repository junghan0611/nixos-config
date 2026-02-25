#!/usr/bin/env bash
set -euo pipefail

# Syncthing .stignore 배포 스크립트
# 관리: ~/repos/gh/nixos-config/stignore/
# 대상: ~/sync/*/.stignore + ~/sync/*/stignore-common

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}i${NC} $1"; }
success() { echo -e "${GREEN}v${NC} $1"; }
warn()    { echo -e "${YELLOW}!${NC} $1"; }
error()   { echo -e "${RED}x${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STIGNORE_DIR="$(dirname "$SCRIPT_DIR")/stignore"
SYNC_ROOT="$HOME/sync"

SYNC_FOLDERS=(code emacs family logseq man markdown org screenshot slipbox videos)

# Validate source files exist
check_sources() {
    if [[ ! -f "$STIGNORE_DIR/stignore-common" ]]; then
        error "stignore-common 파일이 없습니다: $STIGNORE_DIR/stignore-common"
        exit 1
    fi
}

# Deploy stignore-common to all sync folders
deploy_common() {
    info "stignore-common 배포 → ~/sync/*/"
    echo ""
    for folder in "${SYNC_FOLDERS[@]}"; do
        local target="$SYNC_ROOT/$folder"
        if [[ -d "$target" ]]; then
            cp "$STIGNORE_DIR/stignore-common" "$target/stignore-common"
            success "$folder/stignore-common"
        else
            warn "$folder/ 디렉토리 없음 (건너뜀)"
        fi
    done
}

# Generate .stignore for each folder
deploy_local() {
    echo ""
    info ".stignore 생성 → ~/sync/*/.stignore"
    echo ""
    for folder in "${SYNC_FOLDERS[@]}"; do
        local target="$SYNC_ROOT/$folder"
        local local_file="$STIGNORE_DIR/local-$folder"

        if [[ ! -d "$target" ]]; then
            warn "$folder/ 디렉토리 없음 (건너뜀)"
            continue
        fi

        # Build .stignore: header + #include + local patterns
        {
            echo "// .stignore : ~/sync/$folder (로컬 전용, 동기화되지 않음)"
            echo "// 관리: nixos-config/stignore/ → run.sh 's' 메뉴로 배포"
            echo "#include stignore-common"
            echo ""
            if [[ -f "$local_file" ]]; then
                cat "$local_file"
            else
                echo "// (폴더별 추가 패턴 없음)"
            fi
        } > "$target/.stignore"

        local line_count
        line_count=$(wc -l < "$target/.stignore")
        if [[ -f "$local_file" ]]; then
            success "$folder/.stignore (${line_count}줄, local-$folder 포함)"
        else
            success "$folder/.stignore (${line_count}줄, 공통만)"
        fi
    done
}

# Show diff between current and new
show_diff() {
    echo ""
    info "=== 변경 사항 미리보기 ==="
    echo ""
    local changes=0
    for folder in "${SYNC_FOLDERS[@]}"; do
        local target="$SYNC_ROOT/$folder"
        if [[ ! -d "$target" ]]; then
            continue
        fi

        # Check stignore-common
        if [[ -f "$target/stignore-common" ]]; then
            if ! diff -q "$STIGNORE_DIR/stignore-common" "$target/stignore-common" >/dev/null 2>&1; then
                warn "$folder/stignore-common: 업데이트 필요"
                changes=$((changes + 1))
            fi
        else
            warn "$folder/stignore-common: 새로 생성"
            changes=$((changes + 1))
        fi

        # Check .stignore has #include
        if [[ -f "$target/.stignore" ]]; then
            if ! grep -q '#include stignore-common' "$target/.stignore"; then
                warn "$folder/.stignore: #include 없음 → 교체 필요"
                changes=$((changes + 1))
            fi
        else
            warn "$folder/.stignore: 새로 생성"
            changes=$((changes + 1))
        fi
    done

    if [[ $changes -eq 0 ]]; then
        success "모든 폴더가 최신 상태입니다."
    else
        echo ""
        info "$changes개 변경 필요"
    fi
    STIGNORE_CHANGES=$changes
}

# Main
main() {
    check_sources

    case "${1:-deploy}" in
        diff|check|status)
            show_diff || true
            ;;
        deploy|setup)
            show_diff || true
            echo ""
            warn "~/sync/*/ 에 stignore-common과 .stignore를 배포합니다. (y/N)"
            read -p "> " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                info "취소되었습니다."
                exit 0
            fi
            echo ""
            deploy_common
            deploy_local
            echo ""
            success "배포 완료! Syncthing이 자동으로 패턴을 적용합니다."
            ;;
        force)
            deploy_common
            deploy_local
            echo ""
            success "강제 배포 완료!"
            ;;
        *)
            echo "사용법: $0 [deploy|diff|force]"
            echo ""
            echo "  deploy  배포 (확인 후, 기본값)"
            echo "  diff    변경 사항만 확인"
            echo "  force   확인 없이 즉시 배포"
            ;;
    esac
}

main "$@"
