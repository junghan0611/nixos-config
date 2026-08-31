#!/usr/bin/env bash
# turnwatch.sh — OpenClaw 턴 상황 단일 관리면 (oracle 전용)
#
# "원하지 않는 턴이 하나도 없어야 한다"를 지키기 위한 한 화면.
# 턴을 만들 수 있는 모든 입구를 한 번에 세운다: 자율 트리거 인벤토리 →
# 최근 턴 원장(무엇이 유발했는지) → 지금 도는 것 → 실패.
#
# SSOT
#   자율 트리거 : openclaw cron list  (heartbeat / cron / one-shot)
#   턴 원장     : config/state/openclaw.sqlite  audit_events(kind=agent_run)
#   실패        : cron_run_receipts + task_runs
#
# 턴의 유발자는 session_key 모양으로 읽는다 (audit_events에 trigger 컬럼이 없다):
#   agent:X:telegram:… → 사람    agent:X:main    → heartbeat
#   agent:X:cron:…     → cron    …:subagent:…    → subagent
#   …:active-memory…   → 사이드런  probe/skill/prewarm → 운영자 CLI
#
# 사용: ./scripts/turnwatch.sh [hours]   (기본 24)

set -uo pipefail

HOURS="${1:-24}"
OC="${OPENCLAW_DIR:-$HOME/openclaw}"
DB="$OC/config/state/openclaw.sqlite"
CTR="${OPENCLAW_CONTAINER:-openclaw-gateway}"

if [ ! -f "$DB" ]; then
	echo "turnwatch: state db not found: $DB" >&2
	echo "turnwatch: oracle 디바이스에서만 동작한다." >&2
	exit 1
fi

q() { sqlite3 -readonly "$DB" "$@"; }
hdr() { printf '\n\033[1m%s\033[0m\n' "$1"; }
since="(strftime('%s','now')-${HOURS}*3600)*1000"

echo "OpenClaw turnwatch — $(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S %Z')  (최근 ${HOURS}h)"

hdr "1. 자율 트리거 인벤토리 — 사람 없이 턴을 만들 수 있는 전부"
docker exec "$CTR" openclaw cron list 2>/dev/null \
	| cut -c1-160 \
	|| echo "  (gateway 응답 없음)"
echo "  주: 목록에 없는 것은 돌지 않는다. disabled 잡은 목록에서 빠진다."

hdr "1b. 잡별 모델/상태 — 2026.8.1 회귀 감시선 (disabled 포함)"
# 8.1은 cron agentTurn에서 agents.defaults.models[*].agentRuntime 오버라이드를 잃는다.
# model을 안 박으면 agents.defaults.model.primary(openai/*)로 떨어지고, openai 모델의
# 카탈로그 기본 런타임 codex가 disabled라 하드 실패한다 (2026-09-01 가족 cron 2건 실증).
docker exec "$CTR" openclaw cron list --all --json 2>/dev/null \
	| python3 "$(dirname "${BASH_SOURCE[0]}")/turnwatch-jobs.py" \
	|| echo "  (gateway 응답 없음)"

hdr "2. 자율 스위치 — 스스로 학습/기억/생성하는 기능"
docker exec "$CTR" openclaw config get skills.workshop.autonomous.mode 2>/dev/null \
	| sed 's/^/  workshop.autonomous.mode = /'
docker exec "$CTR" openclaw config get plugins.entries.memory-core.config.dreaming.enabled 2>/dev/null \
	| sed 's/^/  memory dreaming        = /'
docker exec "$CTR" openclaw config get plugins.entries.active-memory.enabled 2>/dev/null \
	| sed 's/^/  active-memory          = /'
echo "  internal hooks:"
docker exec "$CTR" openclaw config get hooks.internal 2>/dev/null | sed 's/^/    /'

hdr "3. 턴 원장 — 유발자별 집계"
q -header -column "
select agent_id,
  case
    when session_key like '%:telegram:%' and session_key not like '%active-memory%' then 'human'
    when session_key like '%:subagent:%'                                            then 'subagent'
    when session_key like '%active-memory%'                                         then 'active-memory'
    when session_key like '%:cron:%'                                                then 'cron'
    when session_key like 'agent:%:main'                                            then 'main-session(hb추정)'
    when session_key like '%probe%' or session_key like '%prewarm%'
      or session_key like '%skill%'                                                 then 'operator-cli'
    else 'other'
  end as trigger,
  count(*) runs,
  max(datetime(occurred_at/1000,'unixepoch','+9 hours')) last
from audit_events
where kind='agent_run' and action='agent.run.started' and occurred_at > $since
group by agent_id, trigger
order by runs desc;"

hdr "4. 최근 턴 20건"
q -header -column "
select datetime(occurred_at/1000,'unixepoch','+9 hours') kst,
       agent_id, status, substr(session_key,1,58) session_key
from audit_events
where kind='agent_run' and action='agent.run.started' and occurred_at > $since
order by occurred_at desc limit 20;"

hdr "5. 자동화 실행 결과 (cron receipts)"
q -header -column "
select datetime(started_at_ms/1000,'unixepoch','+9 hours') kst, agent_id, status,
       (finished_at_ms-started_at_ms) ms, substr(coalesce(error_text,''),1,48) error
from cron_run_receipts
where started_at_ms > $since
order by started_at_ms desc limit 15;"

hdr "6. 실패한 작업 (열려 있는 이슈)"
q -header -column "
select datetime(created_at/1000,'unixepoch','+9 hours') kst, task_kind, agent_id,
       substr(coalesce(task,''),1,60) task
from task_runs
where status='failed'
order by created_at desc limit 10;"

hdr "7. 아직 안 끝난 턴 (started 후 finished 없음)"
q -header -column "
select datetime(s.occurred_at/1000,'unixepoch','+9 hours') kst, s.agent_id,
       substr(s.session_key,1,58) session_key
from audit_events s
where s.kind='agent_run' and s.action='agent.run.started' and s.occurred_at > $since
  and not exists (
    select 1 from audit_events f
    where f.kind='agent_run' and f.action='agent.run.finished' and f.run_id=s.run_id)
order by s.occurred_at desc limit 10;"

echo
cat <<'NOTE'

판독 규칙
  - 3번에 'human'과 (의도한) bbot 'main-session(hb추정)' 말고 다른 줄이 보이면 원인을 찾을 것.
  - 'main-session(hb추정)'은 session_key 모양 추론일 뿐이다. hook·CLI·API·cron도 main
    세션 키로 돌 수 있으므로, 확정하려면 그 run_id를 5번 cron receipt와 대조하라.
  - 의도된 예외 1건: bbot 30m heartbeat. typing은 모델 호출 *전에* 시작되므로
    (heartbeat-runner:1501) 실턴이 없어도 bbot 방에는 주기적 typing이 남는다.
  - 텔레그램 typing 경로는 heartbeat만이 아니다. 인바운드 일반 메시지도 모델 실행 전에
    typing을 보낸다 (bot-message-DLpp_4_3.js:1226-30). 사람이 말을 건 직후의 typing은
    정상이다 — heartbeat 탓으로 돌리지 마라.
NOTE
