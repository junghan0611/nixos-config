#!/usr/bin/env bash
# 듀얼 모니터 수동 전환 스크립트
# autorandr 자동 감지 시도 후, 실패 시 xrandr로 직접 설정
# 사용법: ./autorandr-switch.sh [profile]
#   profile: home | office | laptop (생략 시 자동 감지)

set -euo pipefail

# 연결된 외부 모니터 포트 감지
get_external_output() {
    xrandr --query | grep " connected" | grep -v "eDP" | awk '{print $1}' | head -1
}

# 모니터 EDID에서 모델명 추출
get_monitor_name() {
    local output="$1"
    xrandr --prop 2>/dev/null | awk -v out="$output" '
        $1 == out { found=1; next }
        found && /^\S/ { exit }
        found && /EDID:/ { edid=1; next }
        found && edid { print; edid=0 }
    ' | head -1
}

apply_home_qhd() {
    local ext="$1"
    echo ">> 집 프로파일 적용: $ext (QHD 2560x1440) + eDP-1"
    xrandr \
        --output "$ext" --mode 2560x1440 --rate 59.95 --pos 0x0 \
        --output eDP-1 --mode 1920x1200 --rate 60.00 --pos 320x1440 --primary
}

apply_office_4k() {
    local ext="$1"
    echo ">> 사무실 프로파일 적용: $ext (4K 3840x2160) + eDP-1"
    xrandr \
        --output "$ext" --mode 3840x2160 --rate 60.00 --pos 0x0 \
        --output eDP-1 --mode 1920x1200 --rate 60.00 --pos 960x2160 --primary
}

apply_laptop_only() {
    echo ">> 노트북 단독 모드"
    # 외부 출력 모두 끄기
    for out in $(xrandr --query | grep " connected" | grep -v "eDP" | awk '{print $1}'); do
        xrandr --output "$out" --off
    done
    xrandr --output eDP-1 --mode 1920x1200 --rate 60.00 --primary --pos 0x0
}

# --- 메인 ---

PROFILE="${1:-auto}"
EXT_OUTPUT=$(get_external_output)

# 명시적 프로파일 지정 시
if [[ "$PROFILE" != "auto" ]]; then
    case "$PROFILE" in
        home)
            if [[ -z "$EXT_OUTPUT" ]]; then
                echo "외부 모니터가 연결되어 있지 않습니다."
                exit 1
            fi
            apply_home_qhd "$EXT_OUTPUT"
            ;;
        office)
            if [[ -z "$EXT_OUTPUT" ]]; then
                echo "외부 모니터가 연결되어 있지 않습니다."
                exit 1
            fi
            apply_office_4k "$EXT_OUTPUT"
            ;;
        laptop)
            apply_laptop_only
            ;;
        *)
            echo "사용법: $0 [home|office|laptop]"
            exit 1
            ;;
    esac
else
    # 자동 감지: autorandr 먼저 시도
    echo "=== autorandr 자동 감지 ==="
    DETECTED=$(autorandr --detected 2>/dev/null || true)
    echo "$DETECTED"

    if [[ -n "$DETECTED" ]]; then
        echo ""
        echo "autorandr 프로파일 적용 중..."
        autorandr --change && {
            echo "autorandr 적용 성공"
        } || {
            echo "autorandr 실패, xrandr fallback 진행..."
        }
    fi

    # autorandr 후에도 외부 모니터가 미러링/미적용 상태면 fallback
    if [[ -n "$EXT_OUTPUT" ]]; then
        # 외부 모니터의 최대 해상도로 판별
        MAX_RES=$(xrandr --query | awk -v out="$EXT_OUTPUT" '
            $1 == out { found=1; next }
            found && /^\S/ { exit }
            found && /[0-9]+x[0-9]+/ { print $1; exit }
        ')
        echo ""
        echo "외부 모니터: $EXT_OUTPUT ($MAX_RES)"

        # 현재 실제 활성 상태 확인
        IS_ACTIVE=$(xrandr --query | grep "^$EXT_OUTPUT" | grep -c "+")

        if [[ "$IS_ACTIVE" -eq 0 ]]; then
            echo "외부 모니터 비활성 상태 — fallback 적용"
            case "$MAX_RES" in
                2560x1440) apply_home_qhd "$EXT_OUTPUT" ;;
                3840x2160) apply_office_4k "$EXT_OUTPUT" ;;
                *)
                    echo "알 수 없는 해상도 ($MAX_RES), 수동 설정 필요"
                    echo "  $0 home   — QHD 2560x1440"
                    echo "  $0 office — 4K 3840x2160"
                    exit 1
                    ;;
            esac
        fi
    fi
fi

echo ""
echo "=== 최종 디스플레이 상태 ==="
xrandr --query | grep -E "^(eDP|HDMI|DP)" | head -10

notify-send "Display" "모니터 프로파일 적용 완료" 2>/dev/null || true
