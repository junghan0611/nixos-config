#!/usr/bin/env bash
# whisper-groq.sh - 전역 음성 입력 (Groq Whisper API + sox silence detection)
# 사용법: 키바인딩으로 실행 → 말하기 → 2초 침묵 시 자동 종료 → 변환 → 붙여넣기
# 마이크 소음 레벨 확인 (숫자가 높을수록 시끄러움)
# rec -n stat 2>&1 | grep "Maximum amplitude"
# 1. 마이크 입력 볼륨 낮추기 (권장) pavucontrol → 입력 장치 탭 → 마이크 볼륨을 **50-70%**로 낮추기
# 2. 임계값을 대폭 올리기 25%

set -e

#---USER CONFIG---
TEMPD="/dev/shm"
AUDIO_FILE="$TEMPD/whisper-groq.wav"
LOG_FILE="$TEMPD/whisper-groq.log"

# Groq API 키 (환경변수 또는 pass)
GROQ_API_KEY="${GROQ_API_KEY:-$(/usr/bin/pass api/groq/junghanacs 2>/dev/null || echo "")}"

# 자동 붙여넣기 (1=활성화, 0=클립보드만)
AUTOPASTE=1
#---END CONFIG---

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }

# 후처리 함수 (커스터마이징 가능)
postprocess() {
    local text="$1"
    # 예: 티먹스 → tmux, 클로드 → Claude 등
    # text="${text//티먹스/tmux}"
    # text="${text//클로드/Claude}"
    echo "$text"
}

# API 키 확인
if [[ -z "$GROQ_API_KEY" ]]; then
    notify-send -u critical "Whisper" "API 키 없음"
    exit 1
fi

# 이미 실행 중이면 종료 (녹음 중지)
if pidof -q rec; then
    pkill rec
    exit 0
fi

log "=== 녹음 시작 ==="
notify-send -t 1500 "Whisper" "녹음 중... (2초 침묵 시 자동 종료)"

# sox rec: silence detection
# silence 1 0.1 3%  → 0.1초 동안 % 이상 소리 있어야 녹음 시작
# silence 1 2.0 10%  → 2초 동안 % 이하면 종료
rec -q -t wav "$AUDIO_FILE" rate 16k silence 1 0.1 3% 1 2.0 10% 2>/dev/null

# 파일 크기 확인
filesize=$(stat -c%s "$AUDIO_FILE" 2>/dev/null || echo "0")
log "파일 크기: $filesize bytes"

if [[ "$filesize" -lt 1000 ]]; then
    log "녹음이 너무 짧음"
    notify-send -u low "Whisper" "녹음이 너무 짧음"
    rm -f "$AUDIO_FILE"
    exit 0
fi

notify-send -t 1000 "Whisper" "변환 중..."

# Groq API 호출
RESPONSE=$(curl -s https://api.groq.com/openai/v1/audio/transcriptions \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -F file=@"$AUDIO_FILE" \
    -F model="whisper-large-v3" \
    -F language="ko" 2>>"$LOG_FILE")

log "API 응답: $RESPONSE"

TEXT=$(echo "$RESPONSE" | jq -r '.text // empty')

if [[ -z "$TEXT" ]]; then
    ERROR=$(echo "$RESPONSE" | jq -r '.error.message // "알 수 없는 오류"')
    log "변환 실패: $ERROR"
    notify-send -u critical "Whisper" "변환 실패: $ERROR"
    rm -f "$AUDIO_FILE"
    exit 1
fi

# 후처리
TEXT=$(postprocess "$TEXT")
log "최종 텍스트: $TEXT"

# 클립보드에 저장 (xsel 사용)
echo -n "$TEXT" | xsel -ib

# 자동 붙여넣기
if (( AUTOPASTE )); then
    sleep 0.1
    xdotool key ctrl+shift+v
fi

notify-send -t 1500 "Whisper" "완료 (${#TEXT}자)"
rm -f "$AUDIO_FILE"
