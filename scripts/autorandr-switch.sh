#!/usr/bin/env bash
# 듀얼 모니터 수동 전환 스크립트
# 사용법: ./autorandr-switch.sh

set -euo pipefail

echo "현재 감지된 프로파일:"
autorandr --detected

echo ""
echo "프로파일 적용 중..."
autorandr --change --debug

echo ""
echo "현재 디스플레이 상태:"
xrandr --query | grep -E "^(Screen|eDP|HDMI|DP)" | head -10

notify-send "Display" "autorandr 프로파일 적용 완료" 2>/dev/null || true
