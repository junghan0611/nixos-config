# NEXT.md — 다음 할 일

운영 baseline은 [AGENTS.md](AGENTS.md). 후속 작업 / 미완 검증은 여기에. 닫힌 항목은 [CHANGELOG.md](CHANGELOG.md)로 흘려보낸다 — 최근 스냅샷 `v2026.9.8`.

작업 끝나면 항목 지우고, 새로 발견한 후속은 추가. 영속할 사실은 AGENTS.md / docs/openclaw-gotchas.md / `~/openclaw/README.md` change history로 옮긴다.

---

# RAIL — 현재 좌표

- [x] **1. OpenClaw `2026.8.2` 안정화 고정** — 9.1/9.2 미채택(GLG 2026-09-06). 라이브 healthy · 롤백면 `8.1-rollback` 하나만 유지
- [x] **2. 컷오버 잔재 회수** — `/home` 94%→75%, docker 12.6→9.8GB. 롤백면 은퇴 완료
- [x] **3. 기억축 청소** — dreaming 4월 화석 880 + 세션 아카이브 835 = **1,715청크 회수(4,915→3,202, -35%)**. 6봇 `dirty:no`
- [x] **4. 지배 세션 압축 — 압축할 게 아니었다.** gpt DM 무응답의 원인은 컨텍스트가 아니라 **rate-limit 로 죽은 run 이 남긴 세션 락**이었다(`lastRunError: API rate limit reached`, `endedAt` 2026-09-05T14:20, 이후 run 0회). 실제 창은 `route=fits` 185,615/272,000. `sessions.abort` 한 줄로 복구(첫 턴 5초, 텔레그램 `messageId=3595`). 전사 미절단. 함정 전문 → [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) 첫 항목
- [ ] **5. 봇 무응답을 사람이 먼저 알아채는 구조** ← CURRENT (GLG 2026-09-06: *"이런 문제 발생했는데 뭘 알려주는 게 없네"*). gpt 가 **하루 넘게 죽어 있는 동안 알림이 0건**이었다 — GLG 가 말을 걸어보고서야 발견했다. 로그에는 3분마다 같은 에러가 찍혔고, health-monitor 의 `stuck session recovery` 는 `reason=active_reply_work` 로 매분 **skip** 했다(락 잡힌 세션을 "일하는 중"으로 본다). 필요한 것: ① 세션 `status=failed` 가 N 분 이상 지속되면 main/운영 채널로 통지 ② `spooled update … keeping for retry` 가 반복되면 같은 통지 ③ 그 판정이 upstream 몫인지 우리 cron 한 줄인지 결정([docs/openclaw-automations.md](docs/openclaw-automations.md) 에 얹을 자리)
- [ ] **6. 상류 리포트** ← PAUSED: 5 이후. 우리 설정으로 못 고치는 **확정 6건 + 후보 2건**이 모였다(아래 §상류). 후보는 ⑦ rate-limit 종료 run 이 세션 락을 놓지 않아 `sessions compact` 까지 막는 것, ⑧ 안드로이드 앱이 heartbeat automation 상세를 못 여는 것(앱 확정은 미검증)

- [x] **7. 안드로이드 앱이 tailnet 으로 못 붙던 것** — 원인은 버전업도 페어링도 아니었다.
  `openclaw_default` 도커 네트워크가 2026-09-02 에 새로 생기면서 `gateway.trustedProxies` 의
  `172.18.0.0/16`(caddy 경로)만으로는 tailscale serve 경로(**172.19.0.1**)가 신뢰 밖에 남았다 —
  **설정은 그대로인데 그 아래 네트워크가 움직인 화석.** `/health` 는 무인증이라 200 이고 `/` 만
  403(`proxy_attribution_required`)이던 비대칭이 진단을 갈랐다. `/32` 로 좁게 더하고 restart →
  앱 연결 확인(`Connected 1`), 재승인 대기는 앱 재연결로 자동 해소. 함정 전문 →
  [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) 첫 항목

- [x] **8. entwurf ↔ OpenClaw 다리 — 유보로 닫았다.** GLG 가 다리를 건너는 대신 **B 를 컨테이너
  밖으로 꺼냈다**(`workspace-bbot` 독립 리포, 호스트 pi 시민 `20260908T181437-30802a`). 그래서
  `.assembled` ro 마운트 + Dockerfile node 심볼릭은 **실행하지 않는다**(취소 아닌 유보 — GLG
  발화가 "일단"). 오늘 잰 것은 [entwurf#109](https://github.com/junghan0611/entwurf/issues/109)
  에 정본으로 남겼다(내 코멘트 3건). **tmux 소켓 마운트는 금지 유지.**

- [x] **9. bbot 메멘토 autopilot** — 2026-09-10 heartbeat(main 누적)에서 3h isolated `agentTurn`으로 이관. `anthropic/claude-opus-5` + `thinking:"xhigh"`, explicit Telegram `accountId:"bbot"` delivery, 첫 fresh run delivered 검증. bbot heartbeat는 `{every:"0m"}`를 명시 유지한다 — `unset`하면 6봇 defaults cadence가 되살아난다. 상세는 [docs/openclaw-automations.md](docs/openclaw-automations.md) §bbot 3h. **불충분 2건**: ① "8/12–9/9 침묵의 원인이 NO_REPLY" 는 전사 대조를 안 했다 ② 앱 건은 상류 후보 ⑧.

- [ ] **bbot Android admin scope 판단** — 현재 폰은 cron 목록·상세·run history 읽기 전용이고 mutation은 `Admin access required`(정상). 폰에서 직접 cron 편집/수동 실행이 정말 필요할 때만 shared token/password 재연결 또는 admin scope upgrade를 승인한다. 필요 없으면 현 상태 유지; [gotchas](docs/openclaw-gotchas.md) claw 항목 참고.

- [ ] **10. doctor 가 찾아낸 것 셋** ← 2026-09-09 첫 전수 점검(`openclaw config validate` + `doctor` read-only). **`config validate` 는 통과했다** — 스키마 위반 0, 경고는 우리가 9/1 에 일부러 끈 `active-memory` 하나뿐. 문제는 스키마가 아니라 선언과 배포다.
  - [ ] **glg 봇 `USER.md` 가 29% 잘려서 주입된다** — `5,668 raw / 3,999 injected`. 전체 bootstrap 예산은 `31,322/60,000`(52%)로 여유가 있는데 **파일당 상한**에 걸렸다. 가족봇이 GLG 정보를 3분의 1 잘린 채 읽고 있다는 뜻. 처방은 `agents.entries.glg.bootstrapMaxChars`(doctor 가 이 키를 직접 알려준다). **셋 중 사람에게 실제로 닿고 있는 유일한 것이라 먼저다.**
  - [ ] **`summarize`·`tmux` 가 5봇 전부에서 번들본을 덮는다** — `winner=openclaw-workspace … loser=openclaw-bundled`. 의도한 것이면 정상이지만 **의도했는지 확인된 바 없다.** 확인 안 하면 버전업으로 내장본이 개선돼도 우리 사본이 계속 이긴다.
  - [ ] **`AgentSelectionRequiredError` 가 doctor 의 health check 한 칸을 막는다** — `openclaw message send` 가 거부되던 것과 같은 에러다. 우리 CLI 사용만의 불편이 아니라 **자기 점검이 안 도는 상태**. 스키마에 `bindings[].match.{channel,accountId} → agentId` 라는 정식 자리가 있는데(`src/config/zod-schema.agents.ts:90-163`) 우리는 안 쓴다 — 계정↔에이전트가 이름 규칙에 기대고 있고, 앱·웹도 이 선언을 읽는다.
  - [x] ~~`forge` 스킬이 gpt/gemini/mini 에서 symlink-escape 로 로드 거부~~ — **대상 아님**(GLG 2026-09-09: forge 는 공사 중, 안 써도 된다). 되살릴 때 `skills.load.allowSymlinkTargets` 를 볼 것.

현재 좌표: 1·2·3·4·7·8·9 완료 → **5(무응답 통지)가 다음 한 수** → 10(doctor 셋) → 6(상류)

# NOW

- **Current**: 8.2 고정 + 기억축 정리 판이 계속된다. 2026-09-08 은 여기에 두 판이 얹혔다 — 안드로이드 앱 연결 복구(RAIL 7)와 entwurf 다리 유보(RAIL 8). 라이브 무사(`2026.8.2` healthy, 6봇 polling 정상). **트리는 clean 이고 push 까지 끝났다**(`6c8b1fb`).
- **Next**: (1) 무응답 통지 설계(RAIL 5) → (2) `docker exec openclaw-gateway openclaw memory index --agent gpt` 증분 → (3) 청크 수와 봇 실경로 latency 재측정.
- **Blocker**: 없음. gpt DM 은 살아있다(`status=done`, `route=fits` 62,540/272,000, msgs 4).
- **회수 판단 보류**: 락 해제 때 라이브 창이 91→4 메시지로 축소됐다. 착수 전 스토어 백업이 컨테이너 안에 있다 — `~/.openclaw/agents/gpt/agent/openclaw-agent.sqlite.pre-compact-20260906T2120.bak` (226MB). **맥락 회수가 불필요하면 지운다** (oracle 디스크 `/home` 75%).
- **Verify**: 봇 실경로 기준선 **`mini 12.0s 성공 / glg 26.1s 타임아웃`**(`openclaw agent --session-key probe-memlat-…`). **측정은 직렬로, 부하를 같이 기록하고 중앙값으로** — 4 vCPU 라 병렬로 재면 큐 대기를 잰다.
- **Read**: 아래 §"기억축을 세션만으로" · §"회수 품질" · [sorge#1](https://github.com/junghan0611/sorge/issues/1) 코멘트 5건.
- **Do not touch**: `--force` 재색인 금지(전량 재임베딩). `~/repos/gh` bind 를 rw 로 되돌리지 말 것. Active Memory·dreaming 켜지 말 것. `machines/shared.nix` 의 `emacs-nox` 전역 제거 금지. **지금 붙어 있는 안드로이드 페어링을 지워서 scope 를 고치려 들지 말 것** — 앱이 낡은 동안엔 재페어링해도 같은 scope 가 나오고 연결만 잃는다. **`gateway.trustedProxies` 에서 `172.19.0.1/32` 를 빼지 말 것** — 앱 연결이 끊긴다. **entwurf `.assembled` 마운트·node 심볼릭을 실행하지 말 것**(RAIL 8 유보). **tmux 소켓은 절대 마운트하지 말 것** — 컨테이너가 호스트에서 임의 프로세스를 실행하게 된다.

# 앱 후속 (2026-09-08, RAIL 7 에서 파생)

- [ ] **안드로이드 앱을 `2026.8.x` 로 올린다** — 앱 ui 가 `v2026.7.1` 이라 페어링 scope 에
  `operator.questions` 가 없고, 게이트웨이 로그가 30초마다
  `[ws] ✗ question.list FORBIDDEN missing scope: operator.questions` 를 뱉는다. 앱의 질문/승인
  화면이 비어 보인다. **CLI 로 못 고친다** — `devices` 에 scope 편집 서브커맨드가 없고
  (`approve/rotate/revoke/rename/remove/clear/join-code` 뿐) `openclaw.json` 에도 device scope
  기본값이 없다. 앱을 올린 뒤 재페어링해야 풀린다.
- [ ] **`run.sh t)` SSH 터널의 운명 결정** — trustedProxies 변경의 대가로 터널 경유 Control UI 가
  403 이 됐다(도커 NAT 가 터널과 tailscale serve 를 같은 172.19.0.1 로 뭉갠다 — `/32` 로도 분리
  불가). 지금은 경고 + tailnet 경로 안내로 남겨뒀다. thinkpad 도 tailnet 에 있으니 **터널 자체를
  은퇴시킬지** 판단이 필요하다.
- [ ] **공유 `~/.claude` 가 rw 라 컨테이너가 호스트에 쓴다** — 컨테이너 Claude 가 호스트
  `~/.claude/plugins/` 에 `.orphaned_at` 을 썼다(2026-09-08 13:41:48 KST, uid 1000). 지금 호스트는
  여전히 `enabled` 라 실해는 없었지만 **컨테이너가 호스트 플러그인 상태를 건드릴 수 있는 자리**다.
  좁힐지 알고 둘지 판단 필요 — 봇이 skills 를 쓰므로 단순 ro 는 깨진다(하위 경로별로 갈라야 한다).

# 시계 — 되살아날 축 (2026-09-08, RAIL 8 에서 파생)

- [ ] **컨테이너 cron 이 호스트 시민을 깨울 수 있는가** — entwurf#109 를 급하게 만든 진짜 이유는
  "이 계에서 cron `agentTurn` 을 가진 스택은 OpenClaw 하나"였다. **B 가 컨테이너를 나오면서 그
  도어벨을 두고 나왔다** — 지금 B 를 깨우는 것은 GLG 의 손이거나 형제 메시지뿐이다. 다시 문제가
  되면 이 질문으로 바뀌고, 오늘 판 것보다 훨씬 싸다(호스트 pi 시민의 control socket 은 garden-id
  이름 `<dir>/<gardenId>.sock` 이라 디렉터리만 보이면 유효). 두 가지가 걸린다 — `gcStaleSockets`
  가 다른 ns 의 살아 있는 소켓을 `dead` 로 읽고 **unlink** 할 수 있고(파괴적), **호스트 쪽 타이머가
  경계를 아예 안 넘는 더 싼 답일 수 있다.** 지금 재지 않는다.

- **병행 레인(이 세션 소관 아님)**: Emacs 31.1 nuc/laptop 이관(급하지 않다, 아래 §Emacs) · 🔴 8.1 cron 런타임 회귀 · B 는 이제 `workspace-bbot` 리포의 호스트 시민이다(별도 형제, 이 리포 소관 아님).

# 상류 리포트 — 우리 설정으로 못 고치는 것 (2026-09-06 확정, RAIL 5)

속도 2건:
1. **읽기 질의가 RW 세션으로 구현돼 있다** — 매니저가 `readOnly` 없이 열고 열 때마다 스키마 수렴(쓰기). 같은 파일에 세션 전사 writer 가 붙어 바쁜 봇에서 timeout 이 된다. **read-only 리더는 같은 시각 같은 쿼리가 0.047초다.**
2. **`embedding` 을 TEXT 로 저장한다** — 행당 88KB = 원문의 138배. vec0 blob 인덱스는 따로 정상 존재.

품질 4건:
3. **세션은 mtime 으로 감쇠한다** — 경로 날짜가 없어서. append 되는 세션은 영원히 새것.
4. **세션당 캡·다양성 보정이 없다** — MMR 은 스니펫 Jaccard 만 보고 sessionId 를 안 본다.
5. **deleted/reset 아카이브를 고의로 색인한다** — 필터가 `conversationRecall` 일 때만 건다.
6. **`chunkTokens:400` 이 토큰이 아니다** — `maxChars=tokens×4`, 한글은 글자당 ×4 로 세는 휴리스틱. 하한이 없어 6자 청크도 생긴다.

증거: gpt `q='임베딩'` 8칸 중 **1위가 3일 전 삭제된 세션**, 6칸이 세션 하나. 조사는 형제 grok-4.6 의 `/app` 번들 독해 + 이 호스트 실측.

후보 2건 더 (아직 확정 아님):

7. **rate-limit 로 끝난 run 이 세션 락을 놓지 않는다** — 복구 수단인 `sessions compact` 까지 함께 잠긴다(2026-09-06, RAIL 4 참조).
8. **안드로이드 앱(node)이 `payload.kind:"heartbeat"` automation 의 상세를 못 연다** — 목록에는 `ok` 로 뜨는데 눌러보면 *"gateway returned an invalid automation"*. 같은 화면에서 `morning-family-schedule-reminder`(`agentTurn`)는 정상 표시된다(권한만 `admin access required`). 두 잡의 차이: heartbeat 는 `payload.kind:"heartbeat"` 이고 `delivery`/`description`/`sessionKey` 가 없고 `wakeMode:"next-heartbeat"`, `declarationKey` 있음(system-owned).
   - 확인된 것: 그 문자열이 게이트웨이 이미지 dist 전체에 **없다**(grep 0건), 같은 잡을 CLI 는 온전히 읽는다 → 게이트웨이가 뱉은 에러가 아니다.
   - **불충분**: 앱 단독 버그로 확정하려면 안드로이드 DTO/RPC payload 대조가 필요하다(교차검수 gpt-5.6-terra, 2026-09-09). 앱 버전과 에러 화면도 아직 안 봤다.

---

## 🟢 datasette 도입 — 1층(nixpkgs + 오버레이) 착지 (2026-09-04)

GLG 요청(sorge 담당자 경유): Magit Forge 로컬 sqlite를 브라우저에서 훑는 면.
대상 DB `~/doomemacs/.local/etc/forge/forge-database.sqlite` (3.6MB · 20 repos · issues 164 / open 57).

**어디에 넣었나**: `flake.nix` 오버레이(broken 우회) + `users/junghan/home-manager.nix` `home.packages`
의 `isLinux && !isOracle` 블록. **oracle 제외**(대상 DB가 없다). rebuild 한 번이면 각 기기에 따라온다.

**왜 1층인가 — 2층(uv tool)을 거쳐 돌아온 경로다.**
처음엔 `pkgs.datasette` 가 평가부터 거부돼(26.05·unstable 양쪽 동일) 2층 `uv tool` 로 내려놨다.
GLG가 *"nixos에 있는데 기다려봐봐"* 라고 짚어서 다시 쟀고, 결론이 뒤집혔다:

| | nix 1층 | uv 2층 |
|---|---|---|
| datasette | 0.65.2 | 0.65.3 |
| python-multipart | 0.0.29 | 0.0.32 |
| asgi-csrf 비호환 | 있음 | **똑같이 있음** |

**uv 가 문제를 피해가는 게 아니었다.** uv도 같은 비호환을 안고 있고, broken 게이트가 없어 조용히
설치될 뿐이다. 버전 차이는 패치 하나. 그 하나 때문에 선언 밖으로 나가고 기기마다 수동 설치할 이유가 없다.

**막힌 원인(실측)**: `asgi-csrf` 0.11 이 `python-multipart` 0.0.26+ 의 API 변경을 못 따라간다.
nixpkgs가 `meta.broken = python-multipart >= 0.0.26` 으로 마킹 → datasette 평가 거부.
테스트를 돌려 실패 지점을 특정했다: `asgi_csrf.py:291`
`TypeError: FormParser.__init__() got an unexpected keyword argument 'FileClass'` — **multipart POST 파싱 한 곳뿐**.
읽기 전용 브라우징은 GET 경로라 닿지 않는다. 그래서 `doCheck=false` + broken 내림으로 오버라이드했다.

- [ ] **⚠️ 경계**: datasette 에서 **쓰기/폼 POST를 쓰면 이 오버라이드는 부족하다**(write 플러그인, 로그인 폼).
      그땐 오버레이를 지우고 upstream(`simonw/asgi-csrf#38`) 수정을 기다린다.
- [ ] **회수 조건**: `asgi-csrf` broken 이 풀리면 `flake.nix` 의 datasette 블록을 통째로 지운다.
      확인: `nix eval .#nixosConfigurations.thinkpad.pkgs.datasette.version` 이 오버레이 없이 통과하는지.
- [ ] **rebuild 필요** — 이 세션에서 `switch` 는 하지 않았다(eval/build 검증까지). uv 사본을 지웠으므로
      `sudo nixos-rebuild switch --flake .#thinkpad` 전까지 thinkpad 에 datasette 이 없다. nuc/laptop 은 각자 다음 rebuild.
- [x] ~~thinkpad uv 설치본 제거~~ — GLG 지시로 `uv tool uninstall datasette` 완료(2026-09-04).
      확인: `uv tool list` → `No tools installed`, `~/.local/bin/datasette` 없음,
      `~/.local/share/uv/tools/` 디렉토리 자체가 사라짐. PATH 그림자 함정 해소.
      **따라서 switch 전까지 이 기기에 datasette 이 없다** — 아래 rebuild 항목이 곧 복구다.

**띄우는 플래그 — 결론 났다**(sorge 가 문서 원문으로 확정, 나에게 전달):
```
datasette /home/junghan/doomemacs/.local/etc/forge/forge-database.sqlite
```
**`--immutable` / `-i` 금지.** 그 파일은 Emacs 가 `forge-pull` 로 쓰는 살아 있는 DB고,
immutable 은 락·변경 감지를 끄는 선언이라 잘못된 결과나 `SQLITE_CORRUPT` 가 될 수 있다
(SQLite 공식 문서 · datasette PR #1870 · `doomemacs-config` 담당자가 sqlite CLI 쪽에서 준 조건과 같은 함정).
행 수 캐시 이득을 잃지만 3.6MB 규모에선 무의미하다.

**실측 근거(2026-09-04, thinkpad)**: nix 빌드본 0.65.2 로 forge DB **사본**(`/tmp`, 원본 미접촉)에서
`datasette --get` → `issue` 164 rows, `state='open'` 57, query ~1.3ms. 사본은 삭제함.

---

## 🔴 8.1 회귀 — 비주력 경로가 죽은 codex 런타임으로 떨어진다 (2026-09-01, 진행 중)

**오늘 아침 두 개가 동시에 터졌고 뿌리는 하나다.** 경위·코드 근거·재현은
[docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) 최상단 두 항목, 봇별 현황은
[docs/openclaw-automations.md](docs/openclaw-automations.md)(**자동화 SSOT**). 여기는 **남은 것만**.

한 줄 요약: `agents.defaults.models["openai/*"].agentRuntime = "openclaw"` 오버라이드를
cron 경로가 잃고 disabled인 `codex`로 떨어진다. 일반 세션 경로는 멀쩡하다. active-memory는
같은 뿌리일 수 있으나 실행 표본이 없어 가설로 남긴다.

### 오늘 만진 것 (전부 되돌릴 수 있음)

| 변경 | 상태 | 되돌리기 |
|---|---|---|
| 가족 cron 3건에 `--model anthropic/claude-sonnet-5` | 08:00 잡은 **실증 완료**(delivered) | `cron edit <id> --clear-model` |
| 아내 07:00 cron `disable` | GLG 지시 | `cron enable 2b9edc67-…` |
| main/glg/gpt/mini heartbeat 제거 | bbot 30m만 남음 | `openclaw.json.bak-heartbeat-off-20260901T075810` |
| active-memory 비활성 + gateway restart | typing과 상관 관측; **원인 미확정** | `openclaw.json.bak-activemem-off-20260901T083503` |
| main `typingMode=never` | 09:21 hot reload 적용; 사용자 가시 typing 억제 | `config unset agents.entries.main.typingMode` |
| `scripts/turnwatch.sh` + `run.sh w)` | 커밋 `6ddc428` | — |

### 남은 것

- [ ] **아내 07:00 cron을 언제 다시 켤지 GLG 판단.** model은 이미 sonnet-5로 박아뒀다.
      그 잡 자체는 여전히 성공 실행 0회지만, 이제 **형제 잡(08:00)이 직접 실증됐다**(아래) — 켜면 돈다고 볼 근거가 세졌다.
- [x] ~~9/2 08:00 KST 반복 잡 확인~~ — **통과.** `cron runs` 실측: `completionStatus: succeeded`,
      **`provider: "claude-cli"`, `model: "claude-sonnet-5"`**, `delivered: true`, 53.7s, `consecutiveErrors: 0`.
      **`--model` 명시 우회가 작동한다** — 죽은 codex로 안 떨어졌다. 어제는 간접 실증뿐이었는데 이제 그 잡 자체가 증거다.
- [ ] **1회성 `baron-kindergarten-dropoff-2026-09-02`는 확인 불가** — `cron list --all`에도 없다.
      one-shot은 소진 후 스토어에서 사라지는 듯. **텔레그램 도착 여부는 GLG 육안 확인 몫.**
- [ ] **subagents 미검증.** `agents.defaults.subagents.model = openai/gpt-5.6-terra`로 같은 뿌리를
      공유한다. 8.1 이후 실행 0건이라 표본이 없다. **자연 발생을 기다려** `sessions list`의
      Runtime 컬럼을 보는 게 무비용 검증이다(`OpenClaw Default`면 정상, `OpenAI Codex`면 같은 병).
- [ ] **active-memory를 되살릴지 결정.** 지금은 껐다. luna/codex와 typing의 인과는 미확정이므로
      anthropic으로 바꾸는 수선도 아직 하지 않는다. 애초에 "실질적으로 잘 동작하지 않는다"는
      평가가 있었으니(ORACLE.md) **폐기도 선택지.**
- [ ] **upstream 이슈로 올릴지 판단.** 8.1 cron/plugin 경로의 model-policy resolver 버그.
      교차검수(gpt-5.6-terra)도 별도 추적 사안으로 봤다.
- [ ] **`daily_real_estate_auction_study_brief_*`(mini, disabled)** — 켜기 전에 model을 박아야 한다.
      안 그러면 같은 이유로 죽는다. turnwatch §1b가 이걸 `codex 낙하 위험`으로 표시한다.

### 진단 교훈 (반복 방지)

내 첫 진단은 **틀렸다** — typing을 heartbeat 탓으로 지목했는데 heartbeat 4개를 지워도 안 멈췄다.
교차검수가 "typing 경로는 하나가 아니다"를 짚었고, 결국 **한 번에 한 변수만 끄는** 방식으로 잡았다.
**관측면이 없는 증상(typing은 로그에도 audit에도 안 남는다)은 코드 판독이나 한 번의 on/off로 단정하지 마라.**

- [ ] **7일 8.1 typing soak.** main `typingMode=never`를 유지한다. 재발을 보면 시각·어느 봇의
      UI인지·직전 인바운드 여부를 함께 남기고, 그 창의 `audit_events`/gateway 로그와 대조한다.
      active-memory는 이 기간 재활성하지 않는다.

---

## 🟢 OpenClaw 8.2 컷오버 완료 — soak만 남음 (2026-09-02 10:38 KST)

**라이브 = `2026.8.2` (0965053), healthy.** 15초 컷오버가 왜 가능했나(이미지 세 상수 대조 → 마이그레이션 0 확정)·검수 전항목·규모 대조는 [CHANGELOG.md](CHANGELOG.md) `v2026.9.2`로 이관했다. 판정 절차는 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) *"bump가 '한 줄'인지 '마이그레이션'인지는 릴리즈 노트로 판정하지 마라"*, 사전 검토·실행 전문은 [issue #8](https://github.com/junghan0611/nixos-config/issues/8). 여기는 **남은 것만**.

**롤백면**: 이미지 `openclaw-custom:8.1-rollback`(`ed2a67c2f90b`) 하나 + config `~/openclaw/config/openclaw.json.bak-pre-8.2-20260902T103549`. 8.2가 state를 안 건드렸으므로 state 복원은 불필요하다.

### 남은 것

- [ ] **내일(9/3) 08:00 KST cron 재관측** — 8.2에서의 첫 자동 실행이다. `--model` 우회가 계속 필요한지,
      그리고 위 🔴 회귀가 8.2에서도 재현되는지. **재현되면 "8.1 일회성"이 아니라 두 릴리즈 연속 회귀**이고,
      🔴의 "upstream 이슈로 올릴지" 판단이 그만큼 무거워진다.
- [ ] **`doctor --fix`는 안 태웠다.** 마이그레이션이 0이라 #134429 코드 경로를 지나지 않아 태워도 검증이 안 된다.
      **그 실측은 다음 메이저 hop으로 이월.**
- [ ] **🔭 Linux 데스크톱 컴패니언(.deb/AppImage, x86-64)** — 조사만, 설치 금지.
      먼저 답할 것: "remote Gateway 연결"이 claw 자물쇠 3겹(Authelia → gateway token → pairing) 중
      **어디를 통과하는가.** gateway token만으로 붙으면 그건 Authelia 우회하는 네 번째 경로다.
      대상은 laptop/thinkpad(oracle은 aarch64 headless라 무관). 패키징도 3층 모델과 마찰.
- [ ] **`tools.sessions.visibility = "all"` 재검토** (8.2와 무관). 라이브에 명시돼 있어 8.2의 기본값 변경엔
      안 흔들리지만 새 기본보다 **넓다**. 가족 봇 섞인 6봇에 `tree`/`self`가 맞는지.
- [ ] **관찰 1건 (회귀 주장 아님)**: `gpt`·`gemini` 두 봇이 스모크에서 자신을 **"힣봇(glg)"** 이라 소개했다.
      모델 해상은 각자 정확했다. 8.2 이전과 대조하지 않았으므로 기록만 — 워크스페이스 페르소나가 겹쳐 보이는 자리.
- [ ] **미해명 — main 은 잡이 없는데 main 계정으로 하트비트 알림이 나갔다** (9/2 10:47:58,
      `outbound send ok accountId=default`). 방아쇠는 내 격리 프로브가 띄운 grep 이 턴 종료로 SIGTERM 된 것이고
      (`resolveHeartbeatTerminalToolFailure`), **8.2 회귀는 아니다**(그 경로는 8.1 이미지에도 있다).
      다만 `cron list --all` 엔 `heartbeat:bbot` 하나뿐이고 `agents.defaults.heartbeat.agentId`·`systemAgent` 둘 다
      unset 이라 **defaults 하트비트는 비활성이어야 한다** — 잡 없이 어떻게 배달됐는지는 못 밝혔다.
      **재발이 단서다**: 시각·계정·직전 턴의 도구 종료 상태를 함께 남길 것. 근거는
      [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) "미해명 — main 은 잡이 없는데".
      ⚠️ **처방으로 `agents.defaults.heartbeat.target: "none"` 을 쓰지 마라 — bbot 을 죽인다**(그 배달은
      살아 있어야 하는 라이브 기능). 막아야 하면 `agents.entries.<id>.heartbeat.target` 으로 그 봇만.
- [ ] **나머지 4봇 heartbeat 재활성 (GLG 예정)** — main·glg·gpt·mini 는 **검수 목적으로 일부러 꺼둔 상태**다
      (고장 아님). 검수가 끝나면 GLG 가 켠다. 되돌리기는 `config set agents.entries.<id>.heartbeat '{"every":"1h"}'`.
      켤 때 8.1 이 넣은 **턴 0회에도 owner DM typing** 동작이 함께 돌아온다는 것만 기억할 것.

### 교훈 (반복 방지)

- **시각은 훅이 아니라 `date`로 확인한다.** SessionStart 훅의 `time_kst`를 그대로 믿고 "지금 06:2x, 08:00 게이트
  전이니 bump 금지"라고 판단했는데 실제로는 **10:28**이었다 — 게이트는 2시간 반 전에 지나 있었다. 훅 값은
  세션 시작 스냅샷이고 세션이 길어지면 화석이 된다.
- **초록이 나오면 그게 진짜 내 파일을 읽은 초록인지 먼저 의심한다.** config 격리 파싱 1차 시도는
  `OPENCLAW_CONFIG` env로 경로를 주려다 전부 `unset`으로 나왔다. 값이 우리 것(`all`/`never`/`false`)으로
  읽히는 걸 확인하고 나서야 판정으로 썼다.

---

## 🟡 OpenClaw 9.4 업그레이드 — 검증 완료, 컷오버 승인 대기 (2026-09-11)

라이브는 `2026.8.2`(0965053, Dockerfile `FROM ghcr.io/openclaw/openclaw:2026.8.2`) 그대로다. 후보 `v2026.9.4`(3a9d69d)는 raw와 **실제 Dockerfile 레이어** 양쪽에서 열었다: `openclaw-custom:9.4-preflight` 빌드 성공, OpenClaw `2026.9.4`·Claude CLI `2.1.268` 확인. **아직 Dockerfile/라이브 config/state를 바꾸지 않았다.**

- shared state는 `v15 → v17`의 실제 migration이다. WAL-aware 라이브 사본에서 9.4 Doctor가 `Workshop ownership v16`과 `prepared worker v17`를 완료했고 canonical state index 1개도 재구성했다. `worker_environments=0`이라 prepared-worker 데이터 이관은 없다. 따라서 8.2로의 rollback은 이미지 tag만으로 불가하며 **사전 전체 state 복원**이 필요하다.
- 7개 agent DB는 schema `19` 유지지만 모두 `idx_agent_session_nodes_active` same-version index repair가 필요하다. 사본 Doctor는 완료했고 lint에 agent-schema 실패가 남지 않았다.
- config는 retired `skills.workshop.allowSymlinkTargetWrites` 때문에 9.4에서 처음엔 거부된다. Doctor가 이를 제거하고 `agents.defaults.systemAgent.agentId=main`을 추가한 사본은 `config validate` 통과했다. `active-memory` disabled·OpenRouter env 경고는 기존 상태다.
- Workshop pending 2건 중 **`next-current-pointer` 1건은 glg agent Workshop 경로로 retarget**, **`butlercli` 1건은 외부 symlink 대상이라 stale** 처리된다. 후자는 기존 skill을 지우지 않지만 Workshop proposal로는 더 이상 관리하지 않는다 — 수락 전 GLG가 stale 처리(거절/보존)를 승인할 것.
- 사본 lint의 `claude`/skills/gateway 경고는 raw image에 compose PATH·외부 mounts·실행 gateway를 주지 않은 격리 환경 산물이다. 실제 custom 후보 이미지에는 Claude CLI가 있다. Google profile expired 경고와 plaintext SecretRefs 권고는 컷오버 blocker가 아닌 기존 운영 부채다.

- [ ] **컷오버 승인 후에만**: (1) gateway를 idle로 만들고 config root+7 agent DB+shared DB를 WAL-aware 전체 백업(외부 `auth-profile-secrets` 포함) → (2) 현재 `openclaw-custom:latest`를 `8.2-rollback`으로 tag → (3) Dockerfile 9.4 bump/build, 새 이미지의 `doctor --fix` → (4) gateway 기동, `doctor --json`·7 agent DB index·Workshop 상태 확인 → (5) GPT bot 먼저 smoke turn 후 가족봇 확대.
- [ ] **사전 용량 재확인**: 현재 `/` 4.9GB(95%)라 9.4 preflight image가 있는 상태에서 무심코 새 build/backup을 겹치지 말 것. Docker reclaimable 4.28GB와 `/home` 18GB를 측정한 뒤 GLG 승인 아래 필요한 것만 정리한다.
- **Do not touch**: live `config/openclaw.json`을 미리 손수 삭제·state schema marker 하향·`8.2` image만으로 rollback 시도 금지. 실패 시 8.2 image + verified pre-upgrade state/auth backup을 함께 복원한다.

---

## 🟡 봇 시맨틱 스킬 stopgap 2개 — 다음 recreate에서 durable로 한 번에 종결 (2026-09-03)

andenken 통합 인덱스 소비자 검수(andenken [#11](https://github.com/junghan0611/andenken/issues/11#issuecomment-5518338358),
소비자축 종결)에서 나온 컨테이너 로컬 stopgap 두 개가 살아 있다. 둘 다 **같은 recreate 창에서** durable로 닫는다 —
전문·근본원인·역할 분담은 [issue #9](https://github.com/junghan0611/nixos-config/issues/9).

**stopgap ① env 16키** — 컨테이너 `/home/node/.env.local`에 `ANDENKEN_SESSION_*`/`ANDENKEN_MD_*` 직접 배치
(호스트 파이프, 값 노출 0, `600 node:node`). 래퍼 소싱 + `readEnvWithFileFallback`(`embedding-provider.ts:576`) 양쪽이 읽어서
재시작 없이 세션축·가든축 부활(실측 통과). ⚠️ legacy 전역 슬롯 `ANDENKEN_PROVIDER`는 openrouter를 거부하고 조용히 null —
반드시 namespaced `ANDENKEN_SESSION_PROVIDER`.

**stopgap ② dictcli store 스테이징** — agent-config 담당자가 nix store 2경로(glibc 2.40 인터프리터 + gcc-14.3.0-lib RUNPATH,
52M)를 `docker cp`로 컨테이너 쓰기 레이어에 복사. **봇 위치에서 Layer 3 한↔영 확장이 지금 실제로 돈다**
(`하네스→harness` 등 exit 0 실측, 2026-09-03). 지울 필요 없음 — recreate가 지운다.

### recreate 시 체크리스트 (이 창에서 전부 닫는다)

- [x] **`~/openclaw/.env`(env_file)에 ANDENKEN 블록 추가** — ①의 durable 승계. 16키, 값 비노출. 백업 `.env.bak-andenken-20260903T0930`.
- [x] **compose dictcli bind 2줄** — live 반영 후 **recreate 적용 완료** (2026-09-03 09:45 KST). gateway health=starting→텔레그램 6채널 polling. `openclaw-cli` 는 TUI owner 없어 exit 1 — 원래 상주 서비스가 아님.
- [x] **recreate 직후 호스트 검증**: 컨테이너 `./dictcli expand "하네스" --json` → `["harness"]` exit 0 (마운트 형태). `search-sessions "하네스"` → `expanded: ['harness']`, stderr `not found` 0. env 16키 process env에 존재.
- [x] 회수 상향 측정: `golden-queries.ts --compare` — **상향 0** (31/33 동일, 하락 4 / 상승 3). 설계 대표 `보편 학문`이 최대 하락(확장어 9개). 가설: 확장 폭 희석. 다음 작업(폭 제한·FHS 아티팩트)은 agent-config 라인. #9 프로비저닝은 닫힘.

**후속 (2026-09-03 10:3x)** — dictcli portable 전환(`4a3afd6`). compose store 2줄은 live+백업에서 **이미 제거**. 적용은 마운트 변경이라 recreate.
- [x] **다음 예정 recreate에 dictcli bind 제거분 적용** — 2026-09-03 10:36 gateway recreate. `/nix/store` 에 qqx8w6hd/rrd22q5c **NONE**, `./dictcli expand "하네스"` → `["harness"]` exit 0, `search-sessions` `expanded: ['harness']`, `not found` 0. skew 부채 소멸.

GLG 2026-09-03: 턴이 잠잠하면 **이 창에서 recreate 한다.** 아래 "OpenClaw 기억망 열기"는 이 창의 일이 아니다.

관련 큰 그림: andenken [#10](https://github.com/junghan0611/andenken/issues/10#issuecomment-5518477947).

---

## 🟡 OpenClaw 기억망 열기 — 바로 안 함 (2026-09-03)

andenken 세션축+가든 md는 봇이 읽는다. 다음 원은 **OpenClaw 쪽 기억망**이고 오늘 착수하지 않는다.

- [ ] OpenClaw 세션(`~/.openclaw/agents/*/sessions/`)을 andenken 코퍼스에 편입 → 양방향 고리
- [ ] `memory_search` stale ↔ `memory status` clean 불일치 — 재인덱스 후 "main 격리" 판정 재확인
- [ ] 시맨틱 크로스에이전트 vs andenken 일원화 — GLG 판단

**org 임베딩은 의도적 보류.** andenken org축 `production: disabled`가 미완이 아니다.
가든 md(`notes/content/`)만 공유한다. 켜려면 andenken을 많이 고쳐야 해서 보류 — 양쪽(이 리포·agent-config)이 이걸로 기억한다.

큰 그림·3면 대조: andenken #10.

---

## 🟢 Emacs 30.2 → 31.1 — thinkpad 완료, 나머지 디바이스는 각자 rebuild (2026-09-02)

**thinkpad switch GREEN.** 결정 배경·근거는 [ROADMAP.md](ROADMAP.md) 운영 결정 이력. 여기는 **남은 것만**.

- [ ] **oracle / nuc / laptop은 아직 30.2다.** 각 디바이스가 다음에 rebuild할 때 따라온다.
      oracle에서 특히 볼 것: `agent-emacs.service`의 `ExecStart=/run/current-system/sw/bin/emacs`는
      **HM이 아니라 시스템 `emacs-nox`를 탄다**(SSOT는 `~/repos/gh/geworfen/ops/systemd/`) —
      즉 rebuild 순간 봇 백엔드 emacs가 31로 바뀐다. 미리 확인해둔 것: aarch64 `emacs-nox-31.1`은
      cache.nixos.org에 있고(narinfo 200, 465MB nar) `systemd-minimal-libs-261.1`을 여전히 링크한다
      → 라이브의 `Type=notify`는 안전. 스모크는 `emacsclient -s /run/emacs/server -e "(+ 6 8)"` → `14`.

### ✅ oracle 이관 완료 (2026-09-02). 순서가 client-first 로 바뀐 이유

이 절은 원래 "rebuild와 `doom sync`를 같은 창에서"라는 경고였다. 실행 과정에서 **더 큰 함정이 나와
순서 자체가 바뀌었다.** 아래가 실제로 한 순서이고, 다음 emacs 업그레이드도 이 순서다.

**핵심 발견 — emacsclient/server 버전 스큐는 조용히 데이터를 썩힌다.**
Emacs 31 `server.el` 이 응답 청크 분할을 제거했고(upstream Bug#80807), 30.x client 는 고정 `BUFSIZ`
버퍼로 매 `recv` 를 독립 메시지처럼 처리해 쪼개진 protocol line 을 못 합친다. 약 8 KB 를 넘으면
인용 누출(`&_` `&-` `&n`) · payload 안에 `*ERROR*: Unknown message:` 주입 · **한글이 잘려 무효 UTF-8**.
`exit 0` · stderr 없음 · healthcheck `(+ 1 1)` 통과 · agenda HTTP 200 — **전부 초록인 채 내용만 깨진다.**
geworfen 이 실제로 서빙하는 `agent-org-agenda-day` 는 바쁜 날 8.6~8.8 KB 라 **메인 화면이 대상**이었다.

**그래서 client-first.** 31 client 는 옛 server 를 의도적으로 계속 지원하므로(실측: 31 client → 30 server
바이트 동등) 컨테이너를 먼저 올리면 깨진 방향이 한순간도 안 생긴다.

1. geworfen · openclaw-gateway 를 **31.1 emacsclient 로 먼저** recreate (호스트는 아직 30.2)
2. `./scripts/emacs-skew-check.sh` 로 확인
3. `sudo nixos-rebuild switch --flake .#oracle`
4. **곧바로** `doom sync` — `build-31.1` 생성 확인
5. emacs 데몬 재기동
6. `./scripts/emacs-skew-check.sh` 전 경로 + agenda 200 + 봇 경로

**마운트가 2개→5개로 늘었다.** 31.1 emacsclient 에 `libselinux` DT_NEEDED 가 새로 생겨 pcre2 까지 끌고 온다.
geworfen 은 앱 바이너리의 glibc(`jp8avbmp`)를 **유지한 채 추가**해야 한다 — 교체하면 ELF 인터프리터를 잃는다.
INTERP 는 `readelf -p .interp` 로 봐라. **`ldd` 는 자기 `RTLDLIST` 를 끼워 보여줘서 틀린다**(여기서 한 번 속았다).

**`agent-server.el` 의 버전 무관 선택이 남은 결함이다** (doomemacs-config 소관):
- `agent-server--find-straight-build-dir` 이 `build-*` 중 **mtime 최신**을 고른다. Doom 은 정반대로
  `build-<emacs-version>` 으로 버전 격리하는데 그걸 무력화한다.
- `:107-114` 가 eln 디렉토리를 `^[0-9]` 로 **nosort** 긁어 `add-to-list` 한다 → 31.1 데몬인데 경로
  첫 항목이 30.2 다. Emacs 는 새 `.eln` 을 첫 항목 아래에 쓰므로 **31.1 캐시가 안 찬다**(재기동해도 안 고쳐진다).
  기능 영향 없음(`.elc` 폴백). 근본 수정은 `emacs-version` 기준 필터.

**롤백면 — 만료일이 있다.** `sudo nixos-rebuild switch --rollback` (세대 69). 컨테이너는 세트 B 로:
`jp8avbmp`(앱) + **`jwg0irp5`**(client) + `3a0zzkx-emacs-nox-30.2`. emacs 줄만 갈면 안 뜬다.
현재 세대(70)의 클로저는 `3a0zzkx` 를 **0회** 참조하고 옛 세대만 잡고 있다 →
**2026-10-01 이후 세트 B 롤백 불가.** (`--delete-older-than 30d`)

- [ ] **롤백 창을 연장할지 판단.** 안 박으면 10/01 에 조용히 옵션이 사라진다:
      `nix-store --realise /nix/store/3a0zzkx…-emacs-nox-30.2 --add-root ~/gcroots/emacs-30.2-rollback --indirect`
- [ ] **gateway recreate 시 `[FATAL tini] exec tini failed: Too many levels of symbolic links` 3회.**
      2026-09-02 recreate 직후 5초 안에 나고 4번째에 정상 기동(`restart: unless-stopped` 가 건졌다).
      이후 FATAL 0. **원인 미확정** — 볼륨이 2→5 로 늘어 recreate 경합 창이 커졌다는 건 가설이다.
      geworfen 은 tini 를 안 쓰므로 대조군이 못 된다. **다음 재부팅이 재현 시험대.**
- [ ] **emacs31 클로저가 store에 두 벌 생긴다.** doomemacs-config의 unstable rev(`9fbb54b`)와 이 리포의
      rev(`ac6b216`)가 하루 차이라 클로저가 완전히 갈라진다 — 각 1.7 GiB, **공유 store 경로 0개**(224개 중 0, 실측).
      rev를 맞추거나, 더 나은 결말로 **doomemacs-config의 preview flake를 은퇴**시킨다("시스템이 31을 갖기 전에
      31을 미리 써본다"는 전제가 이 전환으로 사라졌다). `bin/emacs-unstable.sh`·`~/doomemacs-unstable`·
      `server-name=doom-unstable` 사슬이 걸려 있어 **doomemacs-config 쪽 판단**.
- [ ] **죽은 코드 3개** — `hosts/nuc/configuration.nix:174`, `hosts/oracle/configuration.nix:187`,
      `templates/nixos-oracle-vm/configuration.nix:186`의 `emacs-nox`. `machines/*.nix`는
      `hardware-configuration.nix`만 import하므로 이 파일들은 빌드에 들어가지 않는다. 남겨두면 다음 사람이
      "여기 고치면 되겠네"로 헛다리 짚는다. 이번엔 손 안 댔다.
- [ ] **(선택) 데스크톱의 시스템 `emacs-nox` 중복.** `machines/shared.nix:336`이 전 디바이스에 emacs-nox를
      깐다 → thinkpad/laptop은 HM gtk3와 시스템 nox를 둘 다 진다(31.1 기준 ~1.4 GiB). 전역 제거는 안 된다 —
      oracle의 `agent-emacs.service`가 그 경로를 하드코딩한다. 데스크톱 한정 분기라야 하고, 이번 전환과
      섞지 않았다.

### 이번에 배운 것

- **버전 올린 뒤 "안 되는 것"이 나와도 먼저 상류를 본다.** `ep`(pi 데몬 TTY)가 `Face inheritance results in
  inheritance cycle: gnus-group-news-low`로 죽었는데, 원인은 nix가 아니라 **Emacs 31이 새로 넣은 face 순환
  검사**였다(`strings emacs-31.1`엔 그 문자열이 있고 `emacs-30.2`엔 없다). 그리고 그 순환은 upstream
  doom-themes가 이미 `d114523`(2026-08-21)으로 고쳐둔 것이었다 — 우리 포크 체크아웃만 3월에 멈춰 있었다.
- **doom이 실제로 로드하는 것은 `~/repos/gh/<pkg>`가 아니라 straight 체크아웃이다.**
  `~/doomemacs/.local/straight/repos/`는 별개 클론이다(심링크 아님). 리포를 고쳐놨는데 증상이 그대로면
  거기부터 본다.

---

## 🟢 OpenClaw — `2026.8.2` 로 안정화 고정 (2026-09-06 GLG 결정)

> **9.x 로 올라가지 않는다.** upstream 은 `v2026.9.1`(9/03) · `v2026.9.2`(9/05) 까지 나왔고 latest 는 9.2 다(`gh release list` 2026-09-06 실측). **지금 있는 버전으로 안정화하는 것이 이번 판의 목표**이므로 그 둘은 읽지도 않는다 — 조망은 다음 릴리즈 판에서 한 칸에 몰아 본다.
> 라이브 = `OpenClaw 2026.8.2 (0965053)` · `openclaw-custom:latest` · Up 3일 healthy · 핀 `docker/openclaw/Dockerfile:200`. 롤백면 = `openclaw-custom:8.1-rollback`.

**라이브 = `2026.8.1` (ea80657), healthy.** 컷오버 경위·3층 검수 결과·폐기된 반사신경 3건은 [CHANGELOG.md](CHANGELOG.md) `v2026.8.31`로 이관했다. 11겹 함정표·재현 절차는 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md), 버전 이력은 [ROADMAP.md](ROADMAP.md). 여기는 **남은 것만**.

증거 사슬: `~/openclaw/backups/pre-8.1-cutover-20260831T203708/` (cold 백업 1.8G + gate4~16 stdout/stderr/status + `ROLLBACK.sh`).

- [x] **ORACLE.md 재작성** — 2026-09-06 완결(① 8/31 · ②③④ 이번 세션). ① `doctor --fix 금지`(:265,:280) → **8.1에선 필수 절차**로 성격이 바뀌었다(단 gemini는 이미 Copilot 레일이라 겨눌 대상 없음). ② config 키 이름: `agents.list`→`agents.entries`, `agents.defaults.memorySearch`→`memory.search`, `tools.exec.security/ask`→`tools.exec.mode`, catch-all 규율은 `agents.defaults.models` 키 순서 → **`agents.defaults.modelPolicy.allow` 배열 순서**. ③ 런타임 지형표에서 codex 행 삭제(=2026-08-07 GLG 결정이 이번에 완결됨). ④ `agents.ownership=explicit` + `bindings` 6개 명시가 새 baseline.
- [x] **issue #7 닫기** — 2026-09-06 receipt 코멘트 + close.
- [ ] **레거시 잔재 청소 (비긴급)** — `config/agents/*/sessions/*.migrated` 다수 + `sessions.json.bak*`(gpt 한 세션의 `pre-doctor-openai-codex-repair` 계열만 60M+). soak 는 통과했으나 **`update cleanup` 이 못 집는다**(위 항목) → 지운다면 수동이고, 그건 롤백 원본 포기 선언이다. `backups/…/isolated-orphans/telegram-deepseek-allowFrom.json`도 그때 판단.
- **오해 방지 3건 (정상이다)**: ① boot 라인이 `11 plugins`인데 `plugins list`는 `12/66 enabled` — 차이는 `google`이고 8.1이 provider를 **lazy-load**한다(설치·enabled 상태 정상, `stock:google/index.js`). ② `AgentSelectionRequiredError`는 `--agent` 없이 CLI를 친 **내 호출** 탓이지 봇 문제가 아니다(ownership=explicit의 정상 동작). ③ telegram `menu text exceeded … 5700-character budget` — 명령 101개라 설명만 줄인다, 기능 영향 없음.
- [ ] **⚠️ 백업 범위 정직하게 — 내 컷오버 백업에는 트랜스크립트가 없다.** `pre-8.1-cutover-20260831T203708/`(1.8G)은 *마이그레이션 대상*(agent/state/plugin-state sqlite, cron, tasks, openclaw.json, sessions.json)만 담았다 — `.jsonl` **0개**(실측). 트랜스크립트를 든 pre-8.1 스냅샷은 **형제가 19:06에 뜬 `pre-8.1-20260831T190622/config-state-cold.tar.zst`(837M, main만 `.jsonl` 276개)** 쪽이다. 즉 **두 디렉터리가 합쳐져야 온전한 롤백면**이다 — soak 통과 전에는 둘 다 지우지 말 것.
- [x] **디스크 회수 — 2026-09-06 실행.** `/home` **87% → 78%(+8.2G)**, docker **build cache 3.72GB + 중간 이미지 2벌** 회수.
      ① `upgrade-lab/8.1-…/evidence`(26M) + `TARGET-CONFIG-SHA256` 을 `backups/pre-8.1-cutover-20260831T203708/lab-evidence/` 로 먼저 구조(`diff -rq` 검증) → ② `rm -rf ~/openclaw/upgrade-lab`(8.2G) →
      ③ `openclaw-custom:8.1-candidate`·`candidate2` 이미지 삭제 + `8.1-candidate3` 태그 해제(같은 id 를 `8.1-rollback` 이 계속 든다) + `docker builder prune -af`.
      ④ **유지**: `pre-8.1-20260831T190622`(837M cold tar, 트랜스크립트 포함) + `pre-8.1-cutover-20260831T203708`(1.8G, 마이그레이션 대상 + gate 증거 + lab-evidence). 둘이 합쳐져야 온전한 롤백면이다.
- [x] **롤백면 은퇴 — 2026-09-06 (GLG: "롤백은 안해").** `backups/` **2.8G → 27M**(gate 증거 17벌 + lab-evidence 26M 만 남김): `pre-8.1-cutover/config` 1.8G · `pre-8.1/config-state-cold.tar.zst` 836M · 옛 백업 3벌 145M · 4월 `openclaw.json.bak-2026042x` 11개 삭제.
      이미지도 7.1 면 전체 은퇴(`7.1-rollback`·`pre-8.1-…` 태그·`ghcr…:2026.7.1-2`) → docker 12.62GB → **9.77GB**.
      **`openclaw-custom:8.1-rollback` 하나는 남겼다** — 우리 커스텀 빌드라 재현하려면 npm 설치 단계를 다시 타야 하고, 11겹 사고의 10번이 정확히 거기서 났다. 2.41G 짜리 보험.
      누적: `/home` 94% → **75%**, `/` 94% → **91%**.
- [ ] **아직 못 지우는 두 덩이 — 유일본 가능성.** ① `session-sqlite-import-archive` **417M**: `update cleanup` 이 스스로 `verification-required / historical-manifest-without-import-proof` 라고 판정한다. 확인해보니 `agents/glg/sessions/` 에 **살아 있는 `.jsonl` 이 0개** — 원본이 이 archive 뿐일 수 있다. ② `*.pre-doctor-*.bak` 67M + `*.jsonl.bak-N` 24M + `*.migrated` 4M, 같은 이유. **도구가 "증명 못 했다"고 말한 것을 눈대중으로 지우지 않는다** — 지우려면 sqlite 안에 해당 전사가 있다는 증명이 먼저다.
- [ ] **`openclaw update cleanup` 은 지금 아무것도 회수하지 않는다 (2026-09-06 실측).** `--dry-run` 결과 **`Candidates: 0 bytes`**, `verification-required: 434MB`(`session-sqlite-import-archive/*.imported-*`, 사유 `historical-manifest-without-import-proof`), `protected: 75MB`(`*.migrated`·`*.pre-doctor-*.bak`, 사유 `unmanifested-recovery-original`). **즉 `--yes` 를 눌러도 0바이트다** — CLI 정규 경로가 우리 잔재를 아직 못 집는다. `.migrated`/`.bak` 수동 청소는 이 판정을 알고 하는 것이지, 그 명령으로 되는 일이 아니다.
- [x] **[sorge#1](https://github.com/junghan0611/sorge/issues/1) 의 이 리포 몫 — 호스트별 authority · writable 계약 선언.** ORACLE.md §"호스트별 기억축 authority" 에 `writer | read-only consumer | absent` 표로 박았다.
      **부수 발견이 본체였다**: ORACLE.md mount 표가 `~/repos/gh` 를 **rw** 로 적고 있었는데 실물은 **2026-08-12 부터 ro** 다(compose:72–73, `docker inspect … rw=false`). sorge#1 의 `openclaw.lance` EROFS 는 권한 사고가 아니라 **계약대로**였고, 그 축은 oracle 에 **absent** 다. 표를 실물에 맞췄다.
      **금지**: 그 EROFS 를 이유로 bind 를 rw 로 되돌리는 것. 필요한 건 consumer 쪽 absent 응답(= `agent-config` 몫)이다.
- [ ] **🟠 OpenClaw 임베딩 저장 부피 — A층은 우리 몫이다 (2026-09-06 최초 계량).** `agents/` 3.7G 중 기억축 1.53G 이고 **그 62% 가 인덱스가 아니라 캐시**다(`dbstat`):
      `memory_embedding_cache` 11,079행 **948MB**(그중 **6,955행=63% orphan** — `memory_index_chunks` 에 같은 `hash` 없음) · `memory_index_chunks` 4,909행 419MB · vec 160MB.
      원인 ① `embedding` 이 **TEXT** — 4096 float 를 JSON 문자열로 저장해 행당 **86KB**(blob 이면 16KB). ② **상한은 있다 — `Cache cap: 50000`**(`status --deep` 이 찍는다, 6봇 공통. 앞서 "안 보인다"고 적은 것은 틀렸다). 다만 **행수** 상한이라 86KB/행이면 50,000행 = **4.3GB** 다. 현재 최대 glg 5,783행 = 상한의 12%.
      `freelist_count` 6봇 전부 **0** → DB 팽창이 아니라 실데이터. 캐시 행은 전부 현행 모델(8B/4096d)이라 옛 모델 걸러내기 식 청소는 없다.
      **디스크만의 문제가 아니다** — 2026-09-06 latency 측정에서 검색 속도도 이 `embedding TEXT` 바이트에 선형(0.5초/MB)임이 드러났다. 5번과 한 뿌리다.
      **다음 한 수**: orphan 삭제 + `VACUUM` ≈ **600MB** 회수, **성공 기준에 검색 latency 재측정을 포함한다**. 배타 락이라 **게이트웨이 정지 창 필요** → 8.2 soak 더 보고 GLG 승인 후. 상류엔 `embedding TEXT` 를 리포트 대상으로 본다.
      **소유권 (GLG 2026-09-06)**: OpenClaw 임베딩 품질·설정은 이 집 몫, `andenken` 은 결과물을 쓰는 쪽. 소스 실측은 [andenken#13](https://github.com/junghan0611/andenken/issues/13#issuecomment-5557290434) 로, 층 분리는 [sorge#1](https://github.com/junghan0611/sorge/issues/1#issuecomment-5557292984) 로 넘겼다 — **export 는 `memory_index_chunks` 에서만(415MB), 캐시엔 `path`·`text` 컬럼이 아예 없다.**
- [x] **[sorge#1](https://github.com/junghan0611/sorge/issues/1#issuecomment-5557531010) 7번 oracle receipt — 2026-09-06 다섯 줄 전부 통과.** `andenken 1e61698` + `agent-config ad347ef` 기준. **§1 의 `os error 30` 이 사라졌다** — 컨테이너에서도 `state:absent, authority:thinkpad` + exit 4 로 답한다. 축을 세 경로로 읽었는데도 `openclaw.lance` 는 안 생겼다(그게 요점). 회귀: `verify openclaw`=not found · `verify bogus`=exit 1 · `test:absent` 26 passed · `search:md` 대조군 1건 회수.
      ⚠️ **측정 함정**: `./run.sh verify bogus | tail -5` 로 재면 `$?` 가 tail 것이라 exit 0 으로 보인다. 파이프 걷고 재야 exit 1 이 나온다.
- [x] **[sorge#1](https://github.com/junghan0611/sorge/issues/1#issuecomment-5557783694) 5번 — dirty 해소 완료. timeout 은 원인 특정, 설정으로 못 고친다 (2026-09-06).**
      **dirty**: main·glg·gpt 셋이었다(gpt 만이 아니다. glg 는 `109/108` off-by-one 까지). 해소 = **증분 재색인 `openclaw memory index --agent <id>`** — main 25s·gpt 5s·glg 6s, **6봇 전부 `Dirty: no`**. 새 청크분만 임베딩한다. `--force` 는 전량 재임베딩이라 **쓰지 않는다.**
      **timeout**: 봇 실경로에서 **지금도 죽는다** — `openclaw agent`(게이트웨이 경유, 프로브 세션) 실측 `mini 14.7s 성공 / glg 27.7s 타임아웃`. 봇이 *"검색 도구 타임아웃으로 실패했습니다"* 라고 자답한다.
      **원인은 임베딩도 인덱스 크기도 아니라 락 경합이다.** 성분을 다 쟀더니 합쳐서 1초다 — FTS 0.005s · vec0 KNN+JOIN k=1600 **0.103s** · 최악의 TEXT 폴백 전량(163MB 읽기+JSON.parse 1,945행+JS 코사인, node) **1.04s**. 결과 0건 질의도 92초였다(= 계산이 아니라 대기).
      구조(형제 grok-4.6 의 `/app` 번들 독해): **메모리 인덱스와 세션 전사가 같은 sqlite 파일**이고 `store.databasePath` 는 고정이라 **분리 불가** · 메모리 매니저가 DB 를 **RW 로 연다**(KNN 자식만 readOnly) · **`sync.onSearch:true` 하드코드**.
      **설정 노출 0**: `busy_timeout`(5s)·`journal_mode`·`wal_autocheckpoint`(1000p)·checkpoint(30분 PASSIVE)·`journal_size_limit`(64MB)·`onSearch`·**검색 데드라인 15s**·DB 경로 전부 하드코드. gpt 의 241MB WAL 도 같은 자리.
      **철회한 내 주장 3개**: ~~latency 가 크기에 선형(0.5초/MB)~~ → 에이전트를 크기 오름차순으로 루프 돌며 잰 **측정 산물**이었다(4 vCPU·load 4.8). ~~vec0 가 안 쓰인다~~ → `status --deep` 이 `ready` 를 찍고 있었다. ~~`embedding TEXT` 파싱이 속도의 축~~ → node 로 1초.
      ⚠️ **이 호스트에서 latency 를 잴 때**: 4 vCPU 다. 직렬로, 샘플 사이 간격을 두고, 부하를 같이 기록하고, 중앙값으로 본다. 병렬로 재면 큐 대기를 재는 것이다. `docker exec` 를 연달아 치면 앞 워커와 겹친다.
## 🔴 봇 기억축을 **세션만**으로 좁힌다 — 깨끗한 베이스로 재출발 (GLG 결정 2026-09-06)

**결정**: `memory.search.sources` 를 `["memory","sessions"]` → **`["sessions"]`** 로. 다시 임베딩하더라도 **깨끗한 베이스에서** 시작한다.

**왜 — 지금 memory 축의 절반이 우리가 꺼둔 기능의 4월 화석이다** (2026-09-06 실측, `mode=ro` 직접 조회):

| bot | total | memory | 그중 **dreaming** | 그중 MEMORY/USER | sessions | 그중 deleted |
|---|---|---|---|---|---|---|
| glg | 1,946 | 903 | **445** | 154 | 1,043 | 12 |
| gpt | 1,068 | 543 | **313** | 61 | 525 | 5 |
| bbot | 1,149 | 472 | 0 | 6 | 677 | 10 |
| main | 430 | 233 | 21 | 104 | 197 | 0 |
| gemini | 165 | 130 | 46 | 21 | 35 | 2 |
| mini | 157 | 81 | **68** | 12 | 76 | 3 |
| **합** | **4,915** | **2,362** | **893** | **358** | **2,553** | **32** |

`memory/dreaming/light/2026-04-2x.md` — **dreaming 은 라이브에서 `false` 로 꺼져 있는데** 그 4월 산출물 893청크가 아직 검색 상위를 다툰다(mini 는 memory 축의 84%). 삭제된 세션(`.deleted.*`) 32청크도 인덱스에 남아 있다.

**세션만 남기면 (B 실행 후 기준) 4,035 → 2,553 청크, embedding 텍스트 214MB.**

### ⚠️ 대가 — 이건 공짜가 아니다

`sources:["sessions"]` 는 dreaming 만 빼는 게 아니라 **`MEMORY.md` · `USER.md` · `memory/YYYY-MM-DD.md` 를 통째로 뺀다(358청크가 MEMORY/USER)**. 봇의 **장기 기억 정본이 의미 검색에서 사라진다**. 파일은 그대로 있고 봇이 직접 읽을 수는 있지만, `memory_search` 로는 안 잡힌다.
→ **GLG 확인 필요**: 이 대가를 받는 게 맞나, 아니면 dreaming 만 빼는 길(아래 대안 B)을 먼저 볼 것인가.

### 절차 (라이브 쓰기 — 승인 후 실행)

- [ ] **0. 백업** — `openclaw.json` + 6봇 `memory_index_chunks` 청크 수 스냅샷. 롤백선은 `sources` 한 줄 되돌리기.
- [ ] **1. 기준선 고정** — 봇 실경로 latency 를 지금 값으로 박는다: `mini 14.7s 성공 / glg 27.7s 타임아웃`(`openclaw agent --session-key probe-memlat-…`). **이게 성공 판정의 분모다.**
- [ ] **2. config** — `memory.search.sources = ["sessions"]`. ⚠️ `agents.defaults.models` 처럼 키 순서가 걸린 자리가 아니므로 `config set` 으로 충분하나, 편집 후 `config validate` 필수.
- [ ] **3. 죽은 청크 회수** — `sources` 만 바꾸면 기존 memory 청크가 인덱스에 남을 수 있다. `memory index` 증분이 지우는지 먼저 확인하고, 안 지우면 `memory forget` 경로를 **`--dry-run` 으로 먼저** 본다. **`--force` 재색인은 금지**(전량 재임베딩 = 비용).
- [ ] **4. 검증** — ① 청크 수 4,915 → ~2,553 ② `Dirty: no` 6봇 ③ **봇 실경로 latency 재측정, glg 가 15초 게이트를 통과하는가** ④ 회수 품질 스모크: 봇에게 최근 대화 한 건을 기억 검색으로 찾게 시킨다.
- [ ] **5. 되돌림 조건** — glg 가 여전히 타임아웃이면 이 변경은 **latency 문제를 못 고친 것**이다(아래 참조). 그때는 품질 이득만 남으므로 유지할지 되돌릴지 다시 판단.

### 정직하게 — 이건 latency 의 근본 처방이 아니다

latency 의 원인은 코퍼스 크기가 아니라 **검색 경로가 DB 를 RW 로 열고 쓰기를 한다는 것**이다(아래 sorge#1 5번 항목). 라이브 파일을 `mode=ro` 로 열면 같은 시각 같은 쿼리가 **0.047초**다. 그러니 이 작업의 1차 성과는 **검색 품질**(죽은 4월 dreaming 이 상위에서 빠짐)이고, latency 개선은 부수효과로 기대할 뿐 보장이 아니다.

### ✅ B 실행 완료 — dreaming 4월 화석 880청크 회수 (2026-09-06 18:3x, GLG 승인)

`memory forget` 은 **세션 단위**라(`--session/--participant/--hook-source/--since`) 경로 지정이 안 된다. 그래서 **파일 쪽**으로 갔다 — **인덱스는 파일을 따라간다**.

**한 일**: 워크스페이스 5곳의 `memory/dreaming/{deep,light}/2026-04-2x.md`(21파일씩, 합 984K)를
`~/openclaw/backups/dreaming-april-20260906T183253/<workspace>/memory/dreaming/` 로 **이동**(삭제 아님) → 6봇 증분 `memory index`(각 6~7초).
`DREAMS.md` 와 `memory/.dreams/` 는 **인덱스에 없어서 안 건드렸다**(실측 0청크).

**결과** — 정확히 예측대로다:

| bot | 청크 | dreaming 잔여 | embedMB | dirty |
|---|---|---|---|---|
| glg | 1,959 → **1,514** | 0 | 127.1 | no |
| gpt | 1,068 → **755** | 0 | 63.3 | no |
| main | 430 → **409** | 0 | 34.3 | no |
| gemini | 165 → **119** | 0 | 10.0 | no |
| mini | 157 → **89** | 0 | 7.5 | no |
| bbot | 1,149 → 1,149 | 0 (원래 없음) | 96.4 | no |
| **합** | **4,915 → 4,035** | | | |

config 변경 0 · 재임베딩 0 · 게이트웨이 정지 0 · 완전 가역(디렉터리 되돌리고 증분 색인).

**latency 는 안 고쳐졌다 — 그리고 그게 진단이 맞았다는 증거다.** 봇 실경로 재측정:

| | 기준선(정리 전) | 정리 후 |
|---|---|---|
| mini | 14.7s 성공 | **12.0s 성공** |
| glg | 27.7s **타임아웃** | **26.1s 타임아웃** |

glg 는 청크가 23% 줄었는데 1.6초 줄었다. **코퍼스 크기는 원인이 아니다** — 원인은 검색 경로가 DB 를 RW 로 열고 쓰기를 한다는 것이고(read-only 로는 같은 쿼리가 0.047초), 그건 우리 설정 밖이다.

**얻은 것**: 죽은 4월 dreaming 이 검색 상위에서 사라졌다(mini 는 memory 축의 84%가 그거였다). 재임베딩할 일이 생겨도 이제 깨끗한 베이스에서 시작한다.
- [ ] **회수 확인 후 backups 정리** — 한 달쯤 두고 아무도 안 찾으면 `dreaming-april-20260906T183253` 삭제(984K).

## 🟠 회수 품질 — 8칸 중 7칸이 "지워진 것 + 한 대화" (2026-09-06 실측)

속도와 별개 축이다. **설정으로 못 고친다** — 정확히는 *이 두 증상을 고치는* 설정 레버가 없다(minScore/maxResults/sources 는 있지만 아래 이유로 안 듣는다).

### 증거 한 장 — gpt, `q='임베딩'`, `--max-results 8`

```
0.7607  sessions/gpt/8cdd31ae-….jsonl.deleted.2026-09-03T09-51-09.319Z.….zst   ← 1위
0.7253  sessions/gpt/999d7150-95ca-41b6-9209-400d1aa99c6a.jsonl
0.7213  …999d7150…   0.6928  …999d7150…   0.6740  …999d7150…
0.7253  …999d7150…   0.6692  …999d7150…   0.6584  …999d7150…
```

**1위가 3일 전 삭제된 세션이다.** gpt 인덱스 전체 deleted 청크는 **5개뿐**인데 그 하나가 1위를 먹었다.
나머지 7칸 중 **6칸이 세션 하나**(`999d7150` = gpt sessions 525청크 중 **335, 64%**).

### 기전 (형제 grok-4.6 의 `/app` 소스 독해 + 위 실측)

| 결함 | 내용 |
|---|---|
| **deleted 아카이브를 고의로 색인한다** | 인덱서가 `.deleted`/`reset`/`bak` 를 `archive-artifact` 로 코퍼스에 넣는다. 검색 필터는 `conversationRecall` 일 때만 drop → 일반 `memory_search` 엔 남는다 |
| **세션은 mtime 으로 감쇠한다** | temporalDecay(halfLife 30일)는 `memory/…/YYYY-MM-DD.md` 는 **경로 날짜**로 깎지만(4월 dreaming 은 계수 0.041), **세션은 경로에 날짜가 없어 파일 mtime** 을 쓴다. append 되는 세션은 **영원히 새것**이다 |
| **세션당 캡·다양성 보정이 없다** | 검색 경로에 세션 캡·path diversity·sessionId 페널티 **0**. MMR(λ=0.7)은 스니펫 Jaccard 만 보고 **sessionId 를 안 본다** — 위 6/8 이 그 증거다 |
| **`chunkTokens:400` 은 토큰이 아니다** | 토크나이저 없음. `maxChars = tokens×4 = 1600 "추정 문자"` 이고 한글은 **글자당 ×4** 로 세어 한글 순수면 ~400음절/청크. 하한이 없어 `- 안녕` 같은 **6자 청크**도 생긴다 |

### minScore 는 **안 만진다** — 히스토그램이 그렇게 말한다

CLI `--json --max-results 8`, 직렬 측정:

| 질의 | 점수 band |
|---|---|
| `cron 회귀` | **0.35 ~ 0.42** |
| `기억` (2자) | 0.40 ~ 0.53 |
| `임베딩` | 0.65 ~ 0.82 |

- **`cron 회귀` 가 전 구간 0.35~0.42 다.** 문서 기본값 **0.35 로 올리면 이런 실질 질의가 먼저 죽는다.** 라이브 0.3 이 그걸 살리고 있다.
- **짧은 CJK 가 점수로는 안 무너진다** — `기억`(2자)이 `cron 회귀` 보다 높다. FTS 가 `<3자 CJK` 에서 MATCH 대신 LIKE 로 떨어지는 건 코드 사실이지만(textScore=0, 사실상 벡터-only), 이 코퍼스에선 벡터만으로 버틴다.
- **deleted 1위(0.76)는 임계값 문제가 아니다** — 0.3 이든 0.35 든 통과한다.

### 📌 문서에 박을 한 줄

**`memory_search` 결과의 1번은 최고점이지만, 2번부터는 점수 내림차순이 아니다(MMR 재정렬).** 점수는 안 바뀌고 순서만 바뀐다 — 버그가 아니다. "1위 = 가장 관련" 은 맞고 "8칸이 점수순" 은 틀리다.

### 남은 레버 둘 — 설정이 아니라 운영

- [x] **① 세션 아카이브 이동 — 완료 (2026-09-06, GLG 승인). 32청크가 아니라 835청크였다.**
      내가 처음 센 32 는 `.deleted.` 만이었다. **`.reset.`(사용자가 `/reset` 한 세션)이 803청크로 본체**다:
      `deleted 32 + reset 803 = 835`, 전체의 **21%**. bbot 은 470/1,149 = **41%** 가 reset 아카이브였다.
      6봇 `sessions/*.{deleted,reset}.*` 47파일·2.4M 을 `~/openclaw/backups/session-archives-20260906T185012/` 로 이동 → 증분 색인.
      **결과: 4,037 → 3,202 (-835), 아카이브 잔여 0.** config 변경 0 · 재임베딩 0 · 가역.
      | bot | 청크 | | bot | 청크 |
      |---|---|---|---|---|
      | glg | 1,515 → 1,503 | | main | 409 → 311 |
      | gpt | 755 → **572** | | gemini | 119 → 111 |
      | bbot | 1,149 → **669** | | mini | 90 → **36** |
      **누적: dreaming 880 + 아카이브 835 = 1,715청크 회수 (4,915 → 3,202, -35%).**
- [ ] **② 지배 세션 — 압축은 GLG 가 직접 한다 (2026-09-06 결정). 에이전트는 손대지 않는다.**
      **둘 다 GLG 의 실제 텔레그램 DM 이다.** 정체를 확인하고 나서 성격이 갈렸다:
      - **gpt `999d7150` = `agent:gpt:telegram:gpt:direct:123861330`, 27h 전, `237k/200k` = 컨텍스트 118% 초과.**
        검색 품질과 무관하게 **이미 운영상 압축이 필요한 상태**라 실행했으나 **2회 모두 실패**:
        `Compaction failed: Auth profile "openai:junghanacs@gmail.com" is temporarily unavailable for openai/gpt-5.6-sol`
        압축은 LLM 요약이라 모델 호출이 필요하다. 프로필 자체는 정상(`expires 2026-09-14`, cooldown 표시 없음)이고 6채널 전부 `works` — **일시적 provider 조건으로 보인다. 나중에 재시도.**
        ⚠️ `--max-lines` 로 자르면 모델 없이 되지만 **요약이 아니라 절단**이다. 라이브 DM 에 손실 방식을 임의로 쓰지 않았다.
        **→ GLG 가 직접 압축하기로 했다.** 에이전트는 재시도하지 않는다. 압축 후 `memory index --agent gpt` 증분만 돌리면 인덱스가 따라온다.
      - **glg `7bc4935f` = `…:telegram:glg:direct:8960149052`, 5일 전 마지막 활동, `148k/1000k` = 15%.**
        **의도적으로 멈췄다** — 컨텍스트가 건강하고(15%), **GLG 본인 DM 이 아닌 다른 텔레그램 사용자와의 대화**다(다른 glg DM 은 `81880552`·`123861330`). 압축은 인덱스 정돈만을 위해 **남의 대화를 다시 쓰는 일**이라 승인 범위를 넘는다고 판단했다. **이것도 GLG 몫으로 넘긴다.**

### 상류 리포트 (확정 4건 + 증거)

세션 mtime 감쇠 · 세션 캡 없음 · deleted 아카이브 색인 · `chunkTokens` 가 토큰이 아님. 증거는 위 "8칸 중 7칸".

---

- [ ] **⏸ GLG 판단 — `memory.search.provider: "none"`(FTS-only) 을 한 봇에 시험할지.** 유일하게 남은 설정 탈출구다: embedQuery 왕복과 KNN 자식 스폰이 사라지고 5ms FTS 만 남는다. 대가는 의미 검색 상실(키워드만). 라이브 쓰기라 승인 전 보류. 되돌리기는 쉽다 — 후보는 gpt 나 bbot.
- [ ] **상류 리포트 후보 2건** — ① 메모리 인덱스와 세션 전사가 한 파일이고 검색 매니저가 RW 로 연다(바쁜 봇에서 검색이 락에 갇힌다) ② `embedding` 을 TEXT 로 저장한다(행당 88KB = 텍스트의 138배). 우리가 못 고치는 층이다.
- [ ] **정기 작업으로 승격 검토** — `memory index` 는 dirty 가 뜰 때마다 필요하다(6봇 순회 1분 이내). cron 에 얹을지, 사람이 볼 때 돌릴지 판단. 얹는다면 [docs/openclaw-automations.md](docs/openclaw-automations.md) 가 SSOT.
- [ ] **Skill Workshop 잔여 2건** — `off` 인데도 6/15 부터 살아 있던 glg 제안 `next-current-pointer-20260615-958582b72f` 을 **사람이 처리**해야 한다(`apply`/`reject`/`quarantine`). 쓰기 경로 질문은 닫혔다(ORACLE.md §Skill Workshop: 대상은 워크스페이스 실디렉터리, SSOT 는 mount ro 로 2차 방어 — probe 로 확인). 남은 미해결은 **scanner 의 `clean` 판정 근거**와 **제안 3개 상한 도달 시 동작**.
- [ ] **별건 2개 (업그레이드 이전부터 있던 간극)**: bbot workspace에 skills 미배포(`run.sh k)` 재실행 필요) / bbot·mini `IDENTITY.md` 형식이 달라 `agents list`에 Identity 줄이 안 뜬다(봇 본인은 자기 정체성을 정확히 안다 — 실턴으로 확인).

---

## 🟡 uid 전체 SIGTERM 사건 — 발신자 미상, 감사 설비만 갖췄다 (2026-09-01)

2026-09-01 20:42:53.53~.63, **93ms 안에 uid 1000 프로세스 전체가 SIGTERM**을 맞았다. SSH 세션 5개(`mm_reap: child terminated by signal 15`), tmux 판 전부(1~2주 붙어 있던 pane 5개), emacs, syncthing, gpg-agent, `systemd --user`, prime-agent 데몬 수퍼바이저, 그리고 **호스트 uid가 1000이던 컨테이너 3개**(openclaw-gateway/forge/aions-cloudflared)가 동시에 죽었다. root로 도는 컨테이너 11개는 무사 — 컨테이너 단위도 도커 단위도 아닌 **uid 단위 신호**, `kill(-1, SIGTERM)`의 서명이다.

공격이 아니다: 오늘 성공한 SSH 로그인은 전부 junghan 본인 IP 2개, 외부 성공 0. 스캐너(34.81.32.10)의 `.env`/`docker-compose.yml` 탐색 619건은 **전부 308, 200 하나도 없음**. OOM도 아니다(23Gi 중 11Gi free, `OOMKilled=false`, systemd-oomd 로그 0건).

**발신자를 못 밝혔다.** auditd 꺼짐 · atuin 오늘 105건 중 kill/reboot/systemctl 0건(마지막 대화형 입력 19:20:29 `piao`) · 20:42 근처 발화 타이머 없음 · `.bash_logout`/`.zlogout` 부재 · 20:42대 코어덤프 없음 · 오늘자 에이전트 transcript 전수 검색 0건. prime-agent(마지막 도구 호출 20:18)·entwurf·openclaw 컨테이너(PID 네임스페이스 격리) 셋 다 코드 경로 확인 결과 브로드캐스트 수단이 없어 **전부 피해자**로 판정.

- [ ] **재발하면 즉시 `sudo audit-query term`.** 이번엔 못 밝혔지만 다음엔 한 줄로 나온다. 발신자가 잡히면 여기에 박고 근본을 고친다.
- [ ] **저널 1G 상한과 감사 로그가 사후 분석의 두 축.** `diskclean.sh`는 저널을 200M로 vacuum하려 하지만 `sudo journalctl`이 NOPASSWD가 아니라 매번 건너뛴다. 이제 선언적 1G(커밋 `deb63b6`)가 그 역할을 하니 **스크립트의 200M 단계를 빼거나 1G로 맞출지 판단 필요**. 200M이었으면 이번 추적이 불가능했다.

---

## 🟡 재부팅 부팅 순서 레이스 — caddy·emacs 둘 다 막았다 (2026-08-16 → emacs 2026-09-01 해결)

커널 `7.1.2 → 7.1.4` 재부팅(04:49 KST)이 **독립된 부팅 레이스 두 개**를 동시에 터뜨려 `junghanacs.com` 서브도메인 전부가 5시간 죽었다. 둘 다 "docker가 다른 무엇보다 먼저 뜨느냐"에 결과가 갈리는 같은 모양이다. 복구는 끝났고(전 vhost 200), **둘 다 항구 차단됐다** — ①은 2026-08-31, ②는 2026-09-01.

**① caddy 443 선점 — 영구 수정 완료.** 경위(tailnet 443 선점 → caddy `exit 128` → 5시간 무응답)와 조치(enp0s6 NIC `10.0.0.157` 바인딩)는 [CHANGELOG.md](CHANGELOG.md) `v2026.8.31`. 이 자리에 남은 건 아래 하드코딩·근본 판단 둘뿐이다.

**② geworfen/agenda — 해결 (2026-09-01).** 2026-09-01 21:15 재부팅에서 **예측 그대로 재현**됐다: docker가 먼저 떠 `/run/user/1000/emacs`를 root 소유로 생성 → `agent-emacs` 기동 실패(*"is not a safe directory"*) → geworfen healthcheck 실패 → autoheal 재시작. 커밋 `d86d9d8`이 `emacs-socket-dir.service`(`After=user-runtime-dir@1000`, `Before=docker.service docker.socket`, `install -d -o junghan -g users -m 0700`)로 항구 차단했다.

후보 ⓒ(systemd-tmpfiles)는 **쓸 수 없다**는 걸 실측으로 확인했다 — `/run/user/1000`은 logind가 거는 tmpfs라 tmpfiles가 먼저 만들어도 tmpfs가 나중에 덮어쓴다. `user-runtime-dir@1000` 뒤 · `docker` 앞이 유일한 창이다. ⓐ(ExecStartPre rmdir)는 geworfen 컨테이너가 이미 옛 inode를 물고 있으면 컨테이너 재시작이 또 필요해 반쪽이다.


- [ ] **`10.0.0.157` 하드코딩 — DHCP가 IP를 바꾸면 caddy가 안 뜬다.** 오라클 VM은 `default via 10.0.0.1 dev enp0s6 proto dhcp`라 리스 갱신에서 주소가 바뀔 여지가 있다(현재까지 고정으로 관측). 정공법은 NixOS에서 enp0s6 static IP 선언 또는 compose를 생성하는 얇은 래퍼. 지금은 **주소가 바뀌면 caddy가 조용히 죽는 구조**라는 걸 알고 두는 상태.
- [ ] **근본 판단 — tailscale serve 443을 계속 쓸 것인가.** 지금은 "NIC 바인딩으로 비켜간" 상태지 충돌을 없앤 게 아니다. OpenClaw tailnet 레인을 `--https=8443`으로 옮기면 caddy가 `0.0.0.0`을 되찾지만 페어링 URL이 바뀐다. 안 옮기면 443이 두 주인을 가진 채로 남는다.
- [ ] **재부팅 후 점검 체크리스트가 없다.** 이번엔 GLG가 "ax 안 들어가진다"로 발견했다 — 5시간 뒤였다. `run.sh`에 부팅 후 자가진단(전 vhost 8-세트 + 컨테이너 Up + emacs 소켓 2개) 항목을 넣을지 판단. `docs/openclaw-gotchas.md` "caddy 변경 = 8-세트 검수"의 부팅판.
- [ ] **gotchas 박제** — 위 두 레이스를 `docs/openclaw-gotchas.md`에 영속화. 현재 caddy 항목은 *Caddyfile 편집* 함정만 담고 **부팅 시 포트 선점**은 없다.
- 봇은 무사했다: 텔레그램 6채널이 **폴링**이라 caddy와 무관하게 5시간 내내 연결 유지(`channels status --probe` 전부 `works`), heartbeat 30분 주기 정상, 08:00 cron 음성 발송 성공. 죽은 건 `claw` Control UI 공개면뿐.
- 참고 상태: openai OAuth ok 8d·168h 92% left, anthropic OAuth 자동갱신 주기 내. gemini는 2026-08-27부터 `github-copilot/gemini-3.7-flash` (Google 구독 안 함).

---

## 🔴 github-copilot 옛 토큰 회전 — 제거(8/16)와 복귀(8/27) 뒤에 남은 부채

경위 3단(8/16 4층 제거 → 8/19 CLI 재도입 → 8/27 gemini 서빙 레일 복귀)과 **`config unset`은 토큰을 안 지운다** 함정은 [CHANGELOG.md](CHANGELOG.md) `v2026.8.31` / [ROADMAP.md](ROADMAP.md)로 이관. **현재 사실은 8/27이다** — gemini는 `github-copilot/gemini-3.7-flash`로 서빙 중. 아래 회전 부채는 **8/16에 샌 옛 토큰** 이야기이고 새 로그인 토큰과는 별개다.

- [ ] **🔴 GitHub 토큰 2개 회전.** 제거 과정에서 평문이 에이전트 세션 트랜스크립트에 남았다: gateway auth store의 `ghu_xJoQ…`(Copilot provider token)와 `~/.copilot/config.json`의 `gho_Ia8n…`(Copilot CLI OAuth). 저장소에서는 지웠으나 **GitHub 쪽에서 revoke해야 실효**한다 — Settings → Applications에서 GitHub Copilot 권한 취소. claw 배포 때 gateway token 건([claw 항목](#clawjunghanacs.com--openclaw-control-ui-공개면--배포-완료-2026-08-06))과 같은 모양의 부채다.
- [ ] **`plugins.allow` 화이트리스트 회귀 관찰.** allow는 실제 게이트라 목록에서 빼면 그 플러그인이 disabled된다(ROADMAP 2026-06-04 "plugins.allow 명시" 함정). 8/16 당시엔 boot WARN 0·6봇 정상을 확인했지만(그 뒤 8/27 Copilot 복귀와 8.1의 `phone-control` 제거로 목록이 두 번 바뀌었다 — 현재 개수는 재측정 대상), 업그레이드로 새 bundled plugin이 들어오면 allow에 없어서 조용히 꺼진다는 성질은 그대로다.

---

## thinkpad 마이크 — UCM 잭 바인딩 제거로 해결, 재부팅 검증만 남음 (2026-08-25)

원인([alsa-ucm-conf#785](https://github.com/alsa-project/alsa-ucm-conf/issues/785))·실측 진폭·조치(UCM 트리 + `ALSA_CONFIG_UCM2`)·검증은 [CHANGELOG.md](CHANGELOG.md) `v2026.8.31`로 이관. 남은 것만:

- [ ] **재부팅 검증 안 함.** systemd 유닛 `Environment=`라 살아남는 게 자연스럽지만 실제로 재부팅해 확인한 적은 없다. 다음 재부팅 때 `wpctl status`의 기본 소스가 Stereo인지 한 번 보면 닫힌다.
- [ ] **상류가 고쳐지면 이 블록을 지운다.** [alsa-ucm-conf#785](https://github.com/alsa-project/alsa-ucm-conf/issues/785). 이 기기엔 `Internal Mic Phantom Jack` 컨트롤이 없어 upstream 제안(phantom jack 있으면 바인딩 생략)이 그대로는 안 맞는다 — 상류 수정이 이 케이스를 덮는지 확인하고 제거할 것.
- 입력 볼륨 1.0에서 최대 진폭이 `0.999969`(클리핑 상단)까지 붙는다. 통화에서 갈리면 게인을 0.6 전후로 낮출 것.
- **다시 시도하지 말 것** (전부 실패, 근거는 `machines/thinkpad.nix` 주석): `wpctl set-default`(configured만 바뀜) · `priority.session` 하향(availability가 우선) · `api.acp.auto-port=false`(availability 그대로) · Mic1에 `node.disabled`(UCM이 두 마이크를 한 프로파일로 묶어 Mic2까지 죽음) · `api.alsa.use-ucm=false`(아날로그 라우팅 소실, 캡처 0).

---

## 디스크 정리 루틴 = `scripts/diskclean.sh` (2026-07-21, thinkpad 실측 91G 회수)

thinkpad가 96%(여유 19G)까지 찼던 건을 계기로 정리 로직을 스크립트 SSOT로 뽑고 `run.sh` `c)`/`C)`에 연결. 디바이스 프로파일은 `~/.current-device`. 개념·순서 근거는 [AGENTS.md](AGENTS.md) §2.6.

실측(thinkpad): 396G → 305G. nix GC 28G + uv prune 16.7G + zig-cache 11G + Trash 6.3G + 브라우저/툴 캐시 5G + `/tmp` 3.8G. **`.direnv`를 GC보다 먼저 지운 것만으로 뒤이은 GC가 19.9GiB 추가 회수** — 자동 GC가 이미 돈 직후였는데도.

- [ ] **다른 디바이스 실측 — 미검증.** `deep --dry-run`은 thinkpad에서만 돌려봤다. **oracle에서 먼저 `--dry-run`으로 확인할 것** — headless라 `GUI_CACHE=false`, `REPO_CACHE=false` 경로가 실제로 잘 빠지는지, docker 프롬프트가 OpenClaw 컨테이너를 제대로 보여주는지. nuc/laptop도 동일.
- [ ] **⚠️ `deep`은 `.zig-cache`/`.direnv`를 통째로 지운다 — 담당자에게 먼저 물어라.** 0단계는 `find ~/repos -maxdepth 4 -name .zig-cache -o -name .direnv`로 **디렉토리 전체**를 밀기 때문에, 담당자가 남기려고 판정한 하위(해시 매니페스트 등)도 함께 날아간다. 소유권을 코드로 선언하는 `.diskclean-owned` 마커는 **GLG가 거절**했다(마커 자체가 관리 대상이 된다). 그래서 방어는 습관 하나뿐이다 — 깊은 정리 전에 그 리포 담당자를 부른다. 실사례·정본 지침은 `CHANGELOG.md` `v2026.8.10`과 봇로그 `20260227T031800`.
- [ ] **회수량은 `df` 실측으로 보고할 것.** `du` apparent는 하드링크/sparse 때문에 실제 회수와 다르다(2026-08-10 사례: apparent 12,375,675,933 B vs `df` 9,720,197,120 B). 세 축(apparent / 할당 / `df` 델타)을 같이 남기면 과대보고가 안 생긴다.
- [ ] **pnpm store 20G는 손 안 댔다.** 라이브 pi 세션이 하드링크를 공유하고 있어 이번엔 제외(`--with-pnpm` opt-in). 세션 없을 때 `pnpm store prune` 실측 필요 — store 20G 중 실제 고아가 얼마인지 아직 모른다.
- [ ] **docker 15.8G reclaimable (thinkpad).** `--with-docker`를 안 걸어서 미실행. `docker image prune -a --filter until=24h`는 **실행 중이 아닌 이미지를 전부** 지우므로, 작업용으로 쟁여둔 이미지가 있는지 보고 나서 돌릴 것.
- 남은 큰 덩어리는 정리 대상이 아니라 **실데이터**다: `~/repos` 76G(work 51G — 최상위 펌웨어 repo 하나가 33G, 3rd 44G — SBC SDK 하나가 29G), `~/sync` 32G. 아카이빙 판단이 필요하면 별건.

---

## glg 가족봇 = Sonnet 5 + 대칭 "정직한 거울" 규칙 (2026-07-16, soak 남음)

glg(가족봇) 모델 **`gpt-5.6-terra` → `anthropic/claude-sonnet-5`**(claude-cli). 정한(123861330)·미례(8960149052) **동일 모델**(정한 세션 `gpt-5.6-sol` user 핀 제거). 배경: terra가 각 DM에서 화자 프레임을 승인(사이코팬시)해 양쪽을 각자 옳다고 세워주던 **"두 에코챔버"** 문제 — 모델 스왑만으론 안 풀려 **USER.md 대칭 규칙이 핵심 방어**. 사건 분석 = `~/org/llmlog/20260610T094022...`의 [2026-07-16] H1(2026-06-10 #4317 cross-DM 계보 위). 커밋 openclaw-config `e4bb3ed` / org private `4464149e`.

- **USER.md 재정렬** (`workspace-glg/USER.md`): 역할=**집사봇**(정한·미례·아버지 모두 같은 봇에 말함→에코챔버 위험 명시), 운영 에스컬레이션을 접근/공개정보 한정으로 축소(**미례님 갈등 질문 정한 보고 금지** = DM 격리·대칭 보호), 가족봇 절대규칙 A(DM 안 대칭·반사이코팬시 7조)/B(Cross-DM 전달) 통합.
- **compact 양쪽 실행** (`sessions compact "agent:glg:telegram:glg:direct:{123861330,8960149052}" --agent glg`) — terra 편파 원문 제거, 진행 스레드는 요약 보존. 실측: 압축 후 "대화 가능?"에 부모님댁 스레드로 직행하던 동문서답 사라짐, 역할 질문에 새 USER.md 그대로 응답.
- [ ] **진짜 soak = 감정 있는 실제 턴.** 지금까지 검증은 메타 문답(모델명/역할)뿐. 남은 확인: 정한/미례가 **venting**할 때도 화자 프레임 승인 대신 대칭·맹점짚기(규칙5) 지키는지. 첫 감정 턴 응답 같이 검수.
- [ ] **watch: 역할 낭독 반복** — 묻지 않았는데 면책 낭독을 대화 중 또 꺼내면 잔소리. 재발 시 USER.md에 "묻지 않으면 역할설명 반복 금지" 한 줄 추가.
- [ ] **thinking = claude-cli adaptive (dial 불가).** thinkingLevel(off/min/low/med/high/max)은 **claude-cli 백엔드에 안 물림**(코드 확인: `extensions/anthropic/cli-backend.ts`·`cli-backends.runtime.js`에 thinking 매핑 0). Sonnet 5 네이티브 thinking으로 돎. dial이 꼭 필요하면 sonnet-5의 `agentRuntime.id=claude-cli` 제거 → anthropic **API 런타임**이면 thinkingLevel=high(extended-thinking) 적용 — 단 구독(정액) 아닌 **종량제 비용**.
- [ ] **compact 요약에 별거/법적 프레임 잔존** — 첫 응답이 "전문가(변호사·상담)" 언급. 집사봇이 상황 기억하는 정도라 문제는 아니나 관찰.
- 롤백: `~/openclaw/config/openclaw.json.bak-glg-sonnet5-20260716T152903` + `agents/glg/sessions/sessions.json.bak-sonnet5-*`. USER.md는 git diff(`e4bb3ed`).

---

## ax.junghanacs.com — umami/remark 지원 (2026-07-15 서빙 시작)

`ax.junghanacs.com` 정적 사이트 라이브(caddy `file_server`, `/srv/ax` ← `~/docker-data/ax` ro 마운트). web root는 담당자 junghan0611(`apply/ax` `make publish`, leak gate 통과분)이 채운다 — caddy 재시작 불요. 배포/함정 상세 → [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) "caddy 변경 = 7-세트 검수".

액세스 로그는 2026-07-20부터 켜져 있다(JSON → stderr → journald). 조회: `docker logs caddy | grep ax.junghanacs.com`. 경위는 CHANGELOG `v2026.7.22`.

- [ ] **umami 붙이기** — `analytics.junghanacs.com`(umami) 이미 가동. ax용 website를 umami에 등록(tracking id 발급). **스니펫은 담당자가 정본(`apply/ax`)에 넣어 publish** — caddy 주입 금지(정본·라이브 갈림 방지, 담당자 명시 요청). caddy 측 작업은 사실상 없음(같은 호스트라 도메인 허용만 확인).
- [ ] **remark 붙이기** — `comments.junghanacs.com`(remark42) 가동. ax `record.html`에 댓글 위젯. 역시 스니펫은 정본. remark42 site-id/allowed-domain에 ax 추가 필요할 수 있음(remark42 env 확인 → `docker/remark42/`).
- [ ] **크롤러 실측 (SC 사이트맵 제출 후속).** 며칠 뒤 로그에서 Googlebot / GPTBot / ClaudeBot / PerplexityBot 실제 방문 여부와 `/llms.txt` 히트를 확인해 담당자(junghan0611)에게 회신. 0건이면 그것도 결과 — robots.txt·사이트맵 쪽을 되짚을 신호.
- [ ] ax 관련 요청은 이 레인(caddy = nixos-config)이 대응. GET-only 공개면이라 authelia 없음.
- **`/llms.txt` Content-Type은 `text/plain` 유지 (2026-07-20 판단).** 어떤 SEO 감사 도구가 `text/markdown`을 요구했으나 llmstxt.org 스펙은 media type을 규정하지 않는다. 오히려 `text/markdown`으로 내보내면 브라우저가 렌더 대신 **다운로드**한다 — ax 블록에 `@md → text/plain` 규칙이 이미 있는 이유가 그거다. 사람이 읽는 공개면을 검증기 경고 하나 때문에 깨지 않는다. notes/junghanacs.com도 같은 상태 유지.

---

## 모델 전면 정렬 — soak 필요 (2026-08-04)

GLG 결정으로 6봇 모델을 싹 맞췄다. **`config primary` ↔ `라이브 DM 세션` 쌍 정렬**이 핵심 — 규칙은 [ORACLE.md](ORACLE.md) "모델 세팅은 config ↔ DM 쌍으로 관리한다".

- main `opus-4-8` → **`anthropic/claude-opus-5`** (카탈로그 미등재 → `defaults.models` 등록 후 격리 probe `fallbackUsed=false` 확인 뒤 승격)
- **DM 어긋남 2건 교정**: bbot이 config=fable-5인데 라이브 DM은 `gpt-5.5`/openai로 돌고 있었다(provider까지 다름). mini도 config=sonnet-5 / DM=sonnet-4-6. 둘 다 `/model`로 정렬.
- **`openai/gpt-5.5` 전면 제거**(잔존 0건) → catch-all 1번은 `openai/gpt-5.4`, `defaults.model.primary`는 `openai/gpt-5.6-terra`
- **`anthropic/claude-sonnet-4-6` 제거** — sonnet은 5로 통일
- 검증: config validate 통과, doctor Errors 0, 6봇 config↔DM 일치, main/bbot 라이브 정체성 응답 확인
- **⚠️ 대가 — main/bbot DM 세션이 굴렀다.** main은 `/model` 첫 시도가 120s timeout → `CLI session cleared` → 새 세션(`d792e9cd`→`323b9a63`), bbot은 provider 전환(codex→claude-cli)으로 롤. **트랜스크립트는 보존**(main 117KB/94줄, bbot 29KB/15줄, `usageFamilySessionIds` 계보 유지)이나 **라이브 스레드 맥락은 리셋**됐다. mini는 같은 provider 내 교체라 세션 유지. 함정 전문은 [ORACLE.md](ORACLE.md) "🔴 `/model`은 DM 세션을 굴릴 수 있다".
- **`Dirty: no`는 스냅샷이지 불변식이 아니다.** 턴을 돌면 새 세션 파일이 생겨 다시 dirty가 된다 — 정렬 직후 "6봇 전부 Dirty:no"라고 적었으나 그 뒤 턴들로 main/mini/bbot이 곧 dirty로 돌아갔다(16:23 재인덱싱으로 다시 정합). **의미 있는 불변식은 dirty 플래그가 아니라 ①`Indexed n/n` 정합 ②실검색 성공**이다.
- 롤백: `~/openclaw/config/openclaw.json.bak-model-align-20260804T153304`

**2026-08-06 후속 정렬 — main DM이 또 어긋나 있었다.** 8/4 정렬 뒤에도 main 텔레그램 DM(`agent:main:telegram:default:direct:123861330`)이 **`claude-opus-4-8`로 돌고 있었다**(config primary는 opus-5). 6봇 전수 확인 결과 어긋난 건 이 하나. `/model anthropic/claude-opus-5` + `--timeout 540`으로 정렬했고 **이번엔 세션이 안 굴렀다** — `sessionId` `323b9a63…` 그대로 유지, 라이브 맥락 보존. 같은 provider 내 교체 + 넉넉한 timeout이면 살아남는다는 게 실측으로 재확인됐다(8/4엔 120s로 죽었다). **교훈: "정렬했다"는 한 번 찍고 끝나는 게 아니다 — DM pin은 다시 어긋난다. 업그레이드·정렬 후 `sessions list` 전수 대조를 습관으로.**

- [ ] **main DM 맥락 회수 판단.** 위 롤로 라이브 스레드가 빈 맥락에서 시작한다. 옛 트랜스크립트(`agents/main/sessions/d792e9cd-….jsonl`)가 살아있으니 필요하면 `sessions compact`/수동 요약으로 회수 가능 — GLG가 실제로 아쉬운지 먼저 확인할 것.
- [ ] **opus-5 soak (main).** 승격 당일 격리 probe + 라이브 정체성 응답만 확인했다. 볼 것: 실제 긴 턴에서의 품질·지연, Max 20x 쿼터 소진 속도가 opus-4-8 대비 달라지는지. 처지면 per-agent 카탈로그에 남긴 `anthropic/claude-opus-4-8`로 `/model` 복귀.
- [ ] **fable-5 실사용 확인 (bbot).** 라이브 DM이 몇 주간 gpt-5.5로 돌던 걸 오늘 fable-5로 되돌렸다 — **봇 스스로 "그 사이 기억층에 빈 구간이 있을 수 있다"고 보고**했다. 다음 실대화에서 맥락 연속성 확인.
- [ ] **`anthropic:default [anthropic/token]` 프로파일 정리 판단.** glg/gpt/gemini 3봇에만 붙어있는 **유일한 비-OAuth(종량제) 항목**. 현재 primary 경로로는 안 쓰이지만 claude-cli OAuth 실패 시 구독 밖 과금으로 흐를 수 있는 자리다. 안 쓸 거면 제거.

---

## OpenClaw 7.1 잔여 후속 — 8.1로 넘어온 것만 (2026-07-14 → 2026-08-31 갱신)

7.1/7.1-2 서사(correction release가 버전 문자열을 안 올린다, Control UI 상시 오탐)는 [ROADMAP.md](ROADMAP.md)·[docs/openclaw-gotchas.md](docs/openclaw-gotchas.md)로 이관. **8.1 컷오버 후에도 살아있는 항목만 남긴다.**

- [ ] **bbot 세션 `think:xhigh` 처리 판단.** 8.1 컷오버 후에도 그대로다(2026-08-31 실측: bbot direct/subagent 세션 `think:x…`, main/mini는 medium). **세션 sticky가 config를 이긴다**는 성질은 8.1에서도 동일. 의도한 것이면 per-agent `agents.entries.bbot.thinkingDefault`로 정식 등록하고, 잔재면 세션에서 내린다.
- [ ] **gpt 봇 thinking 인상 여부 관찰.** `thinkingDefault=medium`은 sol에겐 **인하가 아니라 인상**(upstream 기본 `low`). GLG 목적이 "턴 속도"였으므로 느려지면 `agents.entries.gpt.thinkingDefault="low"`로 되돌린다. ⚠️ 8.1에서 gpt는 codex 런타임을 떠나 **openclaw 내장 런타임**을 타므로 thinking 매핑이 달라졌을 수 있다 — 쿼터 리셋 후 재관측.
- [ ] **luna/terra lane 품질 soak.** ① active-memory recall 품질(요약 정확도, `stopReason=missing` 비율), ② recall latency — 5.4-mini의 31.5s Codex CLI 콜드스타트가 사라졌으니 **개선돼야 정상**, ③ subagent 결과물 품질(terra), ④ ChatGPT 구독 quota 소진 속도(Codex Plus 크레딧 표는 이 두 lane에 더 이상 안 맞는다).
- [ ] **`channels.mattermost` 죽은 설정 정리.** 2026-08-31 실측 — `channels` 키가 `discord/mattermost/telegram` 3개인데 mattermost는 **botToken을 든 채** 남아있다. 안 쓰면 `config unset channels.mattermost`로 토큰까지 지운다(평문 시크릿 축소).

---

## oracle `/home` 회수 — 1차 완료, 근본은 남음 (2026-07-13)

`run.sh E → a)` 전체 정상. SSOT 7개 + harness + gog 모두 최신(codex 0.144.1, gog v0.34.0). `/home` 여유 **1.7G → 11G (99% → 90%)**.

회수한 것: `global/5`(pnpm10 화석) + 화석 shim 19개 + `.tools`, `uv cache clean`(4.7G), `go clean -modcache`, `~/.npm/_cacache`(npm은 `npm view` 전용이라 orphan), openclaw-backups의 raw 기억 스냅샷 2개(pre-5.18/5.20, 2.3G).

배운 것 둘:

- **pnpm store는 하드링크로 공유된다.** `global/5`가 `du`상 3.3G여도 store와 링크를 공유해서 `pnpm store prune`은 37.7MB만 반환했다. pnpm 트리 크기를 회수량으로 착각하지 마라.
- **openclaw-backups는 config 백업이 아니라 봇 기억(sqlite) 스냅샷이다.** pre-5.22(281M)가 그 기억의 압축본을 이미 품고 있어서 raw 2개만 지우고 압축본은 남겼다. 라이브 기억은 `~/openclaw/config/memory/`(1.4G, glg 608M).

- [ ] 근본은 `~/repos` 32G + `~/sync` 19G + `~/openclaw/config/agents` 3.6G. 별도 세션에서 `diskspace` 스킬로.
- [ ] `openclaw-backups/pre-5.22`(281M, 5월 기억 압축본) — 언제 버릴지는 GLG 판단.
- [ ] `entwurf` CLI 복구 여부 — 부모 dir 고아 shim(0.12.4)이 PATH에 살아있었으나 글로벌 manifest엔 없었고 이번 정리로 사라짐. MCP 브리지는 repo 클론에서 `require.resolve`로 뜨므로 **영향 없음**. 필요하면 `@junghanacs/entwurf`(npm 0.12.6)를 `PNPM_PACKAGES`에 한 줄 추가하면 복구.

---

## ★ 스킬 심볼릭 배포 전환 (트라이얼 성공, 2026-06-09)

워크스페이스 스킬을 **복사 → 심볼릭(repo SSOT 직결)**로 전환 중. butlercli 1개로 트라이얼 → 성공. 되면 **전체 스킬 심볼릭 전환** 예정.

### 검증된 사실 (butlercli 트라이얼, oracle Docker)
- 메커니즘: `config/workspace-glg/skills/butlercli` → 심볼릭 → `/home/junghan/repos/gh/butlercli/.claude/skills/butlercli`
- **이중 마운트가 핵심**: docker-compose `~/repos/gh:/home/junghan/repos/gh:rw`(원래 ~/.claude 호환용) 덕에 `/home/junghan/...` 절대경로가 host·container 양쪽 resolve. (어제 "심볼릭 깨짐, 복사만" 판단은 이 마운트 간과한 오판)
- openclaw config: `skills.load = { allowSymlinkTargets: ["/home/junghan/repos/gh/butlercli/.claude/skills"], watch: true }`. `allowSymlinkTargets`만으로 심볼릭 following 켜짐(skills엔 `followSymlinks` 없음). `watch:true` = 스킬 편집 hot-reload(재시작 불요).
- 검증: 재시작 후 `skills list --agent glg --json`에 `butlercli source=openclaw-workspace` 등록. **no-drift 즉증** — 담당자가 repo SKILL.md에 AREA OVERVIEW mode 추가한 게 재복사 없이 glg에 바로 반영됨.
- **중첩 심볼릭 + scripts/.env 검증 (2026-06-09)**: 스킬 디렉토리 안 `scripts -> ../../../scripts`(repo-root) 상대심볼릭이 워크스페이스 심볼릭 경유로 컨테이너에서 끝까지 resolve. `python3 scripts/estate_area.py 호매실동`이 심볼릭 CWD에서 실 data.go.kr+NEIS로 307건·중위 4.6억 반환. `.env`는 `_estate_common.py`의 `__file__.resolve()`(심볼릭→repo 실경로)→repo/.env + `~/repos/gh/butlercli/.env` fallback으로 로드 — 심볼릭 무관 robust. → **repo-backed 스킬(scripts/ 포함)이 심볼릭으로 완전 동작 = 전체 전환 템플릿 검증됨**. (glg가 17:00에 본 "scripts 없음"은 담당자가 17:01 scripts심볼릭 추가 직전 스냅샷 — 결함 아닌 타이밍)
- ⚠️ 현재 openclaw-config dirty: `workspace-glg/skills/butlercli`(dir→심볼릭) + `openclaw.json`(skills.load). 커밋은 GLG. 백업 `openclaw.json.bak-symlink-trial-*`.

### 다음 한 걸음 (전체 전환 전 결정거리)
- [ ] **device 이식성 결정** — 심볼릭 타깃/allowSymlinkTargets가 device별 다름(oracle `/home/junghan/repos/gh`, Termux `/storage/repos`). openclaw-config가 device 공유면 committed 심볼릭이 깨짐 → **심볼릭은 gitignore하고 run.sh `k)` deploy가 device별 생성**하는 설계가 robust. (현재 k)는 복사 — 심볼릭 생성 모드로 개편 검토)
- [ ] **스코프 결정** — 심볼릭(per-workspace, glg-only) vs `skills.load.extraDirs`(전역 공유, sibling repo 직접 스캔). repo-backed 스킬(butlercli류)은 심볼릭/extraDirs 적합, pi-skills 공유셋(26종)은 복사가 적합 — 혼합 정책 정리.
- [ ] **pi-skills SSOT 루트 화이트리스트** — 전체 전환 시 `~/.pi/agent/skills/pi-skills`(컨테이너 경로 확인) 도 allowSymlinkTargets에 추가 필요.
- [ ] **glg 외 봇 확장** — 트라이얼은 glg만. 전체 봇(workspace*) 일괄 전환 시 run.sh AGENTS_FULL 루프를 심볼릭 생성으로.
- [ ] butlercli 트라이얼 soak: glg 실사용에서 부동산 질문 시 스킬 정상 트리거·실데이터 응답 확인(라이브 turn).
- [ ] **gogcli SKILL.md 통일 — 심볼릭 단일화(완료, CHANGELOG `v2026.7.22`) 후 남은 티끌.** 바이너리는 SSOT 심볼릭으로 묶였으나 SKILL.md는 아직 각 디렉토리별 실파일이다(agent-config Jul5 upstream 15KB vs workspace/claude-skills Apr13 옛 10KB) — 작아서 공간은 무관하나 **내용이 갈린다**. 통일하려면 SKILL.md도 SSOT 심볼릭, 단 openclaw workspace 스킬 등록이 심볼릭 SKILL.md를 읽는지 먼저 확인.

---

## 0. Forge — 포지 레이어 인프라 (활성, 2026-05-27 가동)

`forge.junghanacs.com` (Forgejo 15.0.2 LTS, postgres 16-alpine, Caddy + Let's Encrypt) Oracle 가동. 봇멘트의 코드면 확장. 설계: 노트 `20260527T073823`.

### 운영 책임 경계

| 자리 | 책임 |
|---|---|
| **이 repo** `docker/forge/` | Docker compose, Caddy 블록, host-specific 인프라 (oracle 박힘, alskdjf 구축 중 2026-05-27) |
| **`forge-config` repo** | 운영 ownership — 라벨/footer/봇 행동 규약 + bin/forge CLI + agent skill SSOT |
| **`agent-config/skills/forge`** | thin pointer 박힘 (별도 세션 결과 회수 2026-05-27) — SSOT는 `~/repos/gh/forge-config/bin/forge` |

### 다음 한 걸음

- [~] **alskdjf 구축 중** — 같은 compose 구조 복사, DOMAIN/데이터 path만 호스트별 변경. SETUP.org 그대로 재사용. 진행 결과는 봇로그 히스토리에 박을 것
- [ ] **백업 cron 도입** — `pg_dump` + `tar` 일별 자동 (현재 수동)
- [ ] **fail2ban Forgejo jail** — 도메인 노출 후 공격 패턴 관찰하고 활성

### 검증된 운영 사실

Forge 가동 검증 완료분(인스턴스 + Caddy 30초 인증서, work alskdjf v15.0.2, glg-bot user/token × 2, GitHub PAT 분리, sandbox round-trip, forge-config 라벨 5개, bin/forge 4-command, 함정 3개 봇로그 박제)은 [ROADMAP.md](ROADMAP.md) "Forge 레이어 가동"으로 이관. (verboseDefault는 이후 full→on 환원 — ROADMAP 참조.)

### 운영 책임 아님

- ❌ 라벨 정책 / footer 규약 / agent 행동 → forge-config repo
- ❌ bin/forge CLI / agent skill → forge-config repo
- ❌ 7-spike 로드맵 → agent-config #13 + forge-config/NEXT.md

---

## 0.5 authelia — map.junghanacs.com 가드 (✅ 배포 완료 2026-07-01)

`map.junghanacs.com`(butler-viewer, 가족 부동산 데이터) **앞단에만** authelia forward-auth 인증창. butler-viewer 내부 수정 0, 다른 서브도메인 규칙 0. 설계 = **A안(서브패스 포털 `map.junghanacs.com/authelia`, 쿠키 domain=map, 새 DNS 불필요)**. 봇 push는 내부 proxy 네트워크 직결이라 Caddy 안 거침 → 가드 영향 0.

- **라이브 (authelia v4.39.20)**. 검증(curl): 미인증 `/`·`/v/*`·`/api/surfaces/*` → 302 authelia 리다이렉트(share_token만으론 데이터 못 뚫음), 포털 `/authelia/` 200, 봇 내부 `butler-viewer:8765/` → 200 무영향.
- **파일**: `docker/authelia/{docker-compose.yml, configuration.yml.template, users.yml.template, .gitignore, README.md}` (공개 추적) + `configuration.yml`·`users.yml` (실파일, **gitignore — 시크릿/해시 미커밋**). Caddyfile map 블록 = forward_auth 버전으로 교체됨.
- [ ] **아내가 실브라우저로 로그인 1회 확인** — curl로 리다이렉트/포털/봇경로는 검증했으나 실제 로그인 submit+쿠키+뷰어 도달은 사람 1회 필요. 계정 `family` / 비번은 GLG가 아내에게 전달.
- 2026-08-06: claw 추가로 계정이 **2개**가 됐다(`family`=map / `glg`=claw operator). 그룹이 곧 경계 — 아래 claw 항목.
- 롤백: Caddyfile map 블록 원복 + `docker restart caddy`, authelia는 `docker compose down`.

---

## claw.junghanacs.com — OpenClaw Control UI 공개면 (✅ 배포 완료 2026-08-06)

`claw.junghanacs.com`에 OpenClaw Control UI. **인증 통합은 안 했다** — 자물쇠 3겹을 그대로 쌓았다:
`Internet → Caddy HTTPS → Authelia forward_auth(operator만) → OpenClaw gateway token → HTTPS device pairing → Control UI`.
`gateway.auth.mode`는 **`token` 유지**(trusted-proxy 전환 금지), `dangerouslyDisableDeviceAuth` 금지.
설계 검토는 gpt 봇(codex)과 4라운드 cross-review로 굳혔다 — 함정 전문은 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) claw 항목.

- **왜 3겹을 다 유지하나**: `openclaw-gateway`가 `proxy` 도커 네트에 붙어 있어 같은 네트 컨테이너가 Authelia를 건너뛰고 18789에 직결한다(실측: caddy→gateway `/` = **200 무인증 HTML**, `/control-ui-config.json` = 401). **진짜 경계는 token+pairing이지 forward_auth가 아니다.** 게다가 이 게이트웨이는 `security audit` 기준 전 봇 `exec security=full` · `sandbox=off` · `fs.workspaceOnly=false` — Control UI admin 세션은 사실상 **oracle 원격 셸**이다.
- **Authelia**: 계정 `glg`(groups: `operator`) 신설, claw 규칙 3단(bypass → operator one_factor → **deny catch-all**). 적용 전 `check-policy` 4건 판정 — operator=one_factor / **family=deny** / 포털=bypass / map 회귀=one_factor.
- **OpenClaw config 2건**(restart 반영): `controlUi.allowedOrigins`에 `https://claw.junghanacs.com` 추가 + 화석 `https://openclaw.junghanacs.com`(DNS 없음) 제거, `auth.rateLimit {10, 60000, 300000}` 신설(`security audit` WARN `auth_no_rate_limit` 해소).
- **Caddy**: claw 블록 + HSTS `max-age=300`만(보안 헤더는 게이트웨이가 이미 실음 — 중복 주입 금지). 8-세트 검수 회귀 0.
- **브라우저 실연결까지 확인**: `token_missing` → 토큰 입력 → pairing 승인 → RPC 정상 왕복(`cron.status`/`sessions.usage`/`models.authStatus` ✓). device는 GLG 모바일, `operator.admin` 포함 5스코프.
- [ ] **🔴 gateway token 회전** — 배포 중 토큰 평문이 에이전트 세션 트랜스크립트에 남았다(GLG 요청). 회전 후 브라우저 Settings에 새 토큰 재입력 필요.
- [ ] **HSTS `max-age` 상향 판단** — 24h 관찰 후 `31536000`으로 올릴지. **`includeSubDomains`·preload는 금지**(junghanacs.com 하위에 http-only가 생기면 통째로 잠긴다).
- [ ] **family 계정 브라우저 negative test** — 정책 판정으로는 `deny` 증명됐으나 실제 로그인 화면에서의 거부 UX는 미확인.
- [ ] **`~/openclaw/backups/claw-20260806T191048/` 정리** — `LOGIN.txt`·`operator-password.txt`(둘 다 600)에 평문 자격증명. 패스워드 매니저로 옮긴 뒤 삭제.
- [ ] (P2) `gateway.trustedProxies`가 `172.18.0.0/16`(proxy 네트 전체)이다. token 모드에선 인증 우회가 아니라 client IP 판정용이지만, 같은 네트 컨테이너가 X-Forwarded-For를 위조해 per-IP rateLimit을 오염시킬 수 있다. 좁히려면 caddy 실IP인데 recreate마다 바뀌므로 compose static IP 고정이 정공법.
- 롤백: Caddyfile claw 블록 제거 + `docker restart caddy` / authelia cookies·rules 원복 + `docker restart authelia` / openclaw config 원복 + restart. 백업 `~/openclaw/backups/claw-20260806T191048/`(700).

---

## 1. pi-shell-acp 정리 — 완료, 잔재 청소만 (2026-06-10 ACP 제거)

claude-cli native(main/bbot/mini) + codex(glg/gpt) + **gemini 네이티브 `google-gemini-cli` OAuth 전환(2026-06-10)** 으로 pi-shell-acp 사용처 0 → `plugins.entries.pi-shell-acp.enabled=false`로 제거. **이 배포에 third-party ACP 없음.** 정리 사이클의 본체는 끝났고 mount 잔재 청소만 남음.

> 완료분(2026-05-26~31 자리들, **2026-06-10 gemini 네이티브 부활 + pi-shell-acp 제거**, **6.1→6.5 업그레이드**)은 [ROADMAP.md](ROADMAP.md) "운영 결정 이력"/"OpenClaw 업그레이드 이력"으로 이관. pi-shell-acp Issue #25: <https://github.com/junghan0611/pi-shell-acp/issues/25>.

### 남은 한 걸음 (ACP 잔재 청소)

- [ ] **compose mount 정리** — gemini가 마지막 ACP 사용처였다. `docker-compose.yml`의 ACP 전용 mount(`~/.pi/agent`, `~/.claude-plugin/skills` 등)가 남아있으면 제거(이제 unblocked). 단 claude-skills overlay(§ skills)와 겹치는 mount는 남김 — 헷갈리지 말 것.
- [x] **pi-shell-acp 엔트리 최종 거취 — 2026-06-22(6.9) 완전 제거.** ~~present + `enabled:false` 영구 유지~~ → **6.9 strict plugin discovery가 죽은 `plugins.load.paths`(pi-shell-acp 경로)를 startup hard-fail로 거부해 crash loop** 발생 → `plugins.load.paths` + `plugins.entries.pi-shell-acp` + `plugins.allow` 전부 제거. **옛 "엔트리 삭제 = 기본 로드 복귀" 함정(2026-06-10)은 6.9에서 무효** — provider 외부화로 pi-shell-acp가 번들에서 완전히 사라져 default-load할 대상 자체가 없음(제거 후 clean boot·warnings 0 확인). workspace-gemini는 네이티브 gemini가 씀, 유지.
- [ ] **#27 moot 확인** — gemini ACP 빈응답(#27)은 네이티브 전환으로 **우리 운영상 해소**. 이슈 자체는 pi-shell-acp repo에서만 추적. #25 분석은 별건.
- [~] **bbot turn soak GREEN / Telegram ingress follow-up** — 2026-06-29 무응답 사건: claude-cli/OAuth/session은 정상(probe ok, direct session 3.5s ok), root cause는 bbot isolated polling ingress 유령 connected. 컨테이너 런타임 핫패치로 bbot만 standard polling 전환 후 살아남. **후속**: 핫패치는 recreate/image rebuild 시 사라지므로 Dockerfile/entrypoint patch 또는 upstream config toggle로 영구화할지 결정. 상세는 `docs/openclaw-gotchas.md`.
- [ ] **Copilot Premium soak (gemini 챗봇)** — 재로그인 직후 Premium 잔량 확인됨. fallback 없으니 쿼터 소진=무응답. `models status`의 Premium % 주시.
- [ ] **이미지생성(나노바나나) `GEMINI_API_KEY` 경로 미재검증** — gemini 챗봇이 `google-gemini-cli/` OAuth로 전환된 뒤, `GEMINI_API_KEY`(`google` api-key provider) 기반 이미지생성이 여전히 동작하는지 확인. 두 provider가 분리돼 무관할 가능성 큼(추정). **실제 이미지 호출 1회로 검증 전까지 단정 금지.** (`auth.order.google` 핀은 cross-provider라 안 먹어 제거됨 — 자세한 건 ROADMAP 2026-06-10 함정 항목)
- [ ] **(보류) telega 리치 지원 매트릭스 (T01~T15)** — 2026-06-22 richMessages 전 6봇 글로벌 ON 했다가 **당일 OFF로 되돌림**(telega가 rich message를 "unsupported"로 가려 **봇 대화 복사 불가** → 소통 워크플로 단절. GLG 결정: "핵심은 rich가 아니라 소통"). **baseline = OFF 확정.** 따라서 매트릭스 추적은 더 이상 active task 아님 — **richMessages 재활성을 검토할 때만** 선결조건으로 부활시킨다. 그때는 main 봇 T01~T15(헤딩/표/details/풀쿼트/divider/sup·sub/mark/spoiler/list/task-list/code/footnote/formula/link) 격리 테스트 → telega에서 정상/폴백/unsupported 3분류 → TOOLS.md + doomemacs-config 패치. 현재는 호환모드(굵게/기울임/링크/코드/스포일러/블록인용)만으로 충분.

---

## 2. 버전 hop 후속 측정 (다음 세션)

### ✅ 6.10 → 6.11 업그레이드 완료 (2026-07-01)

릴리즈 [v2026.6.11](https://github.com/openclaw/openclaw/releases/tag/v2026.6.11)(2026-06-30) = 순수 신뢰성/버그픽스. **idle 창(턴 0) 확인 후 `docker compose down` → Dockerfile bump → 재빌드 → up.** 검증: 버전 2026.6.11, claude-cli(main/bbot/mini) GREEN(bbot 라이브 턴), codex(glg/gpt) OK(openai expires 10d·usable), gemini 403 DOWN(예상), memory 4096d, 6봇 prefix 유지(gemini `google-gemini-cli/`·**google/ 드리프트 0** — read-only doctor만), fallbacks 전부 `[]`. 디스크 82%→77%(캐시 3.3GB 회수), 이미지 2.68→2.05GB.

- **⚠️ node-gyp hang 규명(신규 함정, gotchas 기록됨)**: 재빌드가 `npm install -g` node-gyp에서 9분+ hang. 범인 = **`@google/gemini-cli` 0.49.0**(transitive `@github/keytar`+`node-pty` native, aarch64 buildkit). → **Dockerfile npm 줄에서 3개 제거**: pi-coding-agent+codex-acp(ACP 폐기로 unused) + gemini-cli(gemini DOWN·안 쫓음+범인). `@anthropic-ai/claude-code`만 남김(native 0). 양쪽 Dockerfile 동기.
- [ ] **6.11 텔레그램 실사용 soak** — headless 검증 GREEN, 실 가족봇 turn 5~7d 관찰(codex glg/gpt·claude main/bbot).
- [ ] **jsonschema 컨테이너 baked-in 검증 (다음 recreate 때)** — glg 봇 집사 스킬(butlercli `estate_surface.py`)이 viewer(map.junghanacs.com)로 IR post 전 fail-closed 검증에 Python `jsonschema` 필요(fallback 없음). 6.11 재빌드 때 **라이브 `~/openclaw/Dockerfile`에서만 이 레이어가 누락**(공개 백업 `docker/openclaw/Dockerfile`엔 `9ed9afe`로 이미 존재)되어 실행 컨테이너 Python 3.11에 없었음. **무중단 조치(2026-07-01): 실행 중 openclaw-gateway에 `pip install jsonschema` 런타임 설치(4.26.0, node 유저 `import` OK 확인) + 라이브 Dockerfile을 백업과 동기(byte-identical).** ⚠️ 런타임 설치는 recreate/rebuild 시 사라짐 → **다음 재시작(force-recreate) 후 `docker exec openclaw-gateway python3 -c "import jsonschema"` 검증**으로 Dockerfile 레이어 영구 반영 확인. (라이브 `~/openclaw/Dockerfile` 커밋은 GLG.)

### ⚠️ telegram 채널 stop-timeout 데드락 — 업그레이드마다 upstream 수정 확인 (2026-07-07 발견)

**증상**: gpt 봇(`@glg_gpt_bot`) 텔레그램 반나절 무응답(2026-07-07 ~10:10→22:53 KST 수동복구). **근인**: 매일 ~10:10 KST(**01:10 UTC**) oracle→`api.telegram.org` 경로의 1분짜리 blip(`Too Many Requests: retry after 5` → `deleteWebhook 502 Bad Gateway` → `DNS-resolved IP unreachable`)에 텔레그램 채널이 죽음. 대부분 auto-restart(10회)로 자가복구되나, `[gpt] channel stop exceeded 5000ms after abort`(stop 5s 타임아웃) **데드락**에 걸린 채널은 health-monitor의 15분 주기 restart로도 stop 단계를 못 뚫어 **영구 정지** → 게이트웨이 전체 restart로만 복구.

- **트리거는 우리 것이 아님(끌 대상 없음 — 전수 확인)**: 드리밍 `memory-core.dreaming.enabled:false`, 호스트 systemd 타이머 4개 전부 다른 시각(tmpfiles 23:24 / logrotate 00:00 / nix-gc·fstrim 주간), crontab 비어있음, 저널 10:08~10:13 KST 공백. **oracle 내 흔적 0** → telegram API DC daily maintenance 또는 외부 네트워크 구간의 매일 1분 blip. 매일 01:10~01:11 UTC로 규칙적(07-02~07-07 default/gemini/mini/gpt가 돌아가며 걸림).
- **시스템 영향 없음**: 게이트웨이 `healthy`·`RestartCount=0`·CPU 5%·MEM 3%, spin 아님. 걸린 봇 1개만 무응답이 유일 증상. 유일 리스크 = 관측성(사람이 "답 안 온다"로 뒤늦게 발견).
- **워크어라운드(복구)**: Tasks `0 active` 확인 후 `cd ~/openclaw && docker compose restart openclaw-gateway`(env 변경 없으니 restart 충분·recreate 불요). 채널 레벨/개별 restart는 stop-timeout이라 안 풀림 — 반드시 게이트웨이 프로세스 전체 리셋.
- [ ] **업그레이드 사이클마다 확인 (이 항목의 핵심)** — 릴리즈 노트/이슈에서 **telegram channel stop-timeout / auto-restart 데드락 / health-monitor의 stuck-channel force-recreate** 관련 수정 검색. 고쳐지면 위 수동 게이트웨이 restart 워크어라운드 제거 가능.
- [ ] **gotchas 박제** — `docs/openclaw-gotchas.md`에 이 패턴 영속화(현 gotcha는 bonjour/task-registry 루프뿐, 이 telegram blip 데드락은 미기록).
- [ ] **(선택) 관측성** — stopped/disconnected 채널을 조기 알림(health-monitor 로그 감시 또는 `channels status` 주기 체크). 지금은 사람이 발견하는 구조.

### ✅ Sonnet 5 → mini 승격 + bbot fable-5 재승격 (완료, 2026-07-12)

**mini `sonnet-4-6` → `anthropic/claude-sonnet-5`**, **bbot `opus-4-8` → `anthropic/claude-fable-5`** 라이브 승격 완료(6.11). 둘 다 claude-cli 구독 API 동적 해결 — 이미지 재빌드 불필요. 서빙 검증: primary 경로 `winnerModel` 일치 · **`fallbackUsed=false`**(catch-all 안 탐) · runner=cli. 옛 모델(sonnet-4-6/opus-4-8)은 각 봇 카탈로그 보존(GLG `/model` 복귀 가능).

- **fable-5 서빙 재개** — 2026-06-13 "구독/CLI 서빙 실패"(auto-fallback deepseek 정체성 훼손)로 환원했던 게, upstream v2026.6.6 adaptive-thinking 어댑터 fix([issue #91805](https://github.com/openclaw/openclaw/issues/91805)/[PR #91882](https://github.com/openclaw/openclaw/pull/91882)) + 6.11에서 해소. 승격 전 primary=opus 유지 채 `agent --agent bbot --model anthropic/claude-fable-5` 오버라이드 격리 probe(isolated session, no deliver)로 서빙 확인 후 promote — 실사용자 노출 0.
- **오버라이드 게이트 = `agents.defaults.models` 글로벌 카탈로그**(per-agent `models` 아님, ROADMAP 2026-05-26 "override allow-list가 primary 기준" 함정과 정합). fable을 defaults.models 끝(catch-all #1=gpt-5.5 불변)에 등록해 probe 개방 + `/model fable` 전 봇 개방.
- **6.11 hot-reload는 부분적** — `config set`이 `agents.list`를 파일엔 hot-reload하나 gateway 인메모리 serving/override-allowlist는 진짜 restart라야 rebuild. idle 확인 후 `docker compose restart`로 적용(ORACLE.md line 307 유효).
- [ ] 실 텔레그램 turn soak — bbot(fable)/mini(sonnet-5) 5~7d 관찰. 특히 fable adaptive-thinking(항상 high) latency·쿼터 체감.

---

6.1 hop 완료 (2026-06-04, headless 5봇 GREEN, [ROADMAP](ROADMAP.md) "2026.6.1"). 운영은 안정이나 다음 자리 측정:

- [ ] **6.1 텔레그램 실사용 soak** — headless GREEN 확인됐으나 실 텔레그램 turn 관찰 필요. 특히 **codex lane glg(가족 봇)** — 6.1 codex auth canonical migration 후 실대화에서 401/empty 없는지. claude lane(main/bbot/mini)도 5-7d soak. codex thread compaction(긴 turn 후 `thread not found`) 회귀 여부도 같이.
- [ ] **6.1 state SQLite 통합 안정성** — plugin/task/telegram state가 shared SQLite로 이관됨. sqlite 통합 후 telegram dedupe/offset 정상 동작 확인. (`.migrated` 잔재 정리는 2026-08-04 완료 — `~/openclaw` 전체에 0건.)
- [ ] **subagent bootstrap context 축소 (#85283)** — active-memory recall sub-agent (5.4-mini lane) `status=empty` 비율 변화. 14d soak baseline 비교
- [ ] **`@anthropic-ai/claude-code` 버전 추적** — 5.27 image 재빌드 후 컨테이너 `claude` 2.1.156 (5.22 시점 2.1.150). `--help`에 `claude-opus-4-8` 명시 → opus 4.8 지원. Dockerfile pin 여부 검토
- [ ] **OAuth refresh 자동 검증** — Anthropic `expiresAt` 8h마다 새로 받는지 24h 관찰
- [ ] **active-memory 35s timeout 빈도** — claude-cli 환경에서 mini lane recall이 30~35s까지 늘어남 (직전 baseline 5-10s). subagent context 축소와 연관 가능. **2026-06-13 bbot 제외**(24h 16회 중 timeout 8 / ok 8, ok도 23~30s — 본 턴과 겹쳐 응답성 저해)로 가족·bbot 라인은 닫음. **근본(recall lane이 23~35s·절반 `stopReason=missing`)은 main/gpt에 잔존** — **2026-08-07 처방 시도: lane을 `gpt-5.4-mini`(codex) → `gpt-5.6-luna`(openclaw 내장)로 교체**. Codex CLI 서브프로세스 콜드스타트(31.5s)가 원인의 상당 부분이었다면 여기서 풀린다. 교체 후 재측정할 것

---

## 3. active-memory 관찰 후속 (장기)

24h baseline 통과 (2026-05-08~09, gpt 14 invocation: ok 4 / empty 10 / timeout 0 / elapsed ~8.3s).

확장 후 관찰 (mini가 `claude-cli/sonnet-4-6` 검증 lane으로 빠진 상태 — 현재 active-memory 대상: **main/gpt** 2봇. glg 2026-06-09·bbot 2026-06-13 제외):

- [x] **glg(가족 봇) 응답 latency 체감** — recall 훅 16~35s 지연 호소 → 2026-06-09 glg 제외로 해소. 같은 증상 bbot도 2026-06-13 제외.
- [ ] **main agent 회상 품질 정성 평가** — `status=ok` 비율 추적
- [ ] **14d baseline** — 4봇 합산 invocation/day, status 분포, elapsed 분포. timeout 빈도 0% 유지 확인 (다중 봇 동시 호출 시 OAuth quota 경합)

---

## 4. 8B 4096d 검색 품질 검증 (별개 자리, 우선순위 낮음)

5.7+8B baseline 전환 (2026-05-08, OpenRouter `qwen/qwen3-embedding-8b` 4096d, 가격 절반). reindex 완료. 검증 항목:

- [ ] **4B ↔ 8B 동일 query score 비교** — 4B 측정값 (안녕 0.759, 세션을 0.627, 임베딩 0.680)과 8B 분포 비교. 의미 매칭 vs textScore 비중
- [ ] **4096d ranking 영향** — top-3 변화 사례 + storage 실측 (4B 621M → 8B 약 1GB 예상)
- [ ] **가족 봇(glg) 실응답 품질** — 회상 자연스러움, latency 변화
- [ ] **andenken bake-off 재실시** — andenken도 8B 4096d 따라온 후 cross-store 일관성. 결과 `~/org/llmlog/` 새 노트

---

## 5. HA 데이터 import (baton pass — lifetract repo)

nixos-config 인프라 layer 완료 (commit `53a8d2e`). 다음 단계는 [`~/repos/gh/lifetract`](file:///home/junghan/repos/gh/lifetract):

- [ ] AGENTS.md 신설 — 현재 없음, 현재 동작과 문서 일치 점검
- [ ] HA REST import 스크립트 — `/api/states/sensor.sm_s942n_s26_glgman_*` polling
- [ ] cron 일1회 (NUC 또는 laptop)

---

## 6. 영속화 옮길 자리 (다음 정리 사이클)

지난 사이클들에서 NEXT.md에 누적된 영속 fact들. AGENTS.md / docs/openclaw-gotchas.md / `~/openclaw/README.md` change history로 이관:

### gotchas.md로 옮길 자리

- [ ] **5.x → 5.y host upgrade 직후 `doctor --fix --yes --non-interactive` 의무** — 5.19 #310 이후 자동화됐지만 일관성 차원. Codex OAuth lane 미실행 시 4봇 `FailoverError: No API key found`
- [ ] **OpenClaw 업그레이드 사이클마다 dangling image + build cache 누적 → `run.sh C)` 정기 prune** — `docker system df` reclaimable 명목치 ≠ 실 회수량, builder prune이 본 회수원 (2026-05-17 cycle: 27GB 명목 → image 2.4GB + builder 7.687GB)
- [ ] **Caddyfile bind-mount inode 교체** — 호스트 `Edit`/`Write` atomic rename으로 inode 교체 → caddy 컨테이너 옛 inode 잡고 `caddy reload` 무효. 해결: `docker compose restart caddy`
- [ ] **stuck session auto-recovery 회로** — `recovery=none` 로그는 즉시 action 아님 (605s 안에 자체 회복). 5.18에서 강화됨 (release L59)
- [ ] **top-level `auth.order` 정공법** + `plugins.entries.codex.config.appServer.sandbox=danger-full-access` — 5.20 stamp 자리

### AGENTS.md로 옮길 자리

- [ ] **§3 5.22 isolated polling stall 자동 restart** — boot 직후 fetch-timeout 수동 restart 의무 해제 가능 여부 확인 후 갱신
- [ ] **§2 ACP route stance 5.19 #148 align** — upstream Codex app-server scope 분리와 우리 stance 동일 방향
- [ ] **§3 5.18 Stage 1/2 통과 stamp** — soak GREEN, 5.18 baseline 영속

### 비긴급 잔재

- [ ] `~/docker-data/{mattermost,synapse}` archival (비활성 후 데이터 잔존)
- [ ] orphan transcript 1건 (main `485e865f-...`) — `doctor --fix`로 *.deleted 처리
- [ ] `commands.ownerAllowFrom` 미설정 — owner-only commands 자리
- [ ] `~/.openclaw chmod 700` 권장
- [ ] gateway `0.0.0.0` bind WARN — caddy + auth로 가리는 자리, 정공법

---

## 7. pi-shell-acp Phase 1.8 β 잔여 자리 (⏸ FREEZE, publish 완료 후)

pi-shell-acp 코어 0.7.0 npm publish 라운드 완료 + Phase 3 진입 stamp 대기. 잔여 ⏸ 항목:

- [ ] ⏸ main picker `/model pi-shell-acp/...` 전환 turn 5개 모델 각 단발 검증
- [ ] ⏸ 풀세트 6축 검증 (β 통과선): skill manifest (3a) + invocation (3b) + 세션 자기인식 + workspace 인식
- [ ] ⏸ adad76af session 누적 ack 청소 정책 — stale session archive 정책 검토

### 추적 후보 3건 (⏸ pi-shell-acp issue 검토)

- (a) **분신 child env hallucination** — Codex child가 host `PI_AGENT_ID` 상속해서 자기를 Claude로 자기보고. child env 청소 정책 검토
- (b) **`entwurf_self.socketPath` placeholder** — socket file 없어도 path 반환. `entwurf_self`가 socket file stat 후 반환하는 게 정확
- (c) **MCP bridge child `PI_SESSION_ID` env stale** — bridge child가 spawn 시점 env 캐시. 부모 pi가 새 session으로 갱신해도 env 미반영

### Cross-repo follow-up

- [ ] `pi-shell-acp` 문서에 Docker auth boundary 섹션 추가 — "backend CLI auth는 backend가 소유, pi-shell-acp는 token을 읽거나 변환하지 않음"
- [ ] `agent-config` ref pinning 복귀 결정 — 0.7.0 cut 후 main 추적 정책 정리
- [ ] `plugins/openclaw/README.md` Install layers — settings.json host absolute path 호환성 (`/home/junghan/.pi/agent` 동등 path 두 번째 mount 함정)
- [ ] α 별도 advanced smoke (공개 기본값) — 통과선 1/1b/2/세션 자기인식만

§1 정리 사이클이 활성화되면 이 ⏸ 자리들도 함께 재검토 (deprecate 후보 포함).

---

## 8. NixOS 26.05 이관 — 완료(v2026.7.2), 후속만

**25.11 → 26.05 "Yarara" 이관 완료** (2026-07-02): thinkpad(x86 canary) switch+재부팅 → oracle `build .#oracle` 게이트 → switch → 재부팅 콜드부팅 GREEN(gen #59·#58 롤백 보존, failed 유닛 0, 12컨테이너 자동복구, caddy 6-세트·openclaw 6봇 healthy). 상세는 [CHANGELOG.md](CHANGELOG.md) `v2026.7.2` / [ROADMAP.md](ROADMAP.md). 남은 후속:

- [ ] **#58 GC (25.11 closure 회수)** — 콜드부팅 GREEN 확인됨 → 이제 안전. `sudo nix-collect-garbage --delete-older-than 3d`(또는 run.sh C))로 gen #58 삭제 + 25.11 closure 대량 회수. (부팅 검증 전엔 금지였으나 검증 완료로 해제.)
- [ ] **task B — gog(gogcli) 봇 컨테이너 설치** — switch가 해결 못 하는 별개 작업. oracle 봇 컨테이너에 gog 부재(과거 amd64 번들이 aarch64 실행 불가 → 가족봇 캘린더 조용히 실패, 실측 `GOG MISSING` 확인). upstream arm64 tarball로 Dockerfile 한 줄:
  ```dockerfile
  ARG GOG_VERSION=0.31.1
  RUN curl -fsSL "https://github.com/steipete/gogcli/releases/download/v${GOG_VERSION}/gogcli_${GOG_VERSION}_linux_arm64.tar.gz" \
        | tar -xz -C /usr/local/bin gog && gog --version
  ```
  - **동기 Dockerfile 2개**: `~/openclaw/Dockerfile` + `docker/openclaw/Dockerfile`(현재 byte-identical). summarize `npm install -g` 자리 근처(L133), **`USER node`(L162) 앞 root 구간**에 삽입(`/usr/local/bin` 쓰기 권한). `TARGETARCH` 대신 `arm64` 하드코드(레거시 빌더 빈값 함정 회피).
  - **OAuth creds 마운트**(이미지에 굽지 말 것): 봇 계정 `~/.config/gogcli` → `/home/node/.config/gogcli`(ro). 봇 계정 선택 = **GLG 결정 대기**.
  - 재빌드 후: `docker exec openclaw-gateway gog --version` + `gog calendar` 1회 + 봇 라이브 turn 캘린더 응답. `run.sh k)` SKILL_EXCLUDE에 gogcli 넣지 말 것(봇이 씀).
- [ ] **문서 정정 (라이브마운트)** — caddy·authelia가 repo 워킹트리를 라이브 마운트(`docker/caddy/Caddyfile` · `docker/authelia/{users,configuration}.yml`)함을 `docs/openclaw-gotchas.md`에 박고, nixos-config 스킬의 "docker/*=백업/레퍼런스" 문구 정정(oracle에선 부정확). git checkout/stash가 이 파일 바꾸면 라이브 인증/프록시 영향 — 이번 이관 중 실측 확인(브랜치는 안 건드려 무영향이었음).

---

## 9. 디스크 정리 후속 (2026-06-02, thinkpad)

`run.sh C)` 공격적 정리로 개선 완료(3일 GC + optimise + pnpm prune + 전 디바이스 docker + journal vacuum). 남은 큰 덩어리 — 필요 시 추가 회수:

- [ ] **yocto downloads 21G + sstate-cache 11G** — OPi5 재빌드 캐시. 재빌드 계획 없으면 32G 회수 가능 (`homeagent-config/yocto/`)
- [ ] **work/ 임베디드(rockchip) 빌드 repo 31G** — 빌드 산출물 추정. 정리 대상이면 회수, 확인 필요 (repo명은 PRIVATE)
- [ ] **pnpm store 18G** — 개선된 `C)` 한 번 돌리면 `pnpm store prune`으로 미참조분 회수
- [ ] **store 78G 구조적** — nixpkgs 3트리(25.11 + unstable + pinned) 동시 보유. 26.05 전환 + unstable 정리 시 변화

---

## 10. 키크론 V10 Pro (ZMK) 키맵 닷파일 관리 (2026-06-17, thinkpad)

새 키보드 도입. Q8 → V10 Pro **ZMK** 버전(USB `3434:13a8`, VIA 아님). 설정은 ZMK 웹(Keychron Launcher, `launcher.keychron.com`)에서 하되, **export 파일을 nixos-config에서 버전 관리**한다 (export/import 동작 확인됨).

### 완료
- [x] **hidraw udev rule** — Launcher(WebHID)가 키보드 접근하도록 `shared.nix`에 `uaccess` rule 추가 (커밋 `6d020e9`). oracle 제외, 이동식이라 전 디바이스 공통.
- [x] **i3 `Win+grave` 재배정** — Q8엔 없던 grave(\`) 키가 V10엔 있음. dunst history-pop → `Win+Shift+grave`로 옮기고, `Win+grave` = `focus output next`(eDP 1-5 ↔ HDMI 6-10 모니터 전환).
- [x] **hidraw 접근 결정적화** — uaccess 타이밍 의존("됐다 안 됐다")을 `GROUP=input`로 해소 (커밋 `ee348d4`). junghan ∈ input. rebuild 후 영구. 키보드 입력 IF 00은 uaccess 제외라 더 들쭉날쭉했던 게 원인.
- [x] **export 파일 위치 결정 + 보관** — `users/junghan/keychron/`. 첫 스냅샷 `Keymap-V10-Pro-ZMK-ANSI-Knob-18-8-4.json` 커밋. SSOT는 Launcher, repo는 백업/재현용. 규칙·복원법은 그 폴더 `README.md`.

### 다음 한 걸음 (천천히 — 키 활용 미정)
- [ ] **M1–M5 매크로 키 활용 결정** — Q8엔 없던 키. 아직 무엇에 쓸지 미정. 후보 떠오르면 여기 적고 ZMK 웹에서 바인딩 → export.
- [ ] **마음에 안 드는 키만 우선 수정** — 전체 재설계 말고 거슬리는 키부터. 나머지 레이아웃은 쓰면서 천천히.
- [ ] **(선택) 칩셋 확인** — RTL8762G vs nRF52840. 펌웨어 모드 진입해서 부트로더 볼륨/`dmesg`로 확인. nRF52840이면 `zmk-nix`로 소스 빌드까지 가능, RTL8762G면 Launcher export 관리에 머무름.
