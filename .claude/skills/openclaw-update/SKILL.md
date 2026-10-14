---
name: openclaw-update
description: "oracle OpenClaw 게이트웨이 버전업을 할 때 딱 이것만 본다 — 마이너/메이저 판정, GLG 방식의 교체 순서, 매번 밟았던 함정과 그 해석. 자동화가 아니라 헛발질 방지가 목적이다. 읽기 전용 점검 스크립트 둘(preflight·verify)만 있고, 교체 자체는 사람이 단계마다 확인하며 한다. 트리거: 'openclaw 업데이트', '버전업', '업그레이드', '새 릴리즈 나왔다', '10.x 올리자', 'bump', '이미지 교체', 'swap', 'ELOOP', 'health starting', '업데이트 후 이상'."
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

## 0. 판정 — 마이너인가 메이저인가

```bash
{baseDir}/scripts/preflight.sh <대상버전>      # 예: 2026.10.3 — 읽기 전용
```

다음을 출력한다:
- live 버전과 대상의 선언 `schemaVersions`
- compare(ahead/behind)
- arm64 digest와 label revision이 대상 태그 커밋과 같은지
- hotfix 가드 버전
- root/home 디스크와 이미지별 UNIQUE 크기

| 판정 | 조건 | 할 일 |
|---|---|---|
| **마이너** | `schemaVersions` 동일 | §1 교체만. cold archive·Doctor 리허설·복원 시험 **안 함** |
| **메이저** | state/agent 스키마 상승, 또는 선언이 없음 | **GLG 마이너 규칙의 범위 밖 — 따로 판단한다.** 선례: ROADMAP "9.8→10.2"(정지 → cold archive → `--network none` 사본 리허설 → 컷오버) |

선언값은 첫 판정일 뿐이다. pull한 뒤 이미지에서 schema와 config 파싱을 다시 확인하고, 어긋나면 메이저로 다룬다.

## 1. 마이너 교체 순서

1. **릴리즈 노트를 우리 증상과 대조한다** — `CHANGELOG/<ver>.md`(raw). PR 제목만 보고 "고쳐졌다/직결"이라 하지 말고
   그 커밋의 diff로 범위를 본다.
2. **디스크** — docker는 root(`/dev/sda2`), `~/openclaw`는 home(`/dev/sdb`)이다. 새 base는 압축 해제 약 3.4GB,
   그 위 커스텀 레이어는 약 1GB를 root에 새로 쓴다. 옛 롤백 이미지 삭제는 GLG에게 범위를 제시하고 승인받는다.
3. **base pull은 digest로**
   ```bash
   docker pull ghcr.io/openclaw/openclaw@<arm64 digest>
   docker image inspect …@<digest> --format '{{index .Config.Labels "org.opencontainers.image.version"}} {{index .Config.Labels "org.opencontainers.image.revision"}}'
   ```
   `~/openclaw/Dockerfile`의 `ARG OPENCLAW_BASE=…@sha256:<digest>` 한 줄을 바꾸고, 이력 주석 1~2줄을 남긴다.
4. **hotfix 가드 이식** — `patch-memory-cron-parent.py`는 버전·바이트에 고정돼 있어 새 버전에서 **빌드가 일부러 실패한다**.
   - upstream이 고쳤는지 소스 blob으로 본다(`gh api …/contents/<path>?ref=v<ver> -q .sha`). 고쳤으면 패치를 회수한다.
   - 안 고쳤으면 **새 이미지 dist에서** 다시 잰다(`docker run --rm --network none --entrypoint sh <base> -c …`):
     chunk 이름, 원본 sha, helper sha, import 줄 개수. 결과 sha는 변환을 적용해 계산한다.
   - 미패치 base에서 테스트를 두 번 돌린다. `--baseline`(characterization)은 **GREEN**, 기본 모드는 **RED**여야 한다.
     패치 후 빌드 안에서 기본 모드 **GREEN 10/10**.
   - npm tarball dist는 Docker dist와 chunk 이름이 달라 **대용할 수 없다**.
5. **빌드** — config가 컨텍스트에 들어가지 않게, 최소 컨텍스트(임시 디렉터리에 Dockerfile·patch·test + `.dockerignore`)에서 빌드한다:
   `docker build -t openclaw-custom:<ver>-candidate-<date> .`
   로그에서 `claude --version`, `…applied/verified`, `10 behavior assertions passed`를 확인한다.
6. **config 격리 파싱** — 바꾸지 않고 읽기만 한다:
   ```bash
   docker run --rm --network none -e OPENROUTER_API_KEY=dummy \
     -v ~/openclaw/config/openclaw.json:/home/node/.openclaw/openclaw.json:ro \
     --entrypoint node openclaw-custom:<ver>-candidate-<date> openclaw.mjs config validate --json
   ```
   이어서 비교용으로 `openclaw.json`을 영수증 디렉터리(700)에 600 권한으로 복사해 둔다.
7. **교체** — 게이트웨이에 턴이 없을 때. 단계마다 결과를 보고 다음으로 간다.
   ```bash
   docker exec openclaw-gateway openclaw gateway call gateway.suspend.prepare --json \
     --params '{"requestId":"swap-<ver>","terminalPolicy":"preserve"}'      # status=ready, activeCount=0 일 때만 진행
   docker tag openclaw-custom:<ver>-candidate-<date> openclaw-custom:latest
   cd ~/openclaw && docker compose -p openclaw-config up -d --no-build --force-recreate openclaw-gateway
   docker exec openclaw-gateway openclaw gateway call health --json   # ok:true 가 나올 때까지 15초 간격으로
   ```
   - ready가 아니면 `gateway.suspend.resume`으로 풀고 나중에 다시 한다.
   - 실패하면 이전 candidate로 `latest`를 다시 태그하고 같은 `up` 명령을 실행한다.
   - 10.3 때 썼던 감싼 스크립트는 참고용 영수증일 뿐이다: `~/openclaw/backups/swap-10.3-20261014/swap.py`.
8. **확인 (모델 호출 없음)**
   ```bash
   {baseDir}/scripts/verify.sh ~/openclaw/backups/swap-<ver>-<date>     # 읽기 전용
   ```
   - 실제 동작은 다음 자연 cron과 실제 대화로 본다. 모델을 부르는 smoke는 GLG가 요청할 때만 한다.
9. **기록** — 순서대로:
   - openclaw-config: Dockerfile, patch, README change history
   - nixos-config: `docker/openclaw/` 미러 3종, ROADMAP 이력, ORACLE 현재 버전·롤백, NEXT 관찰, gotchas 새 함정
   - 커밋은 로컬까지만 한다. **push는 GLG가 말할 때만** 한다.

**묻는 것은 셋뿐이다**: 롤백 자산 삭제 · 모델 호출 smoke · push. 나머지는 끝까지 진행하고 한 번에 보고한다.
롤백 수단은 직전 candidate 이미지를 지우지 않고 두는 것이다. 스키마가 같아도 Doctor가 바꾼 config·auth까지
되돌린다는 증명은 아니다 — 그 위험을 알고 간다.

## 2. 함정표 — 증상 → 뜻 → 할 일 (모두 실측)

| 증상 | 뜻 | 할 일 |
|---|---|---|
| recreate 직후 `[FATAL tini] exec tini failed: Too many levels of symbolic links`, RestartCount 0~4 | 기존 증상. 재시작 정책으로 몇 초 안에 회복한다(9.8: 3회, 10.2: 0회, 10.3: 4회). 원인은 미확인 | RPC `health.ok` 뒤에 **RestartCount가 더 늘지 않으면** 정상. 계속 늘면 로그 첫 줄부터 본다 |
| 수 분간 응답 없음 | entrypoint가 **startup Doctor를 자동 실행**한다(10.2: 350초, 10.3: 307초) | 기다린다. GLG가 허용했다 |
| Docker `health: starting/unhealthy`가 오래 감 | healthcheck 간격이 3분이라 badge가 늦게 따라온다(10.3: RPC ok 뒤 약 3분, 기동 후 약 8분) | 완료 판정은 **RPC `health.ok`**. badge로 판정하지 않는다 |
| 이미지를 지웠는데 `df`가 그대로 | BuildKit cache가 레이어를 붙잡고 있다 | `docker builder prune -f --filter until=168h`(10.3: 2.05GB 회수) |
| 빌드가 `hotfix requires OpenClaw <ver>`로 실패 | 의도된 fail-closed | §1-4 이식. 가드를 약하게 만들지 않는다 |
| 격리 `config validate`에 `plugins.entries.zai: plugin not installed` | zai는 이미지가 아니라 live state `~/.openclaw/extensions/zai`에 있다 | 오탐. 교체 후 `zai loaded global`이면 끝 |
| Doctor 경고 "Codex runtime is selected, but the Codex plugin is disabled"(main·gpt 6.1-sol) | 기존 상태. 턴은 openclaw 런타임으로 떨어진다 | `plugins.entries.codex.enabled:false`를 **지우지 않는다** |
| Doctor "Missing canonical transcript archive file(s)" | 레거시 이관 잔재. blob은 보존돼 있다 | 무시 |
| live config 안에 `.pre-startup-migration-*.bak`이 생김 | 기동 Doctor의 DB 사전 백업(10.2: 1.09GiB, 10.3: 0) | soak 뒤 GLG 승인 후 정리 |
| health `deliveryQueues.failed=1` | 6월 16일 레거시 tombstone(`completed_permanent`). 정상 기준값 | 무시. DB 직접 삭제 금지 |
| `Activity summary publication failed … aborted` | Control UI 실시간 push만 실패한다. 요약은 저장된다 | 관찰만 |
| `cd ~/openclaw && docker compose stop/restart`가 아무것도 안 함 | `~/openclaw`가 심볼릭이라 프로젝트명이 달라진다(9.8) | 항상 `-p openclaw-config`. 정지 뒤 `docker ps`로 확인 |
| claude-cli 봇만 턴마다 1초 만에 죽음 | npm postinstall이 조용히 실패한 것 | Dockerfile의 `--allow-scripts` + `install.cjs` + `claude --version` 3단을 유지한다 |
| cron.runs의 `provider: anthropic` | 모델 접두어 표시일 뿐이다. 실제 실행은 `cli exec provider=claude-cli` | 로그로 확인. 과금 경로 변화가 아니다 |
| 사본 Doctor가 OAuth refresh를 시도 | (메이저 리허설에서만) 사본이 live 토큰을 회전시킬 수 있다 | 사본 실행은 **항상 `--network none`** |

## 3. 영수증 자리

- `~/openclaw/backups/swap-<ver>-<date>/`(700): 로그, `openclaw.json.pre-swap`(600), suspend 응답, 빌드 로그.
- 사전 검토 보고서는 `nixos-config/.agent-reports/`(gitignore)에 둔다.
