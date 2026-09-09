# OpenClaw 자동화 SSOT — 봇별 크론/heartbeat 현황

> **이 문서가 SSOT다.** "사람이 말을 걸지 않아도 도는 것"의 전량을 봇별로 적는다.
> 라이브와 어긋나면 라이브가 옳고 이 문서가 틀린 것이다 — 발견 즉시 고쳐라.
>
> **동기화 방법 (한 줄)**: `./run.sh` → `w)` 또는 `./scripts/turnwatch.sh`
> 그 출력의 §1·§1b가 이 문서의 표와 같아야 한다. 다르면 이 문서를 갱신한다.

기준 시각: **2026-09-09 14:4x KST** · OpenClaw **2026.8.2** (0965053)

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
| **glg** (힣, 가족봇) | `anthropic/claude-sonnet-5` | **없음** | 가족 알림 3건 (아래) | 예 — 아침 알림 |
| **gpt** | `openai/gpt-5.6-sol` | **없음** | 없음 | **아니오** |
| **gemini** | `github-copilot/gemini-3.7-flash` | **없음** (원래 없었음) | 없음 | **아니오** |
| **mini** | `anthropic/claude-sonnet-5` | **없음** | 없음 (disabled 1건) | **아니오** |
| **bbot** (B) | `anthropic/claude-fable-5-1` | **3h** (`accountId: bbot`) | 없음 | 예 — 의도된 루프 |

`agents.defaults.heartbeat = {every:"1h"}`는 남아 있지만 **아무에게도 적용되지 않는다.**
`heartbeat-config-*.js`(`resolveHeartbeatConfig`) — 엔트리에 `heartbeat`를 명시한 봇만 등록된다.
지금은 bbot 하나. 8.2도 동일(재확인 2026-09-02). 이미지도 같은 말을 한다 — *"Multi-agent config has
no ambient heartbeat owner; heartbeats stay disabled until `agents.defaults.heartbeat.agentId` or
`agents.defaults.systemAgent.agentId` is set"* 이고 우리는 둘 다 unset이다.

> ⚠️ **`agents.defaults.heartbeat.target: "none"`을 걸지 마라 — bbot을 죽인다.**
> `target`은 배달처 스위치(`owner`(기본) / `last` / `none`)이고, defaults에 걸면 **지금 유일하게
> 살아 있는 bbot 배달까지 함께 막는다.** 소음을 막을 일이 생기면 `agents.entries.<id>.heartbeat.target`
> 으로 그 봇만 걸어라. cron 발송은 이 스위치와 무관하다(잡이 자기 `delivery.to`를 따로 든다).
> 상세는 [openclaw-gotchas.md](openclaw-gotchas.md) "`heartbeat.target` — `none`을 defaults에 걸지 마라".

### main·glg·gpt·mini heartbeat를 왜 없앴나 (2026-09-01)

모델 턴을 **0회** 돌면서 (실행 receipt 6~19ms) 매시간 다음 둘만 만들고 있었다:
- 텔레그램 owner DM에 typing 표시 1회 — 8.1이 새로 넣은 동작 (§함정)
- `task_runs`에 `automation_run` 행 1개 — `tasks list`를 도배

`agent:<id>:main` 세션이 있는 봇만 heartbeat가 실턴이 된다. 그 세션을 가진 건 bbot뿐이다.
되돌리려면: `openclaw config set agents.entries.main.heartbeat '{"every":"1h"}'`

**이건 고장이 아니라 GLG의 의도다** (확인 2026-09-02). 네 봇은 **검수 목적으로 일부러 꺼둔 상태**이고
검수가 끝나면 다시 켠다. 반대로 **bbot 배달은 지금 살아 있어야 하는 라이브 기능**이다 — 위 경고 상자대로
defaults 레벨 억제는 그걸 죽이므로 금지. "왜 네 봇이 조용하지"를 다시 조사하지 마라, 답은 여기다.

### main typing 억제 — 원인 미확정 상태의 운영 가드 (2026-09-01)

`agents.entries.main.typingMode = "never"`를 설정하고 hot reload를 확인했다. 이는 main의
사용자 가시 typing을 우선 끄는 **가드**이며, 원인 확정은 아니다. active-memory를 끈 뒤
잠시 사라졌던 typing이 다시 관측되어, `active-memory → 죽은 codex 런타임 → typing` 인과는
현재 증명되지 않았다. 8.1 soak 동안 재발 시각과 `audit_events`의 main run을 함께 기록한다.

### bbot 3h — 의도된 예외 (2026-09-09에 30m에서 늘림)

GLG가 일부러 유지한 루프다. `claude-fable-5-1` 실턴이 돈다. 그 턴이 Claude 구독을 쓰고
`agent:bbot:main` 세션이 계속 자라므로 (2026-09-01 30m 시절 76k/200k)
**2026-09-09에 `30m` → `3h`로 늘렸다** — 하루 48턴 → 8턴.
**bbot 방에는 3시간마다 typing이 뜬다 — 이건 정상이다.** 30분마다 안 뜬다고 고장으로 재조사하지 마라.

**"매번 sentinel만 반환한다"는 이제 사실이 아니다.** 8/30까지 `HEARTBEAT_OK`, 8.1 이후
`NO_REPLY` 를 돌려주던 것은 맞지만, 그건 **깨움 문장이 판단보다 먼저 닫았기 때문**이지
하트비트가 그런 물건이어서가 아니었다. 2026-09-09 에 B 가 cron scratch 로 판단 순서를
넣자 같은 하트비트가 도구를 쓰고 커밋을 떨어뜨리고 배달까지 했다(아래 §scratch).

#### cadence 는 config 에서만 바꾼다 — cron 잡을 고치지 마라

```bash
# ⚠️ 하위 경로로 바꿔라. 객체 통째로 set 하면 accountId 같은 형제 키가 함께 날아간다.
openclaw config set agents.entries.bbot.heartbeat.every '"3h"'

# 객체째로 줘야 한다면 --merge 를 반드시 붙인다 (기본이 replace 다)
openclaw config set agents.entries.bbot.heartbeat '{"every":"3h"}' --merge
```

`config set --help` 가 말한다: `--merge  Merge object/map values instead of replacing
the target path (default: false)`. **기본이 교체다.** 이 문서의 이전 판이 `--merge` 없이
객체를 통째로 주는 명령을 실었는데, 그대로 실행하면 `accountId: "bbot"` 이 조용히 사라져
하트비트가 다시 main 봇 방으로 간다(교차검수 gpt-5.6-terra, 2026-09-09).

`cron list` 의 `heartbeat-bbot` 은 config 의 **투영**이다. `resolveHeartbeatMonitorPlan`
(`src/cron/heartbeat-monitor.ts`)이 config 에서 `everyMs` 를 재계산해 다르면 `kind:"update"`
로 덮으므로, `cron edit` 으로 박은 값은 다음 reconcile 에서 되돌아간다(애초에 system-owned
라 거부된다 — 아래 §함정).

restart 는 필요 없다: 설정 hot reload 가 `reconcileHeartbeatJobs` → `heartbeatRunner.updateConfig`
를 차례로 부르고, `updateConfig` 가 `cooldownUntilMs = lastRunStartedAtMs + 새 interval` 로
다시 잡아 **여분의 턴이 즉시 튀지 않는다**. 단 `anchorMs` 는
`sha256(schedulerSeed:agentId) % intervalMs` 라 **interval 이 위상 입력**이므로 위상이 옮겨간다.

실측(2026-09-09): 12:03 로그 `config hot reload applied (agents.entries.bbot.heartbeat.every)`,
`cron list` → `everyMs 10800000`, `anchorMs` 702682 → 6102682. **다음 예정 시각 14:41 에 정시
발화**했다 — hot reload 가 스케줄에 반영됐다는 증거는 이 정시 발화이지, 그 사이 수동 실행
(`runId=manual`)이 아니다.

#### 하트비트 배달은 cron 잡의 delivery 와 무관하다

`cron list` 의 `heartbeat-bbot` 은 `deliveryStatus: not-requested` 인데도 **배달된다.**
그 필드는 cron 잡 자신의 배달 설정이고, 하트비트 산출은 **러너가 자기 경로로** 내보낸다
(`src/infra/heartbeat-runner-delivery.ts`). 둘을 같은 것으로 읽으면 "배달 경로가 없다" 는
잘못된 결론이 나온다.

배달 대상은 `resolveHeartbeatDeliveryTarget` (`src/infra/targets.ts`) 이 정한다:

```text
heartbeat.target 이 undefined  → "owner" (GLG DM). 명시가 없으면 이쪽이다.
계정 해석 순서                  → heartbeat.accountId
                                → (세션 채널이 같을 때) 그 세션의 accountId
                                → 채널 기본 계정
```

**`agent:bbot:main` 세션에는 채널이 없다.** 그래서 명시가 없던 2026-09-09 12:07 에는 채널
기본 계정(`default` = main 봇)으로 떨어져, B 의 하트비트가 **main 봇 방으로 갔다**. `accountId`
를 박아 고쳤다 — 14:41 비트 실측: 로그 `[heartbeat] using explicit accountId` →
`outbound send ok accountId=bbot messageId=2775`, GLG 화면에 `@glg_b_bot` 으로 도착.

⚠️ 첫 배달에는 upstream 안내문이 한 번 붙는다 —
*"Set agents.defaults.heartbeat.target: \"none\" to keep these internal."*
**따르지 마라.** defaults 에 걸면 유일하게 살아 있는 bbot 배달까지 죽는다(§함정, gotchas).

#### scratch — 하트비트의 계약면

깨움 문장은 `HEARTBEAT.md` 가 아니라 **cron scratch** 다.

```bash
openclaw cron scratch <jobId>                          # 현재 내용 읽기
openclaw cron scratch <jobId> --file <path>            # 교체
```

2026-09-09 실측: scratch 를 넣은 뒤 프롬프트가 885자(rev1) → 1218자(rev2, 임시 단락 포함)로
늘었고, 그 비트 안에서 B 가 커밋을 떨어뜨렸다(`5ac4c09`, `2d3dc9e`).

**손을 썼는지의 지표는 트랜스크립트가 아니라 비트 시각 안의 커밋이다.** 이 런타임의
OpenClaw 트랜스크립트는 message 행만 남기고 tool 이벤트를 적지 않으므로, "도구 사용 0회"
는 측정이 아니라 형식 산물이다(B 가 자기 주장을 이 근거로 은퇴시켰다, 2026-09-09).

---

## 활성 cron (enabled)

| 이름 | 봇 | 스케줄 | 대상 | 모델 |
|---|---|---|---|---|
| `heartbeat-bbot` | bbot | every 3h | 자기 main 세션 (배달은 `accountId: bbot`) | (defaults) |
| `morning-family-schedule-reminder` | glg | `0 23 * * *` UTC = **08:00 KST** | GLG DM | `anthropic/claude-sonnet-5` |
| `baron-kindergarten-dropoff-2026-09-02` | glg | 1회성 2026-09-01 23:00Z | GLG DM | `anthropic/claude-sonnet-5` |

## 비활성 cron (disabled — 목록에서 지우지 말 것)

| 이름 | 봇 | 왜 꺼졌나 |
|---|---|---|
| `morning-family-schedule-reminder-wife` | glg | GLG 지시로 정지 (2026-09-01). model은 sonnet-5로 고쳐둠 — 켜면 바로 돈다 |
| `daily_real_estate_auction_study_brief_*` | mini | 이전부터 off. ⚠️ **model 미지정** — 켜기 전에 model을 박아야 한다 |
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
