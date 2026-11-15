# entwurf × OpenClaw — 봇 책상 설치·실사용 절차 (oracle)

> **상태: main 책상 설치·왕복 완료 (2026-11-15 A 창, 1–12단계).** 13단계 영수증은 entwurf 릴리즈 커밋 뒤 재측정 대기. 다음 집 mini. (entwurf #160)
> 처음 가는 길이라 되는 것 자체가 관측이다. 실행하면서 놀란 지점은 맨 아래 **관측 기록**에 그 자리에서 적는다.
>
> 운영 규칙(책상이 버티게 하는 규칙 넷)은 [openclaw-gotchas.md 책상 절](openclaw-gotchas.md)과 `openclaw` 스킬 §12가 정본이다. 이 문서는 **설치하고 처음 써 보는 순서**만 다룬다.

## 무엇을 만드나

- 봇 집(agent) 하나에 **책상 세션 하나** — pin된 명시 key 세션(`agent:<봇id>:entwurf`). GLG: *"책상키는 entwurf 만 쓰자. '-' 이걸 넣는게 어색하다."*
- entwurf가 그 자리에 **garden id**를 붙인다(birth). 형제들은 이 garden id로 봇 책상에 편지를 보내고, 책상도 형제에게 답한다.
- 책상 이름(key)과 garden id는 다르다.
  - key는 GLG가 정하는 OpenClaw 세션 이름이다.
  - garden id는 entwurf가 birth 때 찍는 시민 주소다(`YYYYMMDDTHHMMSS-xxxxxx`).
  - garden id는 (scope, key) 자리에 붙고 `/reset`을 넘어 유지된다.
  - **처음 붙은 key는 바꿀 수 없다.** 다른 key로 바꾸려 하면 거절된다.

두 방향:

| 방향 | 길 |
|---|---|
| host 형제 → 책상 | entwurf → host shim(`openclaw-oracle-gateway`) → `docker exec` → Gateway → 책상 세션 (native-push) |
| 책상 → host 형제 | 책상 봇이 entwurf 플러그인 도구 호출 → 전용 SSH 키(forced command) → host `entwurf` → 대상 형제 |

## 전제 — 한 host, 한 빌드

- oracle은 entwurf를 **checkout(`~/repos/gh/entwurf`)에서만** 돌린다. npm 설치본을 섞지 않는다. GLG: *"섞이면 안되거든. … 나는 소비자는 아니니까."*
- 2026-11-15 측정: 운영 컨테이너는 entwurf를 전혀 로드하지 않았다. host 쪽에서 섞이던 원천 둘은 같은 날 정리됐다.
  - pnpm 전역 설치본을 제거했다.
  - sorge 운영자 MCP 설정을 checkout으로 돌렸다.
- `~/repos/gh`는 컨테이너에 **같은 경로로** 마운트돼 있다. 그래서 플러그인을 checkout 경로에서 그대로 link한다. npm도 이미지 rebuild도 필요 없다.
- 이 창을 열기 전에 entwurf 쪽 검증(R2, ACP 개선)이 끝나 있어야 한다. GLG: *"acp 개선 사항 다 검증 된것 확인되면 이후에 하자"*

## 확인된 사실 (v2026.11.3 소스 판독)

| 질문 | 답 | 근거 |
|---|---|---|
| key에 `-`가 들어가도 되나 | 된다. sessions.create key는 비어 있지만 않으면 된다 | `packages/gateway-protocol/src/schema/primitives.ts:25` |
| entwurf 쪽 key 규칙 | `agent:<봇id>:`로 시작, 공백·제어문자 없음, 256자 이하 | entwurf `pi-extensions/lib/openclaw-citizens.ts` |
| key에 피할 것 | 대문자(소문자로 정규화되는 곳이 있다), `subagent:`·`cron:`·`acp:` 표지, `:group:`·`:channel:` | `src/sessions/session-key-utils.ts`, `src/config/sessions/reset.ts` |
| 책상의 reset 유형 | `direct` — Telegram DM과 같은 칸 | gotchas 책상 절 규칙 2 |
| 명시 key create의 부모 | 자동으로 `agent:<id>:main` → pin 가능 | lab M1 |
| 플러그인 link 후 반영 | 운영에서도 hot reload가 안 됐다 → Gateway restart 필요 | 운영 관측 2026-11-15 (관측 기록 8행) |

## 첫 집과 다음 집

| 순서 | 봇 | 모델·런타임 | 집(host) | 왜 |
|---|---|---|---|---|
| 1 | **main** (default) | GPT 내장 런타임 | `~/openclaw/config/workspace` | 테스트. OpenClaw가 직접 압축하므로 "압축 뒤에도 같은 garden으로 답하나"를 실제로 볼 수 있다 |
| 2 | **mini** | Sonnet (claude-cli) | `~/openclaw/config/workspace-mini` | main이 되면 바로 다음. Claude가 스스로 압축하고 OpenClaw의 압축·크기 상한이 걸리지 않아, main과 대조군이 된다 |

GLG: *"일단 테스트할거니까 main(default) 봇으로 해보자"*, *"이게 되면 mini로 해보면 된다 소넷이니까."*

- 컨테이너 안에서 main의 집은 `/home/node/.openclaw/workspace`로 보인다(`agents.defaults.workspace`, `agents.entries.main.workspace`).
- birth의 `--cwd`에는 **host 경로**를 넣는다.

## 창 규칙

- **시각:** bbot 메멘토(02:30·08:30·14:30·20:30 KST)와 08:00 cron을 피한다. Gateway restart는 메멘토 ±15분 밖에서, 진행 중인 봇 턴이 0일 때만 한다.
- **창 안에서 하지 않는 것:** `docker compose up`·recreate, 이미지 rebuild, prune·GC, 모델 smoke, 수동 cron run.
- **실패 시:** 어느 단계든 검증이 실패하면 그 단계 롤백 한 줄 → 창 닫음. "일단 진행"은 없다.

## 절차 (main 기준)

담당: **운영** = nixos-config 담당자, **entwurf** = entwurf #160 조정자. 승인은 **GLG 직접 승인만** 친다(조정자 전달은 승인이 아니다).

| # | 단계 | 담당 | GLG 승인 | 롤백 한 줄 |
|---|---|---|---|---|
| 1 | 후보 고정: checkout HEAD = 후보 SHA, 작업트리 clean, SHA를 창 기록 맨 위에 | entwurf | 창 열기 1건 (1–3 묶음) | 이전 운영 SHA로 checkout |
| 2 | `pnpm run build-bridge` — oracle은 checkout 단일 빌드라 **이것이 곧 운영 dist 재빌드** | entwurf | 1에 포함 | 이전 SHA에서 build-bridge 재실행 |
| 3 | `run.sh install-meta-bridge` + `doctor-meta-bridge` | entwurf (운영 관측) | 1에 포함 | 이전 SHA에서 install-meta-bridge 재실행 (uninstall 아님 — 다른 Claude 세션 수신이 끊긴다) |
| 4 | 모든 reader 재시작 (§재시작 순서) | 각 세션 주인 | **1건** (살아 있는 대화를 끊는다) | 이전 dist로 되돌린 뒤 같은 순서 재시작 |
| 5 | host shim `~/.local/libexec/entwurf/openclaw-oracle-gateway` — PATH에 bare `openclaw`를 두지 않는다. 선언은 home-manager `users/junghan/modules/openclaw-entwurf.nix`(oracle만) | 운영 | **1건** (커밋 + switch) | 선언 revert + switch |
| 6 | 선언 `~/.pi/agent/openclaw-citizens.json`: scope `oracle`, gateway `{ "bin": <5의 절대경로> }`, allow key 하나 | 운영 작성, entwurf 파서 검사 | **1건** | allow 줄 삭제 (빈 allow도 유효한 닫힘) |
| 7 | 컨테이너→host 전용 SSH 키 + `authorized_keys` forced command(`restrict,from=<실측 출처>,command=…`), 래퍼 `ConnectTimeout=3`. 선언 위치는 **`machines/oracle.nix`**(`lib.mkAfter`) — `hosts/oracle/configuration.nix`는 설치 때만 쓰고 flake에 없다 | 운영 | **1건** (커밋 + switch) | authorized_keys 줄·forced script revert + switch, 키 디렉터리 삭제 |
| 8 | 플러그인 link: `plugins install --link --force /home/junghan/repos/gh/entwurf/plugins/openclaw`(`--force`는 ClawHub 밖 로컬 소스 확인일 뿐). config는 **객체 하나로** `config set plugins.entries.entwurf '{…}' --strict-json`: `enabled`·`config.entwurfBin`(7의 래퍼)·`declPath`(컨테이너에서 보이는 경로)·`scope`(`oracle`) — 키별 set은 필수 속성 검사에 걸린다 | 운영 실행, entwurf 값 확인 | **1건** | `plugins uninstall` (+ 9와 같은 restart) |
| 9 | Gateway restart (플러그인 로드) | 운영 | **별도 1건** (idle gate 측정 후) | 8 롤백 뒤 같은 restart 1회 |
| 10 | 책상(shim으로 `gateway call <method> --params '{…}' --json`): `sessions.create {key}` → `sessions.patch {pinned:true}` → `sessions.describe`로 `pinned===true`, spawnedBy 없음, 부모 ∈ {없음, agent main} 확인 — **끊김 없이** | 운영 | **1건** — 직전에 key 확정·`session.notifyOnCreate` 결정 | unpin (archive는 GLG 판단) |
| 11 | birth: `entwurf openclaw-birth --scope oracle --session-key <key> --cwd <host 절대경로>` — 10 **바로 뒤** | entwurf | 10에 포함 | 6 롤백(allow 빼기)이 닫기 |
| 12 | 왕복 양방향 + F2(압축 뒤·`/reset` 뒤 같은 garden 답신, pin 유지) | entwurf 측정, 운영 관측 (describe·전사 크기·Gateway 로그 에러) | **1건** (봇 턴 = 모델 사용) | 관측만 — 실패 시 6 롤백 |
| 13 | `check-openclaw-home-receipt` 영수증 — entwurf VERIFY 기준 11 (MUST tier green) | entwurf | 결과 보고 | — |

**mini(다음 집):** 6에 allow 줄을 하나 추가하고(새 garden id) 10–13만 반복한다. 1–9는 재사용한다.

### 재시작 순서

**host reader 먼저, Gateway는 맨 끝.** Gateway가 새 플러그인으로 송신을 시작하는 순간 host 쪽 수신자가 모두 새 dist여야 한다.

1. pi-durable 프로세스 — child bridge가 `dist/`를 읽는다. 단계 2 뒤 반드시 재시작한다.
2. pi 세션 — dist bridge child와 ACP 기동 child가 있다.
3. Claude Code 시민들 — bridge는 기동 시 `src/`를 읽으므로 재시작해야 새 코드가 반영된다. 운영 담당 세션 자신은 **맨 마지막**에 재시작하고, 재개한 뒤 9로 간다.
4. sorge 운영자 claude — checkout bridge를 쓴다.
5. 재시작마다 `doctor-meta-bridge` 1회.
6. (8 뒤) `docker restart openclaw-gateway` 1회 → health 확인. tini ELOOP이면 승인된 `docker start` 1회(2026-11-13 선례). recreate가 아니다.

실제 대상은 창을 열 때 `ps`로 다시 센다. 목록은 날마다 다르다. 2026-11-15 17:38에는 herdr server가 떠 있지 않았다.

### timeout 예산

- 플러그인 송신 timeout은 90s다. 송신 경로의 최악은 79.5s이고, 래퍼에 남는 여유는 10.5s다.
- SSH 기본 `ConnectTimeout=10`이면 여유가 0.5s밖에 남지 않는다. 그래서 **3s로 낮춘다.** 남는 7.5s가 인증과 원격 `entwurf` 기동을 덮는다.
- 7의 검증에서 "핸드셰이크 + 원격 기동"을 따로 잰다. 5s를 넘으면 플러그인 timeout 상향을 entwurf 쪽에 요청한다.

## 닫기·정지

- **운영 정지:** 선언에서 그 봇의 allow 줄을 뺀다. record와 세션은 그대로 남는다.
- **책상을 끊는 운영 행위:** 모델·provider 교체와 OpenClaw 버전업. 미리 GLG에게 알린다(스킬 §12 규칙 3, `openclaw-update` 스킬).

## 관측 기록 (실행하면서 채운다)

처음이라 되는 것도 놀라운 지점이다. 각 줄에 날짜·단계·무엇을 봤나·영수증 위치를 적는다. 비밀·IP·토큰은 적지 않는다.

| 날짜 | 집 | 단계 | 관측 | 영수증 |
|---|---|---|---|---|
| 2026-11-15 | main | 5 | shim 검증(switch 전): 맞는 url → rc0 3.3s, 다른 url → rc1 "Gateway destination changed", `OPENCLAW_CONFIG_PATH` 설정 → rc64 | 운영 세션 |
| 2026-11-15 | main | 7 | 첫 선언을 `hosts/oracle/configuration.nix`에 넣었다가 빌드에 키가 없어 발견 — flake 밖 파일. `machines/oracle.nix`로 옮김. switch 뒤: 래퍼 argv 틀림 → invalid 한 줄 rc2 / 빈 stdin → entwurf invalid rc2 0.51s / 같은 키로 `id` → forced command가 대체 / host에서 같은 키 → Permission denied(from 제한) | sshd 로그(출처 컨테이너 주소) |
| 2026-11-15 | main | 8 | `plugins install`은 기존 `plugins.allow`에 id를 자동 추가. 저장은 됐으나 hot reload 실패: 다른 플러그인(memory-core) 서비스 정지가 5s timeout → "persisted but was not applied". entwurf 문제가 아니다 | config 백업 `~/openclaw/backups/swap-10.9-cc322-20261113/openclaw.json.pre-entwurf-plugin-20261115` |
| 2026-11-15 | main | 9 | 21:45 `docker restart` 1회. ready 21:47:56(≈2.5분), healthy 21:49:15 — 그사이 healthcheck가 "Shared-state read and cleanup failed"로 실패(기동 중 상태 DB 경합 추정, ready 뒤 소멸). 12 plugins에 entwurf 포함, `toolNames=['entwurf_v2']`. ELOOP 없음. 무관 경고: acpx missing-package-dir(미설치 그대로) | Gateway 로그 |
| 2026-11-15 | main | 10 | create 응답 `delivery.kind=none`·`createdVia operator`·`spawnDepth 0`, 작업 폴더 컨테이너 workspace, 모델은 봇 기본(gpt-6.1-sol). describe: `pinned=true`, spawnedBy/parent 필드 없음, `classification custom`. notifyOnCreate 기본(true)이어도 전달 대상이 none이라 알림이 갈 곳이 없었다 | describe 출력 |
| 2026-11-15 | main | 11 | birth → garden `20261115T215046-12438c`, 재실행은 attach(멱등) | entwurf 조정자 로그 |
| 2026-11-15 | main | 12 | host 형제 → 책상 native-push → 책상이 `entwurf_v2`로 답신, 왕복 ≈13s | entwurf 조정자 `/tmp/ff08d4-next/a-window/` |
