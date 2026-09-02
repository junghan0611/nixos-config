#!/usr/bin/env bash
# model-demotion-check.sh — claude-cli 봇이 "몰래 다른 모델로 갈아탄" 사건을 훑는다.
#
# 왜 필요한가 (2026-09-02):
#   bbot(Fable 5)이 13:20 KST에 Opus 4.8로 강등됐고 그 뒤 두 턴을 그 모델로 답했다.
#   봇도, 텔레그램도, OpenClaw 세션 목록도 그 사실을 말해주지 않는다. GLG가 대화 주제를
#   기억해서 겨우 드러났다 — "말을 안 해줬으면 몰랐을 뻔했다".
#
# 메커니즘 (claude-code 2.1.258 바이너리 실측):
#   primary 모델이 stop_reason="refusal" 로 스트림을 끝내면 CLI가 그 턴을 fallback 모델로
#   **한 번 자동 재시도**한다. 트랜스크립트에는 assistant content block
#   {"type":"fallback","from":{...},"to":{...}} 로 남고, usage.iterations 에
#   type="message"(원 모델) + type="fallback_message"(강등 모델)가 나란히 찍힌다.
#   내부 스키마: subtype="model_refusal_fallback", trigger="refusal",
#                direction=retry|revert|sticky, scope=session|local.
#   ★ scope="session" 이면 "the swap is made persistent for the session" —
#     그 세션의 남은 턴이 전부 강등 모델로 간다. 이게 진짜 피해다.
#   ※ 용량(529 overload) 폴백은 다른 경로다(api_request_fallback_triggered, reason="overloaded").
#     그건 이 블록을 남기지 않는다. 즉 여기 잡히는 건 "앤트로픽이 턴을 내린" 케이스다.
#
# 사용:
#   ./scripts/model-demotion-check.sh              # 최근 7일
#   ./scripts/model-demotion-check.sh --days 30
#   ./scripts/model-demotion-check.sh --all
#   ./scripts/model-demotion-check.sh --context    # ★ 강등된 턴의 사용자 메시지 첫 줄까지
#
# ⚠️ --context 는 사적 대화 본문을 화면에 띄운다. 이 스크립트는 어디에도 저장하지 않는다.
#    출력을 파일로 리다이렉트하거나 공개 리포에 붙여넣지 마라.
#
# exit code: 0 = 강등 없음 / 3 = 강등 발견 / 1 = 실행 오류

set -euo pipefail

CONTAINER="${OPENCLAW_CONTAINER:-openclaw-gateway}"
DAYS=7
SHOW_CONTEXT=0

while [ $# -gt 0 ]; do
	case "$1" in
		--days) DAYS="${2:?--days 는 숫자가 필요하다}"; shift 2 ;;
		--all) DAYS=0; shift ;;
		--context|--why) SHOW_CONTEXT=1; shift ;;
		-h|--help) sed -n '2,32p' "$0"; exit 0 ;;
		*) echo "알 수 없는 인자: $1" >&2; exit 1 ;;
	esac
done

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
	echo "컨테이너 '$CONTAINER' 가 안 돈다. OPENCLAW_CONTAINER 로 이름을 바꿀 수 있다." >&2
	exit 1
fi

docker exec -i -e DAYS="$DAYS" -e SHOW_CONTEXT="$SHOW_CONTEXT" "$CONTAINER" python3 - <<'PY'
import json, os, glob, re, time, datetime

DAYS = int(os.environ.get("DAYS", "7"))
SHOW = os.environ.get("SHOW_CONTEXT") == "1"
KST = datetime.timezone(datetime.timedelta(hours=9))

cutoff = 0.0
if DAYS > 0:
	cutoff = time.time() - DAYS * 86400

def kst(ts):
	# ts: "2026-09-02T04:20:13.684Z"
	try:
		d = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
		return d.astimezone(KST).strftime("%Y-%m-%d %H:%M:%S")
	except Exception:
		return ts or "?"

def bot_of(project_dir):
	# ".../-home-node--openclaw-workspace"      -> main
	# ".../-home-node--openclaw-workspace-bbot" -> bbot
	name = os.path.basename(project_dir)
	m = re.search(r"openclaw-workspace(?:-([a-z0-9]+))?$", name)
	if not m:
		return None
	return m.group(1) or "main"

def first_user_line(text):
	"""사용자 메시지에서 OpenClaw 컨텍스트 헤더를 걷어내고 진짜 발화 첫 줄만."""
	if not isinstance(text, str):
		return ""
	# 컨텍스트 블록(⟦openclaw:ctx⟧ ...)은 마지막 것 뒤가 실제 발화다
	tail = text.rsplit("⟦openclaw:ctx⟧", 1)[-1]
	lines = [l.strip() for l in tail.splitlines() if l.strip()]
	# 컨텍스트 잔여물(#session:... 로 시작하는 줄) 제거
	lines = [l for l in lines if not l.startswith("#session:") and not l.startswith("```")]
	return lines[-1][:160] if lines else ""

findings = []
scanned = 0

for pdir in sorted(glob.glob(os.path.expanduser("~/.claude/projects/*openclaw-workspace*"))):
	bot = bot_of(pdir)
	if not bot:
		continue
	for f in sorted(glob.glob(os.path.join(pdir, "*.jsonl"))):
		if cutoff and os.path.getmtime(f) < cutoff:
			continue
		scanned += 1
		try:
			rows = []
			for line in open(f, encoding="utf8", errors="replace"):
				line = line.strip()
				if not line:
					continue
				try:
					rows.append(json.loads(line))
				except Exception:
					continue
		except Exception:
			continue

		for i, d in enumerate(rows):
			msg = d.get("message") or {}
			content = msg.get("content")
			if not isinstance(content, list):
				continue
			blk = next((p for p in content
			            if isinstance(p, dict) and p.get("type") == "fallback"), None)
			if not blk:
				continue

			ts = d.get("timestamp", "")
			if cutoff and ts:
				try:
					when = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
					if when < cutoff:
						continue
				except Exception:
					pass

			frm = (blk.get("from") or {}).get("model", "?")
			to  = (blk.get("to") or {}).get("model", "?")
			# trigger.category 는 있으면 싣는다 (없는 CLI 도 있다)
			trig = blk.get("trigger") if isinstance(blk.get("trigger"), dict) else {}
			category = trig.get("category") or ""

			# 원 모델이 실제로 응답을 만들었는지 — 용량 폴백과 가르는 지표
			iters = ((msg.get("usage") or {}).get("iterations") or [])
			orig_out = sum(it.get("output_tokens", 0) for it in iters
			               if it.get("type") == "message")

			# 강등 이후 이 세션이 어떻게 됐는가
			after_msgs = 0
			after_turns = 0
			last_model = None
			first_user_after = ""
			for e in rows[i + 1:]:
				m2 = (e.get("message") or {}).get("model")
				if e.get("type") == "assistant" and m2:
					last_model = m2
					if m2 == to:
						after_msgs += 1
				if e.get("type") == "user":
					c2 = (e.get("message") or {}).get("content")
					if isinstance(c2, str) and "openclaw:ctx" in c2:
						after_turns += 1

			# 강등을 유발한 사용자 메시지 (이 fallback 앞쪽에서 가장 가까운 사용자 턴)
			trigger_line = ""
			for e in reversed(rows[:i]):
				if e.get("type") == "user":
					c2 = (e.get("message") or {}).get("content")
					if isinstance(c2, str) and "openclaw:ctx" in c2:
						trigger_line = first_user_line(c2)
						break

			findings.append({
				"kst": kst(ts), "bot": bot, "from": frm, "to": to,
				"category": category, "orig_out": orig_out,
				"after_msgs": after_msgs, "after_turns": after_turns,
				"sticky": last_model == to,
				"session": os.path.basename(f)[:8],
				"trigger": trigger_line,
			})

findings.sort(key=lambda x: x["kst"])

window = "전체" if DAYS == 0 else f"최근 {DAYS}일"
print(f"\n\033[1m모델 강등 점검\033[0m — {window} · 트랜스크립트 {scanned}개 스캔 "
      f"· claude-cli 봇 {len(set(bot_of(p) for p in glob.glob(os.path.expanduser('~/.claude/projects/*openclaw-workspace*')) if bot_of(p)))}개\n")

if not findings:
	print("  강등 없음.\n")
	raise SystemExit(0)

print(f"  \033[1;31m강등 {len(findings)}건\033[0m — 앤트로픽이 턴을 내리고 CLI가 다른 모델로 재시도한 자리다.\n")
hdr = f"  {'KST':<19}  {'봇':<6}  {'강등':<34}  {'이후':<16}  세션"
print(hdr)
print("  " + "-" * (len(hdr) - 2))
for x in findings:
	swap = f"{x['from']} → {x['to']}"
	sticky = "\033[31m세션 고착\033[0m" if x["sticky"] else "복귀함"
	after = f"{x['after_msgs']}건/{x['after_turns']}턴 {sticky}"
	cat = f" [{x['category']}]" if x["category"] else ""
	print(f"  {x['kst']:<19}  {x['bot']:<6}  {swap:<34}{cat}  {after:<16}  {x['session']}")
	if x["orig_out"] == 0:
		print(f"  {'':<19}  {'':<6}  ⚠ 원 모델 출력 0 토큰 — 용량 폴백일 수도 있다(refusal 아님)")

if SHOW:
	print("\n  \033[1m강등을 부른 사용자 메시지\033[0m  ⚠ 사적 대화다. 저장·공유 금지.\n")
	for x in findings:
		print(f"  {x['kst']}  {x['bot']}")
		print(f"    {x['trigger'] or '(찾지 못함)'}\n")
else:
	print("\n  주제를 보려면: --context  (사적 대화 출력, 저장 안 함)")

print("\n  판독:")
print("    · '세션 고착' = 그 뒤 턴도 강등 모델로 갔다. 사용자는 모른 채 다른 모델과 대화한 것.")
print("    · 되돌리려면 해당 봇 텔레그램 DM 에서 /model <원래모델> 로 세션을 다시 박는다.")
print("    · 설정은 안 바뀐다 — openclaw.json 은 그대로고 세션만 갈아탄 것이라")
print("      'openclaw sessions list' 나 config 를 봐서는 안 보인다. 그래서 이 스크립트가 있다.\n")
raise SystemExit(3)
PY
