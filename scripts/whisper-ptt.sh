#!/usr/bin/env bash
# whisper-ptt.sh - 워키토키(Push-to-Talk) 음성 입력
# i3 keybinding:
#   bindsym F1          exec --no-startup-id whisper-ptt.sh start
#   bindsym --release F1 exec --no-startup-id whisper-ptt.sh stop

#---CONFIG---
TEMPD="/dev/shm"
AUDIO_FILE="$TEMPD/whisper-ptt.wav"
LOG_FILE="$TEMPD/whisper-ptt.log"
PID_FILE="$TEMPD/whisper-ptt.pid"
GROQ_API_KEY="${GROQ_API_KEY:-$(pass api/groq/junghanacs 2>/dev/null || echo "")}"
AUTOPASTE=1
#---END CONFIG---

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }

cmd_start() {
    # 이미 녹음 중이면 무시 (키 반복 방지)
    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log "이미 녹음 중 (PID $old_pid), 무시"
            return 0
        fi
        rm -f "$PID_FILE"
    fi

    if [[ -z "$GROQ_API_KEY" ]]; then
        notify-send -u critical "🎙️ PTT" "API 키 없음"
        exit 1
    fi

    rm -f "$AUDIO_FILE"

    # rec을 nohup으로 실행 (setsid 사용 X — PID 정확성 보장)
    nohup rec -q -t wav "$AUDIO_FILE" rate 16k > /dev/null 2>&1 &
    local rec_pid=$!
    disown "$rec_pid"
    echo "$rec_pid" > "$PID_FILE"

    log "=== PTT 녹음 시작 (PID $rec_pid) ==="
    notify-send -t 800 "🎙️ PTT" "녹음 중..."
}

cmd_stop() {
    if [[ ! -f "$PID_FILE" ]]; then
        log "PID 파일 없음, 무시"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")
    rm -f "$PID_FILE"

    if ! kill -0 "$pid" 2>/dev/null; then
        log "PID $pid 이미 종료됨"
        return 0
    fi

    # SIGINT → rec이 WAV 헤더 정상 기록
    log "rec PID $pid에 SIGINT 전송"
    kill -INT "$pid" 2>/dev/null || true

    # 프로세스 종료 대기 (최대 3초)
    local i=0
    while kill -0 "$pid" 2>/dev/null && (( i < 30 )); do
        sleep 0.1
        i=$((i + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
        log "SIGINT 타임아웃, SIGKILL"
        kill -9 "$pid" 2>/dev/null || true
        sleep 0.2
    fi

    # 파일 쓰기 완료 대기
    sleep 0.3

    log "=== PTT 녹음 종료 ==="

    # 파일 확인
    local filesize
    filesize=$(stat -c%s "$AUDIO_FILE" 2>/dev/null || echo "0")
    log "파일 크기: $filesize bytes"

    if [[ "$filesize" -lt 1000 ]]; then
        log "녹음이 너무 짧음"
        notify-send -u low -t 1000 "🎙️ PTT" "너무 짧음"
        rm -f "$AUDIO_FILE"
        return 0
    fi

    # WAV 유효성 간단 체크 (첫 4바이트 = "RIFF")
    local header
    header=$(head -c 4 "$AUDIO_FILE" 2>/dev/null || echo "")
    if [[ "$header" != "RIFF" ]]; then
        log "WAV 헤더 손상 — RIFF 아님: $header"
        notify-send -u critical "🎙️ PTT" "녹음 파일 손상"
        rm -f "$AUDIO_FILE"
        return 1
    fi

    notify-send -t 800 "🎙️ PTT" "변환 중..."

    # Groq API 호출
    local RESPONSE
    RESPONSE=$(curl -s --max-time 30 \
        https://api.groq.com/openai/v1/audio/transcriptions \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        -F file=@"$AUDIO_FILE" \
        -F model="whisper-large-v3" \
        -F language="ko" 2>>"$LOG_FILE")

    log "API 응답: $RESPONSE"

    local TEXT
    TEXT=$(echo "$RESPONSE" | jq -r '.text // empty')

    if [[ -z "$TEXT" ]]; then
        local ERROR
        ERROR=$(echo "$RESPONSE" | jq -r '.error.message // "알 수 없는 오류"')
        log "변환 실패: $ERROR"
        notify-send -u critical "🎙️ PTT" "실패: $ERROR"
        rm -f "$AUDIO_FILE"
        return 1
    fi

    log "최종 텍스트: $TEXT"

    echo -n "$TEXT" | xsel -ib

    if (( AUTOPASTE )); then
        sleep 0.1
        xdotool key ctrl+shift+v
    fi

    notify-send -t 1500 "🎙️ PTT" "완료 (${#TEXT}자)"
    rm -f "$AUDIO_FILE"
}

case "${1:-}" in
    start) cmd_start ;;
    stop)  cmd_stop ;;
    *)
        echo "Usage: $0 {start|stop}" >&2
        exit 1
        ;;
esac
