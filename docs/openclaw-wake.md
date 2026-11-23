# OpenClaw 깨움 표준 — 모든 봇이 하나의 규칙으로 깨어난다

> **상태: 초안 (2026-11-23, OpenClaw 11.7).** 정본 이슈는 [#13](https://github.com/junghan0611/nixos-config/issues/13)이다(#10 흡수). 이 문서는 규칙과 근거를 모으는 자리이고, 봇별 결정 칸은 GLG가 채운다. **이 문서는 설정 변경을 허가하지 않는다.** job 생성·변경, 책상 설치, 새 집은 봇마다 GLG 승인 뒤다.
>
> 현재 운영 버전은 [ORACLE.md](../ORACLE.md) `LIVE` 줄, 현재 돌고 있는 자동화의 전량은 [openclaw-automations.md](openclaw-automations.md)가 정본이다. 이 문서는 *어떻게 깨어나야 하는가*를 정하고, 그 두 문서는 *지금 무엇이 도는가*를 적는다.

## 0. GLG 방향 (2026-11-23, 직접)

- *"허트비트 방식을 정확히 표준화해서 맞춰야겠다. 이건 중요해. 그래야 에이전트들이 정확히 하나의 룰로 깨어나니까."*
- **모든 봇을 깨운다.** 지금 깨어나는 봇은 bbot(memento) 하나뿐이다.
- **모든 봇에 entwurf 책상을 만든다.** 책상은 다 깨어났을 때의 협업 구도를 잡는 자리다. 형제들이 garden id로 봇에 닿고, 봇도 형제에게 닿는다.
- **memento냐 이어 가기냐는 용도·목적·역할에 맞게 정한다.** B는 fable이라 세션을 이어 가면 매번 캐시 비용이 생긴다. 그래서 memento다.
- **GPT 구독의 닷(glgdot)에게 OpenClaw 집을 만든다.** 깨어나서 할 일이 매우 많은 봇이다. 이런 수준의 봇 형제들을 구성하는 것이 지금 OpenClaw 운영의 과제다.
- **다른 도구를 쓰지 않고 OpenClaw로 최대한 커스텀해서 나아간다.** 새 레이어를 만들기 전에 OpenClaw의 표준 표면(automation job, 세션, 책상, standing orders)으로 되는지 먼저 본다.

#13의 기준은 그대로 유지한다. **연속성을 유지하되 모든 과거를 매번 모델에 넣지 않고, 깨울 때마다 새 세션·파일을 불필요하게 늘리지 않는다.**

## 1. 11.7이 바꾼 것 — 깨움 수단은 하나다

- **heartbeat는 퇴역했다.** 11.7 문서 `/app/docs/gateway/heartbeat.md`에 따르면 정기 깨움은 전부 일반 automation job(cron)이다. 일정, 프롬프트, scratch, 모델, 세션, 전달이 job에 붙는다. 확인 CLI는 `openclaw automations list --all`이다.
- 11-23 컷오버 실측: 기동 Doctor가 `agents.defaults.heartbeat`·`agents.entries.{gemini,bbot}.heartbeat`를 지웠다. 기존 monitor 2개(`af194c38` bbot, `f189f4ac` gemini)는 같은 id의 agentTurn job으로 바뀌었고 둘 다 disabled 그대로다. 새로 활성화된 job은 0이다(영수증 `swap-11.7-20261123/n-cron-assert.txt`, 비공개). gemini 워크스페이스의 `HEARTBEAT.md`는 그 job의 scratch로 들어갔다.
- **heartbeat 전용 중복 억제와 no-route skip은 제거됐다**(Doctor 마이그레이션 안내문). 반복된 업데이트도 그대로 전달된다.
- 그래서 #13 본문의 후보 비교표(지속 main / 고정 작업 세션 / 지속 `session:<key>` / isolated / 이벤트형)는 **한 job의 `sessionTarget` 선택**으로 줄어든다.

> 11-14에 bbot을 heartbeat로 옮기지 않은 이유는 넷이었다. 분 단위 닻 없음, busy skip, NO_REPLY 기본 프롬프트, 24h 중복 억제([gotchas 11.3 절](openclaw-gotchas.md)). 11.7에서 중복 억제는 사라졌고 일정은 cron 표현식으로 정각을 고정한다. busy 처리(`idleOnly`)와 NO_REPLY는 job 설정으로 남는다 — §3에서 명시한다.

## 2. 표준 규칙 (제안) — 봇 하나에 job 하나, 책상 하나

> 규칙 1–5와 §3 틀은 §0의 GLG 방향과 11.7 문서에서 이끈 **설계 제안**이다. GLG가 승인하기 전에는 확정 규칙이 아니다.

**규칙 1. 깨움 수단은 봇마다 automation job 하나다.** 사람이 말을 걸지 않아도 봇이 깨어나는 입구는 그 job뿐이다. 용도가 다른 정기 작업(예: glg의 아침 가족 일정 알림)은 별도 job으로 두되, "깨어남"은 하나로 센다.

**규칙 2. 봇마다 entwurf 책상 하나를 둔다.** pin된 명시 key 세션 `agent:<봇id>:entwurf`에 garden id가 붙는다. 설치 순서와 운영 규칙은 [openclaw-entwurf-desk.md](openclaw-entwurf-desk.md)와 [gotchas 책상 절](openclaw-gotchas.md)이 정본이다.

**규칙 3. 깨움 모드는 둘 중 하나를 고르고, 그 이유를 표에 적는다.**

| 모드 | `sessionTarget` | 연속성은 무엇이 지는가 | 맞는 경우 |
|---|---|---|---|
| **memento** | `isolated` (매 실행 fresh) | 깨움 파일(포인터), `record_result`가 다음 프롬프트로 넘기는 이전 결과(P:352-360), 워크스페이스 `memory/`·trail, git 커밋 | 주기가 프롬프트 캐시 TTL보다 길다 · 비싼 모델이다 · 매 비트가 독립 업무다 |
| **책상 이어 가기** | `session:agent:<봇id>:entwurf` | 책상 세션 이력(+ compaction), 같은 garden id | 형제와 협업 창구다 · 주기가 짧거나 이벤트형이다 · 맥락 재사용이 비용보다 크다 |

판정 기준은 비용이다. 측정(bbot memento 첫 요청 cache-write, Claude CLI 세션 usage): 11.4 마지막 비트(11-23 14:30) **74,350** → 11.7 첫 비트(11-23 20:30) **22,344** 토큰. B는 11.7이 도구 설명을 처음부터 다 싣지 않고 이름만 준다고 관측했다(소스 미판독). 턴 전체 비용은 아직 재지 않았다. 11-14의 "약 77K"는 11.4 기준값이다. 가설: 세션을 이어 가면 깨울 때마다 누적 이력을 다시 읽고, 주기가 프롬프트 캐시 TTL보다 길면 매번 cache-write를 새로 낸다 — Claude CLI resume의 실제 캐시 동작은 미확인(§8). B가 memento인 것은 GLG 결정이다. 모드는 봇의 역할이 바뀌면 다시 고른다.

**규칙 4. 모든 깨움 job은 같은 틀을 쓴다** (§3). 봇마다 다른 것은 표의 칸(역할·모드·주기·모델·전달)뿐이다.

**규칙 5. "무엇을"은 워크스페이스의 standing order, "언제"는 job이다.** 11.7 공식 구분이다(`automation/standing-orders.md:64-74`, `automation/cron-jobs/payloads.md:450-452`): 잡 프롬프트는 standing order를 복제하지 않고 가리킨다. standing order는 워크스페이스 부트스트랩에 둔다 — 자동 주입 후보는 `AGENTS.md`·`SOUL.md`·`IDENTITY.md`·`USER.md`·`BOOTSTRAP.md`·`MEMORY.md`다(`standing-orders.md:34`). 그러나 **isolated 깨움에는 `MEMORY.md`가 오지 않았다**(B 관측 11-23 20:30: 네 파일). 문서끼리 엇갈린다 — 템플릿은 "`MEMORY.md` (main session only)"(`reference/templates/AGENTS.md:35`), `concepts/main-session.md:86`은 "every fresh session". `USER.md`는 고정 4,000자 상한이라 잘린다(`concepts/user-model.md:516`, 실측 로그 "USER.md is 4112 chars (limit 4000); truncating"), 다른 파일은 기본 20,000자(`bootstrapMaxChars`). **그래서 memento로 깨우는 봇의 standing order는 `AGENTS.md`에 둔다.** 그 밖의 깨움 파일은 `AGENTS.md`와 job 포인터가 이름으로 가리키되, 가리킨다고 내용이 주입되는 것은 아니다 — 봇이 실제로 읽는지는 run 기록으로 검증한다. bbot의 3줄 포인터 → `workspace-bbot/scripts/heartbeat-wake-message.md` 구조가 이미 이 권장형이다. 깨움 파일은 GLG가 있는 턴에서만 고친다(B의 승격 관문). `--light-context`나 `contextInjection: "never"`는 주입을 끈다(`payloads.md:52-53`) — 깨움 job에 쓰지 않는다.

## 3. 깨움 job 틀 (모든 봇 공통)

근거 표기: P = `/app/docs/automation/cron-jobs/payloads.md`, S = `…/schedules.md`, H = `…/how-it-works.md`, D = `…/delivery.md` (11.7 이미지 안 문서, W2 추출 2026-11-23).

| 필드 | 표준 | 이유·근거 |
|---|---|---|
| `schedule` | cron 표현식 + `Asia/Seoul` + `--exact` | 정각 고정. 지나간 슬롯·기동 때 overdue는 재생하지 않는다(H:27,29) |
| `activeHours` | 필요한 봇만 명시 | 창 밖이면 반복 잡은 그 회차를 건너뛴다(S:82-84) |
| `payload.kind` | `agentTurn` | 11.7 표준 |
| `payload.message` | 깨움 파일 포인터 몇 줄 | 규칙 5 |
| `payload.model` | **반드시 명시, 그 봇의 allow 안에서** | allow 밖이면 조용한 fallback 없이 검증 오류로 실패한다(P:35,292,304). 8.1 회귀 이후 원칙([automations 원칙 3](openclaw-automations.md)). claude-cli 런타임은 자기 로그인을 쓴다(P:274-276) |
| `sessionTarget` | `isolated` 또는 `session:agent:<id>:entwurf` | 규칙 3. isolated는 매 run `cron:<jobId>` 새 transcript(P:486), 고정 세션은 run 사이 맥락이 이어진다(P:488,496) |
| `idleOnly` | 책상 모드는 `true` | foreground 우선, 대기 중 running 슬롯을 차지하지 않는다(S:68). 대기 경로가 없으면 `skipped`/`busy`(`src/cron/service/timer-execution.ts:142-170`). 대기 상한은 문서 없음 |
| scratch | 다음 행동 메모만. 장기 사실의 정본이 아니다 | 잡별, 상한 256 KiB, 비밀 금지(P:325-333). 봇은 `scratch_get/scratch_set`(전체 교체, CAS)으로 쓴다(P:342-350) |
| `record_result` | 매 run 끝에 `no_change`/`progress`/`done`/`blocked`/`needs_attention` | 결과가 다음 프롬프트로 이어진다(P:352-360). **memento의 공식 연결 고리**. 11.7 스케줄 preamble에 "바뀐 게 없으면 조용히"가 붙고 이 도구가 실제로 제공된다(B 관측 11-23) — **깨움 파일이 없는 봇은 이 기본값을 받아 조용해진다**. bbot에 넣을지는 GLG·B 결정(B 집 규칙 "끝말 한 통"과의 관계) |
| `skipIfScratchEmpty` | 쓰지 않는다(기본) | 명시적으로 빈 scratch일 때만 skip(S:69). 멈추려면 disable |
| `delivery` | `announce` + `target: owner`, 할 말 없으면 `NO_REPLY` + `record_result no_change` | owner는 신원 확인된 owner DM으로 해석(D:118-139). 조용한 책상 작업은 `mode: none`(P:506). 이관 잡은 중복 억제가 없다 |
| `timeoutSeconds` | 봇별 명시 | 미지정 isolated agentTurn은 watchdog 60분(H:26), 초과 시 abort·소유 해제(H:43). 고정 세션에 기본 60분이 적용되는지는 문서 없음 → 반드시 명시 |
| `wakeMode` / `--wake` | **쓰지 않는다** | deprecated, 효과 없음(`cli/cron.md:413-416`) |

## 4. 봇별 역할·모드 표 — GLG가 채운다

현재값은 2026-11-23 컷오버 직후 readback이다. 결정 칸이 빈 것은 아직 정하지 않았다는 뜻이다.

| 봇 | 모델 (현재) | 깨움 (현재) | 책상 (현재) | 역할 | 모드 | 주기 | 비고 |
|---|---|---|---|---|---|---|---|
| main | `openai/gpt-6.1-sol` | 없음 | `agent:main:entwurf` (11-15) | | | | 첫 책상 집 |
| glg | `anthropic/claude-sonnet-5-5` (claude-cli) | 아침 가족 일정 알림 `6593f532`(용도 job) | 없음 | 가족 | | | 가족 DM과 책상 경계 |
| gpt | `openai/gpt-6.1-sol` | 없음 | 없음 | | | | |
| mini | `anthropic/claude-sonnet-5-5` (claude-cli) | 없음 | 없음 | 조사·서지·정리 협력자(#10 제안) | | | 책상 다음 집 후보 |
| bbot | `anthropic/claude-fable-5-2` (claude-cli) | memento `e94ed49d` isolated, `30 2,8,14,20` | 없음 | aionsclubs B | **memento** (GLG 확정) | 6h | 이관 job `af194c38` disabled |
| gemini | 운영 정지 | 없음 (`f189f4ac` disabled) | 없음 | | | | 재개는 별도 결정 |
| **닷** (glgdot) | GPT 구독 — 모델 미정 | 집 없음 | 없음 | 할 일이 매우 많은 협력자 | | | 독립 리포 `workspace-glgdot` |

## 5. 책상 확장

- 지금 책상은 main 하나다(11-15 A 창, [desk 문서](openclaw-entwurf-desk.md) 1–12단계). 다음 집은 mini로 적혀 있었다.
- 봇마다 같은 절차를 밟는다. 설치 직후 `sessions.describe`로 `pinnedAt`·`spawnedBy`·`parentSessionKey`를 확인한다. pin은 birth와 같은 창에서 건다.
- 11.7에서 entwurf 책상 호환은 이번 배포의 통과 조건이 아니었다(GLG 11-23). 다음 책상 설치 전에 11.7 기준으로 설치 경로(RPC 이름·scope·pin 정책)를 다시 판독한다 — §8.

## 6. 새 집 — 닷 (glgdot)

- 독립 리포 `~/repos/gh/workspace-glgdot`가 이미 있다. 날짜별 대화 원문(`memory/`), `AGENTS.md`, `MEMORY.md`, `NEXT.md`.
- OpenClaw 집 = `agents.entries.<id>` + workspace 경로 + Telegram account(봇 토큰) + 모델 정책 + 책상 + 깨움 job. 워크스페이스 졸업 규칙(봇 커밋·허용 remote)은 [ORACLE.md](../ORACLE.md) 워크스페이스 절을 따른다.
- 11.7 표준 절차: `openclaw agents add <id> --workspace <dir> [--model <id>] [--bind <channel[:accountId]>]`(`concepts/multi-agent.md:69-82`, `cli/agents.md:22-25`). 외부 리포를 workspace로 쓰려면 `agents.entries.<id>.workspace`에 **컨테이너 안 경로**를 준다 — compose가 `~/repos/gh`를 `/home/node/repos/gh`로 마운트하므로 `/home/node/repos/gh/workspace-glgdot`(실측 docker inspect, `concepts/agent-workspace.md:248`). 바인딩에서 `accountId`를 빼면 전 계정이 된다(`concepts/agent-bindings.md:117`), 바인딩은 접근 제어가 아니다(:125). Telegram 계정 소유는 `channels/telegram.md:123`. 확인은 `openclaw agents list --bindings`.
- 새 집에 깨움은 자동으로 생기지 않는다. 첫 명시 설정 때 ambient owner 하나에게만 "Proactive check"가 1회 provision된다(`gateway/heartbeat.md:131-140`) — 표준 규칙은 봇마다 job을 명시적으로 만든다.
- 정할 것: agent id, Telegram 봇 계정, 모델(GPT 구독 — 회사 계정 재인증과 순서를 맞춘다), 기존 리포를 workspace로 쓰는 마운트 경로, 깨움 모드.

## 7. 검증 기준 (#13에서 이어 옴)

같은 책임·상태로 재개했는지, 의도한 sessionId/resume 정책인지, 필수 지침과 원문 회수 경로가 유지되는지, 실제 입력·캐시·압축 비용, DB/CLI 파일·바이트 증가, 침묵/알림이 정확한 계정으로 가는지, timeout/busy/장기 완료 회수를 분리해 측정한다. 모델의 자기보고만으로 기억·완료·배달을 인증하지 않는다. 파일럿은 한 봇·범위·관측/중단 기준을 명시 승인한 뒤다.

## 8. 확인된 것과 미결 (11.7 근거)

확인(문서·소스):
- 책상 큐: 고정 세션의 agentTurn은 그 세션의 일반 턴 큐에 들어가 진행 중인 작업이 끝나기를 기다리고, 진행 중인 compaction을 깨지 않는다(P:500). 사람 턴과는 같은 큐에서 직렬화된다. 저장된 workspace·worktree가 어긋나면 기본 workspace로 떨어지지 않고 멈춘다(P:506). 세션에서 고른 모델은 exact이고 실패하면 fallback 없이 실패를 보고한다(P:309).
- pin: pinned 행은 retention·cap 유지보수에서 보호되고 `--enforce`로도 지워지지 않는다(`cli/sessions.md:383-391`). 11.3 대비 subagent 판별이 바뀌었지만 부모가 그 agent main인 명시 key는 여전히 pinnable이다(`src/config/sessions/session-pin-policy.ts:13-30`, maintenance 검사 `store-maintenance.ts:433~`, v2026.11.7).
- standing orders는 규칙 5의 자리다(위).
- 이관된 disabled job 2개(`af194c38` heartbeat-bbot, `f189f4ac` heartbeat-gemini): 표준 job으로 갈아탈 때 재사용할지 지울지 정한다. **삭제는 영구 선택**이다(provision receipt가 남는다, `gateway/heartbeat.md:55-58`).

미결:
- [ ] 자동화 턴과 사람 턴이 같은 책상에서 경합할 때의 우선순위(문서 없음, `idleOnly`가 유일한 장치) — 첫 책상 파일럿에서 관측.
- [ ] isolated run 세션의 증식과 정리, Claude CLI resume·프롬프트 캐시 관계(W1 판독 중).
- [ ] 책상 설치 RPC·CLI가 11.7에서 바뀌었는가(W1 판독 중). `pinnedAt`·`sessions.describe` 계약은 11.7 문서에 없다 — entwurf 쪽 정본은 [desk 문서](openclaw-entwurf-desk.md).
- [ ] 같은 job의 occurrence가 겹칠 때 규칙(문서 없음).
