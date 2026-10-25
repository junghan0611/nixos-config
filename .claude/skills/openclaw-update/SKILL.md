---
name: openclaw-update
description: "oracle OpenClaw 게이트웨이 버전업을 할 때 딱 이것만 본다 — 마이너/메이저 판정, GLG 방식의 교체 순서, 매번 밟았던 함정과 그 해석. 자동화가 아니라 헛발질 방지가 목적이다. 읽기 전용 점검 스크립트 둘(preflight·verify, fail-closed)만 있고, 교체 자체는 사람이 단계마다 확인하며 한다. 트리거: 'openclaw 업데이트', '버전업', '업그레이드', '새 릴리즈 나왔다', '10.x 올리자', 'bump', '이미지 교체', 'swap', 'ELOOP', 'health starting', '업데이트 후 이상'."
user_invocable: true
---

# openclaw-update — 버전업할 때 보는 한 장

> 2026-10-14 GLG:
> - *"마이너 버전 업데이트 백업 롤백 준비하지 않고 게이트웨이 안돌때 하면될거야. 리허설 할필요 없고 이미지 가져와서 교체하는 식으로"*
> - *"게이트웨이 턴만 안돌고 있으면 내렸다가 올리는것은 상관없어"* · *"다 끝나고 알려주면돼"*
> - *"다 자동화 할필요 없다. 자동화하면 터지니까 그냥 헛발질 안하게하는게 중요하다."*

이 스킬은 **절차서와 함정표**다. 스크립트 둘은 사실을 출력할 뿐 아무것도 바꾸지 않는다. pull·빌드·교체는
아래 명령을 **한 단계씩 결과를 보고** 실행한다. 런타임 설정·스키마 일반은 `openclaw` 스킬, 디바이스·커밋
규율은 `nixos-config` 스킬이 진다.

스크립트는 측정이 하나라도 빠지면 통과시키지 않는다(fail-closed). 스크립트를 고치면 오프라인 fixture를 먼저 돌린다:
`python3 -I {baseDir}/scripts/selftest.py` — docker·gh·curl을 가짜로 바꿔 끼우고 실패 시나리오의 exit 코드를 단언한다.
런타임·네트워크·모델은 건드리지 않는다.

**현재 운영 중지 정책이 과거 검수 예보다 우선한다.** [ORACLE.md](../../../ORACLE.md)의 provider/계정/자동화 가용성을 먼저 읽는다. ZAI·xAI와 Gemini 입력이 정지된 상태에서 과거의 `zai: loaded`·Telegram6계정 기준을 맞추려고 재활성화하지 않는다. 다음 버전업은 보류 중이며, 재개할 때 검수 도구/fixture의 플러그인·계정 기대 계약부터 별도 검토한다. 검증 실패를 숨기거나 안전 게이트를 약하게 만들어 통과시키지 않는다.

## 0. 판정 — 마이너 후보인가

```bash
python3 -I {baseDir}/scripts/preflight.py <대상버전>      # 예: 2026.10.3 — 읽기 전용
```

다음을 출력한다:
- live 버전(형식 검증)과 대상의 선언 `schemaVersions`(state/agent 정수)
- compare: `ahead` 또는 `identical`이고 behind 0이어야 한다
- arm64 digest와 label revision이 대상 태그 커밋과 같은지
- Dockerfile 핀, hotfix 가드 버전, root/home 디스크와 docker 사용량(정보)

| exit | 판정 | 할 일 |
|---|---|---|
| **0** | **마이너 후보** — 선언 스키마가 같다 | §1로 간다. 후보일 뿐이다: config·auth·plugin·권한 계약은 §1-1 릴리즈 노트와 §1-6 격리 파싱이 따로 확인한다 |
| **3** | **메이저** — state/agent 스키마가 다르다 | **GLG 마이너 규칙의 범위 밖 — 따로 판단한다.** 선례: ROADMAP "9.8→10.2"(정지 → cold archive → `--network none` 사본 리허설 → 컷오버) |
| **1** | **FAIL** — 뒤처짐·분기, arm64 manifest 없음, label≠태그 커밋 | 멈추고 보고한다. pull·빌드하지 않는다 |
| **2** | **UNKNOWN** — 버전·스키마·compare·커밋 중 측정 실패 | 추측하지 않고 보고한다. 선언이 없는 것도 여기다 |

선언값은 첫 판정일 뿐이다. pull한 뒤 이미지에서 schema와 config 파싱을 다시 확인하고, 어긋나면 메이저로 다룬다.

## 1. 마이너 교체 순서

1. **릴리즈 노트를 우리 증상과 대조한다** — `CHANGELOG/<ver>.md`(raw). PR 제목만 보고 "고쳐졌다/직결"이라 하지 말고
   그 커밋의 diff로 범위를 본다. config·auth·plugin·권한 계약이 바뀌면 마이너 후보라도 멈추고 보고한다.
2. **디스크** — docker는 root(`/dev/sda2`), `~/openclaw`는 home(`/dev/sdb`)이다. 10.3 때는 새 base가 압축 해제로 약 3.4GB,
   커스텀 레이어가 약 1GB를 root에 썼다(관측값). 10.4는 df 기준으로 pull에 3.65GB, build에 1.10GB를 썼다. 옛 롤백 이미지 삭제는 GLG에게 범위를 제시하고 승인받는다.
3. **base pull은 digest로**
   ```bash
   docker pull ghcr.io/openclaw/openclaw@<arm64 digest>
   docker image inspect …@<digest> --format '{{index .Config.Labels "org.opencontainers.image.version"}} {{index .Config.Labels "org.opencontainers.image.revision"}}'
   ```
   `~/openclaw/Dockerfile`의 `ARG OPENCLAW_BASE=…@sha256:<digest>` 한 줄을 바꾸고, 이력 주석 1~2줄을 남긴다.
4. **hotfix 가드 이식** — `patch-memory-cron-parent.py`는 버전·바이트에 고정돼 있어 새 버전에서 **빌드가 일부러 실패한다**.
   - 먼저 대상 소스 파일의 blob을 이전 버전과 비교한다(`gh api repos/openclaw/openclaw/contents/<path>?ref=v<ver> -q .sha`).
     **같은 blob이면 미수정 근거**다 → 이식한다. **blob이 바뀌었다고 upstream이 고친 것은 아니다** → 미패치 새 base
     bundle에서 기본 모드 검출기를 돌려 **GREEN일 때만** 패치를 회수한다. RED면 이식한다.
   - 이식은 **새 이미지 dist에서** 다시 잰다(`docker run --rm --network none --entrypoint sh <base> -c …`):
     chunk 이름, 원본 sha, helper sha, import 줄 개수. 결과 sha는 변환을 적용해 계산한다.
   - 미패치 base에서 테스트를 두 번 돌린다. `--baseline`(characterization)은 **GREEN**, 기본 모드는 **RED**여야 한다.
     패치 후 빌드 안에서 기본 모드 **GREEN 10/10**.
   - npm tarball dist는 Docker dist와 chunk 이름이 달라 **대용할 수 없다**.
5. **빌드** — config가 컨텍스트에 들어가지 않게, 최소 컨텍스트(임시 디렉터리에 Dockerfile·patch·test·`summarize-bot.sh` + `.dockerignore`; Dockerfile의 COPY 대상 전부 포함)에서 빌드한다:
   `docker build -t openclaw-custom:<ver>-candidate-<date> .`
   로그에서 `claude --version`, `…applied/verified`, `10 behavior assertions passed`를 확인한다.
6. **config 격리 파싱** — 바꾸지 않고 읽기만 한다:
   ```bash
   docker run --rm --network none -e OPENROUTER_API_KEY=dummy \
     -v ~/openclaw/config/openclaw.json:/home/node/.openclaw/openclaw.json:ro \
     --entrypoint node openclaw-custom:<ver>-candidate-<date> openclaw.mjs config validate --json
   ```
   이어서 비교용으로 `openclaw.json`을 영수증 디렉터리에 `openclaw.json.pre-swap`으로 복사해 둔다. 쓰기 **전에** 권한을 정한다
   (뒤늦은 chmod는 잠깐 644로 노출된다):
   ```bash
   umask 077; R=~/openclaw/backups/swap-<ver>-<date>; mkdir -p -m 700 "$R"
   cp ~/openclaw/config/openclaw.json "$R/openclaw.json.pre-swap"
   ```
7. **교체** — 게이트웨이에 턴이 없을 때. 단계마다 결과를 보고 다음으로 간다.
   ```bash
   umask 077; R=~/openclaw/backups/swap-<ver>-<date>      # §1-6에서 700으로 만든 비공개 영수증 자리
   docker exec openclaw-gateway openclaw gateway call gateway.suspend.prepare --json \
     --params '{"requestId":"swap-<ver>","terminalPolicy":"preserve"}' > "$R/suspend-prepare.json"
   #   status=ready · activeCount=0 · blockers 비어 있음 — 셋 다일 때만 진행. 보낸 requestId도 같은 영수증에 적어 둔다.
   docker tag openclaw-custom:<ver>-candidate-<date> openclaw-custom:latest
   cd ~/openclaw && docker compose -p openclaw-config up -d --no-build --force-recreate openclaw-gateway
   docker exec openclaw-gateway openclaw gateway call health --json   # ok:true 가 나올 때까지 15초 간격으로
   docker exec openclaw-gateway openclaw --version                    # 대상 버전인지
   docker inspect openclaw-gateway --format '{{.Image}}'              # candidate의 Id와 같은지 (verify --image가 다시 대조)
   ```
   - **suspend 응답을 버리지 않는다.** 풀 때는 그 응답의 `suspensionId`가 필수다(resume 스키마가 `suspensionId` 하나만 받는다):
     `docker exec openclaw-gateway openclaw gateway resume <suspensionId>`. ready가 아니면 이걸로 풀고 나중에 다시 한다.
     10.3에서는 recreate 뒤 새 프로세스에 suspend가 남지 않았다(관측).
   - **RPC 대기에는 deadline을 둔다** — 10.3 때 20분. 10.2·10.3·10.4의 RPC 준비는 recreate부터 350초·307초·371초였다(관측값, 보장 아님).
     다음 중 하나면 **멈추고 판단한다**(자동 롤백하지 않는다): deadline 경과 · `health.ok` 뒤에도 RestartCount가 계속 는다 ·
     ELOOP나 새 에러 줄이 이어진다.
   - **중단·롤백은 상태부터 본다.** 그 사이 새 게이트웨이가 이미 떠서 턴을 받고 있을 수 있다. 무조건 다시 recreate하지 않고
     `docker inspect`·RPC health로 상태를 확인한 뒤, 롤백 recreate도 같은 idle gate(suspend.prepare → ready)를 거친다.
     롤백 = 이전 candidate로 `latest`를 다시 태그하고 같은 `up` 명령.
   - prepare 응답 파일은 umask 077 아래서 써서 처음부터 600이다.
   - 10.3 때 썼던 비공개 감싼 스크립트 `~/openclaw/backups/swap-10.3-20261014/swap.py`는 복구 사본 정리로 폐기됐다. 현행 실행/복구 수단으로 찾거나 그 파일에 재현을 의존하지 않는다. 당시 영수증과 지금의 승인된 정본 절차는 다른 것이다.
8. **확인 (모델 호출 없음)**
   ```bash
   python3 -I {baseDir}/scripts/verify.py --receipts ~/openclaw/backups/swap-<ver>-<date> \
     --image openclaw-custom:<ver>-candidate-<date>                     # 읽기 전용
   ```
   - exit 0 = 필수 항목 전부 PASS · 1 = FAIL 있음 · 2 = UNKNOWN 있음(필수 측정 누락 또는 사람 판단 필요). 0이 아니면 완료가 아니다.
     `--receipts`·`--image`를 빼면 그 비교가 UNKNOWN이 된다 — 교체 판정용으로는 둘 다 준다.
   - 보는 것: 버전 형식, 컨테이너 running, 실행 중 이미지 Id = candidate Id, RPC `health.ok`, Telegram 연결 수 = `--accounts`(기본 6), 플러그인 errors/unavailable 빈 값,
     eventLoop, deliveryQueues.failed가 비었거나 6월 tombstone과 정확히 같음, 필수 플러그인 상태(codex disabled 포함),
     hotfix 파일 전체 sha(패치 스크립트의 `VERSION`·`PATCHED_SHA`·`HELPER_SHA256`과 대조 — 마커 존재만으로는 무결성이 아니다),
     `codex.enabled:false`, pre-swap 대비 config 변경 경로, cron consecutiveErrors, 서빙 8+3, comments ping(본문은 출력하지 않는다).
   - config 경로가 하나라도 바뀌면 UNKNOWN이고 **경로 이름만** 출력한다. Doctor bookkeeping인지는 사람이 판정한다 — 자동 허용 목록은 없다.
     패치 스크립트가 없으면 UNKNOWN이다. hotfix 회수는 §1-4의 GREEN 확인을 거친 결정이지 파일이 없어진 상태가 아니다.
   - 실제 동작은 다음 자연 cron과 실제 대화로 본다. 모델을 부르는 smoke는 GLG가 요청할 때만 한다.
9. **기록** — 순서대로:
   - openclaw-config: Dockerfile, patch, README change history
   - nixos-config: `docker/openclaw/` 미러 3종, ROADMAP 이력, ORACLE 현재 버전·롤백, NEXT 관찰, gotchas 새 함정
   - 로컬 커밋도 `commit` 스킬 규율(범위·hook)을 따른다. **push는 GLG가 말할 때만** 한다.

**묻는 것은 셋뿐이다**: 롤백 자산 삭제 · 모델 호출 smoke · push. 나머지는 끝까지 진행하고 한 번에 보고한다.
단, 이 규칙은 **승인된 마이너(preflight exit 0)이고 각 단계가 위에 적힌 결과를 낼 때**만 적용한다. preflight·verify의
FAIL/UNKNOWN, 릴리즈 노트의 계약 변화, §1-7 중단 기준, 함정표에 없는 증상이면 그 자리에서 멈추고 보고한다.
롤백 수단은 직전 candidate 이미지를 지우지 않고 두는 것이다. 스키마가 같아도 Doctor가 바꾼 config·auth까지
되돌린다는 증명은 아니다 — 그 위험을 알고 간다.

## 2. 함정표 — 증상 → 뜻 → 할 일

숫자는 9.8·10.2·10.3·10.4에서 **관측한 값**이다. 허용 범위나 보장이 아니다. "기존 증상"으로 넘기려면 영수증의 이전 관측과
**같은 대상·같은 메시지인지 비교**한 뒤에만 넘긴다.

| 증상 | 관측과 뜻 | 할 일 |
|---|---|---|
| recreate 직후 `[FATAL tini] exec tini failed: Too many levels of symbolic links` | 9.8: 3회, 10.2: 0회, 10.3: 4회, 10.4: 0회. 원인 미확인 — 0회는 관측일 뿐 수정 판정이 아니다 | RPC `health.ok` 뒤 RestartCount가 더 늘지 않는지 본다. 계속 늘거나 새 에러가 이어지면 §1-7 중단 기준 |
| 수 분간 응답 없음 | entrypoint가 startup Doctor를 자동 실행한다. 350초(10.2)·307초(10.3)·371초(10.4)는 recreate부터 RPC 준비까지의 **전체 시간**이지 Doctor 단독 소요가 아니다 | §1-7 deadline 안에서 기다린다. GLG가 허용했다 |
| Docker `health: starting/unhealthy`가 오래 감 | healthcheck 간격이 3분이라 badge가 늦게 따라온다(10.3: RPC ok 뒤 약 3분) | 완료 판정은 **RPC `health.ok`**와 verify. badge로 판정하지 않는다 |
| 이미지를 지웠는데 `df`가 그대로 | BuildKit cache가 레이어를 붙잡을 수 있다. 10.2 이미지 삭제 때는 df 이득이 40KiB였고, 캐시 레코드의 shared 전환을 관측했다. base layer는 `from local` 레코드(빌드 시점, 각 0B 표기)가, 빌드 layer는 exec 레코드가 단독 보유로 바뀌었다. 그래서 reclaimable 값은 과소 표기다 | `docker system df`로 Build Cache부터 재고, `docker buildx du --verbose`로 rmi 전후 shared 전환 레코드를 대조한다. 10.3에서 쓴 `docker builder prune -f --filter until=168h`(2.05GB)는 **관측된 회수 기법일 뿐 자동 허용 명령이 아니다** — 공유 빌드 캐시라 범위를 제시하고 GLG 승인 후 |
| 빌드가 `hotfix requires OpenClaw <ver>`로 실패 | 의도된 fail-closed | §1-4 이식. 가드를 약하게 만들지 않는다 |
| 격리 `config validate`에 `plugins.entries.zai: plugin not installed` | 10.2·10.3에선 zai가 이미지가 아니라 live state `~/.openclaw/extensions/zai`의 global plugin이라 생긴 오탐이었다 | 현재 승인된 설치/중지 정책과 대조한다. 운영 정지된 zai를 과거의 `loaded`로 수선하지 않는다. 검수 도구의 기대 계약도 먼저 확인한다. 다른 플러그인 이름이면 오탐으로 단정하지 않는다 |
| Doctor 경고 "Codex runtime is selected, but the Codex plugin is disabled"(main·gpt 6.1-sol) | 9.8 이후 기존 상태. 턴은 openclaw 런타임으로 떨어진다 | `plugins.entries.codex.enabled:false`를 **지우지 않는다**. 대상 에이전트가 늘면 조사 |
| Doctor "Missing canonical transcript archive file(s)" | 10.2·10.3에서 레거시 이관 잔재로 관측. blob은 보존돼 있었다 | 이전 영수증과 대상·개수가 같으면 관찰만. 새 대상이면 조사 |
| live config 안에 `.pre-startup-migration-*.bak`이 생김 | 기동 Doctor의 DB 사전 백업(10.2: 1.09GiB, 10.3: 없음) | soak 뒤 GLG 승인 후 정리 |
| health `deliveryQueues.failed`가 비어 있지 않음 | 6월 16일 레거시 tombstone(`outbound`, count 1, `completed_permanent`)이 기준값이다 | verify가 그 값과 **정확히 같을 때만** PASS. 다르면 조사. DB 직접 삭제 금지 |
| `Activity summary publication failed … aborted` | 10.2에서 Control UI 실시간 push만 실패하고 요약은 저장됐다 | 같은 메시지면 관찰만 |
| `cd ~/openclaw && docker compose stop/restart`가 아무것도 안 함 | `~/openclaw`가 심볼릭이라 프로젝트명이 달라진다(9.8) | 항상 `-p openclaw-config`. 정지 뒤 `docker ps`로 확인 |
| claude-cli 봇만 턴마다 1초 만에 죽음 | 9.x에서는 npm postinstall이 조용히 실패한 것이 원인이었다 | 빌드 로그의 `claude --version`부터 본다. Dockerfile의 `--allow-scripts` + `install.cjs` + `claude --version` 3단을 유지한다. 그게 정상인데도 죽으면 다른 원인 — 단정하지 않는다 |
| cron.runs의 `provider: anthropic` | 10.2에선 모델 접두어 표시였고, 로그의 실제 실행은 `cli exec provider=claude-cli`였다 | 매번 로그로 확인한다. 표시만 보고 과금 경로를 판단하지 않는다 |
| 사본 Doctor가 OAuth refresh를 시도 | (메이저 리허설에서만) 사본이 live 토큰을 회전시킬 수 있다 | 사본 실행은 **항상 `--network none`** |

## 3. 영수증 자리

- `~/openclaw/backups/swap-<ver>-<date>/`(700): 로그, `openclaw.json.pre-swap`(600), `suspend-prepare.json`(600 — `suspensionId`·requestId 포함), 빌드 로그.
- 사전 검토 보고서는 `nixos-config/.agent-reports/`(gitignore)에 둔다.
