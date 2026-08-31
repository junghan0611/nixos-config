# NEXT.md — 다음 할 일

운영 baseline은 [AGENTS.md](AGENTS.md). 후속 작업 / 미완 검증은 여기에. 닫힌 항목은 [CHANGELOG.md](CHANGELOG.md)로 흘려보낸다 — 최근 스냅샷 `v2026.8.31`.

작업 끝나면 항목 지우고, 새로 발견한 후속은 추가. 영속할 사실은 AGENTS.md / docs/openclaw-gotchas.md / `~/openclaw/README.md` change history로 옮긴다.

---

## 🟡 OpenClaw 8.1 컷오버 완료 — soak + 후속 (2026-08-31 21:15 KST)

**라이브 = `2026.8.1` (ea80657), healthy.** 컷오버 경위·3층 검수 결과·폐기된 반사신경 3건은 [CHANGELOG.md](CHANGELOG.md) `v2026.8.31`로 이관했다. 11겹 함정표·재현 절차는 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md), 버전 이력은 [ROADMAP.md](ROADMAP.md). 여기는 **남은 것만**.

증거 사슬: `~/openclaw/backups/pre-8.1-cutover-20260831T203708/` (cold 백업 1.8G + gate4~16 stdout/stderr/status + `ROLLBACK.sh`).

- [ ] **24h soak** — 6봇 응답성, memory_search 콜드, cron/heartbeat 발송 대상(8.1이 owner DM 기본으로 바꿈, #121988), telegram 렌더 복사 가능성(telega).
- [ ] **ORACLE.md 재작성** — 8.1로 사실이 바뀐 자리들. ① `doctor --fix 금지`(:265,:280) → **8.1에선 필수 절차**로 성격이 바뀌었다(단 gemini는 이미 Copilot 레일이라 겨눌 대상 없음). ② config 키 이름: `agents.list`→`agents.entries`, `agents.defaults.memorySearch`→`memory.search`, `tools.exec.security/ask`→`tools.exec.mode`, catch-all 규율은 `agents.defaults.models` 키 순서 → **`agents.defaults.modelPolicy.allow` 배열 순서**. ③ 런타임 지형표에서 codex 행 삭제(=2026-08-07 GLG 결정이 이번에 완결됨). ④ `agents.ownership=explicit` + `bindings` 6개 명시가 새 baseline.
- [ ] **issue #7 닫기** — 결과/receipt 코멘트 달고 close.
- [ ] **레거시 잔재 청소 (비긴급)** — `config/agents/*/sessions/*.migrated` 다수 + `sessions.json.bak*`. 마이그레이션이 남긴 원본이라 soak 통과 후 지운다. `backups/…/isolated-orphans/telegram-deepseek-allowFrom.json`도 그때 판단.
- **오해 방지 3건 (정상이다)**: ① boot 라인이 `11 plugins`인데 `plugins list`는 `12/66 enabled` — 차이는 `google`이고 8.1이 provider를 **lazy-load**한다(설치·enabled 상태 정상, `stock:google/index.js`). ② `AgentSelectionRequiredError`는 `--agent` 없이 CLI를 친 **내 호출** 탓이지 봇 문제가 아니다(ownership=explicit의 정상 동작). ③ telegram `menu text exceeded … 5700-character budget` — 명령 101개라 설명만 줄인다, 기능 영향 없음.
- [ ] **⚠️ 백업 범위 정직하게 — 내 컷오버 백업에는 트랜스크립트가 없다.** `pre-8.1-cutover-20260831T203708/`(1.8G)은 *마이그레이션 대상*(agent/state/plugin-state sqlite, cron, tasks, openclaw.json, sessions.json)만 담았다 — `.jsonl` **0개**(실측). 트랜스크립트를 든 pre-8.1 스냅샷은 **형제가 19:06에 뜬 `pre-8.1-20260831T190622/config-state-cold.tar.zst`(837M, main만 `.jsonl` 276개)** 쪽이다. 즉 **두 디렉터리가 합쳐져야 온전한 롤백면**이다 — soak 통과 전에는 둘 다 지우지 말 것.
- [ ] **디스크 회수 (soak 통과 후)** — `/home` 82% (18G 여유). `~/openclaw/upgrade-lab/` **8.2G**가 최대 회수원, 그다음이 후보 이미지 태그 3개(`8.1-candidate`/`candidate2`/`candidate3`)와 위 백업 2.7G. 롤백면(`7.1-rollback` 이미지 + 백업 2종)은 **soak 끝날 때까지 유지**.
- [ ] **별건 2개 (업그레이드 이전부터 있던 간극)**: bbot workspace에 skills 미배포(`run.sh k)` 재실행 필요) / bbot·mini `IDENTITY.md` 형식이 달라 `agents list`에 Identity 줄이 안 뜬다(봇 본인은 자기 정체성을 정확히 안다 — 실턴으로 확인).

---

## 🔴 재부팅 부팅 순서 레이스 — caddy는 막았고 emacs는 안 막았다 (2026-08-16)

커널 `7.1.2 → 7.1.4` 재부팅(04:49 KST)이 **독립된 부팅 레이스 두 개**를 동시에 터뜨려 `junghanacs.com` 서브도메인 전부가 5시간 죽었다. 둘 다 "docker가 다른 무엇보다 먼저 뜨느냐"에 결과가 갈리는 같은 모양이다. 복구는 끝났고(전 vhost 200), **재발 방지가 절반만 됐다**.

**① caddy 443 선점 — 영구 수정 완료.** 경위(tailnet 443 선점 → caddy `exit 128` → 5시간 무응답)와 조치(enp0s6 NIC `10.0.0.157` 바인딩)는 [CHANGELOG.md](CHANGELOG.md) `v2026.8.31`. 이 자리에 남은 건 아래 하드코딩·근본 판단 둘뿐이다.

**② geworfen/agenda — 미해결.** docker가 호스트 emacs보다 먼저 떠서 마운트 소스 `/run/user/1000/emacs`를 **root 소유로 생성** → `agent-emacs.service`가 *"is not a safe directory because it is not owned by you"*로 기동 실패 → `server` 소켓 부재 → geworfen healthcheck 영구 실패 → autoheal이 2.5분마다 재시작(5시간 약 120회). 수동 복구는 emacs·geworfen 정지 → root 소유 dir `rmdir` → `agent-emacs`+`emacs` 기동 → geworfen `--force-recreate`. **다음 재부팅에 docker가 또 이기면 그대로 재발한다.**

- [ ] **emacs 소켓 dir 레이스 항구 차단 (①의 짝, 이게 남은 본체).** 후보 셋: ⓐ `agent-emacs.service`에 `ExecStartPre`로 `/run/user/1000/emacs` 소유자 검사 후 root 소유면 `rmdir`, ⓑ geworfen 컨테이너 시작을 emacs 유닛 뒤로 미룸(`restart: unless-stopped`라 docker가 부팅 시 자력 기동 — systemd drop-in으로 순서 강제 필요), ⓒ systemd-tmpfiles로 부팅 시 junghan 소유 선점. ⓐ가 제일 싸고 국소적 — **GLG 판단 필요.**
- [ ] **`10.0.0.157` 하드코딩 — DHCP가 IP를 바꾸면 caddy가 안 뜬다.** 오라클 VM은 `default via 10.0.0.1 dev enp0s6 proto dhcp`라 리스 갱신에서 주소가 바뀔 여지가 있다(현재까지 고정으로 관측). 정공법은 NixOS에서 enp0s6 static IP 선언 또는 compose를 생성하는 얇은 래퍼. 지금은 **주소가 바뀌면 caddy가 조용히 죽는 구조**라는 걸 알고 두는 상태.
- [ ] **근본 판단 — tailscale serve 443을 계속 쓸 것인가.** 지금은 "NIC 바인딩으로 비켜간" 상태지 충돌을 없앤 게 아니다. OpenClaw tailnet 레인을 `--https=8443`으로 옮기면 caddy가 `0.0.0.0`을 되찾지만 페어링 URL이 바뀐다. 안 옮기면 443이 두 주인을 가진 채로 남는다.
- [ ] **재부팅 후 점검 체크리스트가 없다.** 이번엔 GLG가 "ax 안 들어가진다"로 발견했다 — 5시간 뒤였다. `run.sh`에 부팅 후 자가진단(전 vhost 8-세트 + 컨테이너 Up + emacs 소켓 2개) 항목을 넣을지 판단. `docs/openclaw-gotchas.md` "caddy 변경 = 8-세트 검수"의 부팅판.
- [ ] **gotchas 박제** — 위 두 레이스를 `docs/openclaw-gotchas.md`에 영속화. 현재 caddy 항목은 *Caddyfile 편집* 함정만 담고 **부팅 시 포트 선점**은 없다.
- 봇은 무사했다: 텔레그램 6채널이 **폴링**이라 caddy와 무관하게 5시간 내내 연결 유지(`channels status --probe` 전부 `works`), heartbeat 30분 주기 정상, 08:00 cron 음성 발송 성공. 죽은 건 `claw` Control UI 공개면뿐.
- [ ] **6봇 memory 인덱스 전부 `Dirty: yes`.** 재부팅 + 5시간치 세션 누적분. 콜드 `memory_search` 15s 하드타임아웃 방어의 1차선이 인덱스 정합이므로(`.claude/skills/nixos-config` §5) 재인덱싱 판단 필요. dims 4096 정상, `Sources: memory, sessions` 정상.
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
