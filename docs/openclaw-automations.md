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

## Utility 보조 호출 — 운영자에게 알려진 목적만

**현재 선택(2026-10-11, 운영9.8):** `agents.defaults.utilityModel = "openai/gpt-6-luna"`.
6봇 모두 상속하며 per-agent utility override는 없다. Luna만 모델별 런타임을
`openclaw`로 명시했다. Codex 활성화·주 대화 모델/allowlist 변경·새 cron/heartbeat 추가는 없다.
GLG 원칙은 **모르게 호출하지 않는다: 목적·발동 조건·선택 모델을 기록하고 새 용도는 먼저 논의**다.
이 문서는 운영 승인 경계이며, `utilityModel` 설정 자체가 목적별 강제 ACL은 아니다.

### 알려진 소비자와 발동 조건

아래는 9.8 소스에서 읽은 소비자 목록이다. **전부 실사용됐다는 측정이 아니며**, 각 기능의
기존 요청/콜백/가시성 조건이 맞을 때 보조 호출이 가능하다는 뜻이다. 이번 변경에서 기능별
새 옵션을 켜지는 않았다. utility가 존재하는지를 가용성 gate로 쓰는 소비자는 명시 모델의
영향을 받으므로, 실제 호출 수가 이전과 같다고 보장하지 않는다.

| 목적 | 호출이 가능한 조건 | 대체 경로·주의 |
|---|---|---|
| 대화/토픽 제목·레이블 | 새 대화/토픽의 이름 생성, Control UI의 제목 준비 요청 | 일반 제목 생성은 실패 시 primary를 시도할 수 있다. `sessions.title.prepare`는 utility-only이며 세션을 생성/변경하지 않는다 |
| 진행 설명 | 채널이 narration 콜백을 제공하고 해당 턴의 utility 사용이 허용될 때 | 본 답변과 별도 호출. `progress-narrator.ts`의 명시 조건을 따른다 |
| 라이브 세션 관찰·요약 | Control UI의 가시 구독/관찰 대상 작업에서 observer가 요약을 요청할 때 | 독립 cron이 아닌 관찰 기능; 매 메시지마다 무조건 실행된다고 읽지 않는다 |
| Activity recap | 권한 있는 클라이언트의 `sessions.activitySummary.ensure` 요청 | 보통 목록 조회만으로는 생성하지 않는다. 실패 시 이전 요약 유지, primary fallback 없음 |
| Companion 옆 질문 | 클라이언트가 세션 옆 질문을 요청할 때 | utility 선택은 요청 모델/사용자 모델 정책 영향을 받으며 primary 경로를 쓸 수 있다. 읽기 도구를 쓰는 별도 질의이지 항상 tool-free는 아니다 |
| 녹취 요약 보강 | transcript capture의 요약 경로에 config와 발화가 제공될 때 | utility 다음 primary를 시도할 수 있고, 모델 실패 시 결정적 요약으로 복귀 |

제품 세부 규칙: [9.8 Models 문서](https://github.com/openclaw/openclaw/blob/v2026.9.8/docs/concepts/models.md),
`src/auto-reply/reply/{conversation-label-generator,progress-narrator}.ts`,
`src/gateway/{session-observer,session-activity-summaries,session-companion-policy}.ts`,
`src/transcripts/{capture-summary,summary-model}.ts`(모두 라이브와 같은 `fc23bc8`).

### 인증·검증·차단 경계

- 새 API key를 추가하지 않았다. 현재 OpenAI config의 인증 mode는 OAuth이고,
  제목 준비 실응답은 `provider=openai`, `api=openclaw-openai-chatgpt-responses-transport`,
  `model=gpt-6-luna`, HTTP200으로 관측했다. 이 측정은 ChatGPT 구독 transport이며 실제 청구서를 검사한 것은 아니다.
- 운영자가 알고 실행한 검증: `sessions.title.prepare` 1회, 비개인 테스트 문장으로
  `유틸리티 설정 검증` 반환. primary fallback 없는 호출이고 기존 대화/토픽을 수정하지 않았다.
  재기동 뒤 6개 Telegram 계정 `running/connected`, Gateway healthy, cron 12개/활성2개를 확인했다.
- 이전168h의 Haiku 직접 API15건은 별도 과거 증거다. 당시 key/OAuth 종류·실청구와
  정확한 소비자별 목적은 미확인이다. 토큰 삭제/재인증을 실행한 것이 아니며 해결됐다고 덮지 않는다.
- **미설정은 자동 모델 선택**이다. 다시 unset해서 Haiku 자동 기본값을 되살리지 않는다.
  `utilityModel: ""`도 보조 호출 전체 금지가 아니라 작은 모델 routing off다.
  제목/녹취 요약의 primary fallback까지 막으려면 기능별 차단 방법을 따로 결정해야 한다.
- 모델/API/status 로그만으로 모든 개별 목적을 확정하지 않는다. 새 소비자나 미설명 호출을
  발견하면 목적·trigger·입력 범위·모델/인증 경로를 확인하고 이 목록을 갱신한 뒤 사용한다.

---

## 봇별 현황

| 봇 | 모델 | heartbeat | 소유 cron | 사람 없이 도는가 |
|---|---|---|---|---|
| **main** (default) | `openai/gpt-6.1-sol` | **없음** | 없음 | **아니오** (typing 기본값 복귀 2026-10-03) |
| **glg** (힣, 가족봇) | `anthropic/claude-sonnet-5` | **없음** | 가족 알림 3건 (1 enabled, 2 disabled) | 예 — 아침 알림 |
| **gpt** | `openai/gpt-6.1-sol` | **없음** | 없음 | **아니오** |
| **gemini** | `zai/glm-5.3` | **없음** (원래 없었음) | 없음 | **아니오** |
| **mini** | `anthropic/claude-sonnet-5` | **없음** | 없음 (disabled 1건) | **아니오** |
| **bbot** (B) | `anthropic/claude-fable-5-1` | **꺼짐** (`{every:"0m"}`) | `bbot-memento-autopilot` 3h | 예 — fresh memento loop |

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
`--model anthropic/claude-fable-5-1`, `--thinking xhigh`, explicit Telegram `accountId:"bbot"` delivery를 갖는다. **cron의 모델 런타임은 defaults 카탈로그만으로 충분하지 않다.** bbot의 `models["anthropic/claude-fable-5-1"].agentRuntime.id="claude-cli"`도 명시한다.

2026-09-19의 격리 probe는 Claude CLI 서빙을 통과했지만, bbot 전용 카탈로그 엔트리가 없던 첫 scheduled run(10:26)은 API `anthropic` provider로 풀려 `missing-provider-auth`로 996ms 만에 실패했다. 해당 엔트리를 추가한 뒤 manual catch-up은 `claude-cli` / fable-5-1로 572,900ms 성공·Telegram delivered를 확인했다. 다음 **정기** fable run은 13:26 KST다.

첫 **강제** run은 fresh session key `agent:bbot:cron:<job>:run:<id>`, 113,123ms,
`deliveryStatus: delivered`로 확인했다. 이 기록은 scheduled 발화 증거가 아니다 — 첫 scheduled 시각은
2026-09-10 10:26:59 KST다.

깨움 계약은 B 소유 `workspace-bbot/scripts/heartbeat-wake-message.md`에서 job `message`로 **스냅샷**된다.
B 파일을 고친 뒤에는 설정 담당자가 그 내용을 `cron edit <job-id> --message ...`로 재동기화한다.
일반 cron scratch는 저장만 될 뿐 agentTurn prompt에는 주입되지 않고, heartbeat scratch만
`heartbeat-runner-prompt`가 읽는다. B 파일은 B만 고친다. 현재 job은 operator-created
`toolsAllow:["*"]` / `scheduledToolPolicy:"trusted"`다. 이는 cron의 전체-tool 기본을 명시한 것이며,
GLG 결정(2026-09-10): 3시간 memento라는 **깨움 면만** 운영자가 소유하고, 벽돌을 포함한 실행 규칙은
B와 GLG가 고친다 — 여기서 강제·축소하지 않는다.

#### cadence·배달은 cron job이 소유한다

```bash
openclaw cron edit e94ed49d-847e-4c1e-b127-c914171d5c5b --every 3h
openclaw cron enable e94ed49d-847e-4c1e-b127-c914171d5c5b
```

이 job은 일반 operator-owned cron이다. delivery·model·schedule 변경은 job을 읽고 `cron edit`으로
처리한다. `agents.entries.bbot.heartbeat`는 `{ "every": "0m" }`를 유지한다 — `unset`은
`agents.defaults.heartbeat`를 다시 상속해 6봇의 main-session heartbeat를 되살린다.

**gateway restart 는 이 상태를 흔들지 않는다**(2026-09-10 실측, skill §4의 "등록이 바뀌는 변경까지
hot reload 가 덮는지 미확인" 중 restart 쪽을 닫는다). restart·recreate 전후로 cron 12건/활성 2건,
memento `nextRunAtMs`·`anchorMs`, `heartbeat-bbot` disabled, `{every:"0m"}` 가 모두 동일했고
부팅 로그도 `[heartbeat] disabled` 였다. 즉 **명시 disable 은 재기동을 건너 살아남는다.**

---

## 활성 cron (enabled)

| 이름 | 봇 | 스케줄 | 대상 | 모델 |
|---|---|---|---|---|
| `bbot-memento-autopilot` | bbot | every 3h | GLG DM (`telegram:123861330`, `accountId:bbot`) | `anthropic/claude-fable-5-1` |
| `morning-family-schedule-reminder` | glg | `0 23 * * *` UTC = **08:00 KST** | GLG DM | `anthropic/claude-sonnet-5` |


## 비활성 cron (disabled — 목록에서 지우지 말 것)

| 이름 | 봇 | 왜 꺼졌나 |
|---|---|---|
| `morning-family-schedule-reminder-wife` | glg | GLG 지시로 정지 (2026-09-01). model은 sonnet-5로 고쳐둠 — 켜면 바로 돈다 |
| `daily_real_estate_auction_study_brief_miir` | glg | 이전부터 off. ⚠️ **model 미지정** — 켜기 전에 model을 박아야 한다 |
| `SK브로드밴드 인터넷 이사 신청 리마인더` | glg | 2026-09-07 one-shot이 disabled로 보존됨. **model 미지정** |
| `heartbeat-bbot` | bbot | system-owned retained disabled row (`everyMs:3600000`); bbot `{every:"0m"}`의 정상 투영. 편집/삭제 금지 |
| `skill-collection-review-{main,glg,gpt,gemini,mini,bbot}` | 6봇 각 1개 | 8.1이 심은 자율 스킬 검토 자동화. 라이브 job은 모두 disabled 상태(2026-09-13 turnwatch 실측) |

---

## 자율 스위치 — 스스로 학습/기억/생성하는 기능

| 스위치 | 값 | 비고 |
|---|---|---|
| `skills.workshop.autonomous.mode` | `propose` | GLG가 변경·확인(2026-09-13). `skill-collection-review` 6개 job은 현재 disabled 상태 |
| `plugins.entries.memory-core.config.dreaming.enabled` | `false` | GLG: 아직 안정화된 기술이 아니다. 스위치를 끈 것으로 끝내지 않고 **4월 산출물 880청크도 회수**했다(2026-09-06, [NEXT.md](../NEXT.md) §B 실행 완료). 켜지 말 것 |
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

**대응**: cron `agentTurn`에는 `--model anthropic/claude-sonnet-5`처럼 **model을 명시**한다. claude-cli 모델은 해당 agent의 `agents.entries.<id>.models["<model>"].agentRuntime.id="claude-cli"` 등록도 확인한다 — defaults만 등록된 fable-5-1은 bbot cron에서 API provider로 잘못 해상돼 auth 실패했다(2026-09-19).
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
