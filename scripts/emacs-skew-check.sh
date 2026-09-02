#!/usr/bin/env bash
# emacs-skew-check.sh — emacsclient/server 버전 스큐로 인한 조용한 응답 손상 검사.
#
# 왜 필요한가: Emacs 31 server.el 이 응답 청크 분할을 없앴고(upstream Bug#80807),
# 30.x emacsclient 는 고정 BUFSIZ 버퍼로 매 recv 를 독립 메시지처럼 처리해 쪼개진
# protocol line 을 못 합친다. 결과는 조용한 오염이다:
#   - 인용 누출:  공백→&_  하이픈→&-  newline→&n  앰퍼샌드→&&
#   - 에러문 주입: "*ERROR*: Unknown message: " 가 stdout payload 안에 섞임
# exit code 0, stderr 비어 있음, healthcheck `(+ 1 1)` 통과, agenda HTTP 200 —
# 전부 초록인 채로 내용만 깨진다. 그래서 이 스크립트가 따로 있다.
#
# 사용: ./scripts/emacs-skew-check.sh [host|geworfen|gateway|all]
set -uo pipefail
TARGET="${1:-all}"
RC=0

# 경계를 넘기는 싼 probe. 20000자 무공백 → 정상이면 정확히 20002 B("따옴표 2개 포함").
PROBE_N=20000
PROBE_EXPECT=$((PROBE_N + 2))
MARKERS='&_|&-|&&|&n|\*ERROR\*: Unknown message'

run_one() {
	local label="$1" ; shift
	local out rc marks len
	out=$("$@" --eval "(make-string ${PROBE_N} ?x)" 2>/dev/null); rc=$?
	len=${#out}
	marks=$(printf '%s' "$out" | grep -cE "$MARKERS" || true)
	if [ "$rc" -ne 0 ]; then
		printf '  %-22s ❌ emacsclient exit=%s (연결 실패)\n' "$label" "$rc"; RC=1; return
	fi
	if [ "$len" -ne "$PROBE_EXPECT" ] || [ "$marks" -ne 0 ]; then
		printf '  %-22s ❌ 손상: %s B (기대 %s), 오염마커 %s\n' "$label" "$len" "$PROBE_EXPECT" "$marks"; RC=1; return
	fi
	printf '  %-22s ✅ %s B, 마커 0\n' "$label" "$len"
}

# 실데이터 왕복 — geworfen 이 라이브로 부르는 유일한 elisp 는 agenda-day 다
# (agenda-week / alive? 는 정의만 있고 caller 없음 — geworfen ARCHITECTURE.md 감사 2026-09-02).
# 바쁜 날의 day 는 이미 8 KB 경계를 넘는다: 2026-09-01=8.8KB, 08-30=8.6KB 실측.
# 그래서 "오늘"이 아니라 **바쁜 과거 날짜**를 기준일로 박는다 — 오늘은 오전엔 작아서 못 잡는다.
BUSY_DAY="${BUSY_DAY:-2026-09-01}"
run_week() {
	local label="$1" ; shift
	local out marks len
	out=$("$@" --eval "(agent-org-agenda-day \"${BUSY_DAY}\")" 2>/dev/null)
	len=${#out}
	marks=$(printf '%s' "$out" | grep -cE "$MARKERS" || true)
	if [ "$marks" -ne 0 ]; then
		printf '  %-22s ❌ day(%s) 오염: %s B, 마커 %s\n' "$label" "$BUSY_DAY" "$len" "$marks"; RC=1
	else
		printf '  %-22s ✅ day(%s) %s B, 마커 0\n' "$label" "$BUSY_DAY" "$len"
	fi
}

# 어느 client 가 어느 server 를 때렸는지 사후에 가릴 수 있어야 한다.
# switch 후엔 호스트 PATH 의 emacsclient 가 31.1 로 바뀌므로, 라벨에 버전을 찍는다.
cv() { "$@" --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1; }

echo "=== emacs 버전 스큐 검사 ==="
echo "호스트 server : $(/run/current-system/sw/bin/emacs --version 2>/dev/null | head -1)"
echo "호스트 client : $(cv emacsclient)"
echo "geworfen client: $(cv docker exec geworfen emacsclient)"
echo "gateway  client: $(cv docker exec openclaw-gateway emacsclient)"

if [ "$TARGET" = all ] || [ "$TARGET" = host ]; then
	echo "[호스트]"
	run_one  "host c$(cv emacsclient) probe" emacsclient -s /run/user/1000/emacs/server
	run_week "host c$(cv emacsclient) day"   emacsclient -s /run/user/1000/emacs/server
fi
if [ "$TARGET" = all ] || [ "$TARGET" = geworfen ]; then
	echo "[geworfen]"
	run_one  "geworfen c$(cv docker exec geworfen emacsclient) probe" docker exec geworfen emacsclient -s server
	run_week "geworfen c$(cv docker exec geworfen emacsclient) day" docker exec geworfen emacsclient -s server
fi
if [ "$TARGET" = all ] || [ "$TARGET" = gateway ]; then
	echo "[openclaw-gateway]"
	run_one  "gateway c$(cv docker exec openclaw-gateway emacsclient) probe" docker exec openclaw-gateway emacsclient -s /run/emacs/server
	run_week "gateway c$(cv docker exec openclaw-gateway emacsclient) day" docker exec openclaw-gateway emacsclient -s /run/emacs/server
fi

echo
if [ $RC -eq 0 ]; then
	echo "결과: 전부 통과"
else
	echo "결과: 실패 있음 — 위 ❌ 경로는 응답이 오염됐다"
fi
echo
echo "주의: day 왕복은 보조 검사다. day 크기는 경계(약 8 KB) 근처에서 진동해서"
echo "      (같은 9/1 이 8155~8929 B 로 관측) '어떤 날은 깨지고 어떤 날은 멀쩡'하게 보인다."
echo "      판정은 고정 크기 probe(20002 B) 로 한다 — 그건 항상 두 경계를 넘는다."
exit $RC
