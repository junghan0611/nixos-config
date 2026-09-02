# OpenClaw 운영 Gotcha 모음

`AGENTS.md`에서 분리된 현장 디버깅/incident 참고. nixos-config가 OpenClaw 담당자이므로 이 파일이 SSOT.

세 카테고리:

- **활성** — 운영 중 자주 부딪힘. 현재 deployment(5.2)에 그대로 적용.
- **비활성** — 기능 자체가 disabled. 재활성화 시 다시 참고.
- **역사** — resolved/superseded. 정책 근거를 보존하기 위해 남김.

---

## 활성

### 호스트 청소기가 **프롬프트 텍스트를 죽인다** — `acp-zombie-reaper` 은퇴 (2026-09-01)

**4월 acpx 시절 손설치한 청소기가, 보호 대상이 6월에 사라진 뒤에도 4개월 더 돌면서 남의 agent 세션을 15분마다 저격했다.** 은퇴 처리 완료(`systemctl --user disable --now acp-zombie-reaper.timer`).

**함정의 정체 — argv 부분문자열은 술어가 될 수 없다.** `~/openclaw/scripts/acp-zombie-reaper.sh` Phase 1은
`ps -eo pid,etimes,user,args`의 **한 줄 전체**에 `claude-agent-acp`가 있으면 900초 넘은 것을 SIGTERM했다.

```sh
# 이 줄이 원인이다 — $0 는 argv 전체이고, argv에는 프롬프트가 실린다
awk -v age="$AGE_SECS" '$2 > age && $0 ~ /claude-agent-acp/ && $0 !~ /awk/ { print $1 }'
```

Claude Code·copilot CLI는 **프롬프트를 argv에 통째로 싣는다.** 그래서 *이 청소기 얘기를 하는 프롬프트를 받은
평범한 세션*이 그대로 조준선에 들어온다. 실측(2026-09-01 12:10 KST): 호스트에 ACP 프로세스 **0개**인데
스크립트의 `alive_acp` 카운터는 **3**을 셌다 — 셋 다 프롬프트에 그 문자열이 박힌 CC/copilot 세션이었고,
그중 하나가 이 조사를 하던 세션 자신이었다(12:27:52 tick에 죽을 예정이었다).

**왜 8개월간 안 보였나.** 벤더 핸들러가 SIGTERM을 `dispose(); process.exit(0)`으로 흡수해서
**exit 0 / 무시그널**로 도착한다. 죽인 흔적이 정상 종료처럼 보인다.

**보호 대상은 이미 없었다** (전부 실측):

| 확인 | 결과 |
|---|---|
| upstream `openclaw/acpx` PR #245 | **CLOSED, 머지 안 됨** (`mergedAt=null`, 2026-04-21). 스크립트 주석의 "still OPEN"은 화석 |
| 이 배포의 ACP | `acp.enabled=false`, acp 쓰는 agent 0개 (2026-06-10 제거, [ORACLE.md](../ORACLE.md) §ACP 제거 완료) |
| 8.1 이미지의 acpx | **미설치**. `/app/node_modules/acpx` 부재, `.bin/acpx`·`.bin/claude-agent-acp` 둘 다 **dangling 심링크** |
| 컨테이너 프로세스 | gateway 4개뿐, acpx/claude-agent-acp 0 |

**reap 이력이 은퇴 근거다** (journal Phase 1 75건):

```
04-19~25   58건  한 tick에 3~5개씩  ← 진짜 acpx 누수기 (스크립트 mtime 04-18)
04-21             PR #245 CLOSED
06-10             ACP 제거 → 보호 대상 소멸
07-30~08-31 17건  전부 "reaping 1"  ← 전량 오폭
```

**요약줄 두 개 다 고장나 있었다.** `alive_claude`의 `grep -cE ' [c]laude($| )'`는 **앞 공백을 요구**해서
`claude --model opus`(줄 맨 앞)도 `/home/junghan/.local/bin/claude`(앞이 `/`)도 못 센다 →
매 tick `claude=0`은 관측이 아니라 고장난 계기판. `alive_acp`는 반대로 프롬프트를 세서 없는 것을 있다고 했다.

**남긴 것 / 지운 것**: 타이머만 `disable --now`. 스크립트(`~/openclaw/scripts/acp-zombie-reaper.sh`)와
유닛 파일 2개(`~/.config/systemd/user/acp-zombie-reaper.{timer,service}`)는 **화석으로 그대로 둔다** —
4월 누수기의 운영 증거다. 셋 다 nixos-config repo 밖의 **손설치**(nix store 심링크 아님)라
다른 디바이스에는 존재하지 않는다. **다시 켜지 마라.**

**교훈(재발 방지)**: 호스트 전역 청소기가 남의 프로세스를 **이름/argv**로 고르면 안 된다. 술어는 argv 바깥에
있어야 한다 — cgroup(`/proc/<pid>/cgroup`) 또는 launch env 마커(`/proc/<pid>/environ`). 컨테이너 안의
누수는 애초에 **컨테이너 안의 supervisor**가 맡을 일이다.

### 8.1 은 **cron 경로에서 모델 런타임 오버라이드를 잃는다** — 가족 cron 2건 사망 (2026-09-01)

**cron 회귀는 확정, active-memory와 같은 뿌리라는 것은 가설이다.** 8.1 컷오버 다음 날 아침에
동시에 의심됐지만, 증상 동시성은 인과가 아니다.

`agents.defaults.models["openai/gpt-5.6-terra"].agentRuntime.id = "openclaw"` 를
**일반 에이전트 세션은 적용하는데 cron 경로는 잃는다.** 잃으면 openai 모델의 카탈로그 기본
런타임 `codex` 로 떨어지고, codex 는 2026-08-07 결정으로 disabled 라 하드 실패한다.
active-memory도 같은 모델 정책 해상도를 탈 가능성은 있으나, 실행 표본 없이 확정하지 않는다.

```
Agent harness runtime "codex" is unavailable because its plugin registration is
missing from this prepared run.
```

| 증상 | 무엇이 죽었나 | 어떻게 드러났나 |
|---|---|---|
| cron | 가족 아침 알림 2건 (아내 07:00 · GLG 08:00) | 아무도 모르게 조용히 실패. 로그가 telegram poll diag 로 100% 덮여 있었다 |
| active-memory (`gpt-5.6-luna`) | 실행 0건, typing과 시간상 상관 | 비활성화 뒤 한 차례 소실됐으나 재관측되어 인과 미확정 |

**회귀 확정 근거** — `task_runs` 에서 아내 07:00 잡이 8/28·29·30·31 succeeded → 9/1 첫 failed.
**대조군** — gpt 봇 일반 세션은 같은 오버라이드가 먹혀 `gpt-5.6-sol / OpenClaw Default` 로 뜬다.
**추가 사실** — pre-8.1 백업에는 `"openai/gpt-5.6-terra": {}` 로 **runtime 매핑 자체가 없었고**
그때 cron 은 잘 돌았다. `agentRuntime: openclaw` 매핑은 8.1 컷오버 중 생겼다(`doctor --fix` 유력).
단 그 백업 mtime 이 8/27 이라 4 일 묵었다 — 단독으로 upstream 회귀를 절대 확정하진 못한다.

#### 대응

```bash
# cron agentTurn 은 model 을 반드시 명시한다
docker exec openclaw-gateway openclaw cron edit <job-id> --model anthropic/claude-sonnet-5
# active-memory 는 조사 중 껐다 (main 전용 lane 이었다)
docker exec openclaw-gateway openclaw config set plugins.entries.active-memory.enabled false
# main의 사용자 가시 typing을 우선 억제한다 (원인 판정과 별개)
docker exec openclaw-gateway openclaw config set agents.entries.main.typingMode never
```

`agents.defaults.model.primary` 를 Claude 로 바꾸는 광역 수선은 **하지 마라** — CLI/API/새 자동화까지
blast radius 가 번지고 회귀 원인을 숨긴다(교차검수 gpt-5.6-terra 동의).

#### 진단이 두 번 빗나갔다 — 그 순서가 교훈이다

1. 처음엔 typing 을 **heartbeat 탓으로 지목**했다. 8.1 이 heartbeat 에 typing 을 새로 붙인 건
   사실이지만(아래 항목), heartbeat 4 개를 지워도 typing 은 멈추지 않았다.
2. 교차검수가 **"typing 경로는 하나가 아니다"** 를 짚었다 — 인바운드 일반 메시지도 모델 실행 전에
   typing 을 보낸다(`bot-message-DLpp_4_3.js:1226-30`). 코드로 경로를 짚은 것과 그 경로가
   실제 원인이라는 것은 다르다.
3. active-memory만 끈 뒤 `typingMode`를 원복한 관측에서 한 차례 typing이 멈췄지만,
   뒤에 main typing이 재관측됐다. 따라서 그 실험은 상관을 강하게 만들었을 뿐 인과를 닫지 못했다.
4. 현재는 main `typingMode=never`로 사용자 가시 신호를 억제하고 8.1 soak에서 재발 시각과
   audit run을 함께 모은다.

**교훈**: 관측면이 없는 증상(typing 은 로그에도 audit 에도 안 남는다)은 코드 판독이나 한 번의
on/off 관측으로 단정하지 말고 **되돌릴 수 있는 변수를 하나씩 바꾸며 반복 관측**으로 좁혀라.

### 8.1 heartbeat 는 턴이 없어도 owner DM 에 typing 을 보낸다 (2026-09-01)

위 항목의 진범은 아니었지만 **사실 자체는 맞다.** 8.1 이 새로 넣었다.

- `targets-CwL8pr8V.js:301` — heartbeat 배달 대상 기본값이 **owner DM** (`target ?? "owner"`)
- `heartbeat-runner-CWkWsEqw.js:1170` — `showOk:false, showAlerts:true`
  → 메시지는 안 보내는데 `hasChatDelivery` 는 true 가 된다
- `:167` — `typingMode !== "never"` 면 typing 활성 (기본 on)
- `:1376` — keepalive 6 초. `:1501` 에서 **모델 호출 전에** 시작한다
- 텔레그램 채널 플러그인(`channel-DyARihQ8.js:1603`)은 `sendTyping` 만 있고 `clearTyping` 이 없다
  (matrix 에만 있다) → 끌 방법이 없고 5 초 뒤 알아서 꺼진다

**그래서 실턴이 0 인 heartbeat 도 typing 을 낸다.** main/glg/gpt/mini 는 `agent:<id>:main` 세션이
없어 heartbeat 가 6~19ms no-op 였는데도 매시간 typing 1 회와 `task_runs` 행 1 개를 만들고 있었다.
2026-09-01 에 네 봇의 heartbeat 를 config 에서 제거했다. bbot 30m 만 남았다(의도된 루프).

⚠️ heartbeat 잡은 **system-owned 라 `cron disable` 이 거부된다**
(`system-owned monitor jobs cannot be edited by cron clients`). config 에서 빼야 한다:
`openclaw config unset agents.entries.<id>.heartbeat`.
등록 조건은 `heartbeat-config-Z4gqDu5K.js:33` — 엔트리에 `heartbeat` 를 명시한 봇만 등록된다.

봇별 현황 SSOT 는 [openclaw-automations.md](openclaw-automations.md).

#### `heartbeat.target` — `none` 을 **defaults 에 걸지 마라** (2026-09-02, 8.2 에서 재확인)

배달처 스위치이지 on/off 스위치가 아니다. 허용값은 셋뿐이고(`targets-*.js`:
`rawTarget === "none" || rawTarget === "last" || rawTarget === "owner"`), 안 정하면 `owner` 다:

| 값 | 뜻 |
|---|---|
| `owner` | **기본값.** 소유자 DM 으로 보낸다 (`target ?? "owner"`) |
| `last` | 그 봇이 마지막으로 대화한 방으로 |
| `none` | 아무 데도 안 보낸다. **하트비트는 계속 돌고 기록도 남는다** — 입만 막는다 (`=== "none" \|\| !delivery.to) return delivery`) |

⚠️ **`agents.defaults.heartbeat.target: "none"` 은 금지다 — bbot 을 죽인다.**
지금 등록된 하트비트는 bbot 하나이고 **그 배달은 의도된 라이브 기능**이다(GLG 확인 2026-09-02).
나머지 4 봇이 조용한 건 고장이 아니라 **GLG 가 검수 목적으로 일부러 꺼둔 것**이고, 검수가 끝나면 다시 켠다.
따라서 소음을 막아야 할 일이 생기면 **defaults 가 아니라 `agents.entries.<id>.heartbeat.target`** 으로
그 봇만 걸어라. cron 발송은 이 스위치와 무관하다 — 잡이 자기 `delivery.to` 를 따로 들고 있다.

**파일명이 아니라 심볼로 찾아라.** 번들 해시는 빌드마다 바뀐다 —
같은 러너가 8.1 에선 `heartbeat-runner-BAMpymke.js`, 8.2 에선 `heartbeat-runner-jhGs3jbv.js` 다
(위 8.1 항목이 적은 `CWkWsEqw` 도 또 다른 빌드다). `target ?? "owner"` 는 8.2 에서도 그대로다.

#### 미해명 — main 은 잡이 없는데 main 계정으로 알림이 나갔다 (2026-09-02)

2026-09-02 10:47:58, `outbound send ok accountId=default` 로 소유자 DM 에 하트비트 알림이 갔다
(`@junghan_openclaw_bot` = main). **그런데 main 에는 하트비트 잡이 없다** — `cron list --all` 에
`heartbeat:bbot` 하나뿐이고, 이미지에도 이런 문장이 있다:

> Multi-agent config has no ambient heartbeat owner; heartbeats stay disabled until
> `agents.defaults.heartbeat.agentId` or `agents.defaults.systemAgent.agentId` is set.

우리는 둘 다 unset 이다(실측). 즉 **defaults 하트비트는 비활성이어야 하는데 알림은 나갔다.**

- **방아쇠는 확인됐다**: 격리 프로브 턴(`agent:main:warm-*`)이 워크스페이스 grep 을 띄웠고, 턴이
  끝나며 그 grep 이 SIGTERM 됐다. 러너의 `resolveHeartbeatTerminalToolFailure` 경로가 그걸
  "봐야 할 일" 로 분류했다. 봇 스스로는 메시지에 **"정상 종료"** 라고 썼다 — 알림이 스스로 문제
  아님을 말한 셈이다.
- **8.2 회귀가 아니다**: `First heartbeat alert` 문자열과 `resolveHeartbeatTerminalToolFailure` 는
  8.1 이미지에도 똑같이 있다(각각 2 파일 / 3 파일). 경로는 원래 있었고 오늘 처음 조건이 맞았다.
- **잡 없이 어떻게 배달됐는지는 못 밝혔다.** 추정으로 메우지 않는다. 재발하면 그때가 단서다 —
  발생 시각·어느 계정·직전 턴의 도구 종료 상태를 함께 남길 것.

### bump 가 "한 줄"인지 "마이그레이션"인지는 **릴리즈 노트로 판정하지 마라 — 이미지를 열어라** (2026-09-02)

바로 아래 8.1 항목의 반대 사례가 하루 만에 왔다. **8.1→8.2 는 진짜로 한 줄 bump 였고, 정지→기동 15 초에
끝났다.** 두 경우를 가른 것은 노트가 아니라 **이미지 안의 세 상수**다.

8.1 노트도 읽을 땐 "핀 교체 + recreate" 로 보였다(그래서 8/31 19:14 부팅이 거부됐다). 8.2 노트의
`breaking` 0 건 역시 그 자체로는 근거가 못 된다. **올리기 전에 이미지를 받아 라이브와 대조하라** —
컨테이너를 안 건드리고 3 분이면 끝난다.

```bash
# ① state 마이그레이션 ID 목록 + agent DB 스키마 상수 + npm (신규 이미지)
docker pull ghcr.io/openclaw/openclaw:<새버전>
docker run --rm --entrypoint sh ghcr.io/openclaw/openclaw:<새버전> -c '
  cat /app/dist/state-migrations.doctor-*.js | grep -o -E "\"[a-z0-9-]+-v[0-9]+\"" | sort -u
  grep -o -E "OPENCLAW_AGENT_SCHEMA_VERSION = [0-9]+|targetVersion = [0-9]+" /app/dist/openclaw-agent-db-*.js | sort -u
  npm --version'
# ② 라이브(현행)에서 같은 것을 뽑아 diff
docker exec openclaw-gateway sh -c '<위와 동일>'

# ③ 라이브 config 를 새 이미지로 격리 파싱 — retired key 를 미리 잡는다
TMP=$(mktemp -d); mkdir -p $TMP/.openclaw
cp ~/openclaw/config/openclaw.json $TMP/.openclaw/openclaw.json
docker run --rm --network none -u "$(id -u):$(id -g)" -v $TMP:/tmp/oc -e HOME=/tmp/oc \
  --entrypoint sh ghcr.io/openclaw/openclaw:<새버전> -c '
    node /app/openclaw.mjs config get tools.sessions.visibility
    node /app/openclaw.mjs config validate'
```

**판정**: ①의 마이그레이션 ID 목록과 스키마 상수가 **동일** + ③이 `Config valid` + retired key 0 ⇒
**한 줄 bump.** 하나라도 다르면 아래 8.1 절차(정지 → 오프라인 마이그레이션 → 직렬 doctor)로 간다.

실측 8.1 vs 8.2 — ID 15 개 완전 동일(최대 `conversation-binding-targets-v15`),
`OPENCLAW_AGENT_SCHEMA_VERSION` 19=19, `targetVersion` 19(+16 레거시 수리) 동일, `npm` 12.0.2 동일,
config `Config valid`. 예측대로 **부팅 로그 마이그레이션/repair/error 0 줄, config 편집 0 건.**

⚠️ **③ 의 초록을 의심하라.** 1 차 시도에서 `OPENCLAW_CONFIG` env 로 경로를 주려다 모든 키가
`Config path is valid but unset` 으로 나왔다 — CLI 는 `$HOME/.openclaw/openclaw.json` 만 본다. 그대로
믿었으면 "우리 config 는 8.2 에서 문제없다" 를 **아무 파일도 안 읽고** 선언할 뻔했다. 반드시 **우리가 아는
값**(`tools.sessions.visibility` 등)이 되읽히는지부터 확인하고 나서 `validate` 결과를 판정으로 써라.

**규모 대조도 같은 방향을 가리켰다** — 7.1-2→8.1: 27 일 · 19,750 커밋 · Changes 149/Fixes 349 · breaking 2.
8.1→8.2: 1.5 일 · 794 커밋 · Changes 12/Fixes 92 · breaking 0. **Fixes:Changes 비**가 2.3:1 → 7.7:1 로
뒤집힌 게 "기능 릴리즈 vs 수정 릴리즈" 의 지표다. 단 이건 방증일 뿐, 판정은 위 세 상수가 한다.

### 7.1 → 8.1 은 버전 bump 가 아니라 **순서 있는 마이그레이션**이다 — 조용한 실패 11겹 (2026-08-31)

**어려웠던 진짜 이유는 각 단계가 어려워서가 아니라, 실패가 전부 "정상"처럼 보였기 때문이다.**
컨테이너 `healthy`, 텔레그램 `6/6 connected + works` 가 찍히는 동안 봇은 답을 못 하거나, 정체성 없이
답하거나, 엉뚱한 에이전트가 계정을 소유하고 있었다. **health check 와 channel probe 는 서빙 검사가 아니다.**
서빙 검사는 격리 프로브 한 줄뿐이다 — 텔레그램 발송 없이 `agent --agent <id> --session-key "agent:<id>:probe-<ts>"`.

두 번째 이유: **의존 사슬인데 도구는 자기 앞 한 칸만 보고한다.** 하나를 고치면 그제야 다음이 드러난다.
"지금 전부 뭐가 막혀 있는지" 보여주는 화면이 없다. 그래서 격리 lab 으로 미리 다 잡을 수 없었다 —
cold archive 에 `credentials/` 와 `exec-approvals.json` 이 없었고(멤버는 `agents,cron,plugin-state,state,tasks` 뿐),
lab 은 네트워크가 없어 **실제 턴을 한 번도 돌리지 않았다**. lab 이 준 것은 5~6번까지고, 7~9번은 라이브에서만 나왔다.

세 번째: **doctor 가 "doctor --fix 를 돌려라"라고 말하는데 그 doctor 자신이 막혀 있는 경우가 있다**(6번).

#### 실제로 걸린 순서 — 각 칸이 앞칸을 풀어야 열린다

| # | 겉보기 증상 | 진짜 원인 | 처방 |
|---|---|---|---|
| 1 | `Gateway failed to start: Invalid config` (7키) | 8.1 이 `memorySearch`·`acp.maxConcurrentSessions`·`ownerDisplay`·`resetOnExit`·`bundledDiscovery` 등 은퇴 | 8.1 **startup config repair 가 자동으로 한다** — 단 2번이 먼저 풀려야 |
| 2 | startup repair 가 "안 도는" 것처럼 보임 | repair 는 **state migration 이 clean 하게 끝난 뒤에만 커밋**된다 (`automatic-startup-config-repair.ts`: "after state migrations") | 순서가 config→state 가 아니라 **state→config** 다 |
| 3 | agent DB 7개 전부 skip, `ready` 거부 | `Agent identity migration requires stopped-writer maintenance` — 게이트웨이가 자기 DB 를 잡고 있으면 못 옮긴다 | **게이트웨이 정지 후** `doctor --fix`. v1→v19 |
| 4 | doctor 1회로 일부만 마이그레이션 | `core:agent-database-maintenance/global` 리스를 도중에 잃는다 (lab·라이브 양쪽 재현) | **직렬 재시도**. 라이브 실측 pass1=main/glg/gpt/gemini/mini, pass2=나머지 |
| 5 | `agents.ownership` 스키마 거부 | 8.1 은 에이전트 2개↑ + default 마커 없음을 거부 (`zod-schema.agents.ts:79-85`). 우리는 6개·마커 0 | `agents.ownership="explicit"` **명시**. 자동 수선 대상이 아니다 — 정책 결정이라서 |
| 6 | doctor 가 배너만 찍고 즉시 종료 | `exec-approvals.json` 레거시 가드가 **doctor 가 실행하려는 그 마이그레이션 앞에서** doctor 를 죽인다 (순환). upstream #133813 / #134036 | 파일을 **state dir 밖으로** 옮기고 `approvals set --file <밖의 경로>` 로 흡수 |
| 7 | 게이트웨이 healthy·텔레그램 붙음, 그런데 **턴이 `UNAVAILABLE`** | `Legacy workspace setup state requires migration` | 6번을 푼 뒤 `doctor --fix` 가 통과한다 |
| 8 | main 이 정체성을 잃음 (봇은 살아 있음) | 8.1 은 workspace 미지정을 `workspace/<agentId>` 로 해석. main 은 `workspace/` 를 쓰고 있었다 → IDENTITY/AGENTS/MEMORY 전부 못 봄 | 6봇 **전부 workspace 를 명시**. `agents list` 의 `Identity:` 줄이 검수 지표 |
| 9 | 텔레그램 `default` 계정에 소유자 없음 | 5번의 직접 귀결. 7.1 은 암묵적 기본 에이전트가 받아줬고 `default` 만 binding 이 없었다(나머지 5개는 있었음) | top-level `bindings` 에 `telegram:default → main` 추가. **6/6 명시** |

#### 10번 — 8.1 과 **무관한**, 같은 날 겹쳐 터진 조용한 실패

| # | 겉보기 증상 | 진짜 원인 | 처방 |
|---|---|---|---|
| 10 | 4개 claude-cli 봇만 매 턴 spawn 1.1초 만에 죽음 | **base 이미지 npm 11.13.0 → 12.0.2.** npm 12 는 install script 를 `allowScripts` 로 **기본 차단**한다 → `@anthropic-ai/claude-code` postinstall 미실행 → `bin/claude.exe` 가 500B 에러 shim (진짜 213MB 는 `node_modules/@anthropic-ai/claude-code-linux-arm64/claude` 에 방치). 빌드 로그엔 error 가 아니라 `npm warn install-scripts` 만 남는다 | Dockerfile 3단: `--allow-scripts=@anthropic-ai/claude-code` + `node install.cjs`(멱등) + **`claude --version` 으로 빌드 fail-closed**. 실측 대조 7.1=285457336B / 8.1=500B |
#### 11번 — 8.1 이 **경고를 거부로 승격**한 자리 (10번과 성격이 다르다)

| # | 겉보기 증상 | 진짜 원인 | 처방 |
|---|---|---|---|
| 11 | gpt 봇만 `UNAVAILABLE`, 나머지 5봇 정상 | 8.1 이 "codex 플러그인 비활성인데 모델이 codex 런타임으로 해상"을 **경고 → 거부**로 승격. 7.1 doctor 는 같은 상태를 경고 7건으로만 냈다 | `openai/gpt-5.6-{terra,sol,luna}` 의 `agentRuntime` 을 `openclaw` 내장으로 **명시**(2026-08-07 GLG 결정의 완결). doctor 경고 7건 → 0. ⚠️ 고친 뒤 프로브가 `⚠️ API rate limit reached` / `rawError=Codex error: The usage limit has been reached` 로 떨어지면 그건 **성공 신호다** — 런타임이 OpenAI 에 도달했다는 뜻이고 벽은 구독 쿼터다. 수정 전 문자열(`runtime "codex" is unavailable`)과 반드시 구분하라 |

#### 재현 가능한 순서 (다음에 이대로 하면 된다)

```bash
# 0) 롤백 이미지 태그 + cold 백업 (게이트웨이 정지 후 떠야 일관적이다)
docker tag openclaw-custom:latest openclaw-custom:<old>-rollback
cd ~/openclaw && docker compose stop openclaw-gateway
#    백업 대상: openclaw.json + agents/ + state/ + plugin-state/ + tasks/ + cron/

# 1) 사람이 정해야 하는 config 편집 3건 (자동 수선 대상 아님)
#    agents.ownership="explicit" / plugins.allow 에서 죽은 항목 제거 / skills.workshop 명시
#    ※ agents.defaults.models 는 파일 직접 편집 — 키 순서 = catch-all 규율

# 2) 레거시 잔해를 state dir 밖으로 (doctor 를 막는 것들)
#    credentials/telegram-<죽은계정>-allowFrom.json  → 백업으로 이동
#    exec-approvals.json → 밖으로 옮기고 `approvals set --file` 로 흡수

# 3) 게이트웨이 정지 상태에서 doctor 직렬 (writer 0 확인 필수)
docker run --rm --network none -v ~/openclaw/config:/home/node/.openclaw:rw \
  <candidate> node openclaw.mjs doctor --fix       # 리스 잃으면 그대로 재실행
#    게이트: state v15 + agent DB 전부 v19 + integrity_check=ok

# 4) 세션 스토어 이관은 별도 경로다 (--fix 가 아니다)
node openclaw.mjs doctor --session-sqlite dry-run   # issues 0 확인
node openclaw.mjs doctor --session-sqlite import
node openclaw.mjs doctor --session-sqlite validate  # legacy 0 확인

# 5) 격리 기동 → ready 확인 → 승격 → recreate → **6봇 격리 프로브**
```

#### 검수는 3층이다 — 하나만 보면 속는다

1. **컨테이너**: `healthy` + `RestartCount` — 여기까지는 아무것도 보장하지 않는다
2. **채널**: `channels status --probe` 6/6 `works` — 붙었다는 뜻일 뿐 답한다는 뜻이 아니다
3. **서빙**: 6봇 격리 프로브. **이걸 안 하면 8·9·10번을 전부 놓친다**

> ⚠️ 재시작 직후 1회 probe 로 장애 판정하지 말 것 — 폴링 재연결 전이면 `disconnected` 로 찍힌다.


### heartbeat를 한 봇에만 주면 나머지 봇이 조용히 꺼진다 (2026-08-12)

> 🔻 **2026-09-01 현재 이 판정 규칙을 의도적으로 이용하고 있다** — bbot 하나만 `heartbeat` 블록을
> 가지므로 나머지 5봇은 전원 OFF다. 그게 지금 원하는 상태다. [자동화 SSOT](openclaw-automations.md).

한 봇의 주기만 바꾸려고 `agents.list[]`에 `heartbeat` 블록을 하나 넣는 순간 **스케줄러가 모드를
바꾼다**. `isHeartbeatEnabledForAgent()`가 이렇게 판정하기 때문이다:

```
list 안에 heartbeat 블록을 가진 에이전트가 하나라도 있나?
  있다 → 그 블록을 가진 에이전트에게만 heartbeat 적용 (나머지 전원 OFF)
  없다 → agents.defaults.heartbeat 존재 시 전원 적용
```

즉 `defaults.heartbeat`는 **아무도 명시하지 않았을 때만** 전원에게 걸리는 폴백이다. bbot에만
`{ every: "30m" }`을 넣으면 bbot만 돌고 main/glg/gpt/mini는 에러도 경고도 없이 멈춘다 — 로그에
"안 도는 봇"은 안 찍히니 한참 뒤에나 눈치챈다.

처방: **heartbeat를 쓰는 봇 전원에게 블록을 명시한다.** 그 순간부터 `agents.list`가 진짜 SSOT이고
`defaults`는 죽은 폴백이 된다 — **새 봇을 추가할 때 블록을 빼먹으면 그 봇은 heartbeat 없이
태어난다.** 반대로 특정 봇을 끄고 싶으면 블록을 안 주면 된다(2026-08-12 gemini가 이 경로로 OFF).

주기 해석 순서는 `overrideEvery ?? agent.heartbeat.every ?? defaults.heartbeat.every ?? "30m"`.
config-only 변경이라 **`docker compose restart openclaw-gateway`면 충분**(recreate 불필요),
restart 뒤 memory prewarm은 평소대로.

### 컨테이너에 전역 gitconfig가 없다 — 봇의 push는 막히고 안전레일은 통째로 빠진다 (2026-08-12)

봇 컨테이너에는 `~/.gitconfig`도 `/etc/gitconfig`도 **존재하지 않았다**. 결과가 두 갈래로 갈렸는데,
한쪽은 시끄럽게 막히고 다른 쪽은 조용히 뚫려 있어서 둘을 같이 보기 전엔 반쪽만 고치게 된다.

- **push는 막힌다(시끄러움)**: `~/.config/gh`가 ro로 마운트돼 `gh auth`는 GREEN인데도 plain
  `git push`는 `fatal: could not read Username for 'https://github.com'`(exit 128). 토큰은
  허가돼 있고 git이 그걸 쓸 배선만 없는 상태 — 권한 문제로 오진하기 쉽다.
- **안전레일은 빠진다(조용함)**: 호스트를 지키는 global `core.hooksPath`가 컨테이너엔 없으니
  봇 커밋이 신원/secret 스캔을 **한 번도 거치지 않고** 공개 리포로 나간다. 아무 에러도 안 나므로
  누가 실측하기 전까지는 보이지 않는다.

처방은 한 파일: `~/openclaw/config/gitconfig-system` → compose에서 `/etc/gitconfig:ro`로 마운트
(공개 백업은 `docker/openclaw/config/gitconfig-system`). credential helper(`!gh auth git-credential`)와
`core.hooksPath`를 같이 넣는다 — **한쪽만 넣으면 열어놓고 지키지 않는 상태가 된다.**

반사신경 둘:

- **이 파일을 고칠 땐 in-place append**(`>>`). single-file bind-mount inode 함정이라 atomic
  rename으로 새 inode를 만들면 컨테이너는 옛 내용을 계속 본다(Caddyfile과 같은 병). 제자리 수정은
  재시작 없이 즉시 반영된다 — `docker exec ... git config --system --list`로 확인.
- **compose 백업만 옮기고 파일을 빼먹지 마라.** bind source가 없으면 docker가 그 자리에 빈
  **디렉터리**를 만들고 `/etc/gitconfig`가 디렉터리가 되면서 컨테이너의 git이 통째로 깨진다.

hooksPath는 경로가 없으면 훅 없이 조용히 진행한다(fail-open) — 봇을 막지는 않는다. gitleaks는
컨테이너에 없어서 fallback 패턴으로 동작하고, 공개 리포(`junghan0611/*`·`junghanacs/*`)는 strict
(신원 용어 + secret)로 잡힌다. 실측(2026-08-12): 정상 커밋 통과, `ghp_` 토큰 커밋 차단, 신원 용어
커밋 차단, `git push --dry-run` 인증 통과 + pre-push 스캔 동작.

### gogcli(gog) 봇 배포 — 정적 링크 필수 + bin SSOT (2026-08-11 갱신)

**한 줄**: 봇 `gog` = openclaw/gogcli 공개 **정적** v0.34.0. 옛 `junghan0611` 포크 0.12는 폐기. **실파일 SSOT = `~/openclaw/bin/gog`** (스킬 트리 밖).

**도달 체인 (2026-08-11 심볼릭 전량 배포 이후)**:

```
workspace*/skills/gogcli  →  agent-config/skills/gogcli  →  gog 심볼릭
claude-skills/gogcli      ↗                                 └→ ~/openclaw/bin/gog  (실파일)
```

업그레이드: ① `external-packages.sh`로 `~/.local/bin/gog` ② `cp ~/.local/bin/gog ~/openclaw/bin/gog` ③ 끝.

**옛 함정 (해결됨, 재발 금지)**: 호스트 `~/.claude/skills`가 agent-config/skills **디렉터리 심볼릭**이면 compose의 `claude-skills → ~/.claude/skills` 마운트가 agent-config를 통째로 오버레이했다. 고정 형태 = `~/.claude/skills` **실 디렉터리 + per-skill 심볼릭**. 또한 옛 `run.sh k)` rsync는 gog 실파일을 자기참조 심볼릭으로 덮어 파괴 — k)는 심볼릭 전용, 복사 금지.

**정적 링크 필수**: 봇 컨테이너 = Debian bookworm aarch64, **nix store 없음**. gog는 `statically linked`여야 컨테이너에서 돈다. openclaw/gogcli 릴리즈 `linux_arm64`는 정적. `go install`(호스트 CGO=1)은 **nix glibc에 동적 링크**돼 컨테이너에서 loader(`/nix/store/…ld-linux`) 부재로 실행 실패(`not found`처럼 보인다). → `external-packages.sh`는 릴리즈 tarball 다운로드로 정적본을 앉힌다(`go install` 아님, 2026-07-15).

**인증 = 호스트 `~/.config/gogcli` 단일 SSOT (rw 공유)**: 봇에 마운트(docker-compose). gog 0.34+는 keyring lock **write**를 요구하므로 마운트 **rw** 필수(2026-07-15 ro→rw). 옛 0.12는 lock 미사용이라 ro로도 됐다. 호스트 `gog login` 1회 = 봇도 반영(개인+회사 both), refresh token 갱신도 호스트 파일에 써진다. `GOG_ACCOUNT`=개인 gmail(default) env — 계정 둘이라 미지정 시 0.34는 `--account` 요구. 회사는 `--account <work-email>` 명시(실제 값은 agent-config SKILL.md).

**"옛 버전은 됐는데 새 버전이 안 된다"의 정체** (0.12→0.34 회귀 둘): (a) keyring lock write → ro 마운트에서 실패(→rw), (b) 계정 여럿 → account 미지정 실패(→GOG_ACCOUNT). 둘 다 옛 버전엔 없던 요구라, 업그레이드가 조용히 봇 캘린더를 깬다.

### 모델 승격이 특정 대화에만 안 먹는다 — `/reset`·`/new`는 user 핀을 못 푼다 (2026-07-14)

**증상**: `agents.list[].model.primary`를 올렸는데 **어떤 DM만** 옛 모델로 답한다. 세션을 `/new`·`/reset` 해도 그대로다. (2026-07-14: glg를 `gpt-5.6-terra`로 승격했는데 GLG 본인 DM만 계속 `gpt-5.5`.)

**근인**: 그 세션에 **사용자가 명시한 모델 핀**이 저장돼 있다. `config/agents/<id>/sessions/sessions.json`:

```json
"modelOverride": "gpt-5.5",
"providerOverride": "openai",
"modelOverrideSource": "user"     ← 과거 /model <id> 실행의 흔적
```

**`/reset`·`/new`는 전사(transcript)만 비우고 이 핀은 유지한다** — 사용자의 명시적 선택을 존중하는 설계다. 그래서 config 기본값을 아무리 바꿔도 그 대화만 안 따라온다.

**처방**: 해당 대화에서 **`/model default`**. config primary로 복귀한다(코드의 상태 문구도 `pinned session; config primary <X> · clear /model default`). `/model gpt-5.6-terra`처럼 새 모델을 직접 지정해도 당장은 되지만 **또 user 핀이 박혀 다음 승격 때 같은 일이 반복된다** — `default`가 정답.

**진단 (어느 세션이 핀을 물고 있나)**:

```bash
python3 - <<'PY'
import json, pathlib
for a in ('main','glg','gpt','bbot','mini','gemini'):
    p = pathlib.Path(f'~/openclaw/config/agents/{a}/sessions/sessions.json').expanduser()
    if not p.exists(): continue
    for k, v in json.loads(p.read_text()).items():
        if isinstance(v, dict) and v.get('modelOverrideSource') == 'user':
            print(f"{a:7} {k:50} {v.get('modelOverride')}")
PY
```

> 승격 작업의 마지막 단계로 이걸 돌려라. **config만 보고 "승격 완료"라 하면 안 된다** — 실사용 대화가 안 따라올 수 있다. 핀 없는 세션(cron·타인 DM)은 다음 턴에 자동으로 새 기본값을 탄다.

### 봇의 "지금"이 UTC — 컨테이너 TZ 미설정 (2026-07-14, 7.1에서 발견)

**증상**: `/status`가 `Current time: … (UTC)`로 뜬다. 봇에게 "몇 시야?" 물으면 UTC로 답한다.

**근인**: 컨테이너에 `TZ`가 없어 `/etc/localtime → Etc/UTC`. OpenClaw `resolveUserTimezone()`은

```js
// agents.defaults.userTimezone 이 비어있으면 → 프로세스 TZ 로 폴백
return Intl.DateTimeFormat().resolvedOptions().timeZone?.trim() || "UTC";
```

즉 **config를 안 박으면 봇의 시간 감각이 컨테이너 TZ를 그대로 물려받는다.**

**왜 표시 문제가 아니라 버그인가**: ① 봇이 새로 만드는 cron이 UTC 기준으로 적힌다(실제로 `morning-family-schedule`이 `0 23 * * * @ UTC`로 박혀 있었다 — 08:00 KST에 *맞아떨어지긴* 하나 의도가 아니라 사고다). ② **봇이 실행하는 스킬/스크립트의 `date`도 UTC** — 자정 근처에 저널·메모리 파일 날짜가 하루 어긋난다.

**처방 (둘 다)**:

1. `docker-compose.yml` 두 서비스(gateway, cli) `environment`에 `TZ=Asia/Seoul`. **env는 restart가 아니라 `up -d --force-recreate`로만 반영된다.**
2. config에도 명시 (컨테이너 TZ에 기대지 않는 SSOT):
   ```bash
   openclaw config set agents.defaults.userTimezone "Asia/Seoul"
   openclaw config set agents.defaults.envelopeTimezone "user"
   ```

⚠️ **config만으론 안 고쳐진다** — 2026-07-14 실측에서 `userTimezone`을 박아도 봇은 계속 UTC로 답했고, 컨테이너 `TZ`를 박고 recreate한 뒤에야 KST가 됐다. 근인은 컨테이너 쪽이다.

**TZ 변경이 안전한 이유(검증됨)**: 기존 cron이 전부 타임존을 **명시**하고 있으면(`@ Asia/Seoul` / `@ UTC` / `at …Z`) 하나도 안 밀린다. 우리 케이스에서 변경 전후 `cron list`의 next 시각 전부 동일했다. **바꾸기 전에 `cron list`로 타임존 미명시 작업이 있는지 반드시 확인할 것** — 있으면 그건 밀린다.

### 이미지 재빌드 node-gyp hang — @google/gemini-cli(keytar+node-pty) (2026-07-01, 6.11)

증상: 6.10→6.11 재빌드 시 `RUN npm install -g` 스텝에서 **node-gyp가 9분+ hang**. CPU 0.2%(컴파일 아님, cc1plus/g++ child 0) + SYN-SENT 0(네트워크 아님) — 그냥 멈춤. 6일 전 빌드엔 없던 새 비용.

근인: **`@google/gemini-cli` 0.49.0**이 transitive로 `@github/keytar`+`node-pty`(native addon)를 끌어와 aarch64 buildkit sandbox에서 node-gyp가 hang. `@anthropic-ai/claude-code`는 native 0(무관), ACP 2개(pi-coding-agent/codex-acp)도 무관.

진단 반사신경: RUN 스텝이 오래면 → `ps -eo pid,etime,args`로 컨테이너/executor 프로세스 확인 → `node-gyp` 보이고 CPU~0 + cc1plus 없으면 **hang** → temp dir에서 `npm install --ignore-scripts <pkg>` 후 `find node_modules -name binding.gyp`로 native 유발 패키지 특정.

조치: Dockerfile `npm install -g` 줄에서 **3개 제거** — `@earendil-works/pi-coding-agent`+`@zed-industries/codex-acp`(ACP 폐기로 unused, config 미참조) + `@google/gemini-cli`(gemini 403 DOWN·agy 대기라 "안 쫓음" + hang 범인). 남긴 건 `@anthropic-ai/claude-code`만(claude-cli runtime, native 0). 결과 빌드 몇 초. gemini 부활(agy) 시 복원 — 그땐 `libsecret-dev` 등 build deps 필요할 수 있음. 양쪽 Dockerfile(`~/openclaw/` + `docker/openclaw/`) 동기 유지.

### correction release(`-N`)는 버전 문자열을 안 올린다 — Control UI "업데이트 사용 가능"은 상시 오탐 (2026-08-06)

Control UI 상단에 **`업데이트 사용 가능: v2026.7.1-2 (실행 중 v2026.7.1)`** 이 뜬다. 이건 뒤처진 게 아니라 **영구 오탐**이다: correction release는 upstream 태그만 `-2`이고 이미지 안 `/app/package.json`의 `version`은 그대로 `2026.7.1`이다. UI는 릴리즈 태그와 자기 version 문자열을 비교하므로, `-2`를 이미 돌리고 있어도 계속 "업데이트 있음"으로 보인다.

**이 알림을 근거로 업그레이드를 판단하지 마라.** 판단은 digest로만 한다:

```bash
# 원격 태그 digest (pull 없음)
for t in 2026.7.1 2026.7.1-2; do
  printf '%-12s ' "$t"; docker buildx imagetools inspect ghcr.io/openclaw/openclaw:$t | sed -n 's/^Digest:[[:space:]]*//p' | head -1
done
# 라이브 이미지의 base 확인 — 로컬 diff_ids 앞부분이 어느 태그와 일치하는가
#   원격: docker buildx imagetools inspect <ref> --format '{{json .Image}}' → linux/arm64.rootfs.diff_ids
#   로컬: docker inspect openclaw-custom:latest --format '{{json .RootFS.Layers}}'
```

**2026-08-06 실제 오진 사례**: Dockerfile FROM 커밋 시각(08-04 16:36)이 이미지 빌드 시각(08-04 15:00)보다 늦은 것을 보고 "FROM만 바뀌고 rebuild가 빠졌다 = 라이브는 7.1"이라고 진단했다. **틀렸다.** 커밋이 사후에 이뤄졌을 뿐 빌드는 이미 `-2` base를 썼다. `build --pull` 재실행이 전 레이어 CACHED로 끝나고 이미지 ID가 안 바뀐 것이 첫 신호였고, diff_ids 대조로 확정됐다(로컬 base 26개 = `-2`, 7.1과는 index 5부터 갈림). **타임스탬프 두 개로 인과를 세우지 마라 — 레이어를 봐라.** NEXT.md의 7.1 항목에 digest 3개(`7.1`/`-1`/`-2`)가 이미 적혀 있었다는 점도 함께 배울 것: 문서를 먼저 읽었으면 오진 자체가 없었다.

### caddy 변경 = 8-세트 검수 필수 + agenda 000 ≠ caddy (geworfen은 emacs 데몬 의존) (2026-07-01, ax 추가 2026-07-15, claw 추가 2026-08-06)

**규칙 (GLG 지시)**: `docker/caddy/Caddyfile`을 건드리면(특히 `docker restart caddy`) **caddy-fronted 전체를 세트로 검수**한다. 하나만 보고 넘기지 말 것. 현재 세트:

```bash
for d in comments.junghanacs.com analytics.junghanacs.com agenda.junghanacs.com \
         ha.junghanacs.com forge.junghanacs.com map.junghanacs.com ax.junghanacs.com \
         claw.junghanacs.com; do
  printf '%-28s → %s\n' "$d" "$(curl -sS -o /dev/null -w '%{http_code}' --max-time 8 https://$d/)"
done
```
정상 기대치: analytics/ha/forge/ax=200, comments=404(remark42 루트 정상), map·claw=302(authelia 게이트), agenda=200.

**ax.junghanacs.com은 이 호스트의 첫 static vhost다** (2026-07-15 추가, 관리 대상). 기존 6개는 전부 `reverse_proxy`(백엔드 컨테이너)지만 ax는 백엔드가 없다 — caddy가 `file_server`로 `/srv/ax`(= 호스트 `/home/junghan/docker-data/ax` ro 마운트, caddy compose 볼륨)를 직접 서빙한다. geworfen 패턴(컨테이너)을 쓰지 않은 이유: geworfen은 실행 바이너리라 컨테이너가 필요했고 ax는 정적 파일뿐이다.

- **web root 채우는 주체 = junghan0611 repo의 `apply/ax` `make publish`** (leak gate 통과분만 들어옴). `make publish`는 파일만 갈아끼우므로 **caddy 재시작 없이 즉시 라이브**. 이 디렉터리에 publish 경로 밖으로 파일을 떨구면 그대로 공개된다 — leak gate가 유일한 관문이다.
- `.md`는 `header @md Content-Type "text/plain; charset=utf-8"`로 브라우저 표시 강제(기본 `text/markdown`은 다운로드됨). `browse` 없음(리스팅 off), authelia 없음(공개면).
- **볼륨을 새로 붙이거나 뺄 땐 `docker restart caddy`로 안 먹는다** — compose 볼륨 변경은 `up -d --force-recreate` 필요(이게 ax 추가 때 6개 blip의 원인). Caddyfile 텍스트만 고치는 평시 변경은 여전히 `docker restart caddy`.
- **향후**: umami + remark42를 ax에 붙일 예정. 단 스니펫은 **정본(apply/ax 소스)에 넣어 publish**로 흘린다 — **caddy에서 주입 금지**(정본과 라이브가 갈라짐). ax 관련 요청은 이 오퍼레이터 레인이 대응한다.

**claw.junghanacs.com은 유일하게 "인증 뒤에 원격 셸이 있는" vhost다** (2026-08-06 추가). OpenClaw Control UI를 공개면에 올린 자리 — 자물쇠 3겹(Authelia forward_auth → gateway token → HTTPS device pairing)을 **전부 유지**해야 한다. 세 가지가 이 vhost의 함정이다:

- **바깥 자물쇠는 컨테이너 평면에서 우회된다.** `openclaw-gateway`가 `proxy` 도커 네트워크에 붙어 있어(172.18.0.10) 같은 네트의 다른 컨테이너(umami/remark42/forge/ha/butler-viewer/geworfen/authelia)는 Authelia를 건너뛰고 18789에 직결한다. 실측: caddy 컨테이너에서 `http://openclaw-gateway:18789/` → **200(Control UI HTML 무인증 서빙)**, `/control-ui-config.json` → 401. 즉 **진짜 경계는 token + device pairing이지 forward_auth가 아니다.** → `gateway.auth.mode`를 **`trusted-proxy`로 바꾸지 마라**. 바꾸는 순간 저 우회 경로가 곧 인증 우회가 된다. `dangerouslyDisableDeviceAuth`도 마찬가지.
- **Authelia ACL은 first-match이고 no-match는 `default_policy`로 떨어진다.** `default_policy: one_factor`이므로 claw에 operator 규칙만 추가하면 `family` 계정이 그 규칙에 불일치한 뒤 default로 떨어져 **결국 통과한다.** 그래서 claw 규칙은 반드시 3단이다: (a) 포털 bypass → (b) `subject: [['group:operator']]` one_factor → (c) **deny catch-all**. 적용 전 검증은 `authelia access-control check-policy --url ... --username ... --groups ...`로 operator=one_factor / family=deny를 확인하고, `authelia config validate`(4.39 canonical; legacy `validate-config`도 아직 동작)로 파싱을 본다. **mount 경로는 `/config/configuration.yml`·`/config/users.yml` 그대로여야 한다** — `authentication_backend.file.path`가 `/config/users.yml`이라 다른 경로에 stage하면 users DB를 못 찾는다.
- **forward_auth는 WS upgrade 시점에 1회만 평가된다.** 그래서 (a) 세션이 만료돼도 이미 열린 WebSocket은 안 끊기고, (b) **만료 후 재연결은 조용히 실패한다** — 브라우저는 로그인 HTML 응답으로 101 업그레이드를 완성할 수 없다. 증상은 UI의 "연결할 수 없음"뿐이고 로그인창이 안 뜬다. 처방: **F5(top-level navigation)** 로 로그인 화면을 받아라. Authelia 세션은 inactivity 2h / expiration 8h / remember_me 1month.

보안 헤더는 **게이트웨이가 자기 응답에 이미 싣는다**(CSP / X-Frame-Options: DENY / nosniff / Referrer-Policy / Permissions-Policy — 실측). Caddy에서 중복 주입하지 마라. Caddy가 얹는 건 **HSTS 하나뿐**(TLS 종단은 한 곳). `includeSubDomains`·preload는 금지 — junghanacs.com 하위에 http-only가 하나라도 생기면 통째로 잠기고 되돌리기 어렵다.

**함정 — agenda 000은 caddy 탓처럼 보이지만 아니다**: `agenda.junghanacs.com`(geworfen:3333)은 **호스트 emacs `server` 데몬**(`agent-emacs.service`, socket `/run/user/1000/emacs/server`, ro 마운트)에 의존한다. 그 데몬이 hang하면 geworfen HTTP 핸들러가 블록 → agenda **HTTP 000**(caddy는 502 아니라 dial 타임아웃). caddy를 방금 재시작했어도 **인과 아님** — 진단으로 갈라라:
- `emacsclient -s server --eval '(+ 1 1)'` (호스트) → 타임아웃(exit 124)이면 **데몬 hang**이 근인, caddy 무관.
- 소켓 inode 호스트 vs `docker exec geworfen ls -lai /run/user/1000/emacs/` **일치**면 마운트 stale 아님(compose 주석의 "emacs 재시작 후 stale" 회복 경로 해당 없음) → 데몬 자체 문제.
- autoheal이 geworfen을 4분마다 재시작 루프(`docker logs autoheal`)면 **컨테이너가 아니라 데몬이 원인** — geworfen restart로는 안 풀린다.

**복구**(geworfen 담당자 소관 — nixos-config에서 직접 데몬 만지지 말고 entwurf로 핸드오프): `systemctl --user restart agent-emacs.service` + 고아 `--daemon=server` 프로세스(parent=init) 청소 + `docker restart geworfen`. 2026-07-01 사건 = map authelia 배포 caddy restart(11:35)와 무관, 데몬 hang이 11:11부터 선재.

### Telegram isolated polling ingress — 유령 connected / inbound 무응답 (2026-06-29)

증상: 채널 status는 `running, connected, transport:just now, mode:polling`인데, 해당 봇 토큰에 직접 `getUpdates(offset=-1)`를 호출해도 `409 Conflict`가 안 뜬다. 즉 OpenClaw status는 connected로 보이나 실제 long-poll request가 없어서 inbound를 소비하지 못하는 **유령 connected** 상태다. `sendMessage`는 정상이라 bot token / outbound 권한 문제로 오판하기 쉽다.

2026-06-29 bbot 사건 관찰:

- bbot `models status --probe --agent bbot` = `claude-cli usable`, OAuth refresh 정상(`expires in 8h`).
- `openclaw agent --agent bbot --session-key agent:bbot:telegram:bbot:direct:123861330 ...` = 기존 Telegram direct session도 3.5s 내 `ok`. 즉 claude-cli runtime/session 자체가 root cause가 아니었다.
- Bot API 직접 `sendMessage`도 성공(`message_id=1388`). outbound 정상.
- 문제는 isolated ingress worker가 실제 long-poll을 유지하지 못한 것. bbot만 standard polling으로 돌리자 `/start`/`/new` 후 inbound가 다시 살아났다.

임시 복구(컨테이너 런타임 핫패치 — **recreate/image rebuild 시 사라짐**):

```bash
cd ~/openclaw
# /app/dist/probe-*.js 의 monitorTelegramProvider isolatedIngress 설정부에서 bbot만 false
# enabled: account.accountId === "bbot" ? false : opts.isolatedIngress?.enabled ?? true,
docker compose restart openclaw-gateway
```

검증 순서:

1. `getWebhookInfo`에서 webhook 비어 있고 pending 수 확인.
2. 직접 `sendMessage`로 outbound 정상 확인.
3. `models status --probe --agent <id>`와 `openclaw agent --session-key agent:<id>:telegram:<account>:direct:<chatId>`로 runtime/session 정상 확인.
4. status가 connected인데 직접 `getUpdates(offset=-1)`가 409를 못 받으면 유령 connected. 단 이 진단 호출 자체가 실제 poller와 충돌을 만들 수 있으니 짧게 1회만.
5. standard polling 전환/핫패치 후 사용자가 실제 DM(`/start`, `/new`, `테스트`)을 보내 inbound→claude turn→sendMessage 로그가 이어지는지 확인.

후속: 이 핫패치를 Dockerfile/entrypoint patch 또는 upstream config toggle로 영구화할지 결정해야 한다. 지금 상태는 컨테이너 내부 수정이라 `up -d --force-recreate`나 이미지 재빌드로 되돌아간다.

### claude-cli provider — `claude` binary not on PATH → EPIPE on every turn (2026-05-26)

OpenClaw 5.20 (`dist/cli-backend-CO2SZJAY.js`)이 `claude-cli` provider를 자동 등록하면서 spawn args를 `command: "claude"`로 박는다. PATH에서 `claude`를 찾는데, image는 `@anthropic-ai/claude-agent-sdk` (+ `@anthropic-ai/claude-agent-sdk-linux-arm64/claude` 번들 binary)만 install 하고 `node_modules/.bin/claude` symlink는 만들지 않음 (SDK package.json에 `bin` field 없음). 결과:

```
spawn("claude", ...) → ENOENT
child exits in ~4ms
parent stdin write → EPIPE
log: "claude live session close: reason=abort" + "model fallback decision: reason=timeout detail=write EPIPE"
telegram UX: "⚠️ Agent failed before reply: write EPIPE. Please try again, or use /new to start a fresh session."
```

함정 자리:
- `openclaw infer model run --model claude-cli/...` 은 **잘 작동**. 다른 dispatch path (one-shot capability) 사용.
- `openclaw agent --agent <id>` + 텔레그램 inbound 둘 다 같은 live session path → 둘 다 EPIPE.
- `/status` 도 정상 표시 (model lookup만 하고 spawn 안 함).

Fix (정공법, env 변경 — force-recreate 필요):

```yaml
# docker-compose.yml — gateway service AND child env (두 자리)
- PATH=/app/node_modules/@anthropic-ai/claude-agent-sdk-linux-arm64:/home/junghan/.pi/agent/claude-plugin/skills/bibcli:.../bin
```

SDK 디렉토리에는 `claude` + LICENSE/README/package.json만 있어서 다른 binary와 충돌 0. `node_modules`가 image 안이라 영구.

대안 (안 채택): host `npm i -g @anthropic-ai/claude-code` 후 mount — 호스트 의존 늘어남. Dockerfile에 `npm i -g` 추가도 가능 — image 재빌드 비용.

> **⚠️ 2026-08-31 정정 — 위 처방은 화석이다. "안 채택"이라던 대안이 지금의 정본이다.**
> `@anthropic-ai/claude-agent-sdk-linux-arm64` 는 **7.1 이미지에도 8.1 이미지에도 존재하지 않는다**(실측:
> 두 이미지 `/app/node_modules/@anthropic-ai/` 에는 `sdk`(+8.1은 `claude-agent-sdk`)뿐). 즉 **compose PATH
> 첫 항목은 이미 오래전부터 빈 경로를 가리키는 화석**이고, 실제로 spawn 되는 것은 Dockerfile 이 전역 설치한
> `/usr/local/bin/claude` → `@anthropic-ai/claude-code` 다. 지워도 되지만 무해해서 남아 있다.
> 이 자리의 현재 함정은 PATH 가 아니라 **npm 12 의 `allowScripts`** 다 — 위 "조용한 실패 11겹" 표의 10번 행.


### bonjour plugin — disable on Oracle Cloud + Docker (since 2026-04-24)

OpenClaw 2026.4.24 split bonjour LAN discovery into a default-on plugin (`@homebridge/ciao`). On Oracle Cloud + Docker with IPv6 disabled (our setup), the mDNS probe fails and emits `Unhandled promise rejection: CIAO PROBING CANCELLED` every ~30s, taking gateway down with it (restart loop). LAN discovery has no value to us — we reach gateway via SSH tunnel, not Bonjour.

Fix: set `plugins.entries.bonjour: { enabled: false }` in `openclaw.json`. Plugin count drops from 9 back to 8 (matching 4.23 behavior). No functional loss.

### Adding non-default models (since 2026-04-27)

OpenClaw 2026.4.24 narrowed default `openclaw models list` to *configured* rows only, and 4.24's `/models add` slash command is deprecated. To make a new model usable from `/model <id>` slash command:

1. Sync the provider API key from `~/.env.local` to `~/openclaw/.env` (preserves the SSOT pairing rule).
2. Add `provider/model-id: {}` under `agents.defaults.models` in `openclaw.json`.
3. `docker compose restart openclaw-gateway`.
4. Verify with `node openclaw.mjs models` (note: no subcommand) — look for the model in the `Configured models` line.

`models list --all` exists but is slow (>60s timeout in our container) — don't rely on it for verification.

### rw mount expansion — git is the rollback surface (2026-04-25)

Since the 4.23 upgrade, `~/repos/gh:rw` and `~/org/{meta,bib,notes}:rw` are open. There is no filesystem enforcement against unintended writes — rollback relies on `git status` / `git diff` / `git restore`.

- Monitor the first hour after any rw-expanding mount change.
- An unintended write into `~/org/diary.org` (or anything else under `~/org:ro`) means the mount config regressed.
- `~/repos/work` remains ro deliberately — never widen this without consulting the company code-safety policy.
- `nixos-config` is a symlink inside `~/repos/gh/` (→ `~/nixos-config`). Container cannot follow it. Agent edits to nixos-config must route through the host, not the bot runtime.

### Codex catalog — models.json drift on upgrade is expected (2026-04-25)

> **⚠️ 2026-08-07 이후 이 절은 이력 문서다.** codex 런타임 의존성을 전부 제거했다(`plugins.entries.codex.enabled=false`, `gpt-5.4`/`gpt-5.4-mini` 카탈로그 삭제). 서빙 경로에 codex가 없으므로 이 drift는 더 이상 운영 이슈가 아니다 — `agents/*/agent/models.json`에 Codex provider 블록이 남아있어도 참조하는 모델이 0이다. codex를 되살리는 경우에만 다시 유효해진다. 배경은 [ORACLE.md](../ORACLE.md) §"런타임 지형".


OpenClaw 2026.4.23 synthesizes the `openai-codex/gpt-5.5` OAuth row automatically. After the upgrade, `git diff config/agents/*/agent/models.json` shows `gpt-5.4 → gpt-5.5` in the Codex provider block. This is catalog-layer drift; the **serving model** is still `openai-codex/gpt-5.4` because `agents.list[].model` pins it explicitly. Verify with:

```bash
python3 - <<'PY'
import json, pathlib
c = json.loads(pathlib.Path('/home/junghan/openclaw/config/openclaw.json').read_text())
for a in c['agents']['list']:
    print(a['id'], a.get('model'))
PY
```

### Dreaming — decoupled from heartbeat (since 2026.4.23)

Upstream #70737 moves dreaming into an isolated lightweight agent turn. It now runs even when `heartbeat` is off for the default agent and is no longer skipped by `heartbeat.activeHours`. `openclaw doctor --fix` migrates stale main-session dreaming jobs in persisted cron configs to the new shape. Our deployment had no stale entries at 4.22 → 4.23 upgrade.

### ACP common failures

- `Authentication required` — confirm `~/.claude` is mounted; a simple `restart` after mount changes is not enough, recreate is.
- Only a few skills visible — broken absolute symlinks inside `~/.claude` pointing at `/home/junghan/repos/gh/...`. Add `~/repos/gh` as a compatibility mount; overlay `claude-skills` to `/home/node/.claude/skills`.
- `session-env ... ENOENT` — `~/.claude` must be **rw**.
- `ACP max concurrent sessions reached` — raise `acp.maxConcurrentSessions` or close stale sessions. Current setting: 3.
- `docker compose restart` alone insufficient after mount or env change — use `up -d --force-recreate`.

### Key pairing — same name, different value (2026-05-08)

`~/.env.local` (호스트 SSOT)와 `~/openclaw/.env` (Docker env_file)에 같은 변수명 `OPENROUTER_API_KEY`가 *서로 다른 값*으로 들어 있을 수 있다. 호스트 키는 정상이지만 컨테이너 키가 OpenRouter privacy/data policy로 막혀 있으면 모든 임베딩이 `404 No endpoints available matching your guardrail restrictions`로 실패.

운영 검증 절차:
- 키 sync는 변수명만 비교하지 말고 *값*까지 비교 (suffix 4자리만 보여 시크릿 노출 없이 일치 여부 확인).
- OpenClaw가 `${VAR}` 자동 보간하므로 한 곳(`~/openclaw/.env`)만 sync되면 충분. recreate 필요 (restart는 env 새로 안 읽음).
- 컨테이너 내부에서 직접 `curl /embeddings` 한 번 200 응답 확인 후 reindex 시작. 키 정상 + 정책 통과 확인 없이 reindex 들어가면 6 agent 모두 동시 실패.

---

## 비활성 — 재활성화 시 참고

### active-memory — model choice matters (currently disabled since 2026-05-03)

5.2 안정성 검증 동안 `plugins.entries.active-memory.enabled: false`로 둠. 재활성 시 baseline은 `~/openclaw/config/openclaw.json` 기존 config (Groq paid tier `gpt-oss-120b` primary, `google/gemini-3-flash` fallback, `timeoutMs: 15000`, `agents: ["glg", "gpt"]`).

운영 발견 (재활성 전 알아둘 것):

- `openai-codex/gpt-5.4-mini` hits a 31.5s Codex CLI subprocess cold-start. Plugin `timeoutMs` is not honored across the subprocess boundary. **Do not use Codex models in blocking hot-path plugins.** → **2026-08-07 이 규칙을 따라 실제로 치웠다**: active-memory lane이 `gpt-5.4-mini`(codex) → `openai/gpt-5.6-luna`(openclaw 내장 런타임, 서브프로세스 없음). 오래 남아있던 recall 23~35s 지연의 유력 원인이 이 콜드스타트였으므로, 교체 후 latency 재측정이 [NEXT.md](../NEXT.md)에 걸려 있다.
- `timeoutMs=8000` is too tight for groq — saw 9.7s boundary timeouts. Use 15000 (upstream default).
- Upstream `3f90d9266` (v2026.4.21) graceful degrade keeps replies alive on timeout; active-memory is an assist layer, not a critical path.
- **Groq free tier TPM=8K로 `gpt-oss-120b` 실사용 불가** (2026-04-23 관측). active-memory 프롬프트는 queryChars 1K라도 전체 input이 ~35K tok이라 매 호출 `413 Request too large`. 해결책: Groq Console에서 **paid tier 전환** ($10 선불, pay-per-use). 전환 후 호출당 ~7원, 응답 ~11s.
- **`modelFallback`은 `rate_limit` 케이스에서 자동 승계되지 않음** — 관측상 `decision=surface_error reason=rate_limit profile=-`로 끝나고 fallback 모델로 재시도하지 않음. 에러 메시지 본문이 그대로 summary로 노출되어 `summaryChars=50` 같은 작은 값으로 찍힘. `timeout`이나 일반 장애에서만 fallback이 탄다.
- **Gemini 3 Flash Lite는 Flash보다 느릴 수 있다** (2026-04-23 관측: Flash 13.4s vs Flash Lite 17.9s→timeout). 이름과 달리 active-memory의 input-heavy 워크로드(input:output ≈ 500:1)에서는 Lite의 TTFT가 더 길었음. Groq LPU의 decode 강점도 이 워크로드에서는 prefill이 지배적이라 제한적.

### ACPX — disabled since 2026-05-03

`plugins.entries.acpx.enabled=false` + `acp.enabled=false`. 5.2가 ACPX를 `@openclaw/acpx` beta로 externalize했고 우리는 미설치. 재활성 시점이 오면 `npm i @openclaw/acpx` + 아래 4개 항목 재참조.

#### ACPX — model override does not persist

As of 2026.4.15 + acpx 0.5.3, the ACP session model cannot be written into config. Schema strict fields on `AcpBindingSchema.acp` (`mode, label, cwd, backend`) and `AgentRuntimeAcpSchema` (`agent, backend, mode, cwd`) have no `model`. Only path: the in-chat slash command.

```
/acp spawn claude --bind here --cwd /home/node/.openclaw/workspace
/acp model anthropic/claude-opus-4-6
```

No host bypass exists. `openclaw acp` is only a bridge to external ACP clients; `message send` is one-way; editing `thread-bindings` files cannot substitute for spawn.

TTL recycles every 2h idle (`acp.runtime.ttlMinutes: 120`) and the model override evaporates. Active threads need manual re-set a few times per day until upstream acpx version bump.

2026-04-19 observation: `/acp model anthropic/claude-opus-4-7` CLI says "session ids resolved" but the actual served model is `claude-opus-4-6` — Anthropic flat-rate OAuth silently downgrades. Use `anthropic/claude-opus-4-6` explicitly; 4.7 needs separate billing.

2026-04-24 re-check on v2026.4.22: catalog now normalizes `anthropic/claude-opus-4-7` to 1M context (display-only fix), but routing is still OAuth-tier gated. **Policy: Claude access is company flat-rate OAuth only** — no direct Anthropic API billing. 4.7 live routing is therefore out of our fixable scope; stay on 4.6 until tier changes.

Inspect truth from the host — never from inside an already-bound thread (text there may be forwarded to the Claude session as a user turn):

```bash
cd ~/openclaw && docker exec openclaw-gateway sh -lc 'node openclaw.mjs sessions --all-agents'
cd ~/openclaw && docker exec openclaw-gateway sh -lc 'sed -n "1,200p" /home/node/.openclaw/telegram/thread-bindings-default.json'
cd ~/openclaw && docker exec openclaw-gateway sh -lc 'sed -n "1,200p" /home/node/.openclaw/telegram/thread-bindings-bbot.json'
```

#### ACPX — sessions do not auto-load workspace identity

A fresh `/acp spawn claude --bind here` Claude session does not read `workspace/IDENTITY.md / SOUL.md / USER.md / AGENTS.md / MEMORY.md`. Direct-runtime agents did (GlueClaw path historically), ACPX Claude sessions do not — claude-agent-sdk does not scan the workspace.

Fix on first turn after spawn:

```
workspace의 IDENTITY.md, SOUL.md, USER.md, AGENTS.md, MEMORY.md를 순서대로 읽고 시작하세요
```

Longer term: put a `CLAUDE.md` in workspace, or inject "read workspace/IDENTITY.md first" into `agents.list[].systemPromptOverride`, or use an ACPX bootstrap script when upstream enables it.

#### ACPX — sessions do not know their own runtime

Asking an ACPX Claude session "what runtime are you on" returns whatever `workspace/MEMORY.md` claims — pure doc-driven inference, not ground truth. In 2026-04-19 testing the binding was explicitly `agent:claude:acp:...` on Anthropic Opus 4.6, but the bot reported "not acpx, I am on direct runtime" because MEMORY.md described GlueClaw as default.

Do not trust bot self-introspection. Verify from the host with `/acp status` outside the thread, or `docker exec ... sessions --all-agents`. Long-term: remove "default runtime" prose from workspace docs, or inject a systemPromptOverride like "you cannot know your own runtime; tell the user to check `/acp status`".

#### ACPX — direct vs ACP-bound session confusion in host inspection

`openclaw sessions --all-agents` interleaves two kinds of rows:

- `agent:<id>:telegram:*` — **direct session** for the Telegram DM. Its `Model` column shows the agent's at-rest/fallback model (or a stale state from before the thread was ever `/acp spawn`-ed).
- `agent:claude:acp:*` — **ACP-bound session** actually serving the live bound conversation. This row's `Model` reflects the active `/acp model` override.

The live serving model is the ACP row, not the direct row. 2026-04-24 misread: interpreted a stale `claude-sonnet-4.6` on a `bbot direct` row as the live bbot state, and reported bbot as "fallback-mode" in a commit message. bbot was in fact on `claude-opus-4-6` via ACPX the whole time.

Verification path (least effort first):

1. Ask the bot itself in-thread.
2. Read `/home/node/.openclaw/telegram/thread-bindings-<account>.json` → `targetSessionKey`. If it starts with `agent:claude:acp:`, the live path is ACPX and the serving model lives in that ACP session, not in any `direct` row.

---

## 역사 — resolved / superseded (정책 근거 보존)

### 4.24 warn-ignored incidents — "Warn = Error" 원칙의 근거 (2026-04)

AGENTS.md §5 "Warn = Error" 원칙이 태어난 두 사건. 둘 다 여러 사이클 동안 무해한 startup noise로 치부됐다가 4.24에서 폭발했다.

- **task registry malformed**: `Failed to restore task registry` (`code:"ERR_SQLITE_ERROR" errcode:779 errstr:"database disk image is malformed"`) — 4.21부터 매 gateway start마다 떴고 11일간 "tolerable startup noise"로 방치. 4.24가 restart-continuation을 같은 task registry로 라우팅하면서, malformed `runs.sqlite`가 background warning → 100% CPU silent retry loop로 돌변해 inbound message 처리가 얼어붙음. Fix: gateway 정지 → `~/openclaw/config/tasks/runs.sqlite`를 백업 폴더로 이동 → start (새 DB 자동 생성, in-flight task state만 손실, user data 없음).
- **bonjour probe loop**: `bonjour: watchdog detected non-announced service` — 4.23부터 반복된 warn을 "ARM cloud LAN noise"로 무시. 4.24가 bonjour를 default-on plugin으로 승격하자 같은 probe 실패가 `Unhandled promise rejection: CIAO PROBING CANCELLED` → ~30s restart loop가 됨. Fix: `plugins.entries.bonjour: { enabled: false }` (현재 활성 gotcha로 박제 — 위 "활성" 참조).

교훈: 두 warn을 사이클 내내 무시한 대가는 user-visible 봇 downtime이었다. warn 조사 비용은 분 단위, 방치 비용은 시간 단위.

### 4.24 → 4.26 / 4.29 lazy-staging incident — resolved on 5.2 (2026-05-03)

**RESOLVED on 5.2.** 4.23 → 4.29 attempt on 2026-05-03 reproduced the same lazy-staging hot-path incident — first inbound message triggered `[plugins] alibaba/runway/tts-local-cli staging bundled runtime deps` mid-hot-path with `eventLoopDelayMaxMs=17213.4` and `[telegram] sendChatAction failed`. Same incident class as 4.26. 4.29 brought the diagnostic timeline + slow-host-startup fixes but no structural fix for "scope of plugin runtime preloads". Jumped directly to **5.2** which carries the structural fix:

- `Plugins/runtime: scope broad runtime preloads to the effective plugin ids derived from config, startup planning, configured channels, slots, and auto-enable rules instead of importing every discoverable plugin`
- `Tools/plugins: cache plugin tool descriptors captured from api.registerTool(...) so repeated prompt-time planning can skip plugin runtime loading while execution still loads the live plugin tool` (#76079)

5.2 verified: ready 7.3s first boot / 5.3s warm boot, CPU 0.23% idle, MEM 246 MiB, **zero `staging bundled runtime deps` lines on hot path**. Family-bot smoke test passed. Single 24s liveness spike on first cold-message only (Codex OAuth + 49k context hydration), idle thereafter. Full operational record in `~/openclaw/README.md` Change history (entry dated 2026-05-03 / version 5.2).

**Operational lessons retained** (these still apply for any future jump where structural fix is unproven):

- *No more two-version jumps on family-traffic gateway* unless the target version has a verified structural fix and we have a no-traffic window.
- *Stage on a non-family agent first* when uncertain.
- *Family responsiveness is the SLO.* If the operator notices latency, that is a P0 — investigate before the next upgrade ships, not after.
- *Trust the structural-fix release tag* but bench-test on a no-traffic window first. "Latest is best" was wrong for 4.24/4.25/4.26/4.29 (no fix), correct for 5.2 (fix shipped).

### 4.24 → 4.26 latency regression — wait-and-watch (2026-04-28, superseded by 5.2)

A two-version jump from 4.24 to 4.26 produced a service-quality incident on the family-traffic gateway. Operator and family reported "responses that used to come instantly now take all day." Multiple `[diagnostic] stuck session` entries with gateway PID showing **102% CPU** on a single node thread. Resolved by emergency rollback to 4.23, which was the latest known-good for both response latency *and* `gpt-image-2` Codex-OAuth image generation. Fully superseded by 5.2 structural fix above; the policy "no two-version jumps on family traffic" born in this incident remains in effect.

### GlueClaw — runtime auto-injected providers from repo presence (resolved by deletion)

OpenClaw plugin discovery walks mounted volumes. Any `openclaw.plugin.json` in a mounted path is a candidate provider. `~/repos/gh/glueclaw/openclaw.plugin.json` was re-injecting `glueclaw` / `sc` providers into every agent's `models.json` on container start, even though `641d497` had removed them at config level. Deleting the local repo broke the injection path. The GitHub fork (`junghan0611/glueclaw`) is preserved as history.

Lesson: if a provider is not wanted, the source directory must leave the mount, not just the config.
