# OpenClaw 레퍼런스 지도 — 소스 SSOT 좌표

> **이 문서는 좌표표다. 절차는 `openclaw` 스킬이 진다.**
> 새 세션이 이 파일을 저절로 읽지는 않는다 — 손이 닿는 경로는 그 스킬(과 AGENTS.md /
> nixos-config 스킬의 라우팅 줄)이다. OpenClaw를 만지기 전 첫 수(`openclaw docs`,
> `config schema`, 클론 버전 고정, config set 함정)는 스킬에 있다.

> **작성 배경**: 4개월 묵은 소스 클론을 읽고 라이브 배선을 오판한 사고(2026-09-09) 재발 방지.
> 작성 시점 사실: `~/repos/3rd/openclaw`를 `v2026.8.2`(commit `0965053fe6b`)로 고정 후 작성
> (`git log -1`: `0965053fe6b9341776df147a6934b7485c60b5ca … docs(release): finalize 2026.8.2 changelog`,
> `git describe --tags` → `v2026.8.2`). 라이브 컨테이너 `docker exec openclaw-gateway openclaw --version`
> → `OpenClaw 2026.8.2 (0965053)`, 이미지 `openclaw-custom:latest`(built 2026-09-08T09:00:34Z) —
> **소스와 라이브가 커밋 해시까지 정확히 일치**한다.
>
> **인용 원칙 — 이 문서 전체에 적용**: 파일 경로는 전부 `src/…`, `docs/…`, `apps/…` 같은 **소스** 기준이다.
> `/app/dist/*.js` 같은 빌드 산출물 경로는 인용하지 않는다 — 번들 해시가 버전마다 바뀌어 인용이 썩는다
> (실측: `heartbeat-runner-*.js`가 8.1→8.2에서 `CWkWsEqw`→`jhGs3jbv`로 바뀜, [openclaw-gotchas.md](openclaw-gotchas.md) 참고).
> dist 심볼 이름(함수명)은 종종 소스와 그대로 대응하므로, dist에서 본 함수명을 **소스에서 grep**해
> 정확한 파일:줄로 재인용하는 식으로 이 지도를 만들었다.

---

## 1. 주제별 레퍼런스 표

각 행은 "이 주제를 만질 때 여기부터 읽는다"는 뜻이다. 심볼 이름 위주로 적어 dist 재대응이 쉽게 했다.

| 주제 | 소스 경로 | 핵심 심볼 | 비고 |
|---|---|---|---|
| **설정 스키마 루트** | `src/config/zod-schema.ts` | `OpenClawSchema` (`z.strictObject(OpenClawSchemaShape).superRefine(...)`) | 앱·웹·CLI가 공유하는 표준의 **최종 진입점**. `openclaw config validate`/`openclaw config schema`가 이걸 돈다 |
| 설정 스키마 top-level 키맵 | `src/config/zod-schema.root-shape.ts` (513줄) | `OpenClawSchemaShape` | 최상위 키(`agents`,`channels`,`gateway`,`bindings`,`skills`,`plugins`,`memory`,…) → 각 서브스키마 심볼로 연결되는 지도 자체. 새 주제를 못 찾으면 여기서 키 이름부터 찾는다 |
| agents — defaults/entries 구조 | `src/config/zod-schema.agents.ts:29-88` | `AgentsSchema` | `ownership:"explicit"` 요구조건, `entries` 키 유일성, `default=true` 마커 규칙이 `superRefine` 안에 있다 |
| agents — 필드 전체(모델/heartbeat/workspace 등) | `src/config/zod-schema.agent-runtime.ts` (1056줄) | `AgentEntrySchema` | 봇 엔트리 하나가 가질 수 있는 전 필드. `heartbeat: HeartbeatSchema` 참조가 `:963` |
| agents — defaults 전용(전역 폴백) | `src/config/zod-schema.agent-defaults.ts` (258줄) | `AgentDefaultsSchema` | `heartbeat: HeartbeatSchema.unwrap()` 이 `:201` — defaults와 entry가 같은 `HeartbeatSchema`를 공유 |
| 모델 오버라이드/런타임 매핑 | `src/config/zod-schema.agent-model.ts` | (모델별 override 조각) | `agents.defaults.models["<provider/model>"].agentRuntime.id` 오버라이드가 여기 형태 — cron 회귀([gotchas.md](openclaw-gotchas.md) "8.1은 cron 경로에서 런타임 오버라이드를 잃는다") 조사 시 시작점 |
| 런타임 id 해석(“pi”=openclaw 별칭) | 소스 미확인 — dist만 확인 (`/app/dist/agent-runtime-id-*.js`, [ORACLE.md](../ORACLE.md) §런타임 지형 인용) | `OPENCLAW_AGENT_RUNTIME_ID` | ⚠️ **미확인**: 이 정확한 상수/deprecation 주석이 있는 소스 파일을 이번 조사에서 못 찾았다(런타임 id 정규화는 `src/agents/` 어딘가로 추정되나 이번 세션에서 grep 미실시). 다음 세션 숙제로 남긴다 |
| channels / accounts 스키마 | `src/config/zod-schema.channels-config.ts` (71줄), `zod-schema.channels.ts` (19줄) | `ChannelsSchema` | 채널별 `accounts.<id>` 서브객체(봇토큰·allowFrom 등)의 스키마 뼈대 |
| channel account 세부(공통 필드) | `src/config/channel-account-config.ts` | (계정 설정 헬퍼) | 텔레그램처럼 멀티계정 채널의 계정별 필드 정규화 |
| **agent ↔ channel account 바인딩** | `src/config/zod-schema.agents.ts:90-163` | `BindingMatchSchema`, `RouteBindingSchema`, `AcpBindingSchema`, `BindingsSchema` | `bindings[].match.{channel,accountId}` → `agentId` 라우팅의 **스키마**. 오늘 우리를 문 문제(텔레그램 계정↔에이전트 결선)가 정의된 자리 |
| 바인딩 헬퍼(타입 판별) | `src/config/bindings.ts` (32줄) | `isRouteBinding`, `isAcpBinding`, `listRouteBindings`, `listAcpBindings` | route vs acp 바인딩 구분 |
| 인바운드 메시지 → 에이전트 **해석 로직** (스키마 아님, 런타임) | `src/channels/conversation-resolution.ts` | `resolveInboundConversationResolution`, `resolveCommandConversationResolution`, `resolveChannelDefaultBindingPlacement` | "실제로 어느 봇이 받는가"의 실행 로직. 스키마는 위 agents.ts, 해석은 여기 |
| **heartbeat 스키마** | `src/config/zod-schema.agent-runtime.ts:74-150` | `HeartbeatSchema` | `every`,`target`,`to`,`accountId`,`session`,`directPolicy`,`activeHours`,`isolatedSession`,`lightContext`,`timeoutSeconds`,`prompt`. `.strict()` — 문서에 없는 필드는 전부 거부 |
| heartbeat 자체 문서(소스 내장, 최신) | `docs/gateway/heartbeat.md` (496줄) | — | **§3 참고. GLG가 원하는 "우리가 새로 쓸 필요 없는 자리"의 정확한 예.** config 예시, 필드 표, 배달 target 규칙(`owner`/`last`/`none`), scratch 사용법까지 전부 있다 |
| heartbeat → cron 투영(system-owned monitor job) | `src/cron/heartbeat-monitor.ts` | (모니터 잡 동기화 로직, 정확한 함수명 미확인 — dist는 `resolveHeartbeatMonitorPlan`) | config `agents.*.heartbeat` → `cron list --all`의 `Heartbeat (agent-id)` 잡으로 변환하는 지점. ⚠️ dist 함수명(`resolveHeartbeatMonitorPlan`)을 이 소스 파일 안에서 직접 grep 확인은 못 했다 — **미확인**, 다음 세션 숙제 |
| heartbeat 배달 대상 해석(owner/last/none) | `src/infra/heartbeat-*.ts` 다수(`heartbeat-wake-target.ts`,`heartbeat-delivery-normalization.ts`,`heartbeat-runner-delivery.ts`) | — | `docs/gateway/heartbeat.md` "Field notes" `target` 항목이 규칙을 이미 문서화(§3 참고). 코드로 더 들어갈 땐 이 파일들부터 |
| **cron/automation 잡 스키마 전체** | `src/cron/types.ts` | `CronPayload` (union), `CronJobPayload*`, `isSystemOwnedCronPayloadKind` | payload kind별 필수 필드의 **타입 SSOT**(zod 아님, TS 타입). 아래 §2에 kind별 표 |
| cron delivery 필드 파싱 | `src/cron/delivery-field-schemas.ts` (60줄) | `DeliveryModeFieldSchema`(`enum(["deliver","announce","none","webhook"])`), `parseDeliveryInput` | `mode:"deliver"`는 역사적 CLI 표기이고 런타임은 `announce`로 정규화(`:11-13`) |
| cron 잡 CLI/게이트웨이 계약 | `src/gateway/server-cron-contract.ts` | `GatewayCronServiceContract` | 게이트웨이가 cron 서비스에 요구하는 계약 인터페이스(스크래치 read/write, 잡 제거 트랜잭션 등) |
| **automation 사용자 문서(소스 내장)** | `docs/automation/cron-jobs.md` (1074줄) | — | payload별 CLI 플래그, 배달 모드 표, 세션 스타일(main/isolated/current/custom) 전부 문서화. §2·§3 참고 |
| gateway 인증/trustedProxies 스키마 | `src/config/zod-schema.gateway.ts` (314줄) | `GatewayConfigSchema` — `controlUi:` `:77`, `auth:` `:116`, `trustedProxies: z.array(z.string()).optional()` `:174` | `gateway.trustedProxies` CIDR 목록 스키마. 실제 프록시 신뢰 로직(어디서 소스 IP를 비교하는지)은 이번 세션에서 소스 미확인 — dist(`targets-*.js` 계열 추정)만 [openclaw-gotchas.md](openclaw-gotchas.md) "도커 네트워크가 갈리면…" 항목에 있음. **미확인** |
| plugins 스키마 | `src/config/zod-schema.root-shape.ts:485-500` | (인라인, `PluginEntrySchema` 참조) | `plugins.allow`/`deny`/`entries.<id>.enabled`/`plugins.load.paths`. `PluginEntrySchema` 자체 정의는 별도 파일(`src/plugins/config-schema.ts` 추정, 미확인) |
| skills 스키마 | `src/config/zod-schema.root-shape.ts:441-482` | (인라인, `SkillEntrySchema` 참조) | `skills.entries.<id>.enabled`, `skills.load.allowSymlinkTargets`, `skills.workshop.autonomous.mode` |
| memory 스키마 | `src/config/zod-schema.root-support.ts:117` | `MemorySchema` | `memory.search.*`(provider/model/remote.baseUrl 등). 라이브는 `provider:"openai"` + `remote.baseUrl: openrouter.ai` — **OpenRouter 종량 API를 memory search용으로만 씀**(챗봇 본선과 무관), 근거는 §4 아래 |

### 표에 못 넣은 것 — 이번 세션에서 시간 안에 못 판 것 (정직하게 미확인으로 남김)

- `plugins.entries.<id>` / `skills.entries.<id>`의 정확한 zod 스키마 정의 파일(`PluginEntrySchema`/`SkillEntrySchema` 본체) — import는 확인했으나 정의 파일까지는 못 열었다.
- heartbeat monitor 투영 함수의 정확한 소스 심볼명(`src/cron/heartbeat-monitor.ts` 안에서 dist의 `resolveHeartbeatMonitorPlan`에 대응하는 이름).
- `gateway.trustedProxies`가 실제로 요청 소스 IP와 비교되는 코드 위치(스키마는 찾았지만 판정 로직은 못 찾음).

---

## 2. cron/automation payload kind별 필수 필드

출처: `src/cron/types.ts` (union 정의) + `docs/automation/cron-jobs.md:223-343` (사용자 문서, 필드 설명 일치 확인).

| kind | 소스 타입 | 필수 필드 | CLI 생성 가능? | 비고 |
|---|---|---|---|---|
| `systemEvent` | `CronPayload` 1번째 union원 (`types.ts:305`) | `text: string` | 예 (`--system-event`) | 모델 호출 없이 메인 세션에 이벤트만 enqueue |
| `agentTurn` | `CronAgentTurnPayload`/`CronAgentTurnPayloadFields` (`types.ts:344-361`) | `message: string` | 예 (`--message`) | 선택: `model`,`fallbacks`,`thinking`,`timeoutSeconds`,`lightContext`,`toolsAllow` |
| `command` | `CronCommandPayload`/`Fields` (`types.ts:369-383`) | `argv: string[]` | 예 (`--command`/`--command-argv`) | 게이트웨이 호스트에서 프로세스 실행. 모델 호출 없음 |
| `script` | `CronScriptPayload`/`Fields` (`types.ts:386-397`) | `script: string` | 예 (`--script <file|->`) | code-mode 헤드리스 실행. `cron.triggers.enabled:false`면 생성·실행 불가 |
| `heartbeat` | `types.ts:312` (주석: *"Gateway-converged only; not accepted from client create/patch APIs"*) | (필드 없음 — 존재 자체가 신호) | **아니오** | **system-owned.** heartbeat-enabled 에이전트당 1개, 게이트웨이가 기동/reload 시 자동 생성. `cron edit`/`cron disable` 거부(`system-owned monitor jobs cannot be edited by cron clients`, [gotchas.md](openclaw-gotchas.md) 실측) |
| `skillCollectionReview` | `types.ts:315,326,331` | (필드 없음) | **아니오** | **system-owned.** `skills.workshop.autonomous.mode` (`auto`일 때만 활성; `propose`/`off`는 disabled 유지). writable workspace당 1개 |

**delivery 모드** (`src/cron/delivery-field-schemas.ts:11`, 문서 `docs/automation/cron-jobs.md:394-401`):

| mode | 뜻 |
|---|---|
| `announce` | 에이전트가 안 보냈으면 최종 텍스트를 target에 fallback 배달 |
| `webhook` | 완료 이벤트를 URL로 POST |
| `none` | runner fallback 배달 없음 |
| (`deliver`) | 레거시 CLI 표기, 런타임에서 `announce`로 정규화됨(스키마가 직접 변환) |

지금 라이브 3개 활성 cron(`cron list --all` 실측, 2026-09-09):

| 이름 | kind | delivery | 비고 |
|---|---|---|---|
| `heartbeat-bbot` | `heartbeat` | not requested | system-owned, `agents.entries.bbot.heartbeat.every="3h"`의 투영 |
| `morning-family-schedule-reminder` | `agentTurn`(추정 — `sessions.describe`류로 미교차검증, model 컬럼이 `anthropic/claude-...`인 것만 실측) | `announce -> telegram:123861330 (explicit)` | glg 에이전트, 매일 08:00 KST |
| `baron-kindergarten-dropoff-2026-09-02` | 미확인(one-shot) | 유사 announce | [openclaw-automations.md](openclaw-automations.md) 표에서만 확인, 이번 세션에서 `cron show`로 직접 안 열어봄 |

---

## 3. OpenClaw 자체 문서/스킬 면 — **여기부터 확인하고 새로 쓰지 마라**

GLG 질문에 대한 답: **있다. 셋 다 라이브에서 실제로 동작 확인했다.**

### 3-1. `openclaw docs` — 라이브 docs 검색 (실측 성공)

```bash
$ docker exec openclaw-gateway openclaw docs --help
Usage: openclaw docs [options] [query...]
Search the live OpenClaw docs
```

실제 검색 실행 결과(`openclaw docs heartbeat`)가 `docs.openclaw.ai`의 실제 페이지들
(`/gateway/heartbeat`, `/automation/cron-jobs/payloads`, `/gateway/config-agents/heartbeat-compaction-and-streaming` 등)을
스니펫과 함께 반환했다 — **소스 `docs/` 트리가 게시되는 사이트를 그대로 검색한다.** 소스 파일
경로와 게시 URL이 헤딩 단위로 쪼개져 대응한다(예: `docs/automation/cron-jobs.md`의 `## Payloads`
섹션이 게시본에서 `/automation/cron-jobs/payloads`로 나뉨).

**결론**: 새 문제를 만나면 코드부터 grep하지 말고 `docker exec openclaw-gateway openclaw docs <검색어>`를
먼저 친다. 이번 조사에서 `heartbeat`/`automation`/`payload`류는 전부 이 경로로 먼저 찾아 맞았다.

### 3-2. `openclaw skills list` — 내장 스킬 목록 (실측 존재)

```bash
$ docker exec openclaw-gateway openclaw skills list --help
Usage: openclaw skills list [options]
List all available skills
  --agent <id>   --eligible   --json   -v, --verbose
```

라이브 config의 `skills.entries`에는 46개 스킬이 `enabled:false`로 명시돼 있다(대부분 애플/맥 전용
스킬 — 이 배포와 무관). **각 봇이 실제로 로드하는 스킬 목록**은 config가 아니라 `agents.entries.<id>.skills`
배열이다(glg 엔트리에 51개 스킬명 확인, 예: `agenda`,`autholog-mend`,`bibcli`,`botlog`,…). 이 명령을
직접 실행해 라이브 판정을 받는 게 정공법 — **이번 세션에선 --help만 확인, 실제 `list --agent glg` 실행은 안 함(미확인)**.

### 3-3. `openclaw config schema` — 스키마 덤프 (실측 성공, JSON Schema)

```bash
$ docker exec openclaw-gateway openclaw config schema | python3 -c "..."
<class 'dict'> ['$schema', 'type', 'properties', 'additionalProperties', 'title']
```

**§1의 zod 스키마가 컴파일된 실제 JSON Schema를 라이브에서 직접 뽑을 수 있다.** 다음 버전으로
넘어갈 때 "무엇이 바뀌었나"를 코드 리딩 없이 판정하는 가장 빠른 방법은:

```bash
docker exec openclaw-gateway openclaw config schema > /tmp/schema-8.2.json
# 신버전 이미지로 같은 명령을 격리 실행(§4 절차) 후 diff
```

### 3-4. 소스 `docs/` 디렉터리 — 설정 레퍼런스 다수 확인

`docs/automation/`, `docs/gateway/`, `docs/reference/` 아래에 헤드리스 스크립트, 데이터베이스 스키마,
릴리즈 검증, 프롬프트 캐싱 등 운영급 레퍼런스가 이미 있다. 이번 조사로 직접 읽어 정확성을 확인한 것:
`docs/gateway/heartbeat.md`, `docs/automation/cron-jobs.md`. **나머지는 존재만 확인(§1 표 밖의
`docs/reference/*` 목록), 내용 검증은 안 했다 — 필요할 때 `openclaw docs <검색어>`로 먼저 찾을 것.**

### 3-5. 안드로이드 앱 / Control UI 의 automation 클라이언트 DTO — **있다, 그리고 스키마 갭의 정체를 여기서 확정했다**

`apps/android/app/src/main/java/ai/openclaw/app/CronJobDetail.kt:147-160`:

```kotlin
internal fun parseGatewayCronJobDetail(job: JsonObject?): GatewayCronJobDetail? {
  ...
  val payloadKind = payload.string("kind") ?: return null
  val scheduleKind = schedule.string("kind") ?: return null
  if (scheduleKind !in setOf("at", "every", "cron", "on-exit")) return null
  if (payloadKind !in setOf("systemEvent", "agentTurn", "command", "script")) return null
  ...
```

이게 **§4(부수 질문)의 답**이다 — 아래 참고.

---

## 4. 부수 질문 — `heartbeat-bbot` 상세가 "invalid automation"인 이유 (확정)

**확정: 클라이언트(Android 앱) 자동화 상세 파서의 스키마 갭이다. 게이트웨이 데이터 문제도, 버전
불일치도 아니다.** 근거는 두 파일:

1. **서버/타입 쪽**: `src/cron/types.ts:305-316` — `CronPayload` union은 `heartbeat`/`skillCollectionReview`를
   **"Gateway-converged only; not accepted from client create/patch APIs"** 라고 명시적으로 분리해둔다.
   즉 이 두 kind는 처음부터 "일반 클라이언트가 만들거나 편집하는 자동화"가 아니라 "시스템이 존재를
   보고만 하는 자동화"로 설계돼 있다.

2. **클라이언트 파서 쪽 — 여기가 실제 원인**: `apps/android/app/src/main/java/ai/openclaw/app/CronJobDetail.kt:160`

   ```kotlin
   if (payloadKind !in setOf("systemEvent", "agentTurn", "command", "script")) return null
   ```

   상세 화면 파서(`parseGatewayCronJobDetail`)는 **payload kind를 4개짜리 화이트리스트로 검사**하고,
   `heartbeat`/`skillCollectionReview`는 그 목록에 없어 **무조건 `null`을 반환**한다. 호출부
   (`NodeRuntime.kt:5906`, `loadCronJobDetailFromGateway`)는 `null`을 받으면 정확히
   `nativeText("Gateway returned an invalid automation.")`를 띄운다(문자열 실재 확인:
   `apps/android/app/src/main/java/ai/openclaw/app/i18n/NativeStringResources.kt:609`,
   `apps/android/app/src/main/res/values/strings.xml:103`).

   **대조 증거 — 목록 화면은 같은 kind를 안 걸러낸다.** `NodeRuntime.kt:7799` `parseCronJobs`(목록
   파서)는 kind 화이트리스트가 없다 — `id`/`name`만 있으면 통과한다. 프리뷰 텍스트 생성 함수
   `cronPayloadPreview`(`NodeRuntime.kt:8219-8232`)도 모르는 kind를 만나면 그냥 `"No prompt"`로
   떨어질 뿐 목록 항목 자체를 죽이지 않는다. **그래서 `heartbeat-bbot`이 목록에는 뜨는데 상세만
   깨진다** — 정확히 GLG가 관찰한 증상과 일치한다.

**게이트웨이 dist 전체에 이 문자열이 0건이었던 이유도 이걸로 설명된다** — 그 문자열은 게이트웨이가
아니라 **앱 바이너리**에 있다. `grep`을 게이트웨이 이미지에서 돌렸으니 0건이 나온 게 당연하다.

**판정에 대한 단서 하나 더**: 이 화이트리스트가 있는 `CronJobDetail.kt`의 마지막 수정 커밋은
`3a1351a3035` (`fix(cron): show script automations across user clients`, 2026-07-21) — **2026.8.x
컷오버보다 훨씬 전**이다. 즉 이건 이번 버전업이 새로 만든 회귀가 아니라, **처음부터 있던 설계
경계**(system-owned kind는 client-facing detail DTO에 없음)로 보인다. 다만 이건 소스 코드
읽기로 확인한 사실이고, **폰에 설치된 실제 앱 빌드가 이 정확한 소스 상태와 같은지는 확인하지
않았다** — [openclaw-gotchas.md](openclaw-gotchas.md)의 다른 항목에 앱이 `ui v2026.7.1`로
게이트웨이(`2026.8.2`)보다 낡아 있다는 실측이 있으므로, 이 화이트리스트 자체는 7.1 이후 안 바뀌었을
가능성이 높지만 **앱 버전 자체를 직접 대조하진 않았다.**

**결론**: 스키마 갭 맞다. 원인은 확정. 수정이 필요한지(client DTO에 heartbeat/skillCollectionReview를
읽기 전용 상세로 노출할지)는 **제품 판단이라 이 문서의 범위 밖**이다 — 사실만 확정해서 남긴다.

---

## 5. 버전업에 견디는 법

### 5-1. 스키마 SSOT — diff만 보면 되는 파일

가장 안정적인 앵커는 **덤프된 JSON Schema 자체**다(§3-3):

```bash
docker exec openclaw-gateway openclaw config schema > /tmp/schema-live.json
```

새 이미지가 나오면 같은 명령을 그 이미지로 격리 실행해 diff 뜨면 끝 — zod 소스 파일 위치가 리팩터로
옮겨져도 이 출력 구조는 안정적이다(JSON Schema는 스키마의 *산출물*이지 파일 위치가 아니므로).

소스에서 직접 diff하려면 `src/config/zod-schema.root-shape.ts`의 `OpenClawSchemaShape` 키 목록부터
비교한다 — 최상위 키가 바뀌면(추가/제거) 큰 구조 변화, 그 아래 서브스키마 파일(`zod-schema.agent-runtime.ts`
등)이 바뀌면 필드 단위 변화다.

### 5-2. 릴리즈 노트에서 뭘 보면 우리 설정이 깨지는지 알 수 있나

**정정: "breaking N건" 카운트는 이 문서 작성 중 재현하지 못했다.** 이전 세션(gotchas.md 2026-09-02
항목)이 8.1→8.2를 "breaking 0건"이라 적었지만, 이번 조사에서 conventional-commit `!:` 마커
(`git log --format='%s' v2026.8.1..v2026.8.2 | grep -c '!:'` → 0)나 `BREAKING CHANGE` 트레일러
(→ 0)로 재현되지 않았다 — 즉 그 숫자가 어디서 나왔는지 **이번 세션에서 확인 불가**. 셀 수 있는
정량 지표로 오독하지 말 것.

**대신 검증된 방법(gotchas.md 실측, 2026-09-02)은 이미지 세 상수 대조다** — 이게 재현 가능한 진짜
판정법이다:

```bash
docker pull ghcr.io/openclaw/openclaw:<새버전>
docker run --rm --entrypoint sh ghcr.io/openclaw/openclaw:<새버전> -c '
  cat /app/dist/state-migrations.doctor-*.js | grep -o -E "\"[a-z0-9-]+-v[0-9]+\"" | sort -u
  grep -o -E "OPENCLAW_AGENT_SCHEMA_VERSION = [0-9]+|targetVersion = [0-9]+" /app/dist/openclaw-agent-db-*.js
  npm --version'
```

이 dist 상수들의 **소스 SSOT**(이번 조사로 확정):

| 상수 | 소스 파일 |
|---|---|
| state migration ID 목록 | `src/infra/state-migrations.doctor.ts` |
| `OPENCLAW_AGENT_SCHEMA_VERSION` | `src/state/openclaw-agent-db-contract.ts:24` (현재 `19`) |

세 상수(state migration ID 목록, agent DB 스키마 버전, npm 버전)가 신구 이미지에서 **동일** +
`config validate`가 `Config valid`를 반환하면 **한 줄 bump**로 판정한다(§5-2 절차 전문은
[openclaw-gotchas.md](openclaw-gotchas.md) "bump가 '한 줄'인지 '마이그레이션'인지" 항목).

CHANGELOG.md(소스 루트) 구조는 `## <버전>` → `### Highlights` / `### Changes` / `### Fixes` /
`### Known issues` / `### Upcoming deprecations` / `### Complete contribution record` 순
(`CHANGELOG.md:6-152` 확인). "Upcoming deprecations" 섹션이 다음 버전에서 뭐가 없어질지 예고하는
자리이니 업그레이드 전에 그 섹션만이라도 읽을 가치가 있다 — 단 이번 세션에서 8.2 항목의 실제
deprecation 내용까지 읽진 않았다(미확인).

### 5-3. 소스와 라이브가 어긋날 때 무엇이 권위인가

**GLG 판단("동작은 라이브, 구조는 소스")에 동의한다.** 근거:

- 소스가 라이브 커밋과 정확히 일치하는 지금(§0)도, **cron list의 실제 delivery 문자열**
  (`"announce -> telegram:123861330 (explicit)"`)이나 **실제 배달 성공/실패**는 소스를 읽어서 알 수
  없고 `docker exec openclaw-gateway openclaw cron show <id>` 같은 라이브 조회로만 확정된다 — 소스는
  "가능한 배선의 모양"을, 라이브는 "지금 실제로 물린 배선"을 답한다.
- 반대로 **어떤 필드가 허용되는지, 어떤 kind가 존재하는지, 우리 config가 왜 이 모양이어야 하는지**는
  소스(zod 스키마 + 타입)가 유일한 권위다 — 라이브 config 파일 자체는 "그 스키마 아래 우리가 고른
  한 인스턴스"일 뿐이라 구조적 질문에 답을 못 준다.
- 실측으로 이 원칙이 이미 한 번 증명됐다: [ORACLE.md](../ORACLE.md) "`sessions list`의 Model 컬럼이
  표와 다르면, 표가 아니라 세션이 진실이다" — 문서(구조를 적어놓은 것)와 라이브 세션(동작 중인 것)이
  갈릴 때 라이브가 이겼다. 같은 원칙의 일반화가 "동작은 라이브, 구조는 소스"다.

### 5-4. 인용하면 안 되는 것

- `/app/dist/*.js` 파일명 전체(번들 해시 포함) — 버전마다 바뀐다. dist에서 찾은 **함수/상수 이름**만
  들고 나와 소스에서 재검색한다.
- 릴리즈 노트의 "breaking N건" 같은, 재현 방법이 불명확한 정량 지표(§5-2에서 이번에 못 살렸다).
- 이 문서 자체에 박힌 라인 번호 — 파일이 리팩터되면 줄 번호가 밀린다. **심볼 이름으로 grep해서
  재검증**하고, 안 맞으면 이 문서를 고친다(이 문서도 화석이 될 수 있다는 뜻).

---

## 부록 — 이번 조사에서 실제로 읽은 것 vs 존재만 확인한 것

**직접 읽고 인용한 것**: `src/config/zod-schema.ts`, `zod-schema.root-shape.ts`(발췌),
`zod-schema.agents.ts`(전체), `zod-schema.agent-runtime.ts`(발췌, HeartbeatSchema 전체),
`src/config/bindings.ts`(전체), `src/cron/types.ts`(발췌), `src/cron/delivery-field-schemas.ts`(전체),
`src/gateway/server-cron-contract.ts`(전체), `docs/gateway/heartbeat.md`(전체),
`docs/automation/cron-jobs.md`(발췌, §Payloads·§Delivery),
`apps/android/.../CronJobDetail.kt`(발췌), `apps/android/.../NodeRuntime.kt`(발췌 3곳),
`CHANGELOG.md`(발췌), `src/state/openclaw-agent-db-contract.ts`(1줄).

**존재만 확인(디렉터리 리스팅 또는 grep 히트만)**: `docs/reference/*` 대부분, `src/config/model-provider-config.ts`,
`src/config/types.memory.ts`, `src/config/zod-schema.core.ts`(ModelsConfigSchema 위치만),
`src/plugins/config-schema.ts` 추정(미열람).

이 구분을 지운 요약은 쓰지 않았다 — "찾았다"와 "존재를 봤다"를 섞으면 다음 세션이 또 오독한다.
