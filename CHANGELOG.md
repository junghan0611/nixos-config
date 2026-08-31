# Changelog

이 NixOS 설정의 주요 변경 기록.

`v2026.5.31`부터 **CalVer 날짜 태그**(`vYYYY.M.D`, 선택적 `-beta.N`/`-rc.N`)를 쓴다 —
이 repo는 버전 라이브러리가 아니라 재현 가능한 인프라라, 의미는 날짜가 담는다.
아래 `0.1.0`~`0.3.2`는 이전 SemVer 이력으로 그대로 보존한다. 서사(왜/어떻게)는
[ROADMAP.md](ROADMAP.md)에, 이 파일은 "무엇이 바뀌었나" 로그다.

## Unreleased

## v2026.8.31 — OpenClaw 8.1 오프라인 컷오버 + aionsclubs 공개면

### OpenClaw 2026.8.1 — 버전 bump가 아니라 순서 있는 마이그레이션이었다

- **7.1-2 → `2026.8.1` (ea80657) 라이브 컷오버** (`cfeb9a5`). 게이트웨이를 정지하고 **오프라인으로** 옮겼다 — 다운타임 **20:36:40 → 21:15:54 KST**(약 39분, 재작업 포함). **`Dockerfile` `FROM` 한 줄 + `--force-recreate`로는 부팅이 거부된다**(19:14 실측: `Invalid config` 7키 + `OpenClawStateDatabaseSchemaMigrationRequiredError`) — 8.1은 **옛 state를 거부**한다. 순서가 강제된다: ① 게이트웨이 정지 후 `doctor --fix` **직렬 재시도**로 agent DB 7개를 v19까지(`core:agent-database-maintenance/global` 리스를 도중에 잃어 나머지를 건너뛴다 — lab·라이브 양쪽 재현) → ② 그제야 startup config repair가 커밋된다(repair는 state migration이 clean하게 끝난 뒤에만 커밋한다) → ③ 세션 스토어는 `--fix`가 아니라 `doctor --session-sqlite {dry-run,import,validate}`라는 **별도 경로**.
- **어려웠던 이유는 실패가 전부 `healthy`로 보였기 때문이다 — 조용한 실패 11겹.** 컨테이너 `healthy` + 텔레그램 6/6 `works`가 찍히는 동안 봇은 답을 못 하거나(7·10·11), 정체성 없이 답하거나(8), 텔레그램 계정에 소유자가 없었다(9). **그래서 검수를 3층으로 못박았다**: 컨테이너 `healthy`(아무것도 보장하지 않는다) → `channels status --probe`("붙었다" ≠ "답한다") → **6봇 격리 프로브**(이걸 안 하면 8·9·10·11을 전부 놓친다). 11겹 표와 재현 절차는 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md), 서사는 [ROADMAP.md](ROADMAP.md), 삽질 전문은 [issue #7](https://github.com/junghan0611/nixos-config/issues/7).
- **격리 lab은 절반만 준다.** 사전 lab 2개로 1~5번을 미리 잡았으나 6·7(cold archive에 `credentials/`·`exec-approvals.json` 미포함)과 8·9·10·11은 못 잡았다 — lab이 `--network none`이라 **실제 턴을 한 번도 안 돌렸기 때문이다.** 나머지 절반은 라이브 턴에서만 나온다.
- **사람이 정한 config 편집 6건** (자동 수선 대상이 아니다 — 전부 정책 결정. 개수는 백업 config ↔ 라이브 config 대조 실측): `agents.ownership="explicit"`(8.1 스키마가 에이전트 2개↑ + default 마커 0을 거부, `zod-schema.agents.ts:79-85`) · `bindings`에 `telegram:default → main`(위 결정의 직접 귀결 — 7.1은 암묵적 기본 에이전트가 받아줬다) · `plugins.allow`에서 은퇴한 `phone-control` 제거 · `skills.workshop` 3키 명시(`autonomous.mode:"off"` / `approvalPolicy:"pending"` / `allowSymlinkTargetWrites:false`) · 6봇 `workspace` 명시 · `openai/gpt-5.6-{terra,sol,luna}`의 `agentRuntime` 명시. 나머지 **17건 semantic 변환은 startup repair가 결정적으로 수행**했다(`agents.list`→`agents.entries`, `agents.defaults.memorySearch`→`memory.search`, `tools.exec.security/ask`→`tools.exec.mode`, legacy 모델맵→`modelPolicy.allow`). **lab config를 통째로 복사하지 않았다** — doctor가 model auth/wizard 경로까지 건드리기 때문.
- **catch-all 규율이 사는 자리가 이사했다.** legacy 모델맵이 `modelPolicy.allow`로 복사되며 **순서가 보존**됐고 1번은 `openai/gpt-5.6-terra` 그대로다. 이제 규율은 `agents.defaults.models`의 **키 순서**가 아니라 **`agents.defaults.modelPolicy.allow`의 배열 순서**다. ORACLE.md의 옛 문구는 이 자리에서 무효.
- **`skills.workshop`을 명시적 `off`로 박고 받았다.** 8.1은 미설정 기본값을 자동 적용 쪽으로 뒤집는데(#115576), 릴리즈 노트가 보호한다는 것도 *"explicit off or propose"*이지 **미설정이 아니다** — 우리에겐 `off`라는 명시 자체가 없었다. 근거: `workspace-skill-write.ts:420-440`이 `allowSymlinkTargetWrites=false`면 심링크 타깃 쓰기를 throw하지만 **auto create는 로컬 real dir에 가능하고 `run.sh k)`가 그걸 지운다** — 우리 스킬 트리는 agent-config SSOT로의 심볼릭이라 자율 쓰기 경로를 열어둘 수 없다.
- **2026-08-07 codex 결정이 미완이었음이 드러나 완결됐다.** 그때 `plugins.entries.codex.enabled=false`로 껐지만 `openai/gpt-5.6-*` 세 모델은 `{}`인 채라 **여전히 Codex 런타임으로 해상**되고 있었다. 7.1은 doctor 경고 7건으로 봐줬고 우리는 그걸 소음으로 취급했다 — **8.1은 fail-closed 한다.** 세 모델에 `agentRuntime:{id:"openclaw"}`를 명시해 결정을 완성했다. doctor 경고 **7 → 0**. ⚠️ 고친 뒤 프로브가 `⚠️ API rate limit reached` / `rawError=Codex error: The usage limit has been reached`로 떨어지면 그건 **성공 신호다**(런타임이 OpenAI에 도달했고 벽은 구독 쿼터) — 수정 전 문자열 `runtime "codex" is unavailable`과 반드시 구분할 것.
- **검수 결과**: 컨테이너 `healthy`·restart 0, boot WARN 0, 채널 **6/6 `works`**, 6봇 모델 prefix·워크스페이스·라우팅 불변, catch-all 1번 유지, doctor codex 경고 0. **서빙 실턴 6/6** — main(opus-5)·glg(sonnet-5)·mini(sonnet-5)·bbot(fable-5)·gemini(`github-copilot/gemini-3.7-flash`) 5봇은 컷오버 직후 **격리 프로브**로 정체성·모델 정확 확인. **gpt는 22:12 KST 쿼터 리셋 뒤 GLG가 6봇 전수 실대화로 확인**했다 — 컷오버 시점의 `rate limit` 응답이 결함이 아니라 구독 쿼터 벽이었다는 판정이 그대로 맞았다. 두 receipt의 성격이 다르다: 5봇은 격리 프로브, gpt는 운영자 실대화다.
- **세션·트랜스크립트 손실 0.** `doctor --session-sqlite import` = 42 → 42 entries·0 issues. 미참조 `.jsonl`은 **삭제가 아니라 아카이브**(`config/agents/<id>/session-sqlite-import-archive/*.imported-<ts>`). 부수 효과로 DB compact 약 870MB 회수. 오래 남아 있던 **orphan transcript 104건이 이 과정에서 해소**됐고, 옛 전제 *"`--fix`는 gemini를 깨므로 못 쓴다"*도 이번 실행에서 드리프트 0으로 반증됐다.
- **롤백면은 백업 2종이 합쳐져야 온전하다** — 컷오버 백업 `backups/pre-8.1-cutover-20260831T203708/`(1.8G, 마이그레이션 대상 + gate 증거 + `ROLLBACK.sh`)에는 **`.jsonl` 트랜스크립트가 0개**다. 트랜스크립트는 `backups/pre-8.1-20260831T190622/config-state-cold.tar.zst`(837M) 쪽에 있다. 이미지 태그 `openclaw-custom:7.1-rollback`. **마이그레이션된 state로는 롤백하지 않는다 — cold 백업이 롤백 원본이다.**
- **릴리즈 교차검토가 문서 네 곳의 드리프트를 잡았다** (`3be5e83`). 원인은 하나다 — **같은 사실을 issue #7·ROADMAP·gotchas 세 곳에 손으로 옮겨 적었다.** 표가 11행으로 자란 뒤에도 두 곳이 "9겹"이라 불렀고(그중 하나는 존재하지 않는 이름의 표를 가리키는 자기참조였다), gotchas 소제목이 10·11번을 한 겹으로 세면서 **8.1 그 자체인 11번을 "8.1과 무관한"으로 묶었고**, config 편집 개수가 4(ROADMAP) / 5(issue)로 갈렸고, `bin/claude.exe` 바이트가 두 값이었다. 넷 다 receipt로 닫았다 — 편집 개수는 백업 config 대조로 **6**, 바이트는 `openclaw-custom:7.1-rollback` 이미지에서 `stat`로 **285457336**. **개수를 산문에서 빼는 건 싼 수선이고, receipt에서 뽑는 게 진짜 수선이다.**

#### 폐기된 반사신경 3건 — 옛 규칙을 그대로 따르면 사고가 난다

1. ~~업그레이드 = `Dockerfile` `FROM` 한 줄~~ → **패치/마이너 hop인지 메이저 hop인지 먼저 판정한다.** 8.1은 한 달치 메이저 + breaking 2건이었고, 그 사이 stable이 없었다(6.34는 백포트).
2. ~~`doctor --fix` 금지~~ → **8.1에선 필수 절차다.** 금지 사유였던 gemini `google/` 재작성은 2026-08-27 Copilot 이관으로 **이미 대상이 소멸**했고, 이번 실행에서 드리프트 0을 확인했다.
3. ~~gemini는 DOWN 유지~~ → **화석이다.** `github-copilot/gemini-3.7-flash`로 살아 있다.

### Added

- **`aionsclubs.org` 격리 클럽하우스 스택** (`97c1360`) — 로컬 관리 터널 `aions` + 전용 docker 네트워크, **호스트 포트 publish 0**. web root는 `/srv/aions/current`(부모 bind `docker-data/aions`), 자격증명은 리포 밖. 이어서 **creator-mode publish**(`86d5152`) — 리포 HEAD를 `docker-data` releases로 스냅샷하고 `current`를 원자적으로 재지향, 게이트는 시크릿 유사 경로에만 거는 soft gate(홈페이지 작업은 열어둔다). `deploy.sh`는 리포 publish 스크립트에 위임(`8e900bb`). **`www` 는 ingress에서 뺐다**(`c2292d8`) — 엣지 Single Redirect가 301로 apex에 보내고 **Redirect Rule이 오리진보다 먼저 평가**되므로 404가 아니다(확인: www → 301, apex → 200). remark42에 aionsclubs 댓글 사이트 추가(`8adcfc8`), `cloudflared` 유틸리티 패키지 추가(`121e923`).
- **heartbeat per-agent 블록 함정 박제** (`ebbe31e`) — 한 봇 주기만 바꾸려 `agents.list[]`에 `heartbeat` 블록을 하나 넣으면 `isHeartbeatEnabledForAgent()`가 **명시 목록 모드로 뒤집혀** 블록 없는 봇이 **에러도 경고도 없이 전부 멈춘다**. `defaults.heartbeat`는 아무도 명시하지 않았을 때만 도는 폴백이다. 2026-08-12 적용: main/glg/gpt/mini 1h, bbot 30m, gemini는 블록 미부여로 OFF.
- **컨테이너 안전레일을 시스템 gitconfig에 배선** (`308f397`, `78fbade`) — 봇 컨테이너에는 `~/.gitconfig`도 `/etc/gitconfig`도 **없었다**. 결과가 두 갈래로 갈렸다: plain `git push`는 credential helper가 없어 exit 128로 **시끄럽게** 막히고, global `core.hooksPath`가 없어 봇 커밋이 신원/secret 스캔을 **조용히** 건너뛰었다. 한쪽만 고치면 열어놓고 지키지 않는 상태가 된다. ⚠️ bind source 파일이 없으면 docker가 그 자리에 **빈 디렉터리**를 만들어 `/etc/gitconfig`가 디렉터리가 되고 컨테이너 git이 통째로 깨진다 — compose 마운트 줄만 옮기고 파일을 빼먹지 말 것.
- 패키지: `lean4`·`ledger`(`d32bfe4`), `appimage-run` + GUI AppImage 샌드박스 주석(`de54a05`).

### Changed

- **gemini 서빙 레일 — 2026-08-16 "github-copilot 전면 제거"는 2026-08-27에 뒤집혔다. 현재 사실은 8/27이다.**
  - **8/16 제거** (`20d03a7`, GLG "이제 안 쓴다"): 네 층을 걷어냈다 — 라이브 config 3곳(`auth.profiles."github-copilot:github"` / `plugins.entries.github-copilot` / `plugins.allow` 14→13) → **auth sqlite 3곳**(`auth_profile_store.primary.profiles` / `auth_profile_state.primary.lastGood` / `usageStats`) → 호스트 `~/.copilot/`. 백업 `openclaw.json.bak-copilot-purge-20260816T102602` + `backups/openclaw-agent.sqlite.bak-copilot-purge-20260816T102602`. **함정 박제: `config unset`은 자격증명을 안 지운다** — `auth.profiles`는 *선언*일 뿐이고 토큰 실물은 `openclaw-agent.sqlite`에 있어 unset + restart 뒤에도 `models status`가 토큰을 그대로 뿜었다. CLI에 프로필 삭제 명령이 없어 sqlite를 직접 손봐야 완결된다 — **copilot만의 얘기가 아니라 모든 provider 은퇴에 해당한다.**
  - **8/19 재도입** (`a8d5655`): `@github/copilot` CLI를 pnpm SSOT(`scripts/external-packages.sh`)에 되돌림.
  - **8/27 복귀** (`9665500`): **gemini 챗봇의 서빙 레일로 Copilot을 되돌렸다** — `github-copilot/gemini-3.7-flash`, 플러그인 재활성 + `plugins.allow` 14개 + **새 device-code 로그인**(옛 토큰 재사용 금지). Google Gemini 구독·gemini-cli·agy는 쫓지 않는다(GLG 결정). 8/16 상태를 baseline으로 읽으면 틀린다. 남은 부채는 **8/16에 샌 옛 토큰의 revoke**뿐 — 새 로그인 토큰과 별개다([NEXT.md](NEXT.md)).
  - 이력 문서(CHANGELOG / `docker/openclaw/Dockerfile` 주석 / `openclaw.json.reference` 스냅샷 / `docker/openclaw/README.md` 날짜 라벨)는 **지우지 않았다** — 지우면 gemini의 경로 이동사가 통째로 사라진다. AGENTS.md 세 문서 분업 원칙 그대로.
- **`workspace-glg` 서사 git 졸업** (`9665500`, 체크리스트 `fcc2606`) — 집사봇 workspace가 `junghan0611/workspace-glg`(private)로 독립. bbot(2026-08-27)에 이은 두 번째. **호스트가 레일만 깔고**(private 리포·origin·훅 loose·부모 gitignore) **봇이 커밋·푸시를 소유**한다. 폴더명 = 리포명. 권한 확대가 아니다 — public 리포 생성·훅 끄기·다른 봇 workspace 수정은 그대로 막혀 있다. 남은 후보는 `workspace/`·`workspace-gpt/`·`workspace-gemini/`·`workspace-mini/`.
- **봇 스킬 배포를 rsync 복사 → agent-config SSOT 절대 심볼릭으로 전환** (`4904439`) — `run.sh k)` 개편, `~/.claude/skills` overlay footgun 문서화, gog 바이너리 SSOT를 스킬 트리 **밖**(`openclaw-config/bin`)으로 이동.
- **whole-org rw 마운트 미러 + ORACLE.md 갱신** (`6ab049d`). `docker/openclaw/README.md`는 **2026-04-22 화석**으로 표기(`85ab35e`) — 라이브 운영 정본은 ORACLE.md다.
- **compose를 라이브 openclaw-config와 정합** (`271f678`) — mount fence(gh ro / aionsclubs rw / `docker-data/aions`)와 gog env 복원. 백업 재배포가 creator-mode 배선을 지우지 못하게 하는 것이 목적.
- **zmx 재도입** (`965583b`) — 26.05 이관 때 제외했던 사유 *"zig15 ↔ 26.05 zig16 충돌"*은 **실측 결과 기우였다**(zmx flake는 zig2nix로 자기 zig 툴체인을 격리해 시스템 zig와 무관). 26.05에는 zmx 0.7.0이 미등록이라 `nixpkgs-unstable` 예외로 되돌렸고, 이번엔 upstream flake의 Zig 0.15 빌드가 아니라 **cache.nixos.org 바이너리**를 쓴다. unstable 예외는 이제 **tdlib + zmx 둘**이며 26.05가 따라잡으면 오버레이와 input을 함께 지운다. (자립성 계약 — entwurf 설치면이 zmx를 스스로 확보하는가 — 은 [entwurf #47](https://github.com/junghan0611/entwurf/issues/47)에 그대로 남는다. 이제 PATH에 있으므로 그쪽에서 "우연히 만족"을 경계할 것.)
- **tmux 상태바를 두 줄로 쪼갰다** (`49de039`) — 한 줄이던 시절엔 디바이스 배지·세션명·시계가 폭을 먼저 먹어 창 목록이 **조각으로** 렌더됐다. `status-format[0]/[1]`로 창 목록을 자기 전폭 줄에 두고, 현재 창은 `#I`를 앞에 세워 배경을 반전한다(뒤따르던 `*` 플래그 하나로만 구분되던 것). 현재 창의 `*`는 떼고 `Z`는 남긴다 — zoom된 pane을 잃어버린 것으로 오해하지 않도록. `status-bg`/`status-fg`는 문서화된 `status-style`로 접었다.

### Fixed

- **claude-cli 4봇이 매 턴 1.1초에 죽던 침묵 회귀 — 8.1이 아니라 base 이미지의 npm이 범인이었다** (`cfeb9a5`). npm **11.13.0 → 12.0.2**가 install script를 `allowScripts`로 **기본 차단**한다 → `@anthropic-ai/claude-code` postinstall 미실행 → `bin/claude.exe`가 **500 B 에러 shim**으로 남고(7.1 base에서는 `285457336 B`) 진짜 213MB 네이티브는 `node_modules/@anthropic-ai/claude-code-linux-arm64/claude`에 방치된다. **빌드는 성공했다** — 로그에 남은 건 error가 아니라 `npm warn install-scripts` 한 줄뿐이고, 부팅도 채널 프로브도 전부 통과한다. Dockerfile 3단으로 고정: ① `--allow-scripts=@anthropic-ai/claude-code` ② `node install.cjs` 명시 실행(멱등) ③ **`claude --version` 빌드 게이트**. **③이 본체다** — 없으면 같은 회귀가 다음 bump에서 또 조용히 지나간다.
- **caddy 443 — tailscale이 먼저 선점하면 `junghanacs.com` 서브도메인이 통째로 죽는다** (`c11b1db`). 커널 `7.1.2 → 7.1.4` 재부팅에서 tailscaled가 docker보다 먼저 올라와 tailnet IP `100.67.72.1:443`을 잡았고, 리눅스는 `0.0.0.0:443`과 특정IP `:443`을 공존시키지 않으므로 caddy가 `exit 128 / address already in use`로 죽었다 — **5시간 무응답**. 지난 부팅(7/2)엔 caddy가 이겼을 뿐 **설정은 내내 충돌 상태였다.** 조치: caddy 포트를 enp0s6 NIC(`10.0.0.157`)에만 묶어 tailnet 443과 공존. 공인 IPv6가 없고 A레코드만 쓰므로 외부 손실 0. ⚠️ 같은 재부팅에서 터진 **emacs 소켓 dir 레이스(geworfen/agenda)는 수동 복구만 했고 항구 차단은 미결**이며, `10.0.0.157` 하드코딩과 "tailscale serve 443을 계속 쓸 것인가"라는 근본 판단도 남아 있다 — 전부 [NEXT.md](NEXT.md).
- **thinkpad 내장 마이크가 빈 잭에 묶여 죽던 문제** (`462842b`). 원인은 [alsa-ucm-conf#785](https://github.com/alsa-project/alsa-ucm-conf/issues/785) — ALC257 + AMD ACP 조합엔 `Input Source` 셀렉터가 없어 UCM이 `HDA/HiFi-mic.conf` fallback 분기를 타고, 그 분기가 **내장** 아날로그 마이크(`HiFi__Mic2`)에 **외부** 잭 컨트롤 `Mic Jack`을 붙인다. 잭이 비면 포트가 `not available` → WirePlumber가 기본 후보에서 빼고 → **열거만 되고 캡처는 완전 무음**인 AMD ACP `Digital Microphone`(`HiFi__Mic1`)을 고른다. 실측 최대 진폭 **Mic2 `0.999969` / Mic1 `0.000000`**. 조치: 잭 바인딩만 걷어낸 UCM 트리를 만들어 pipewire/wireplumber 유닛에 `ALSA_CONFIG_UCM2`로 물렸다 — **`alsa-ucm-conf`를 overlay로 직접 패치하면 alsa-lib 체인이 딸려와 로컬 빌드가 764개**가 되므로 패키지는 건드리지 않는다(현 방식은 11개, 실제 새 빌드는 UCM 트리 하나). 검증: 임시 조치 전부 제거 후 설정만으로 Mic2가 기본 소스로 선택되고 **376832 샘플 캡처**.
- **`~/.config/mimeapps.list` 심링크 파손 — home-manager가 매 switch마다 죽고 있었다** (`1d77cb0`). Chrome 등이 기본 핸들러를 등록하며 심링크를 일반 파일로 갈아치웠고, home-manager는 그 파일을 낯선 것으로 보고 백업하려 하는데 **4월치 `.hm-backup`이 자리를 막고 있어** `home-manager-junghan.service`가 `exit 1`로 죽었다(시스템 부분만 적용되는 상태). 홈 파일 쪽이 최신이라 **그 내용을 리포 SSOT로 승격**했다 — 기본 브라우저 firefox → google-chrome, `github-handler`(github-app/ghapp/gh)·slack 스킴 핸들러, about/unknown 추가.
- **Doom Emacs를 데스크톱 엔트리에서 직접 기동** (`9852477`).
- **컨테이너 YouTube 쿠키를 rw로 + `yt-dlp>=2026.8.19` 핀** (`80202aa`) — oracle에서 EJS challenge solver를 타려면 컨테이너가 쿠키를 재작성할 수 있어야 하고 yt-dlp가 그만큼 새로워야 한다. 라이브 openclaw-config 미러.


## v2026.8.10 — 26.05.20260808 hop + 리포 자기 수선 협업

### Added
- **tailscale constrained node gateway wrapper** (`49280ba`).

### Changed
- **flake lock → nixpkgs `8b8c811`(26.05.20260808) / home-manager `d4fd246` / nixpkgs-unstable `70ce234`** (`9837ed1`). thinkpad `test` → `switch` 통과, **세대 148**, 실패 유닛 0(시스템·유저). 커널 **7.1.4 → 7.1.7** 은 부트 엔트리·`loader.conf` default가 148로 박혔으므로 다음 재부팅부터 탄다.
- **rebuild 비용 실측 — 사전 추정이 3~4배 보수적이었다.** dry-run은 `3.5 GiB 다운로드 → 10.1 GiB unpacked` + 로컬 빌드 74개였고 여기서 store 순증 15~20 GiB를 추정했으나, **실제 순증은 약 5G**(46G→41G). unpacked 대부분이 기존 store path와 겹쳐 하드링크로 흡수되고, 로컬 빌드 74개는 대부분 작은 config derivation이었다(`texlive-combined`는 실체 복사가 아니라 심볼릭 링크 farm). **다음 hop에서도 dry-run의 unpacked 수치를 순증으로 읽지 말 것.**

### 운영 결정 — 리포 자기 수선 handoff는 코드로 굳히지 않는다
- **`.diskclean-owned` 마커 제안 거절** (GLG 결정). 리포에 표식 파일을 두면 `diskclean.sh` 0단계가 그것을 발견해 지우지 않고 담당 스킬 이름만 인쇄하고 넘어가는 방식을 제안했으나, **마커 자체가 관리 대상이 된다**(리포가 늘 때마다, 스킬 이름이 바뀔 때마다 손이 간다)는 이유로 채택하지 않았다. 코드 변경 0.
- **따라서 `scripts/diskclean.sh:157-163`은 여전히 `.zig-cache`/`.direnv`를 통째로 지운다.** 담당자가 남기려고 판정한 하위 디렉토리도 함께 날아간다. **깊은 정리 전에 담당자에게 묻는 습관이 유일한 방어다** — 코드가 막아주지 않는다. §2.6의 정리 순서와 함께 기억할 자리.
- 실사례: 다른 리포의 Zig object 캐시 9.1G를 중앙에서 밀지 않고 담당자에게 넘겨 **df 실측 9.05 GiB 회수**(apparent 12,375,675,933 B와 다르다 — 하드링크/sparse). 담당자는 남길 하위 60M을 판정해 보존했다. 중앙이 밀었으면 그 60M도 잃었다.
- 그 협업에서 이 repo가 발신한 **repo-local 스킬 정본**(`<repo>/.claude/skills/<name>/SKILL.md` 실물 하나 + `<repo>/.pi/settings.json` = `{"skills":["../.claude/skills"]}`, 복제 없이 두 하네스가 같은 파일을 읽는 구조 — 2026-08-10 기준 16개 리포가 같은 문법)과 삭제 계약은 봇로그 `20260227T031800`으로 공개했다.

### Fixed
- **`boot.tmp.cleanOnBoot = true` — NEXT.md 기록이 19일간 stale이었다.** "`nix flake check`만 통과, rebuild 안 했다"고 적혀 있었으나 실제로는 **세대 143(2026-07-22)부터 적용돼 있었다**. 검증: `tmpfiles.d/00-nixos.conf`의 `D! /tmp 1777 root root`가 세대 141·142에는 없고 143~148에 있다. 항목은 NEXT.md에서 제거.

## v2026.8.7 — Control UI 공개면 + codex 런타임 이탈

### Added
- **`claw.junghanacs.com` — OpenClaw Control UI 공개면** (2026-08-06). 자물쇠를 **통합하지 않고 3겹 그대로 쌓았다**: `Internet → Caddy HTTPS → Authelia forward_auth(operator만) → gateway token → device pairing → Control UI`. 통합을 안 한 이유가 핵심이다 — `openclaw-gateway`가 `proxy` 도커 네트에 붙어 있어 **같은 네트 컨테이너는 Authelia를 건너뛰고 18789에 직결한다**(실측: caddy→gateway `/` = 200 무인증 HTML). **진짜 경계는 token+pairing이지 forward_auth가 아니다.** 게다가 이 게이트웨이는 전 봇 `exec security=full`·`sandbox=off`라 Control UI admin 세션은 사실상 **oracle 원격 셸**이다. Authelia에 `glg`(groups: `operator`) 계정 신설 + claw 규칙 3단(bypass → operator one_factor → **deny catch-all**), 적용 전 `check-policy` 4건 판정(operator=one_factor / family=deny / 포털=bypass / map 회귀 무영향). OpenClaw 쪽은 `controlUi.allowedOrigins` 갱신(화석 `openclaw.junghanacs.com` 제거) + `auth.rateLimit` 신설로 `security audit` WARN 해소. caddy 8-세트 검수 회귀 0, 브라우저 실연결(pairing 승인 → RPC 왕복)까지 확인. 설계는 gpt 봇과 4라운드 cross-review로 굳혔다.
- **tmux copy-mode Alt 레이어** — 한글 입력 상태에서도 도는 vi 이동. 이어서 Alt 층을 확장해 **Ctrl 없이 복사 한 사이클**이 닫힌다. `M-\` = 다음 분할(pane 이동)도 같은 문제의식 — 한글 입력 중 Ctrl 조합이 죽는 자리를 Alt로 우회.
- **tdlib unstable 1.8.66 오버레이** — telega.el 하한 충족.

### Changed
- **codex 런타임 의존성 제거 — 내장 `openclaw`(구 `pi`) 런타임으로 일원화** (2026-08-07, GLG 결정). `agentRuntime` 미지정이 곧 OpenClaw 자체 에이전트 루프이고, **그 루프의 옛 이름이 `pi`다**(런타임 코드에 `"pi" → "openclaw"` 별칭 1줄로 잔존). 같은 파일에 whole-agent 런타임 선택이 `@deprecated`로 박혀 있다 — 런타임은 이제 모델별 정책이다. openai가 `openai/oauth`(ChatGPT 구독)로 내장 런타임에서 그대로 서빙되므로 codex CLI를 경유할 이유가 없었다. subagents `gpt-5.4`→`gpt-5.6-terra`, active-memory recall lane `gpt-5.4-mini`→`gpt-5.6-luna`, `gpt-5.4`/`-mini` 카탈로그 삭제, `plugins.entries.codex` disable. 부수 효과로 **31.5s Codex CLI 서브프로세스 콜드스타트**가 recall lane에서 사라졌다 — 오래 남아 있던 recall 23~35s 지연의 유력 원인.
- **`thinkingDefault: "medium"` 신설** — 그동안 이 키는 **미설정**이었고 모델 카탈로그 기본값에 맡겨져 있었다. 기본을 medium으로 두고 필요할 때 올린다(GLG: 턴 속도). ⚠️ upstream 기본이 sol=`low`/terra=`medium`/luna=`medium`이라 **gpt 봇에겐 인하가 아니라 인상**이다. 세션 sticky가 이 값을 이기므로 이미 도는 세션은 안 바뀐다.
- **`subagents.maxConcurrent` 8 → 4** — 에이전트 턴 상한과 동일하게. oracle은 aarch64 VM 한 대에 6봇 + caddy + authelia + forge + HA가 얹혀 있어 8 동시는 봇 턴과 자원을 다툰다.
- **OpenClaw 7.1 → 7.1-2 correction release 적용** (2026-08-04). 다운타임 16초, 모델 드리프트 0, doctor Errors 0. 7.1 대비 실제로 바뀐 파일은 7개뿐(codex 5 + memory-core 2) — 메모리 엔진은 무변경.
- **6봇 모델 전면 정렬** (2026-08-04). main `opus-4-8` → `claude-opus-5`, `gpt-5.5`/`sonnet-4-6` 전면 제거. **config primary ↔ 라이브 DM 세션 쌍 정렬**이 핵심 관리 단위라는 규칙이 여기서 나왔다.
- **autorandr 4K** — LG 4K 사무실 프로파일 scale 0.75, 이어서 scale을 `postswitch`로 고정해 상하 겹침 제거.
- `tm`/`tml`을 `.bashrc.local`에서 repo로 회수. Nix flake inputs 갱신.

### Fixed
- **auto-fallback catch-all 연쇄 함정 차단** — `openai/gpt-5.4`는 `defaults.models` **1번 = catch-all**이었다. codex 제거로 그냥 지웠으면 1번이 gemini(403 DOWN) → `claude-fable-5`(bbot 정체성 모델)로 밀려 **2026-06-13 deepseek 사건과 같은 정체성 훼손**이 재현될 뻔했다. allowlist를 재정렬해 catch-all을 `gpt-5.6-terra`로 고정. 부수 정정: "allowlist 키 순서는 지정 불가"는 **`config set` 경로에 한정**이고, JSON 파일 직접 편집으로는 순서가 선다.
- **`models auth list`의 `expires` 오독 정정** — 거기 찍히는 건 8시간짜리 **액세스 토큰**이고 자동 회전한다. 실제 기한은 `~/.claude/.credentials.json`의 `refreshTokenExpiresAt`(2026-09-05)이며 `models auth list`는 그 값을 안 보여준다. **`expires`가 오늘/내일이어도 정상** — 매일 만료 알람으로 읽으면 있지도 않은 부채가 생긴다. 손댈 조건 3개(mtime 정체 / 리프레시 임박 / 실제 서빙 실패)를 판정 규칙으로 명시.
- **`-2` Control UI 업데이트 알림은 상시 오탐** (2026-08-06 확정). correction release가 `package.json` version 문자열을 안 올려서, UI가 릴리즈 태그(`v2026.7.1-2`)와 실행 중 버전 문자열(`2026.7.1`)을 비교하면 영원히 어긋난다. diff_ids 대조로 라이브가 `-2`임을 확정 — 이 알림은 계속 뜨고, 무시한다.
- **active-memory `agents` 문서 드리프트 정정** — 문서는 오래 `["main","gpt"]` 2개로 적혀 있었으나 라이브는 `["main"]` 단독이었다. gpt는 active-memory가 실질적으로 잘 동작하지 않아 GLG가 뺀 것. 현재 active-memory는 **main 한 봇에만 남은 실험 lane**이다.
- tmux 안에서만 멈추던 커서 깜빡임 복구.

## v2026.7.22 — OpenClaw 7.1 + 디스크 정리 루틴 + tmux 작업면

### Added
- **`scripts/diskclean.sh` — 디바이스 인식 디스크 정리 루틴** — thinkpad 실측 396G → 305G(**91G 회수**). 프로파일은 `~/.current-device`로 갈린다: oracle은 headless + OpenClaw 런타임이라 GC 보존 14일에 휴지통·브라우저·repo 캐시 단계를 건너뛰고, nuc/laptop/thinkpad는 그 반대. **핵심은 순서** — `.direnv`/`result`가 GC root라 flake input을 붙들고 있으므로 repo 빌드 캐시를 **GC보다 먼저(0단계)** 지운다. 자동 GC가 이미 돈 직후였는데도 이 순서만으로 **19.9GiB가 추가 회수**됐다. 회수량의 대부분은 애초에 nix 밖이다(uv 16.7G·zig-cache 11G·Trash 6.3G·`/tmp` 3.8G). pnpm(repo `node_modules`와 하드링크 공유)·docker(oracle에선 OpenClaw 런타임)는 opt-in. `run.sh c)`(safe)/`C)`(deep) 연결, 개념·순서 근거는 AGENTS.md §2.6.
- **tmux 작업면 — 디바이스 배지 + 창 이동 + 세션 fzf** — `status-left` 맨 왼쪽에 `~/.current-device` 배지를 두고 디바이스별로 색까지 가른다(oracle 주황 / nuc 파랑 / laptop 초록 / thinkpad 보라). hostname이 아니라 `.current-device`가 SSOT — `run.sh`·`diskclean.sh`가 프로파일을 고르는 그 값과 같아야 상태바와 실제 동작이 안 갈라진다. `status-left-length`가 tmux 기본 10이라 `#H`가 이미 잘려 있던 것도 함께 수정. `M-[`/`M-]`로 창 이동(ESC `[`=CSI, ESC `]`=OSC라 위험한 조합이지만 pty로 raw 바이트 실측: `\033[`만 오면 키로 처리되고 `\033[A`·`\033[1;5D`는 CSI 파싱이 먼저 이겨 방향키를 삼키지 않는다). `prefix + s`는 세션 fzf 팝업, 기본 `choose-tree`는 `prefix + S`로 보존. `KEYBINDINGS.md`에 tmux 면 신설 — 층위(세션/창/분할) 혼동 방지표를 맨 앞에 두고, 표의 키는 전부 `list-keys`로 대조한 것만.
- **`ax.junghanacs.com` 정적 vhost + 액세스 로그** — caddy 첫 `file_server` 사이트(`/srv/ax` ← `~/docker-data/ax` ro). 이어서 `log { output stderr; format json }` 활성화 — dossier 정체성이 "검증 가능한 증거"인데 방문 기록이 없던 상태(caddy 기본값 off) 해소. Umami는 JS라 크롤러/에이전트를 못 잡으므로 서버 로그가 유일한 관측면. stderr → 컨테이너 log driver가 journald라 회전/보존을 journald가 맡아 compose 무변경(`docker restart caddy`만으로 반영). 7-세트 검수 통과.
- **obsidian — GUI 디바이스 전용** (oracle headless 제외).
- **thinkpad 방화벽 개방** — 8883(SK 테스트베드 MQTT/TLS), 18080(앱↔서버 REST).

### Changed
- **OpenClaw 6.11 → 2026.7.1 업그레이드 + GPT-5.6 승격** — 6봇 전수 GREEN, boot WARN 0, 모델 드리프트 0, 메모리 4096d 정상. gpt → `openai/gpt-5.6-sol`, glg(가족) → `openai/gpt-5.6-terra`(둘 다 격리 probe → 라이브 primary 턴 `fallbackUsed=false` 2단 검증). 단가상 인상이 아니다 — sol은 5.5와 동일($5/$30), terra는 절반($2.50/$15).
- **glg 가족봇 → Sonnet 5 + 대칭 "정직한 거울" 규칙** — terra가 각 DM에서 화자 프레임을 승인(사이코팬시)해 양쪽을 각자 옳다고 세워주던 **"두 에코챔버"** 문제. 모델 스왑만으로는 안 풀려 **USER.md 대칭 규칙이 핵심 방어**. 정한·미례 동일 모델로 낙하(정한 세션의 `gpt-5.6-sol` user 핀을 `sessions.json`에서 직접 제거 — `/reset`·`/new`로는 안 풀린다).
- **bbot → fable-5 재승격, mini → sonnet-5 승격** (6.11 서빙 재개).
- **gog를 `openclaw/gogcli` 공개 정적 릴리즈로 전환** — `go install` 빌드에서 벗어남. 앞선 심볼릭 단일화(마스터 2벌 + SSOT 절대경로 심볼릭 6개)로 300M → 75M.
- **openclaw memory 운영 노하우 문서화** — restart/recreate 구분 + prewarm.

### Fixed
- **OpenClaw 컨테이너 `TZ=Asia/Seoul` — 봇의 '지금'이 UTC였다.**
- **pnpm `global-bin-dir` PATH 가드 + check 거짓 성공 제거** — pnpm은 `global-bin-dir`이 PATH에 없으면 `add -g`/`list -g`를 전부 거부한다. 레지스트리/캐시 문제로 보이지만 원인은 PATH다. `external-packages.sh`가 preflight로 진단하도록.
- **pnpm 설치 실패 시 캐시 재시도 + 패키지별 폴백.**
- **tmux `default-shell` 고정** — 지정하지 않으면 tmux는 서버가 처음 뜨는 순간의 `$SHELL`을 전역 옵션으로 굳힌다. nix devshell 안에서 서버가 태어나면 readline 없는 빌드용 bash가 박혀 그 서버의 모든 pane이 bind/complete 없는 셸을 받았다.
- **tmux — ghostty가 삼키던 `M-u`/`M-v`를 copy-mode 반쪽 스크롤로 회수** (doom의 `evil-scroll-up`/`down` 방향에 맞춤).
- **i3 scratchpad-toggle 새 창 감지를 focus → window-id diff로 전환.**
- **geworfen docker-compose store path를 26.05 세대로 갱신.**
- **문서 정정 2건** — GPT-5.6 승격은 비용 인상이 아니었다(비용축 정정), 모델 승격이 안 먹는 진짜 이유는 `/reset`이 user 핀을 못 푼다는 것.

### Removed
- **미사용 `.beads` 트래킹 제거.**

## v2026.7.2 — NixOS 25.11 → 26.05 이관

### Changed
- **NixOS 25.11(EOL 2026-06-30) → 26.05 "Yarara" 이관** — `nixpkgs`·home-manager `release-26.05` bump. 안전 순서로 진행: thinkpad switch+재부팅 선검증(x86 canary) → oracle `nixos-rebuild build .#oracle`(aarch64 게이트, closure `26.05.20260630.95ca1e2`) → switch → **재부팅 콜드부팅 GREEN**(gen #59 current·#58 롤백 보존, `systemctl --failed` 0, 12컨테이너 자동복구, caddy 6-세트 서빙, openclaw 6봇 healthy·auth pre-warmed). switch-to-configuration exit 4는 dbus-broker/syncthing-init/vconsole live-reload 레이스로 양성(콜드부팅 clean 확증). laptop/nuc는 thinkpad 동일구성 + 부재라 별도 switch 불요.
- **오버레이 전면 제거 + 버전핀 이름 정리** — `overlays=[ ]`, input=nixpkgs/disko/home-manager만. `nodejs_24`/`python312` → unversioned `nodejs`/`python3`. 26.05 회귀 일괄 대응: ollama acceleration→package, neofetch→fastfetch, xorg·xfce top-level, nixfmt-classic→nixfmt, gnome/gdm 옵션 rename, neovim withRuby/withPython3/gtk4.theme legacy 고정.
- **pnpm 전역 단일화** — NixOS 소유 단일 pnpm 11.x(`manage-package-manager-versions=false` + `~/.config/pnpm/rc` global-bin-dir 고정). 흩어진 글로벌(pnpm10 global/5·.tools·orphan shim) 회수 → 정확히 SSOT 6개. `package.json` `packageManager:` 핀과의 전역 싸움 종식(반-nixos 규율).
- **패키지 통제 3층 모델 문서화**(AGENTS.md §2.5) — ① nix store(담을 수 있는 전부) ② `external-packages.sh`(nix 못 담는 것 SSOT) ③ per-repo devShell. 원칙: 복제 없음·한 창고·중앙 통제.
- **bbot fable-5 시도 → opus-4-8 환원** — 번들 claude CLI가 `claude-fable-5`를 인지하나 구독/CLI 서빙 아직 불가(응답 실패). opus-4-8로 환원, 서빙되면 GLG가 세션 `/model`로 수동 승격.

### Added
- **`scripts/external-packages.sh` — 외부 패키지 설치/버전체크 SSOT** — 목록을 run.sh에서 분리해 코드 옆 주석으로 산다. `run.sh e)/E)`는 이 스크립트만 호출. 대상: pnpm 글로벌(netlify-cli·clawhub·@steipete/summarize·@openai/codex·ts-lsp·pi) + curl harness(claude·agy) + `go install`(gog). codex는 curl 인스톨러 GitHub API rate-limit(403) 회피로 pnpm 이관.

### Removed
- **`EXTERNAL_PACKAGES.md` / `~/update-claude.sh` 폐기** — 문서→스크립트 SSOT로 일원화(문서는 썩는다). 미사용 CLI 정리: gt/bd/bv/br·CLIProxyAPI·gemini·ccr·copilot·cline·gccli/gdcli/gmcli·grammy.
- **글로벌 모델 allowlist에서 deepseek 제거 — auto-fallback 정체성 훼손 차단** — configured primary 실패 시 auto-fallback이 allowlist 첫 작동모델로 떨어지는데 `deepseek/deepseek-v4-pro`가 1번이라, bbot이 fable-5(서빙 실패) primary로 올라갔을 때 **deepseek로 응답하는 정체성 훼손** 발생. deepseek pro/flash를 `agents.defaults.models`에서 제거(참조 봇 0) → `openai/gpt-5.5`가 catch-all 1번. ORACLE.md에 "auto-fallback catch-all 함정" 박음.

### Fixed
- **picom v13 deprecated 옵션 6개 + flameshot checkForUpdates + ghostty confirm-close-surface** 26.05 정리.

## v2026.6.13

### Changed
- **OpenClaw 2026.6.5 → 6.6 업그레이드**: `docker/openclaw/Dockerfile` FROM bump (runtime SSOT는 openclaw-config repo). 보안 경계 강화 위주 patch — host env 상속/MCP stdio/sandbox bind 하드닝(emacs-agent env·소켓 주입 생존 확인) + Telegram 라우팅·스트리밍·콜백 수정 + compaction 기본 타임아웃 180s. 업글 후 `doctor --fix` 의무(SQLite auth 마이그레이션 정리), Errors 0.
- **glg 가족봇 기본 모델 5.4 → 5.5 재승격**: cross-DM 가드 완료로 강등 사유 해소 → 가족 실무 답변 품질 우선. 기본값 변경은 신규 세션부터 적용(기존 DM 세션은 저장된 model 유지).

### Added
- **ORACLE.md — gemini OAuth 스코프-403 함정**: 무응답 진단(`models status --probe`로 `insufficient authentication scopes` 식별) + device-code 재로그인 절차 + api-key(`google/`, 나노바나나 전용) 폴백 금지 경고.
- **ORACLE.md — gemini agy 이관 드리프트 운영 원칙**: `google-gemini-cli` deprecation → agy(Antigravity) 이관 진행 중. `doctor --fix`/업글이 gemini를 `google/`로 자동 재작성하는 드리프트(6.6에서 실측·되돌림)가 당분간 구조적 — 흔들리지 말고 "이관 사안"으로 인지·검토하라는 원칙 + 한시적 방어(prefix 재확인·되돌림).

## v2026.6.10

### Changed
- **OpenClaw 2026.6.1 → 6.5 업그레이드**: `docker/openclaw/Dockerfile` FROM bump. Anthropic/Codex/ACP recovery 수정 + MCP tool-result coercion + auth profiles SQLite 마이그레이션(`doctor --fix`). 모델 전부 보존, doctor Errors 0.
- **gemini 봇 ACP → 네이티브 OAuth 전환**: `pi-shell-acp` ACP route를 OpenClaw 네이티브 `google-gemini-cli/gemini-3.1-pro-preview`(OAuth, **Pro 쿼터**)로 교체. fallback 없음. provider prefix가 과금 경로를 가른다 — `google/`(api-key) 아닌 `google-gemini-cli/` 必(함정: `/status` `🔑` auth 라인이 진실, ROADMAP 기록).
- **glg 가족봇 모델 라우팅**: gpt-5.5 승격 후 **gpt-5.4 강등**(cross-DM 판단 과잉 억제) + cross-DM **원문-only 전달 규칙** 신설.

### Added
- **tmux**: ctrl-friendly copy mode.

### Removed
- **pi-shell-acp 제거**: gemini 네이티브 전환으로 사용처 0 → `plugins.entries.pi-shell-acp.enabled=false`. 이 배포에서 third-party ACP 완전 소멸.

## v2026.6.4

### Changed
- **git 커밋 귀속을 `junghan0611` GitHub 계정으로**: identity를 `hosts/*/vars.nix`의 `gitName`/`gitEmail`로 분리. OS username(`junghan`)·실메일(`junghanacs@gmail.com`)과 독립, noreply 이메일로 귀속
- **Firefox**: HTML 기본 핸들러 설정 + Doom Emacs 데스크톱 항목 이름 정리
- **openclaw Syncthing 관리 중단**: `~/repos/gh`로 이전, `.stignore`에서 전체 무시

### Removed
- **한국어 OCR 스택 철회**: tesseract/ocrmypdf/gImageReader 제거 (v2026.6.2에서 추가했으나 용량·유지보수 부담으로 되돌림)

## v2026.6.2

### Added
- **문서/OCR 데스크톱 스택**: zathura(기본 PDF 뷰어, vim 키바인딩, mupdf 백엔드) + readest·foliate(EPUB) + mupdf + libreoffice. apvlv 대체
- **한국어 OCR**: tesseract(eng+kor+osd, 전체 1.1GiB→경량) + ocrmypdf(엔진 공유) + gImageReader(GUI 프론트엔드)
- **calibre**: ebook 관리 (thinkpad)

### Changed
- **`run.sh C)` 공격적 정리**: Nix GC 7→3일 + `nix-store --optimise` + pnpm store prune + journal vacuum 200M + Docker prune 전 디바이스(oracle 전용 해제)
- **mimeapps.list 가변화**: nix store 불변 심볼릭 → 레포 out-of-store 심볼릭. Thunar 런타임 기본앱 변경 + rebuild 없이 레포 편집 즉시 반영 (pdf=zathura, epub=foliate, doc/docx/odt=libreoffice writer)

> 위 데스크톱 항목은 전부 `!isOracle` — 헤드리스 oracle 제외.

## v2026.5.31

첫 CalVer 스냅샷 — 마지막 SemVer 릴리즈(`0.3.2`, 2026-02-22) 이후 전부를 접어 넣는다.
OpenClaw 봇런타임 버전 hop(2026.2.x → 5.28)은 여기선 요약하고, 전체 운영 이력은
[ROADMAP.md](ROADMAP.md)에 있다.

### Added
- **Forge**: Oracle에 셀프호스팅 Forgejo 15 스택 (`forge.junghanacs.com`, Caddy + Postgres 16)
- **Home Assistant**: Oracle 가동 (Health Connect → lifetract 파이프라인)
- **agenda.junghanacs.com** 라이브
- **글로벌 git 안전레일**: `core.hooksPath` 훅 + gitleaks + trufflehog — 커밋/푸시 시 시크릿·식별어 차단
- **파일매니저**: Thunar(XFCE) 주력 — `programs.thunar` + `gvfs` + `tumbler`, archive/volman 플러그인 (pcmanfm 폴백 유지)
- **문서 체계**: NEXT.md(후속), ROADMAP.md(이력), 디바이스 핸드북 ORACLE.md / THINKPAD.md, MEMORY.md, openclaw-gotchas.md
- **geworfen**: Docker healthcheck + autoheal(stale emacs 소켓 자가복구), stats 데이터 마운트
- **봇멘트 인프라**: remark42 셀프호스팅 댓글 (`comments.junghanacs.com`)
- **패키지**: bun, scrcpy, qemu(pi-chat micro-VM), asciinema/gifski, ghostscript, UNIX 데이터 도구
- **thinkpad**: Ollama Vulkan 서비스 (qwen3-embedding:4b)

### Changed
- **OpenClaw**: 2026.2.x → 5.28; claude-cli native 경로 + Opus 4.8 canonical, active-memory, Qwen3-Embedding-8B 4096d (상세 → ROADMAP)
- **입력기**: kime → fcitx5 복원 (per-app group 분리, 한글 passthrough)
- **터미널**: WezTerm cell-widths / 유니코드 drift 해소, ghostty/wezterm config live symlink, 커서 색 통일(#ff4769)
- **폰트**: 시스템 + WezTerm 이모지 monochrome 전환
- **AGENTS.md**: 멀티디바이스 operator brief로 재구조화 후 슬림화 (이력 → ROADMAP)
- **Emacs**: 소켓 분리(user=GUI / server=agent), 데스크탑 호스트 emacs-gtk + GTK dark
- **툴체인**: nodejs 22 → 24; flake/home-manager **nixos-25.11** 채널로 bump
- **i3/xkb**: CapsLock → Menu 매핑(Emacs 한/영 토글), Mod+e → 어디서나 emacs

### Fixed
- **shell**: pnpm v11 global bin 경로; 비대화형 SSH의 PNPM_HOME/PATH
- **oracle**: headless 프로파일 슬림화(xrdp 제거, vconsole/kmscon 비활성); NOPASSWD sudoers의 systemctl stable 경로
- **thinkpad**: Ollama 자동시작 비활성
- **브라우저**: Chrome 145 SIGTRAP → 146; microsoft-edge 144 크래시 → pinned 145
- **remark42**: Dev-auth 자기참조 DNS
- **geworfen**: Docker TZ=Asia/Seoul (KST 날짜 보정)

### Removed
- **gpu-03**: 미사용 machine scaffold 제거 (`machines/gpu-03.nix` + hardware config, flake 미등록)

## [0.3.2] - 2026-02-22

### Added
- **fortune**: `fortune` 패키지 + Kevin Kelly advice 데이터
  - `fortunes/advice/`: *Excellent Advice for Living*, 68 Bits, 99 Additional Bits
  - `~/.fortunes`로 home-manager 배포
- **OpenClaw**: Docker 환경 강화
  - 커스텀 Dockerfile: `gh` CLI, `curl`, `ripgrep`, `fd`, `jq`, `tree` 추가
  - 스킬(skills) 설치 기능 추가
  - shared rw 폴더 + 이미지/서브에이전트 설정 동기화
  - `env_file` 지원 (GROQ_API_KEY)
  - gh CLI 인증 마운트
  - IPv6 비활성화
- **Umami**: 셀프호스팅 웹 애널리틱스 추가 (`docker/umami/`)
- **peon-ping**: NixOS shebang 패치, `peon-setup` 전역 명령어, `--langs` 옵션
- **WezTerm**: 타이틀바 활성화 및 키바인딩 문서 정비

### Changed
- **Docker**: 데이터 볼륨을 `~/docker-data/`로 분리
- **tdlib**: unstable로 전환 (telega.el >= 1.8.60 요구)
- **telegram-desktop**: 비활성화 (한글 입력 불가)
- **flake.lock**: nixpkgs 최신 업데이트

### Fixed
- **OpenClaw**: 2026.2.19 → 2026.2.17 롤백 (서브에이전트 호환성 문제)
- **OpenClaw**: Telegram 멀티계정 모드 — default 계정 `accounts`에 명시 필수
- **OpenClaw**: main 에이전트 model 미설정 수정
- **microsoft-edge**: nixpkgs-pinned(144)로 고정 (빌드 실패 해결)
- **home-manager**: GLG 스크립트 파일 충돌 해결 (force=true)
- **claude-focus.sh**: ● 대기 상태 패턴 추가
- **umami**: .env 시크릿 제거, .gitignore 추가

## [0.3.1] - 2026-02-17

### Added
- **run.sh**: Oracle VM 원격 관리 메뉴 추가 (Remote 섹션)
  - `t) OpenClaw SSH 터널 시작/종료` (`ssh -N -L 18789:127.0.0.1:18789 oracle`)
  - `r) Oracle Docker 서비스 재시작` (openclaw-gateway / caddy+mattermost / 전체)
  - `s) Oracle Docker 서비스 상태` (`docker ps`)
- **OpenClaw**: Mattermost 채널 연동 (`@openclaw` 봇, `chat.junghanacs.com`)
  - Gmail SMTP 설정 (smtp.gmail.com:587 STARTTLS)
  - 방문자 초대 링크 채널
- **OpenClaw**: 멀티 에이전트 — 힣(glg) 에이전트
  - 두 번째 Telegram 봇 (`@glg_junghanacs_bot`)
  - `agents/glg/SOUL.md`, `agents/glg/IDENTITY.md` 생성
  - 디지털 가든 안내자 페르소나 (notes.junghanacs.com)
- **OpenClaw**: Control UI (대시보드) 접속 절차 문서화
  - Docker 환경 device pairing 이슈 해결: `docker exec` 방식
  - `SETUP.org` 재현 가능한 device pairing 절차 추가

### Changed
- **README/README-KO**: Docker 서비스 테이블에 Mattermost, Caddy 추가
- **README/README-KO**: run.sh Oracle 관리 단축키 안내 추가
- **docs links**: Mattermost SETUP.org 링크 추가

## [0.3.0] - 2026-02-17

### Added
- **Docker services (Oracle VM)**
  - **Remark42**: 셀프호스팅 댓글 시스템 (`comments.junghanacs.com`)
    - Let's Encrypt 자동 SSL, GitHub/Google/Telegram/Anonymous 인증
    - `docker/remark42/` — compose, 설정 가이드
  - **OpenClaw**: AI 어시스턴트 게이트웨이 (Telegram + Claude)
    - `ghcr.io/openclaw/openclaw:latest` (ARM64 multi-arch)
    - Telegram 봇으로 모바일 상시 AI 접근
    - repos/gh, repos/work, org read-only 마운트
    - boot-md, session-memory hooks 활성화
    - `docker/openclaw/` — compose, 설정 템플릿, 상세 가이드
- **Oracle VM 방화벽**: HTTP/HTTPS (80, 443) 포트 개방 (Remark42용)
- **i3**: Claude Code 창 순환 키바인딩 (Win+Tab/Shift+Tab)
- **shell**: GLG 도구 모음 NixOS 배포
- **home-manager**: `telegram-bot-api`, `telegram-desktop` 추가
- **edge-tts**: Text-to-Speech 패키지 추가

### Changed
- **README**: Docker 서비스 섹션, 문서 링크 추가 (영/한)
- **EXTERNAL_PACKAGES.md**: OpenClaw을 Docker 배포로 이전

### Fixed
- **greview**: 2단계 디렉토리 스캔 지원
- **whisper**: `/usr/bin/pass`를 `pass`로 변경 (NixOS 호환)

## [0.2.0] - 2026-02-02

### Added
- **thinkpad host** - ThinkPad P16s Gen 2 AMD 지원 추가
  - autorandr 시스템 서비스 활성화 및 수동 전환 스크립트
  - 워크스페이스-모니터 매핑 설정
  - i3 디스플레이 및 resume 개선
- **qwen-code** - Qwen AI code assistant CLI tool (from nixpkgs-unstable)

### Changed
- **i3/dunst**: 폰트명 통일 (D2Coding ligature)
- **i3status**: 모듈에 min_width 추가로 레이아웃 안정화
- **i3status**: 디스크/시간 모듈 여백 추가
- **ghostty**: copy-on-select를 clipboard로 변경
- **gpg**: pinentry-curses로 전환 (SSH 터미널 호환성)

### Fixed
- **gpg**: GPG 캐시 동작 설명 주석 추가 (nixos-rebuild 후 첫 입력 필요)
- **home-manager**: google-chrome을 aarch64-linux(Oracle)에서 제외

## [0.1.0] - 2025-11-17

### Added

#### AI CLI Tools (from nixpkgs-unstable)
- **gemini-cli** - Google Gemini CLI interface for AI-powered assistance
- **codex** - OpenAI Codex CLI for code generation and completion
- **opencode** - Open source code assistant tool
- **claude-code** - Anthropic Claude Code CLI for AI-powered development
- **claude-code-monitor** - Monitoring tool for Claude Code sessions
- **claude-code-acp** - Claude Code ACP (Agent Communication Protocol) integration
- **claude-code-router** - Routing utility for Claude Code requests

All AI CLI tools are sourced from `nixpkgs-unstable` via overlay configuration to ensure access to the latest versions.

#### Configuration Changes
- Added overlay configuration in `flake.nix` for AI CLI tools from unstable channel
- Updated user packages in `users/junghan/home-manager.nix` with AI CLI tools

### Technical Details
- **Modified files**:
  - `flake.nix` (lines 39-46): Added AI CLI tools to overlays
  - `users/junghan/home-manager.nix` (lines 71-78): Added packages to user environment
- **Channel**: nixpkgs-unstable (for latest versions)
- **Scope**: User packages (home-manager)

---

## Version History

### Version Naming Convention
- Major version (X.0.0): Significant configuration restructuring or breaking changes
- Minor version (0.X.0): New features, packages, or modules added
- Patch version (0.0.X): Bug fixes, minor tweaks, configuration updates

### Tags
- [Added] for new features, packages, or configurations
- [Changed] for changes in existing functionality
- [Deprecated] for soon-to-be removed features
- [Removed] for now removed features
- [Fixed] for any bug fixes
- [Security] for vulnerability fixes

---

## How to Use This Changelog

When making changes to the configuration:

1. **Add entry under [Unreleased]** section with appropriate tag
2. **Include date** when releasing a version
3. **Move [Unreleased] items** to a new version section when ready
4. **Update version number** following semantic versioning
5. **Commit with meaningful message** referencing the changelog

### Example Entry Format

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- Feature description with technical details
- File locations and line numbers if relevant

### Changed
- What changed and why
- Impact on existing configuration

### Fixed
- What was broken
- How it was fixed
```

---

## Previous Configurations

Notable configuration state before changelog tracking:

### NixOS Base Configuration
- **NixOS Version**: 25.11
- **Architecture Support**: x86_64-linux, aarch64-linux
- **Systems**: oracle (ARM VM), nuc (Intel NUC), laptop (Samsung NT930SBE)
- **Window Manager**: i3wm (default), GNOME (specialization)
- **Home Manager**: Integrated for user configuration

### Key Features Already Configured
- Disk management with disko
- Korean language support (input methods, fonts)
- Development environment (Python, Node.js, Emacs)
- Syncthing for file synchronization
- Tailscale for networking
- Docker for containerization
- Claude Desktop with MCP support

### Package Management
- Flake-based configuration
- Overlay system for unstable packages
- Ghostty terminal from unstable
- Comprehensive CLI tools (bat, eza, fd, ripgrep, fzf, etc.)
