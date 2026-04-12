#!/usr/bin/env bash
# i3-fcitx5-group.sh — 포커스 창에 따라 fcitx5 그룹 자동 전환
#
# wezterm → Default (영문, Emacs 내장 입력기)
# 그 외 → Korean (fcitx5 hangul)
#
# xprop -spy 방식: X11 _NET_ACTIVE_WINDOW 변경 감지
# i3-msg subscribe보다 안정적, WM 무관
#
# 테스트: ./i3-fcitx5-group.sh
# 종료: Ctrl+C

PREV_GROUP=""

xprop -spy -root _NET_ACTIVE_WINDOW 2>/dev/null | while read -r line; do
  wid=$(echo "$line" | grep -oP '0x[0-9a-f]+' | tail -1)
  [ -z "$wid" ] && continue

  class=$(xprop -id "$wid" WM_CLASS 2>/dev/null | awk -F'"' '{print $4}')
  [ -z "$class" ] && continue

  case "$class" in
    org.wezfurlong.wezterm)
      group="Default"
      ;;
    *)
      group="Korean"
      ;;
  esac

  # 같은 그룹이면 스킵 (불필요한 호출 방지)
  if [ "$group" != "$PREV_GROUP" ]; then
    fcitx5-remote -g "$group" 2>/dev/null
    PREV_GROUP="$group"
  fi
done
