# OpenClaw 자동화 SSOT — 봇별 크론/heartbeat 현황

> **이 문서가 SSOT다.** "사람이 말을 걸지 않아도 도는 것"의 전량을 봇별로 적는다.
> 라이브와 어긋나면 라이브가 옳고 이 문서가 틀린 것이다 — 발견 즉시 고쳐라.
>
> **동기화 방법 (한 줄)**: `./run.sh` → `w)` 또는 `./scripts/turnwatch.sh`
> 그 출력의 §1·§1b가 이 문서의 표와 같아야 한다. 다르면 이 문서를 갱신한다.

기준 시각: **2026-09-10 07:5x KST** · OpenClaw **2026.8.2** (0965053)

관련: [ORACLE.md](../ORACLE.md) (운영 핸드북) · [openclaw-gotchas.md](openclaw-gotchas.md) (함정) · [NEXT.md](../NEXT.md) (후속)

---

## 원칙 — 어설프게 도는 턴은 용납하지 않는다

1. **입구는 이 문서에 적힌 것이 전부여야 한다.** 여기 없는데 도는 게 있으면 사고다.
2. **턴이 없는데 신호만 내는 것도 사고다.** typing 표시, task 레코드, 세션 성장 전부 포함.
   (2026-09-01 실사: heartbeat 4개가 모델 턴 0회로 매시간 typing과 task 행만 만들고 있었다.)
3. **cron `agentTurn`은 model을 반드시 명시한다.** 8.1 회귀 때문이다 — 아래 §함정.

---

## 봇별 현황

| 봇 | 모델 | heartbeat | 소유 cron | 사람 없이 도는가 |
|---|---|---|---|---|
| **main** (default) | `anthropic/claude-opus-5` | **없음** | 없음 | **아니오** (`typingMode=never`, 9/1 관찰 중) |
| **glg** (힣, 가족봇) | `anthropic/claude-sonnet-5` | **없음** | 가족 알림 3건 (1 enabled, 2 disabled) | 예 — 아침 알림 |
| **gpt** | `openai/gpt-5.6-sol` | **없음** | 없음 | **아니오** |
| **gemini** | `github-copilot/gemini-3.7-flash` | **없음** (원래 없었음) | 없음 | **아니오** |
| **mini** | `anthropic/claude-sonnet-5` | **없음** | 없음 (disabled 1건) | **아니오** |
| **bbot** (B) | `anthropic/claude-opus-5` | **꺼짐** (`{every:"0m"}`) | `bbot-memento-autopilot` 3h | 예 — fresh memento loop |

`agents.defaults.heartbeat = {every:"1h"}`는 남아 있다. bbot은 반드시 엔트리에
`{"every":"0m"}`를 **명시**해 상속을 막는다. 이를 `unset`하면 defaults cadence가 다시 물려
**6봇 전원**의 활성 heartbeat monitor가 재생성된다(2026-09-10 07:29에는 bbot 1건만 재현;
6봇 팬아웃은 `resolveHeartbeatAgents` 분기 판독). 현재 heartbeat monitor는 bbot의 retained disabled row 하나뿐이다.

> ⚠️ memento의 배달은 heartbeat `target`이 아니라 cron의 명시 `delivery`(`telegram` /
> `123861330` / `accountId:"bbot"`)가 담당한다. memento를 조절하려고 `agents.defaults.heartbeat.target`
> 을 건드리지 마라.

### main·glg·gpt·mini heartbeat를 왜 없앴나 (2026-09-01)

모델 턴을 **0회** 돌면서 (실행 receipt 6~19ms) 매시간 다음 둘만 만들고 있었다:
- 텔레그램 owner DM에 typing 표시 1회 — 8.1이 새로 넣은 동작 (§함정)
- `task_runs`에 `automation_run` 행 1개 — `tasks list`를 도배

`agent:<id>:main` 세션이 있는 봇만 heartbeat가 실턴이 된다. 그 세션을 가진 건 bbot뿐이다.
되돌리려면: `openclaw config set agents.entries.main.heartbeat '{"every":"1h"}'`

**이건 고장이 아니라 GLG의 의도다** (확인 2026-09-02). 네 봇은 **검수 목적으로 일부러 꺼둔 상태**이고
검수가 끝나면 다시 켠다. bbot의 사람에게 닿는 루프는 이제 heartbeat가 아니라 아래의 isolated memento cron이다.
"왜 네 봇이 조용하지"를 다시 조사하지 마라, 답은 여기다.

### main typing 억제 — 원인 미확정 상태의 운영 가드 (2026-09-01)

`agents.entries.main.typingMode = "never"`를 설정하고 hot reload를 확인했다. 이는 main의
사용자 가시 typing을 우선 끄는 **가드**이며, 원인 확정은 아니다. active-memory를 끈 뒤
잠시 사라졌던 typing이 다시 관측되어, `active-memory → 죽은 codex 런타임 → typing` 인과는
현재 증명되지 않았다. 8.1 soak 동안 재발 시각과 `audit_events`의 main run을 함께 기록한다.

### bbot 3h — 메멘토 autopilot (2026-09-10)

GLG 결정: autopilot은 누적 main heartbeat가 아니라 **매 비트 fresh isolated session**이다.
`bbot-memento-autopilot` (`declarationKey: autopilot:bbot-memento`)은 `agentTurn`이며
`--model anthropic/claude-opus-5`, explicit Telegram `accountId:"bbot"` delivery를 갖는다.
첫 **강제** run은 fresh session key `agent:bbot:cron:<job>:run:<id>`, 113,123ms,
`deliveryStatus: delivered`로 확인했다. 이 기록은 scheduled 발화 증거가 아니다 — 첫 scheduled 시각은
2026-09-10 10:26:59 KST다.

깨움 계약은 B 소유 `workspace-bbot/scripts/heartbeat-wake-message.md`에서 job `message`로 **스냅샷**된다.
B 파일을 고친 뒤에는 설정 담당자가 그 내용을 `cron edit <job-id> --message ...`로 재동기화한다.
일반 cron scratch는 저장만 될 뿐 agentTurn prompt에는 주입되지 않고, heartbeat scratch만
`heartbeat-runner-prompt`가 읽는다. B 파일은 B만 고친다. 현재 job은 operator-created
`toolsAllow:["*"]` / `scheduledToolPolicy:"trusted"`다; 이 권한 범위는 GLG의 별도 정책 결정 전까지 넓히지 않는다.

#### cadence·배달은 cron job이 소유한다

```bash
openclaw cron edit e94ed49d-847e-4c1e-b127-c914171d5c5b --every 3h
openclaw cron enable e94ed49d-847e-4c1e-b127-c914171d5c5b
```

이 job은 일반 operator-owned cron이다. delivery·model·schedule 변경은 job을 읽고 `cron edit`으로
처리한다. `agents.entries.bbot.heartbeat`는 `{ "every": "0m" }`를 유지한다 — `unset`은
`agents.defaults.heartbeat`를 다시 상속해 6봇의 main-session heartbeat를 되살린다.

---

## 활성 cron (enabled)

| 이름 | 봇 | 스케줄 | 대상 | 모델 |
|---|---|---|---|---|
| `bbot-memento-autopilot` | bbot | every 3h | GLG DM (`telegram:123861330`, `accountId:bbot`) | `anthropic/claude-opus-5` |
| `morning-family-schedule-reminder` | glg | `0 23 * * *` UTC = **08:00 KST** | GLG DM | `anthropic/claude-sonnet-5` |


## 비활성 cron (disabled — 목록에서 지우지 말 것)

| 이름 | 봇 | 왜 꺼졌나 |
|---|---|---|
| `morning-family-schedule-reminder-wife` | glg | GLG 지시로 정지 (2026-09-01). model은 sonnet-5로 고쳐둠 — 켜면 바로 돈다 |
| `daily_real_estate_auction_study_brief_miir` | glg | 이전부터 off. ⚠️ **model 미지정** — 켜기 전에 model을 박아야 한다 |
| `SK브로드밴드 인터넷 이사 신청 리마인더` | glg | 2026-09-07 one-shot이 disabled로 보존됨. **model 미지정** |
| `heartbeat-bbot` | bbot | system-owned retained disabled row (`everyMs:3600000`); bbot `{every:"0m"}`의 정상 투영. 편집/삭제 금지 |
| `skill-collection-review-{main,glg,gpt,gemini,mini,bbot}` | 6봇 각 1개 | 8.1이 심은 자율 스킬 검토 자동화. `skills.workshop.autonomous.mode=off`가 누르고 있다 |

---

## 자율 스위치 — 스스로 학습/기억/생성하는 기능

| 스위치 | 값 | 비고 |
|---|---|---|
| `skills.workshop.autonomous.mode` | `off` | 켜면 `skill-collection-review` 6개가 살아난다 |
| `plugins.entries.memory-core.config.dreaming.enabled` | `false` | |
| `plugins.entries.active-memory.enabled` | **`false`** | 2026-09-01 typing 조사 중 비활성; 원인 인과는 미확정 |
| `hooks.internal` | `enabled` (`boot-md`, `session-memory`) | 턴을 스스로 만들진 않지만 인벤토리에 포함 |
| `plugins.entries.codex.enabled` | `false` | 2026-08-07 GLG 결정 |
| `acp.enabled` / `plugins` acpx | `false` / disabled | acpx는 `plugins.allow` 화이트리스트에서 빠져 막혀 있다 |

호스트 쪽 자율 트리거는 0이다 — root crontab 없음, openclaw 관련 systemd timer 없음
(2026-09-01 교차검수에서 확인).

---

## 함정 — 8.1이 cron에서 런타임 오버라이드를 잃는다

**cron 회귀는 확정, active-memory와의 같은 뿌리는 가설이다.**

`agents.defaults.models["openai/gpt-5.6-terra"].agentRuntime.id = "openclaw"` 오버라이드를
**일반 에이전트 세션은 적용하고 cron 경로는 잃는다.** 잃으면 openai 모델의 카탈로그 기본
런타임 `codex`로 떨어지고, codex는 disabled라 하드 실패한다. active-memory도 같은 모델 정책
해상도 경로를 탈 가능성은 있으나, 아직 실행 표본이 없어 확정하지 않는다.

- **cron**: 가족 알림 2건이 2026-09-01 아침에 죽었다.
  `Agent harness runtime "codex" is unavailable...`
  회귀 증거: `task_runs`에서 8/28·29·30·31 succeeded → 9/1 첫 실패.
  대조군: gpt 봇 일반 세션은 `gpt-5.6-sol / OpenClaw Default`로 정상.
- **active-memory** (모델 `openai/gpt-5.6-luna`): 8.1 이후 실행 0건이다. 비활성화와
  typing 소실이 한 차례 함께 관측됐지만 뒤에 typing이 재관측됐다. 원인으로 기록하지 않고
  비활성 상태에서 soak한다.

**대응**: cron `agentTurn`에는 `--model anthropic/claude-sonnet-5`처럼 **model을 명시**한다.
`agents.defaults.model.primary`를 바꾸는 건 권하지 않는다 — blast radius가 넓고 회귀 원인을 숨긴다.

```bash
docker exec openclaw-gateway openclaw cron edit <job-id> --model anthropic/claude-sonnet-5
```

⚠️ heartbeat 잡은 system-owned라 `cron disable`이 거부된다
(`system-owned monitor jobs cannot be edited by cron clients`). config에서 빼야 한다.

---

## 점검 절차

```bash
./scripts/turnwatch.sh          # 최근 24h
./scripts/turnwatch.sh 168      # 최근 7일
```

판정: turnwatch §3 "턴 원장"에 `human`과 bbot `main-session(hb추정)` 말고 다른 줄이 보이면
원인을 찾는다. 단 그 분류는 session_key 모양 추론이므로, 확정하려면 run_id를 §5 cron receipt와
대조해야 한다.

**텔레그램 typing을 heartbeat 탓으로 단정하지 마라.** 인바운드 일반 메시지도 모델 실행 전에
typing을 보낸다(`bot-message-DLpp_4_3.js:1226-30`). 사람이 말을 건 직후의 typing은 정상이다.
