#!/usr/bin/env bash
# Claude Code 창 순환 스크립트
# 창 타이틀에 ✳ 가 있는 X window를 순환하며 포커스
# 사용법: claude-focus.sh [next|prev]
#   next (기본): 다음 Claude Code 창으로 이동
#   prev: 이전 Claude Code 창으로 이동

set -euo pipefail

DIRECTION="${1:-next}"

# ✳ 가 타이틀에 있는 창 목록 (i3 tree에서 가져옴 — workspace 순서 보장)
mapfile -t WINDOWS < <(
    i3-msg -t get_tree 2>/dev/null | \
    jq -r '.. | select(.window_properties?.title? // .name? | strings | test("✳")) | .id' 2>/dev/null
)

COUNT=${#WINDOWS[@]}

if [[ $COUNT -eq 0 ]]; then
    notify-send "Claude Focus" "실행 중인 Claude Code가 없습니다" -u low -t 2000 2>/dev/null || true
    exit 0
fi

if [[ $COUNT -eq 1 ]]; then
    i3-msg "[con_id=${WINDOWS[0]}]" focus >/dev/null 2>&1
    exit 0
fi

# 현재 포커스된 창의 con_id
FOCUSED=$(i3-msg -t get_tree 2>/dev/null | jq -r '.. | select(.focused? == true) | .id' 2>/dev/null | head -1)

# 현재 창의 인덱스 찾기
CURRENT_IDX=-1
for i in "${!WINDOWS[@]}"; do
    if [[ "${WINDOWS[$i]}" == "$FOCUSED" ]]; then
        CURRENT_IDX=$i
        break
    fi
done

# 다음/이전 인덱스 계산
if [[ "$DIRECTION" == "prev" ]]; then
    NEXT_IDX=$(( (CURRENT_IDX - 1 + COUNT) % COUNT ))
else
    NEXT_IDX=$(( (CURRENT_IDX + 1) % COUNT ))
fi

# 포커스 이동
i3-msg "[con_id=${WINDOWS[$NEXT_IDX]}]" focus >/dev/null 2>&1
