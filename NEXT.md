# NEXT.md — 다음 할 일

운영 baseline은 [AGENTS.md](AGENTS.md). 후속 작업 / 미완 검증은 여기에.

작업 끝나면 항목 지우고, 새로 발견한 후속은 추가. 영속할 사실은 AGENTS.md / docs/openclaw-gotchas.md / `~/openclaw/README.md` change history로 옮긴다.

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

- [ ] **umami 붙이기** — `analytics.junghanacs.com`(umami) 이미 가동. ax용 website를 umami에 등록(tracking id 발급). **스니펫은 담당자가 정본(`apply/ax`)에 넣어 publish** — caddy 주입 금지(정본·라이브 갈림 방지, 담당자 명시 요청). caddy 측 작업은 사실상 없음(같은 호스트라 도메인 허용만 확인).
- [ ] **remark 붙이기** — `comments.junghanacs.com`(remark42) 가동. ax `record.html`에 댓글 위젯. 역시 스니펫은 정본. remark42 site-id/allowed-domain에 ax 추가 필요할 수 있음(remark42 env 확인 → `docker/remark42/`).
- [ ] ax 관련 요청은 이 레인(caddy = nixos-config)이 대응. GET-only 공개면이라 authelia 없음.

---

## OpenClaw 7.1 업글 완료 — soak 남음 (2026-07-14)

6.11 → **2026.7.1** 적용. 6봇 전수 GREEN, boot WARN 0, 모델 드리프트 0(gemini `google-gemini-cli/` 유지), 메모리 4096d 정상. **GPT-5.6 승격 실행**: gpt → `openai/gpt-5.6-sol`, glg(가족) → `openai/gpt-5.6-terra` (둘 다 격리 probe → 라이브 primary 턴 `fallbackUsed=false` 2단 검증). 상세는 `docker/openclaw/Dockerfile` 주석 + [ORACLE.md](ORACLE.md).

- [x] **glg DM의 user 핀 해제 — 완료 (2026-07-16).** 핀은 실제로 `gpt-5.6-sol`이었고, glg를 Sonnet 5로 옮기며 `sessions.json`에서 직접 제거(정한·미례 동일 primary로 낙하). 위 "glg 가족봇 = Sonnet 5" 항목 참조. (`/reset`·`/new`로는 핀이 안 풀린다는 gotcha는 유효.)
- [ ] **5.6 soak — 관찰 축은 비용이 아니라 품질.** 단가상 이번 승격은 **인상이 아니다**: sol = 5.5와 동일 단가($5/$30), terra = 5.5의 절반($2.50/$15). 즉 gpt는 같은 값에 상위 모델. 볼 것은 크레딧이 아니라 **응답 품질·지연**. 품질이 처지면 되돌릴 곳은 luna가 아니라 **sol 또는 5.5**다. **(2026-07-16 갱신: glg(가족봇)는 terra를 떠나 Sonnet 5로 이동 — terra soak 무효. 이 항목은 이제 gpt 봇 `sol`만 해당. glg 관찰은 위 "glg 가족봇 = Sonnet 5" 항목으로.)**
- [ ] **`openai/gpt-5.6-luna` 경량 lane 검토.** 5.5 대비 토큰 단가 **1/5**($1/$6) → subagents(`gpt-5.4`)·active-memory recall lane(`gpt-5.4-mini`)을 luna로 옮길지 판단. ⚠️ 단 **luna는 5.5보다 성능 우위가 보장되지 않는다**(비용/속도 최적화 티어) — "싸니까 위"가 아니므로, 옮기려면 해당 lane의 실제 작업(요약·recall)에서 품질을 먼저 확인할 것.
- [ ] **`channels.mattermost` 죽은 설정 정리.** 7.1에서 mattermost가 번들 외부화됐고 `plugins.entries.mattermost`(enabled:false)는 제거해 WARN을 껐으나, `channels.mattermost`는 **botToken을 든 채 라이브 config에 남아있다**. 안 쓸 거면 `config unset channels.mattermost`로 토큰까지 지우는 게 맞다(평문 토큰 축소 = doctor 보안 경고 축소).
- [ ] **메모리 `.migrated` 아카이브 회수 (~1.4G).** 7.1이 legacy `~/openclaw/config/memory/*.sqlite`를 per-agent SQLite로 통합하고 원본을 `.migrated`로 남겼다(glg 637M, gpt 471M, gemini 139M, bbot 112M, main 83M, mini 38M). 라이브 인덱스는 `config/agents/<id>/agent/openclaw-agent.sqlite`에서 정상 동작 확인 — **롤백 안 할 게 확실해지면 삭제 가능. 디스크 90% 상황에서 가장 싼 1.4G.**
- [ ] **orphan transcript 103건** — `~/.openclaw/agents/main/sessions`에 sessions.json이 더 이상 참조 안 하는 `.jsonl` 103개. doctor가 `*.deleted.<ts>`로 아카이브해줄 수 있으나 **`--fix`는 gemini를 깨므로 못 쓴다** → 수동 정리 또는 방치 판단.

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
- [x] **gogcli(gog) 심볼릭 단일화 — 완료 (2026-07-15, 300M→75M)**. 마스터 2벌(`~/.local/bin/gog` 호스트 + `~/openclaw/config/claude-skills/gogcli/gog` 봇 SSOT), 나머지 6개(agent-config + workspace×5) SSOT 절대경로 심볼릭. 봇/호스트 전 경로 v0.34.0 resolve + 캘린더 조회 검증. 상세·이유(오버레이 밖 SSOT, 두 마스터) → [ORACLE.md](ORACLE.md) §5 gogcli. **남은 티끌**: SKILL.md는 아직 각 디렉토리별 실파일(agent-config Jul5 upstream 15KB vs workspace/claude-skills Apr13 옛 10KB) — 작아서 공간 무관하나 내용이 갈린다. 통일하려면 SKILL.md도 SSOT 심볼릭(단 openclaw workspace 스킬 등록이 심볼릭 SKILL.md를 읽는지 확인 필요).

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

- **라이브 (authelia v4.39.20, 단일 공용 계정 `family`)**. 검증(curl): 미인증 `/`·`/v/*`·`/api/surfaces/*` → 302 authelia 리다이렉트(share_token만으론 데이터 못 뚫음), 포털 `/authelia/` 200, 봇 내부 `butler-viewer:8765/` → 200 무영향.
- **파일**: `docker/authelia/{docker-compose.yml, configuration.yml.template, users.yml.template, .gitignore, README.md}` (공개 추적) + `configuration.yml`·`users.yml` (실파일, **gitignore — 시크릿/해시 미커밋**). Caddyfile map 블록 = forward_auth 버전으로 교체됨.
- [ ] **아내가 실브라우저로 로그인 1회 확인** — curl로 리다이렉트/포털/봇경로는 검증했으나 실제 로그인 submit+쿠키+뷰어 도달은 사람 1회 필요. 계정 `family` / 비번은 GLG가 아내에게 전달.
- [ ] **커밋 대기 (GLG)** — 신규 `docker/authelia/*`(템플릿/compose/README/.gitignore) + Caddyfile 수정. 실파일 2개는 gitignore라 안 올라감.
- [ ] (나중, 불필요) 다른 서브도메인 SSO 필요 시 B안(`auth.junghanacs.com` + 쿠키 domain=junghanacs.com)으로 승격 — README "확장" 참조.
- 롤백: Caddyfile map 블록 원복 + `docker restart caddy`, authelia는 `docker compose down`.

---

## 1. pi-shell-acp 정리 — 완료, 잔재 청소만 (2026-06-10 ACP 제거)

claude-cli native(main/bbot/mini) + codex(glg/gpt) + **gemini 네이티브 `google-gemini-cli` OAuth 전환(2026-06-10)** 으로 pi-shell-acp 사용처 0 → `plugins.entries.pi-shell-acp.enabled=false`로 제거. **이 배포에 third-party ACP 없음.** 정리 사이클의 본체는 끝났고 mount 잔재 청소만 남음.

> 완료분(2026-05-26~31 자리들, **2026-06-10 gemini 네이티브 부활 + pi-shell-acp 제거**, **6.1→6.5 업그레이드**)은 [ROADMAP.md](ROADMAP.md) "운영 결정 이력"/"OpenClaw 업그레이드 이력"으로 이관. pi-shell-acp Issue #25: <https://github.com/junghan0611/pi-shell-acp/issues/25>.

### 남은 한 걸음 (ACP 잔재 청소)

- [⏸] **gemini 챗봇 DOWN — agy 연동 대기 (억지로 살리지 않는다, 2026-06-13)** — gemini 무응답은 `google-gemini-cli` OAuth의 `insufficient authentication scopes [403]`. **재로그인 시도했으나(2026-06-13, `models auth --agent main login --provider google-gemini-cli --force` 완료) probe는 여전히 403** — 발급 OAuth 스코프 자체가 OpenClaw의 Generative AI API 경로를 못 덮는다. **agy(Antigravity) 이관이 gemini-cli OAuth를 스코프 레벨에서 깬 것.** **방침(GLG): API(`google/`)로 억지로 살리지 말 것. 안 되는 대로 DOWN 유지하고 두고 본다.** 차단 해소 조건 = OpenClaw가 **agy/antigravity provider 연동**을 지원하거나 업스트림이 `google-gemini-cli` 스코프를 고칠 때. 그때 모델을 agy provider로 마이그레이션(손으로 creds 복사 아닌 공식 provider 추적 — ROADMAP 2026-06-10 forward 리스크). **근본원인 정정 (2026-06-24 규명)**: 403은 OAuth 스코프 *결함*이 아니라 **Google이 2026-05-19 I/O에서 gemini-cli → Antigravity CLI(`agy`) 전환을 발표하고, 개인티어(AI Pro/Ultra/무료 Code Assist) gemini-cli 서빙을 2026-06-18 중단**한 것 — Google이 경로 자체를 닫아 재로그인으로 안 풀린다(우리 DOWN 관찰 2026-06-13과 일치). **추적 단일 지점**: OpenClaw issue [#84527](https://github.com/openclaw/openclaw/issues/84527)(agy를 gemini-cli 대체 CLI backend로) + 구현 PR [#90975](https://github.com/openclaw/openclaw/pull/90975) `feat(google): add Antigravity CLI backend`(보조 #91473/#91474/#91477) — 둘 다 OPEN·활발(2026-06-24). agy CLI 자체는 **v1.0.5에서 Google AI Pro OAuth로 작동 검증됨**(#84527 Kirchlive: `agy --model gemini-3.1-pro-preview --print` OK). **준비 = PR #90975 머지 + OpenClaw 릴리즈 반영 모니터 → 반영 시 gemini를 agy CLI backend로 전환**(creds = agy OAuth/Google AI Pro, `gtgkjh@gmail.com` 구독 등급 선확인 + oracle 컨테이너에 `agy` 바이너리 설치 경로 확보). ⚠️ 재로그인은 config를 `google/` 드리프트시키니 시도 후 반드시 정리(절차·경계 전체는 ORACLE.md gemini 함정 블록).
  - 관찰: OpenClaw 릴리즈 노트/플러그인에 `antigravity`/`agy` provider 등장 여부 주시. 등장 시 이 항목 재가동. **6.8(2026-06-17) 체크 = 미등장** — doctor가 gemini를 `google/`로 또 드리프트시켜 되돌림(6.6에 이어 반복). 베이스라인 `google-gemini-cli/` 유지, 403 DOWN 그대로. **6.9(2026-06-22) 체크 = 여전히 미등장. 단 이번엔 `doctor --fix`를 안 돌려 gemini 드리프트 0** — `google-gemini-cli/` 그대로(403 DOWN). doctor --fix가 드리프트의 원인임이 역으로 확정됨 → 업글 시 `doctor --fix` 미사용이 gemini 보존에 유리. **6.10(2026-06-24) 체크 = agy backend 아직 미머지·미릴리즈** (자동봇 clawsweeper가 #84527에 "v2026.6.10 still exposes only the local `google-gemini-cli` backend" 명시). plugins 80개 중 antigravity/agy provider 0, `@openclaw/google-plugin`(stock)만 존재. 드리프트 0 유지. ※ 6.10 read-only doctor가 gemini를 `google/` 금지경로로 더 이상 안 미는 건 agy 지원 신호가 아니라 **PR #28081(doctor가 죽은 `google-antigravity-auth` 엔트리 auto-prune) 계열 정비**일 뿐 — 위 [⏸] 항목의 #90975/#84527가 실제 추적 지점. 다음 사이클에 PR #90975 머지 여부 + plugins 목록 재확인.
- [ ] **compose mount 정리** — gemini가 마지막 ACP 사용처였다. `docker-compose.yml`의 ACP 전용 mount(`~/.pi/agent`, `~/.claude-plugin/skills` 등)가 남아있으면 제거(이제 unblocked). 단 claude-skills overlay(§ skills)와 겹치는 mount는 남김 — 헷갈리지 말 것.
- [x] **pi-shell-acp 엔트리 최종 거취 — 2026-06-22(6.9) 완전 제거.** ~~present + `enabled:false` 영구 유지~~ → **6.9 strict plugin discovery가 죽은 `plugins.load.paths`(pi-shell-acp 경로)를 startup hard-fail로 거부해 crash loop** 발생 → `plugins.load.paths` + `plugins.entries.pi-shell-acp` + `plugins.allow` 전부 제거. **옛 "엔트리 삭제 = 기본 로드 복귀" 함정(2026-06-10)은 6.9에서 무효** — provider 외부화로 pi-shell-acp가 번들에서 완전히 사라져 default-load할 대상 자체가 없음(제거 후 clean boot·warnings 0 확인). workspace-gemini는 네이티브 gemini가 씀, 유지.
- [ ] **#27 moot 확인** — gemini ACP 빈응답(#27)은 네이티브 전환으로 **우리 운영상 해소**. 이슈 자체는 pi-shell-acp repo에서만 추적. #25 분석은 별건.
- [~] **bbot turn soak GREEN / Telegram ingress follow-up** — 2026-06-29 무응답 사건: claude-cli/OAuth/session은 정상(probe ok, direct session 3.5s ok), root cause는 bbot isolated polling ingress 유령 connected. 컨테이너 런타임 핫패치로 bbot만 standard polling 전환 후 살아남. **후속**: 핫패치는 recreate/image rebuild 시 사라지므로 Dockerfile/entrypoint patch 또는 upstream config toggle로 영구화할지 결정. 상세는 `docs/openclaw-gotchas.md`.
- [ ] **gemini Pro 쿼터 soak** — `usage: Pro/Flash 100% left`에서 실사용 시 소진 곡선 관찰. fallback 없으니 쿼터 소진=무응답, `Week % left` 주시.
- [ ] **이미지생성(나노바나나) `GEMINI_API_KEY` 경로 미재검증** — gemini 챗봇이 `google-gemini-cli/` OAuth로 전환된 뒤, `GEMINI_API_KEY`(`google` api-key provider) 기반 이미지생성이 여전히 동작하는지 확인. 두 provider가 분리돼 무관할 가능성 큼(추정). **실제 이미지 호출 1회로 검증 전까지 단정 금지.** (`auth.order.google` 핀은 cross-provider라 안 먹어 제거됨 — 자세한 건 ROADMAP 2026-06-10 함정 항목)
- [ ] **(보류) telega 리치 지원 매트릭스 (T01~T15)** — 2026-06-22 richMessages 전 6봇 글로벌 ON 했다가 **당일 OFF로 되돌림**(telega가 rich message를 "unsupported"로 가려 **봇 대화 복사 불가** → 소통 워크플로 단절. GLG 결정: "핵심은 rich가 아니라 소통"). **baseline = OFF 확정.** 따라서 매트릭스 추적은 더 이상 active task 아님 — **richMessages 재활성을 검토할 때만** 선결조건으로 부활시킨다. 그때는 main 봇 T01~T15(헤딩/표/details/풀쿼트/divider/sup·sub/mark/spoiler/list/task-list/code/footnote/formula/link) 격리 테스트 → telega에서 정상/폴백/unsupported 3분류 → TOOLS.md + doomemacs-config 패치. 현재는 호환모드(굵게/기울임/링크/코드/스포일러/블록인용)만으로 충분.

---

## 2. 버전 hop 후속 측정 (다음 세션)

### ✅ 6.10 → 6.11 업그레이드 완료 (2026-07-01)

릴리즈 [v2026.6.11](https://github.com/openclaw/openclaw/releases/tag/v2026.6.11)(2026-06-30) = 순수 신뢰성/버그픽스. **idle 창(턴 0) 확인 후 `docker compose down` → Dockerfile bump → 재빌드 → up.** 검증: 버전 2026.6.11, claude-cli(main/bbot/mini) GREEN(bbot 라이브 턴), codex(glg/gpt) OK(openai expires 10d·usable), gemini 403 DOWN(예상), memory 4096d, 6봇 prefix 유지(gemini `google-gemini-cli/`·**google/ 드리프트 0** — read-only doctor만), fallbacks 전부 `[]`. 디스크 82%→77%(캐시 3.3GB 회수), 이미지 2.68→2.05GB.

- **⚠️ node-gyp hang 규명(신규 함정, gotchas 기록됨)**: 재빌드가 `npm install -g` node-gyp에서 9분+ hang. 범인 = **`@google/gemini-cli` 0.49.0**(transitive `@github/keytar`+`node-pty` native, aarch64 buildkit). → **Dockerfile npm 줄에서 3개 제거**: pi-coding-agent+codex-acp(ACP 폐기로 unused) + gemini-cli(gemini DOWN·안 쫓음+범인). `@anthropic-ai/claude-code`만 남김(native 0). 양쪽 Dockerfile 동기.
- [ ] **gemini 부활(agy) 시 `@google/gemini-cli` 복원** — 그땐 `libsecret-dev` 등 build deps 추가 필요할 수 있음(keytar/node-pty 컴파일). 위 [⏸] agy 추적 항목과 연동.
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
- [ ] **6.1 state SQLite 통합 안정성** — plugin/task/telegram state가 shared SQLite로 이관됨(legacy `.migrated` archive). 며칠 후 `.migrated` 잔재 정리 가능 여부 + sqlite 통합 후 telegram dedupe/offset 정상 동작 확인.
- [ ] **subagent bootstrap context 축소 (#85283)** — active-memory recall sub-agent (5.4-mini lane) `status=empty` 비율 변화. 14d soak baseline 비교
- [ ] **`@anthropic-ai/claude-code` 버전 추적** — 5.27 image 재빌드 후 컨테이너 `claude` 2.1.156 (5.22 시점 2.1.150). `--help`에 `claude-opus-4-8` 명시 → opus 4.8 지원. Dockerfile pin 여부 검토
- [ ] **OAuth refresh 자동 검증** — Anthropic `expiresAt` 8h마다 새로 받는지 24h 관찰
- [ ] **active-memory 35s timeout 빈도** — claude-cli 환경에서 mini lane recall이 30~35s까지 늘어남 (직전 baseline 5-10s). subagent context 축소와 연관 가능. **2026-06-13 bbot 제외**(24h 16회 중 timeout 8 / ok 8, ok도 23~30s — 본 턴과 겹쳐 응답성 저해)로 가족·bbot 라인은 닫음. **근본(gpt-5.4-mini lane이 23~35s·절반 `stopReason=missing`)은 main/gpt에 잔존** — 5.4-mini 퇴화/모델 교체 검토 필요

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
- [ ] **zmx — entwurf 설치면 계약 우선, 재도입 보류** — 제외 사유 "zig15 ↔ 26.05 zig16 충돌"은 **실측 결과 기우로 확인**(zmx flake는 zig2nix로 자기 zig 툴체인 격리 → 시스템 zig 무관, 26.05에서 깨끗이 빌드됨). 재도입 자체는 보류: zmx 확보 책임은 **entwurf 설치면(하네스-중립)**에 있고, nixos-config가 먼저 깔면 entwurf가 "zmx는 PATH에 있다"를 우연히 만족된 채 개발 → 자립성 미검증 결합. 계약은 [entwurf #47](https://github.com/junghan0611/entwurf/issues/47#issuecomment-4888633470)로 넘김(probe/optional + upstream prebuilt self-fetch). nixos-config의 zmx 설치는 그 뒤 **순수 개인 편의**(택하면 B 방식 = home-manager 한 줄, 오버레이 자리 재개방 불필요).
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
