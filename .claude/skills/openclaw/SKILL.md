---
name: openclaw
description: "OpenClaw 런타임을 만질 때의 반사신경 — 봇 설정·heartbeat·cron/automation·channels·delivery·gateway를 기억이 아니라 그 버전의 사실로 다룬다. 첫 수는 언제나 `openclaw docs` / `config schema`이고, 소스는 라이브와 같은 태그로 고정한 클론에서만 인용한다. 안드로이드 앱·Control UI가 읽는 표준 스키마도 여기. 트리거: 'openclaw', '오픈클로', '봇 설정', 'heartbeat', '하트비트', 'cron', 'automation', '자동화', 'config set', '봇이 이상해', '봇 무응답', '앱에서 안 보여', 'control ui', 'payload kind', 'delivery', '채널 계정', 'accountId', '버전업', '업그레이드 후'."
user_invocable: true
---

# openclaw — 그 버전의 사실로 만지기

OpenClaw는 릴리즈마다 크게 바뀐다. **에이전트가 이 런타임에서 저지르는 사고는 거의 전부
"기억으로 찍었다" 하나다** — NixOS 설정을 옛 기억으로 만지다 뻑나는 것과 같은 병이다.
이 스킬은 그 병을 막는 절차다.

> **자리.** 이 스킬은 `nixos-config` 리포 스코프다(`.claude/skills/openclaw/`). 전역이 아니다 —
> **OpenClaw 런타임은 oracle 하나에만 있고, 담당자는 이 리포의 에이전트다.** 전역에 두면 그
> 런타임을 만질 일이 없는 형제들에게까지 손잡이가 열린다(2026-09-09 GLG 판정: *"우리만 해.
> 오라클에만 있으니까. 다 보면 안 돼."*).
>
> **경계.** 디바이스·rebuild·run.sh·배포·커밋 규율은 같은 리포의 **`nixos-config` 스킬**이 진다.
> 여기는 **OpenClaw 런타임 자체**(설정 스키마·봇·heartbeat·cron·채널·배달)만 본다.
> 둘은 일부러 분리돼 있다 — 한쪽을 안다고 다른 쪽을 안다고 생각하지 마라.

## 0. 첫 수 — 새로 쓰기 전에 이미 있는 것을 봐라

**upstream이 이미 문서화한 것을 우리가 다시 유도하지 마라.** 라이브에서 바로 돈다:

```bash
docker exec openclaw-gateway openclaw docs <검색어>   # docs.openclaw.ai 를 그대로 검색
docker exec openclaw-gateway openclaw config schema    # 라이브 JSON Schema (draft-07) 덤프
docker exec openclaw-gateway openclaw skills list      # 내장 스킬
```

`openclaw docs heartbeat` 한 줄이면 heartbeat 문서·config 예시·배달 규칙·scratch 사용법이
URL과 함께 나온다(실측 2026-09-09).

**이 절이 존재하는 이유 — 2026-09-09에 치른 값.** 우리는 오후 내내 `/app/dist/*.js`를 읽어
"배달 계정은 `heartbeat.accountId`로 지정한다"를 유도했다. 그런데 소스의
`docs/gateway/heartbeat.md:131`에 이미 이렇게 적혀 있었다:

```js
accountId: "ops-bot", // optional multi-account channel id
```

같은 문서 `:74`가 `target: owner` 폴백 순서까지 문장으로 설명한다. **먼저 봤으면 반나절이
한 줄이었다.**

## 1. 권위 — 무엇이 어느 질문에 답하는가

| 질문 | 권위 | 왜 |
|---|---|---|
| **지금 실제로 어떻게 도는가** | 라이브 런타임 (`docker exec openclaw-gateway openclaw …`, 로그) | 우리 설정·우리 데이터가 얹힌 상태는 여기만 안다 |
| **구조가 어떻게 생겼나 / 어디를 고치나** | 소스 클론 `~/repos/3rd/openclaw` — **라이브와 같은 태그로 고정된 것만** | 파일:줄로 인용 가능하고 버전이 고정된다 |
| **표준이 무엇인가**(앱·웹·CLI 공통) | `openclaw docs` + `src/config/zod-schema*.ts` | 클라이언트들이 이 스키마를 공유한다 |

셋이 어긋나면: **동작은 라이브가 옳고, 구조는 소스가 옳다.** 우리 문서가 그 둘과 어긋나면
우리 문서가 틀린 것이다.

## 2. 소스를 인용하기 전에 — 클론을 라이브에 맞춰라

**이 절차를 건너뛴 인용은 인용이 아니다.** 2026-09-09에 한 형제가 4개월 묵은 클론
(HEAD 5월, 5월부터 멈춘 rebase 얹힘)을 읽고 라이브 배선을 판정했다가 틀렸다.

```bash
docker exec openclaw-gateway openclaw --version        # 예: OpenClaw 2026.8.2 (0965053)
cd ~/repos/3rd/openclaw
git status -sb                                          # rebase/충돌 잔재부터 확인
git fetch --all --tags --prune
git rev-parse --short v<버전>^{commit}                  # 라이브 해시와 일치하는지 대조
git checkout v<버전>
```

체크아웃 전에 **잃을 게 있는지 먼저 재라**: `git rev-list --count origin/main..main`이 0이고
남은 작업이 upstream 커밋뿐이면 `rebase --abort`가 안전하다. 3rd 클론이라도 확인 없이 날리지 마라.

## 3. 인용하면 안 되는 것 — dist 번들 경로

`/app/dist/heartbeat-runner-jhGs3jbv.js` 같은 경로를 문서에 박지 마라. **번들 해시가 버전마다
바뀐다** — 같은 러너가 8.1에선 `-BAMpymke.js`, 8.2에선 `-jhGs3jbv.js`다.

읽는 것은 괜찮다(라이브 동작 확인엔 dist가 빠르다). 단 **인용할 때는 dist에서 본 함수명을
소스에서 grep해 `src/…:줄`로 바꿔 적어라.**

## 4. config를 바꿀 때 — `--merge`가 기본이 아니다

```bash
openclaw config set <path>.<leaf> '"값"'          # 하위 경로로 (권장)
openclaw config set <path> '{...}' --merge        # 객체째면 --merge 필수
openclaw config set … --dry-run                   # 먼저 이걸로
```

`config set --help`: *"Merge object/map values instead of replacing the target path
(default: false)"*. **기본이 교체다.** 객체를 통째로 주면 형제 키가 조용히 사라진다 —
우리 문서가 실제로 그 지뢰를 실었던 적이 있다(2026-09-09, 교차검수가 잡음).

대부분의 config 변경은 **hot reload로 붙는다**(로그 `config hot reload applied (<경로>)`).
등록 자체가 바뀌는 변경까지 덮는지는 미확인 — 그때만 `docker compose restart openclaw-gateway`.

라이브 설정 파일은 `~/openclaw/config/openclaw.json`이고 **커밋 대상이 아니다.**
바꾸기 전에 타임스탬프 백업을 남긴다(`openclaw.json.bak-<사유>-<YYYYmmddTHHMMSS>`).

## 5. 좌표 — 어느 주제를 어디서 보나

**주제별 소스 파일:심볼 표는 `~/repos/gh/nixos-config/docs/openclaw-reference-map.md`에 있다.**
설정 스키마 루트·agents·bindings·heartbeat·cron payload·delivery·gateway·plugins/skills/memory가
`src/…:줄`로 정리돼 있고, 미확인 항목은 미확인이라고 적혀 있다.

그중 자주 쓰는 둘:

- 설정 스키마 루트 `src/config/zod-schema.ts` (`OpenClawSchema`), 키맵 `…root-shape.ts`
- heartbeat 스키마 `src/config/zod-schema.agent-runtime.ts` (`HeartbeatSchema`, **`.strict()`** —
  문서에 없는 필드는 전부 거부된다)

## 6. 앱·웹의 automation 계약 — Android 갭을 구분한다

안드로이드 앱은 게이트웨이가 주는 automation을 **자기 파서로 다시 검증한다.** 그래서 게이트웨이가
멀쩡해도 Android에서만 깨질 수 있다. Control UI는 현재 지원하는 payload kind를 모두 읽기 전용으로
렌더하므로, Android의 파서 갭을 웹에도 일반화하지 마라.

실례(2026-09-09, v2026.8.2): `apps/android/app/src/main/java/ai/openclaw/app/CronJobDetail.kt:160`

```kotlin
if (payloadKind !in setOf("systemEvent", "agentTurn", "command", "script")) return null
```

`heartbeat`가 빠져 있어 heartbeat 잡의 **상세만** *"Gateway returned an invalid automation."*
(`NodeRuntime.kt:2990`,`:5906`)이 된다. 목록 파서는 kind를 안 걸러서 목록엔 정상으로 뜬다.

**교훈**: 앱에서 안 보인다고 게이트웨이 설정을 의심하기 전에, `openclaw cron list --json`으로
게이트웨이가 뭘 주는지 보고 앱 소스의 파서를 확인하라. 앱 소스는 이 리포 안(`apps/android/`,
`apps/ios/`, `apps/linux/`, `apps/macos/`)에 있다.

## 7. 우리 문서와 upstream 문서의 분업

겹치면 둘 다 썩는다.

| | 담는 것 |
|---|---|
| **upstream** (`openclaw docs`, 소스 `docs/`) | 제품의 표준 — 필드 의미, 기본값, 규칙 |
| **우리** (`nixos-config/docs/openclaw-*.md`) | 우리 설치본의 **상태와 함정** — 어느 봇이 무엇을 도는가, 우리가 당한 것, 우리 결정 |

새 사실을 적기 전에 물어라: *이건 제품의 사실인가, 우리 설치본의 사실인가?* 제품의 사실이면
**적지 말고 `openclaw docs`를 가리켜라.**

우리 쪽 SSOT 셋: `docs/openclaw-automations.md`(사람 없이 도는 것 전량) ·
`docs/openclaw-gotchas.md`(함정 카탈로그) · `ORACLE.md`(운영 핸드북).

## 8. 실행 전 체크 — 세 줄

```bash
docker exec openclaw-gateway openclaw --version          # 지금 어느 버전인가
docker exec openclaw-gateway openclaw docs <주제>         # upstream이 이미 답했나
git -C ~/repos/3rd/openclaw describe --tags               # 클론이 그 버전인가
```

셋 다 통과하고 나서 손을 대라. 버전업 직후라면 `openclaw config schema` 출력을 이전 버전과
diff하는 것이 "우리 설정이 깨졌나"의 가장 빠른 답이다.

## 9. 버전업 — GLG 방식 (매번 묻지 않는다)

> 2026-10-14 GLG: *"마이너 버전 업데이트 백업 롤백 준비하지 않고 게이트웨이 안돌때 하면될거야.
> 리허설 할필요 없고 이미지 가져와서 교체하는 식으로"* · *"게이트웨이 턴만 안돌고 있으면 내렸다가
> 올리는것은 상관없어"* · *"다 끝나고 알려주면돼"* · *"업데이트는 매우 중요하다."*

**첫 수는 판정이다 — 마이너인가 메이저인가.** 기준은 이름이 아니라 **선언된 스키마**다. 이미지를
받기 전에 GitHub API로 잰다:

```bash
R=repos/openclaw/openclaw; for t in v<현재> v<대상>; do
  gh api "$R/contents/package.json?ref=$t" -H 'Accept: application/vnd.github.raw' \
    | jq -c '[.version, .openclaw.schemaVersions]'; done          # {state, agent} 비교
gh api "$R/compare/v<현재>...v<대상>" -q '.status, .ahead_by, .behind_by'   # 선형(ahead, behind 0)인가
docker buildx imagetools inspect --raw ghcr.io/openclaw/openclaw:<대상>    # arm64 manifest digest
```

| 판정 | 조건 | 절차 |
|---|---|---|
| **마이너** | `schemaVersions` 동일 | **교체만.** cold archive·Doctor 리허설·복원 시험 **하지 않는다** |
| **메이저** | state 또는 agent 스키마 상승 | **이 절의 GLG 결정 범위 밖이다 — 따로 판단한다.** 선례는 게이트웨이 정지 → cold archive(tar -d 0, sha) → `--network none` 사본 리허설 → 컷오버(ROADMAP "9.8→10.2") |

선언값은 첫 판정일 뿐이다. pull한 뒤 이미지에서 실제 schema·config 파싱을 확인한다(gotchas
"bump가 한 줄인지 마이그레이션인지는 이미지를 열어라"). 선언과 실측이 어긋나면 메이저로 다룬다.

### 마이너 교체 순서 (중간 질문 없이 끝까지 간 뒤 한 번 보고)

1. **릴리즈 노트 대조** — `CHANGELOG/<ver>.md`(raw)를 우리 증상·설정과 맞춘다. PR 제목만 보고
   "직결"이라 말하지 말고 그 커밋 diff로 범위를 확인한다(10.3 #169412 과장 사례).
2. **디스크** — docker는 root(`/dev/sda2`), 운영 상태는 home(`/dev/sdb`)이다. 새 base는 압축 해제
   약 3.4GB + 커스텀 레이어 약 1GB를 root에 쓴다. `docker system df -v`의 UNIQUE로 잰다.
   이미지를 지워도 build cache가 레이어를 붙잡고 있으면 공간이 안 생긴다 →
   `docker builder prune -f --filter until=168h`.
3. **base pull은 digest로** — `Dockerfile` `ARG OPENCLAW_BASE=ghcr.io/openclaw/openclaw@sha256:<arm64>`.
   이미지 label `org.opencontainers.image.revision`이 릴리즈 SHA와 같은지 본다.
4. **로컬 hotfix 가드** — `patch-*.py`는 버전과 바이트에 고정돼 있어 새 버전에서 **빌드가 일부러
   실패한다**. upstream이 고쳤는지 소스 blob으로 확인하고, 안 고쳤으면 새 이미지 dist에서 chunk
   이름·원본 sha를 재측정해 이식한다. 미패치 bundle에서 `--baseline` GREEN, 기본 모드 RED를 확인하고,
   패치 후 기본 모드 GREEN으로 닫는다. npm dist는 Docker dist와 chunk 이름이 달라 대용하지 못한다.
5. **빌드** — 최소 컨텍스트(`.dockerignore`로 Dockerfile·hotfix만 포함)로
   `openclaw-custom:<ver>-candidate-<date>`를 만든다. config 디렉터리가 빌드 컨텍스트에 들어가지 않게 한다.
   빌드 뒤 후보 이미지로 config를 격리 파싱한다:
   `docker run --rm --network none -e OPENROUTER_API_KEY=dummy -v ~/openclaw/config/openclaw.json:/home/node/.openclaw/openclaw.json:ro …
   openclaw.mjs config validate --json`. 이때 global plugin(zai)의 "not installed" 경고는 오탐이다(gotchas 10.3).
6. **교체** — idle gate(`gateway.suspend.prepare` → `ready`, activeCount 0) → `latest` retag →
   `docker compose -p openclaw-config up -d --no-build --force-recreate openclaw-gateway`.
   기동 entrypoint가 startup Doctor를 자동으로 돌리므로 **수 분간 응답이 없는 것은 정상이고, GLG가 허용했다.**
   실측(10.3): tini ELOOP 4회 자동 회복 → RPC health ok 307초 → Docker health badge healthy 약 8분.
   badge는 3분 간격으로 늦게 따라오므로 **완료 판정은 RPC `health.ok`로 한다.**
   실패하면 이전 candidate로 retag하고 다시 recreate한다. 스크립트 선례: `~/openclaw/backups/swap-10.3-20261014/swap.py`.
7. **확인 (모델 호출 없음)** — version · RPC health · restarts 0 · Telegram 6/6 · plugins errors 0 ·
   ELOOP 0 · config diff(bookkeeping 경로만 바뀌었는가) · hotfix가 이미지에 적용됐는가. 실제 동작은
   다음 자연 cron과 실제 대화로 본다. **smoke 모델 호출은 GLG가 따로 요청할 때만.**
8. **기록** — openclaw-config(Dockerfile·hotfix·README change history)와 nixos-config 미러
   (`docker/openclaw/`) 및 문서(ORACLE 현재 버전, ROADMAP 이력, NEXT 후속). push는 GLG가 말할 때만.

### 묻는 것은 셋뿐
- **롤백 자산 삭제**(옛 이미지·백업) — 디스크가 모자랄 때 범위를 제시하고 승인을 받는다.
- **모델 호출이 들어가는 smoke**.
- **push**.

나머지는 끝까지 진행하고 **한 번에 보고**한다. 롤백 수단은 직전 candidate 이미지를 지우지 않고
두는 것이다. 스키마가 같아도 이미지만 되돌리는 롤백이 Doctor가 바꾼 config·auth까지 되돌린다는
증명은 아니다 — 그 위험을 알고 간다.
