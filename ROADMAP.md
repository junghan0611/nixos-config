# ROADMAP — nixos-config / OpenClaw 운영 이력

> 이 파일은 **버전·업그레이드·운영 결정 이력의 SSOT**. 지나간 사건 기록은 AGENTS.md에 흩지 않고 여기에 모은다.
> AGENTS.md는 *현재 운영 상태*만, NEXT.md는 *다음 할 일*만, 이 파일은 *어떻게 여기까지 왔는가*를 답한다.
>
> 관련:
> - [AGENTS.md](AGENTS.md) — 현재 운영 상태 / 정체성 / 책임 경계
> - [NEXT.md](NEXT.md) — 다음 손에 잡힌 단계 (휘발성 후속)
> - [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) — 함정 카탈로그 (활성/비활성/역사)

---

## North Star — 이 repo는 무엇인가

멀티 디바이스 NixOS 저장소(`oracle` / `nuc` / `laptop` / `thinkpad`)이자, **Oracle 클라우드 VM 위 OpenClaw 봇 런타임의 운영 mother repo**.

- 호스트는 단단하게, Docker는 교체 가능한 런타임으로.
- 가족이 쓰는 봇(glg)이 끊기지 않게 — Oracle 작업은 서비스 신뢰성 작업이다.
- 예산 사고(과거 10만원 Gemini 임베딩 폭탄)는 컨테이너 안이 아니라 호스트 키 수명주기에서 차단.
- 운영 실패는 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md)에, 버전·결정 이력은 이 파일에 기록해 다음 세션이 반복하지 않게.

---

## 현재 위치 — `v2026.7.2`

`v2026.5.31`(첫 CalVer) 이후 `v2026.6.2`·`v2026.6.4`·`v2026.6.10`·`v2026.6.13`을 거쳐 현재. 이번 스냅샷의 큰 줄기: **NixOS 25.11(EOL 2026-06-30) → 26.05 "Yarara" 디바이스 베이스 이관** — 오버레이 대청소 + pnpm 전역 단일화 + 외부패키지 `scripts/external-packages.sh` SSOT화 + 패키지 통제 3층 모델(AGENTS.md §2.5). 안전 순서로 완료: thinkpad(x86 canary) switch+재부팅 → oracle `nixos-rebuild build .#oracle`(aarch64 게이트, closure 선실체화) → switch → **재부팅 콜드부팅 GREEN**(gen #59 current·#58 25.11 롤백 보존, `systemctl --failed` 0, 12컨테이너 자동복구, caddy 6-세트 서빙, openclaw 6봇 healthy). 변경 목록은 [CHANGELOG.md](CHANGELOG.md), 다음 할 일은 [NEXT.md](NEXT.md). 봇 런타임 이력은 아래.

**인프라 형상**
- **디바이스 4종**: `oracle`(aarch64 클라우드 VM, headless, 봇 런타임) / `nuc`(home server) / `laptop`(Samsung NT930SBE) / `thinkpad`(work GUI). i3는 oracle 제외 GUI 디바이스에만, oracle은 headless 프로파일.
- **Docker 스택 (Oracle, 설정값까지 공개)**: openclaw · forge · caddy · remark42 · homeassistant · geworfen · umami · autoheal (+ 비활성 mattermost/synapse). nixos-config 커스텀만으로 이 oracle 형상을 재현 가능 — 반년+ 담금질한 공개 인프라.
- **NixOS 채널**: `nixos-26.05` "Yarara" + home-manager 26.05 (stateVersion 25.05 고정 — 최초 설치 마커, 올리지 않음). **v2026.7.2에서 25.11→26.05 이관 완료**(25.11 EOL 2026-06-30 전). 오버레이 제거로 input = nixpkgs/disko/home-manager만. oracle은 `build .#oracle` 게이트 후 switch·재부팅까지 검증.

**봇 런타임 요약**
- OpenClaw **2026.6.11**, healthy t+20s, config warnings 0 (provider 외부화 baseline 유지, fast-mode 신기능 디폴트 수용).
- main `anthropic/claude-opus-4-8`, **bbot `claude-fable-5`(2026-07-12 재승격), mini `claude-sonnet-5`(2026-07-12)** — claude-cli runtime canonical, per-agent auth inherit.
- 전 봇 OpenClaw 네이티브 provider/runtime — **ACP 제거 완료**(2026-06-10, gemini→`google` google-gemini-cli OAuth). third-party ACP 의존 0.

**문서·릴리즈 체계**
- AGENTS.md(현재 상태) / NEXT.md(다음) / ROADMAP.md(이력·서사) / CHANGELOG.md(무엇이 바뀌었나, CalVer) + 디바이스 핸드북 ORACLE.md·THINKPAD.md + docs/openclaw-gotchas.md(함정).
- 릴리즈: agent-config `tag-release` 스킬(CalVer `vYYYY.M.D`) + `commit` 스킬(daily loop). `v2026.5.31`이 첫 적용.

---

## OpenClaw 업그레이드 이력

> 절차 / 검증 / 함정은 사이클별로 박는다. 활성 함정은 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md)로 승격된다.

### 2026.6.10 (2026-06-24, GREEN)

6.9 다음 stable **한 칸** — 유지보수·견고화 patch (250 commits, 대부분 CI/test/`chore(deadcode)`/crabbox·parallels 빌드 격리, 운영 영향 4그룹뿐). 방침(GLG) 동일: **gemini-cli 안 쫓음**(403 DOWN 유지), **claude-cli + codex 서빙 유지가 목표**, **`doctor --fix` 미사용**(read-only `doctor`만, surgical `config set/unset`). Docker 절차: `~/openclaw/Dockerfile` `FROM ...:2026.6.9 → :2026.6.10`(runtime SSOT = openclaw-config repo, nixos-config `docker/openclaw/Dockerfile` 미러 동기) + `docker compose build --pull && up -d --force-recreate`. codex plugin stock 자동 6.10. 빌드 전 디스크 85%(15G) → builder prune로 build cache 3.4G 회수 **80%(20G)**.

**무엇이 바뀌나 — 운영 영향 4그룹** (Breaking 없음, 릴리즈 노트 명시 + compare에 schema/migration breaking commit 부재):
- ① **Fast mode for conversations** (유일한 사용자 가시 신기능): 짧은 대화 턴은 fast mode, 긴 런은 normal 복귀. codex/claude-cli/ACP 전반에서 retries·fallback·progress event에 fast-mode state 유지 + Codex service-tier clear & auto fast status 렌더. **config 키 0** — 6.10 디폴트 수용(런타임 자동 발현, 드리프트 없음).
- ② **hook registry trusted-policy 보존** (#94545): `before_tool_call`이 composed live plugin registry를 일관 사용 — approval workflow용. 우리 approval 비활성이라 영향 적음. + codex projected-context-after-hooks 견고화 다수.
- ③ **provider plugin registry refresh after setup installs** (#95792): first-time onboarding에서 외부 provider(deepseek/groq/cerebras) 설치 후 stale registry로 auth가 끊기던 것 fix. 우리 onboarding 안 함 → 직접 무관, deepseek 부활 시 `plugins install` 흐름에 도움.
- ④ **cron delivery awareness for target sessions** (#93580) + 채널 전환 시 stale channel-origin 누수 차단. cron 쓰면 순이득.
- 비해당: Zai GLM-5.2 reasoning levels / StepFun ClawHub / Gemini schema deadcode 제거.

**gemini 드리프트 0 — `doctor --fix` 미사용 효과 (6.9 패턴 유지)**: read-only doctor가 gemini 마이그레이션을 *제안*만 하고 미적용. 단 이번 6.10 doctor 제안은 6.6/6.8의 `google/`(api-key 금지경로) 재작성과 **달리** "canonical provider refs + **google-gemini-cli runtime 선택**" 방향 — 우리 baseline(`google-gemini-cli/`)과 정합. 그래도 `--fix` 안 했으므로 현 상태 그대로 유지(403 DOWN, agy 이관 대기).

**검증**: `OpenClaw 2026.6.10`, healthy(t+20s), **config warnings 0**(non-loopback bind 경고만 — LAN bind 의도·상시·무해). 모델 6봇 drift 0: main/bbot `claude-opus-4-8`, mini `sonnet-4-6`, glg/gpt `gpt-5.5`, gemini `google-gemini-cli/gemini-3.1-pro-preview`(403 DOWN). probe: `anthropic/claude-opus-4-8`(claude-cli OAuth) **ok·6s** / `claude-cli/claude-opus-4-6 ok·2.7s` / codex `openai via codex status=usable`(anthropic usage 5h 81%·Week 77% 여유) / gemini `google-gemini-cli/...` auth→**403 insufficient scopes**(예상된 DOWN) — **claude+codex 서빙 라이브 확인**. telegram→agent end-to-end는 oracle libtdjson 부재로 GUI 측 GLG ping으로 확인. 백업: `config/openclaw.json.bak-pre610-20260624T151838`. 롤백: Dockerfile FROM 6.9 환원(주석 보존) + rebuild·recreate.

### 2026.6.9 (2026-06-22, GREEN)

6.8 다음 stable **한 칸** — 유지보수·견고화 patch. 방침(GLG): **gemini-cli 안 쫓음**(403 DOWN 유지 수용), **claude-cli + codex 서빙 유지가 목표**, **`doctor --fix` 미사용**(설정 통째 재작성 위험 — read-only `doctor`만 보고 surgical `config set/unset`). Docker 절차: `~/openclaw/Dockerfile` `FROM ...:2026.6.8 → :2026.6.9`(runtime SSOT = openclaw-config repo, nixos-config `docker/openclaw/Dockerfile` 미러 동기) + `docker compose build --pull && up -d --force-recreate`. codex plugin stock 자동 6.9. 빌드 전 디스크 97%(3.7G) → builder/dangling prune로 **78%(21G)** 확보(빌드캐시 9.7G 회수).

**⚠️ Breaking — strict plugin discovery crash loop (봇 다운 → 고침)**: 6.9의 "Gateway plugin discovery at startup"이 startup에서 plugin path를 **strict 검증** → 죽은 `plugins.load.paths`(`.../pi-shell-acp/plugins/openclaw`, 존재 X)를 **hard-fail**로 거부하며 게이트웨이 crash loop(가족봇 다운). 6.8까지는 경고였던 게 6.9에서 치명. `doctor --fix` 없이 죽은 path만 surgical 제거(`plugins.load.paths: []`, 엔트리는 disabled 유지) → restart 복구. **업글 전 `plugins.load.paths` 죽은 경로 선제 점검**이 교훈.

**Provider 외부화 정리 (Standalone official provider plugins)**: 6.9가 perplexity/discord/deepseek를 **번들 → 외부 npm 패키지**로 분리 → 미설치 "not installed" 경고. **perplexity 웹검색은 설치 안 함** — 우리 6봇은 전부 spawned-CLI 런타임이라 검색은 런타임 내장(codex=Codex Hosted Search, claude-cli=Claude WebSearch)으로 충당, OpenClaw perplexity 도구는 redundant(7일 무호출 실측). 따라서 죽은 config를 surgical 제거: `tools.web.search`(perplexity sonar) + `plugins.entries.{discord,perplexity,deepseek}` + `plugins.allow.{deepseek,perplexity}` → **config warnings 0**. deepseek 부활 시 `openclaw plugins install @openclaw/deepseek-provider` + entry/allow 재추가 필요(외부화로 절차 변경).

**gemini 드리프트 0 — `doctor --fix` 미사용의 효과**: 6.6/6.8에서 매 업글마다 `doctor --fix`가 gemini를 `google/`로 재작성하던 드리프트가, 이번엔 `doctor --fix`를 안 돌려서 **발생 안 함**. gemini는 `google-gemini-cli/gemini-3.1-pro-preview` 그대로 유지(403 DOWN, agy 이관 대기 — 안 쫓음).

**검증**: `OpenClaw 2026.6.9`, healthy(t+15s), **config warnings 0**, 13 plugins(active-memory/anthropic/browser/canvas/codex/device-pair/file-transfer/google/memory-core/openai/phone-control/talk-voice/telegram). 모델 6봇 전부 보존(drift 0): main/bbot `claude-opus-4-8`, mini `sonnet-4-6`, glg/gpt `gpt-5.5`, gemini `google-gemini-cli/...`(403 DOWN). probe: `anthropic:claude-cli=OAuth ok·3s`, `openai/gpt-5.5 ok·5.4s`(codex usage 5h 99%/Week 72%) — **claude+codex 서빙 라이브 확인**. telegram→agent end-to-end는 oracle에 libtdjson 부재로 GUI 측 GLG ping으로 확인. 롤백: Dockerfile FROM 6.8 환원(주석 보존) + rebuild·recreate.

### 2026.6.8 (2026-06-17, GREEN)

6.6 다음 stable **한 칸** (6.7은 beta만, 6.6→6.8=373 commits) — 유지보수·견고화 patch. Docker 절차: `~/openclaw/Dockerfile` `FROM ...:2026.6.6 → :2026.6.8`(runtime SSOT = openclaw-config repo, nixos-config `docker/openclaw/Dockerfile` 미러 동기) + `docker compose build --pull && up -d --force-recreate`. codex plugin stock 자동 6.8.

**직접 이득**: Telegram rich delivery(표/리스트/expandable blockquote/의도된 줄바꿈 보존 — 주 채널, 전 가족봇) + memory 견고화(과대 임베딩 배치 431 분할·full reindex rollback/cache 복구·QMD transient 유지) + Codex/Claude replay 복구(OpenAI reasoning-sig·Anthropic thinking-sig recovery, heartbeat dedupe, auto-reply final reply, unknown OpenAI selector 거부) + OAuth image-default를 Codex로 라우팅(우리 `gpt-image-2` 정합) + Hono 4.12.25 패치. **비해당**: Copilot tool-streaming / LM Studio binary-thinking / NFS WAL / WhatsApp·Slack·Discord·Feishu.

**마이그레이션 — doctor --fix 의무 유지**(SQLite auth 마이그레이션 연장선): 실행 결과 Plugins Errors 0 / Skills Eligible 42·Blocked 0, 3봇 Anthropic auth GREEN(`anthropic:claude-cli=OAuth`, 공유 `~/.claude` mount 함정 미재발), openai/codex 서빙 ok.

**⚠️ doctor가 일으킨 gemini 드리프트 (6.6에 이어 6.8에서도 실측·되돌림)**: `doctor --fix`가 또 gemini를 `google-gemini-cli/gemini-3.1-pro-preview` → `google/gemini-3.1-pro-preview` + agent `models` 맵에 `google/...{agentRuntime:google-gemini-cli}` 추가로 **자동 재작성**. `google/`는 api-key(나노바나나 이미지 전용) 금지경로라 되돌림(`config set agents.list.3.model.primary google-gemini-cli/...` + `config unset agents.list.3.models["google/..."]` + restart). **agy 이관 진행 중이라 이 드리프트는 doctor --fix마다 반복 — 6.8 릴리즈에 agy/antigravity provider 없음 확인**(gemini는 403 OAuth 스코프로 DOWN 유지, agy 연동 대기). 절차·경계는 ORACLE.md gemini 함정 블록.

**우리쪽 접점 스모크**: force-recreate 후 `emacs-agent` env·소켓 주입 GREEN(`emacsclient -s /run/emacs/server -e "(+ 6 8)"` → `14`, 6.6 보안 하드닝 경로 유지). Telegram 6봇 provider 시작 + isolated polling ingress 정상, 에러 0.

**검증**: `OpenClaw 2026.6.8`, healthy(t+15s), doctor Errors 0. 모델: main/bbot `claude-opus-4-8`, mini `sonnet-4-6`, glg/gpt `gpt-5.5`, gemini `google-gemini-cli/gemini-3.1-pro-preview`(되돌림, 403 DOWN). probe: claude-cli/codex 서빙 ok·gemini 403 그대로. 롤백: Dockerfile FROM 6.6 환원(주석 보존) + rebuild·recreate.

### 2026.6.6 (2026-06-13, GREEN)

6.5 다음 stable **한 칸** — 보안 경계 강화 위주 patch. Docker 절차: `~/openclaw/Dockerfile` `FROM ...:2026.6.5 → :2026.6.6`(runtime SSOT = openclaw-config repo, nixos-config `docker/openclaw/Dockerfile` 미러도 동기) + `docker compose build && up -d`. codex plugin stock 자동 6.6.

**핵심 주의 — 보안 하드닝의 우리쪽 접점**: "host 환경 상속 / MCP stdio / sandbox bind / Codex HTTP 접근" 경계가 조여짐. oracle custom 빌드에서 유일하게 닿는 곳은 **`emacs-agent.sh` 의 env·소켓 주입** — recreate 후 스모크: `PI_EMACS_AGENT_SOCKET=/run/emacs/server` + `emacsclient` 바이너리 생존 확인 GREEN(하드닝이 주입 경로 미침해). **직접 이득**: Telegram 라우팅/스트리밍/콜백 신뢰성 수정(주 채널) + 무단 DM 텍스트 캐시/프롬프트 컨텍스트 미포함(cross-DM 계열 하드닝) + 세션 재바인드 후 stale approval followup 제거. **운영 변경**: compaction 기본 타임아웃 180s 단축(명시 설정 존중).

**마이그레이션 — doctor --fix 의무 유지**: "SQLite 인증 마이그레이션 검증 후 정리"(6.5 SQLite 이전의 연장). 실행 결과 Errors 0, 3봇 Anthropic auth GREEN(공유 `~/.claude` mount 함정 미재발), openai/codex 서빙 ok.

**⚠️ doctor가 일으킨 gemini 드리프트 (실측·되돌림)**: `doctor --fix`가 gemini를 `google-gemini-cli/gemini-3.1-pro-preview` → `google/gemini-3.1-pro-preview` + `agentRuntime.id=google-gemini-cli`로 **자동 재작성**. `google/`는 api-key(나노바나나 이미지 전용) 금지경로라 되돌림(config set primary + models 맵 엔트리 unset). agy 이관 진행 중이라 이 드리프트는 당분간 반복 예상 — 아래 운영 결정 이력 참조.

**검증**: `OpenClaw 2026.6.6`, healthy, doctor Errors 0. 모델: main/bbot `claude-opus-4-8`, mini `sonnet-4-6`, glg `gpt-5.5`(이번 재승격), gpt `gpt-5.5`, gemini `google-gemini-cli/gemini-3.1-pro-preview`(되돌림, OAuth 스코프-403 별도 — GLG device-code 재로그인 대기). 롤백: Dockerfile FROM 6.5 환원(주석 보존) + rebuild·recreate.

### 2026.6.5 (2026-06-10, GREEN)

릴리즈 트레인이 **월별 patch 넘버링으로 전환** — 6.2~6.4 stable 부재, 6.1(6/3) 다음 stable이 곧 6.5(6/9). 따라서 6.1 → 6.5 는 **stable 한 칸**. Docker 절차: `~/openclaw/Dockerfile` `FROM ...:2026.6.1 → :2026.6.5` + `docker compose build --pull && up -d --force-recreate`. codex plugin은 stock(번들)이라 base bump와 함께 자동 6.5.

**우리 직접 이득 (이 hop을 택한 이유)**: Anthropic/Codex/ACP/agent recovery 대거 수정 — stream start 이벤트를 `message_start`까지 지연시켜 **prompt-cache 만료·Gateway restart 후 extended-thinking 복구**(#90667/#90697), compaction 후 stale thinking signature 제거, **빈 completion handoff 거부**, parent streaming-off override 보존, Codex 세션/스레드 마이그레이션 엣지케이스(#90729 외). + **MCP tool-result 강제 coercion**(`resource_link`/`audio`/malformed image를 materialize 경계에서 text화 → Anthropic 400·세션 히스토리 오염 방지, #90710/#90728). + message-tool send가 delivery로 카운트(#90123). ROADMAP에 박힌 EPIPE·빈응답·streaming-off 계열의 정공 수정 묶음.

**Breaking/마이그레이션 — auth profiles → SQLite (#89102, 의무 확인)**: auth 저장 형식이 per-agent JSON → SQLite로 이전. 업그레이드 후 `openclaw doctor --fix` 실행 → `openclaw-agent.sqlite` 생성, 구 `auth-profiles.json`/`auth-state.json`/`auth.json`은 `*.sqlite-import.<ts>.bak`로 보존(데이터 손실 0). 검증 결과 **stale OAuth shadow 미발생** — 모든 봇 `anthropic:claude-cli: expiring(7h)`(정상 만료 advisory, 자동 refresh), `Headless Claude auth: OK(oauth)`. 공유 `~/.claude` mount 함정(2026-05-31·6.1 사례)이 이번엔 재발 안 함. cron legacy JSON → SQLite도 doctor preflight 자동 마이그레이션.

**안심 포인트**: 위험한 **session-metadata SQLite 마이그레이션은 6.5 beta train에서 의도적 보류**(JSON-backed 유지) — 가장 큰 마이그레이션 리스크가 빠진 릴리즈.

**신규 WARN — pi-shell-acp provider 카탈로그 (gemini ACP)**: 6.5 strict provider 검증이 `plugins.entries.pi-shell-acp` 의 `provider must be an object` 를 새로 잡음(stub provider는 정상 registered). gemini ACP는 이미 **삭제 예정**이라 무관 — 오히려 삭제 근거 강화. **→ 2026-06-10 gemini 네이티브 전환 + pi-shell-acp 제거로 이 WARN 해소**(아래 운영 결정 이력). 그 외 WARN: non-loopback bind(harmless 기존)·Personal Codex CLI assets isolated-homes(harmless info).

**검증**: `OpenClaw 2026.6.5`, ready 5.2s, **14 plugins**(6.1의 13 + 신규 `openai` 플러그인 — Codex/OpenAI provider 분리), healthy. doctor **Errors 0**. 모델 전부 보존: main/bbot `claude-opus-4-8`, mini `sonnet-4-6`, glg `gpt-5.4`(전날 강등 유지), gpt `gpt-5.5`. 디스크 8.9G(91%, 약간 빠듯 — 추후 generation 정리 여지). 롤백: Dockerfile FROM 6.1 환원(주석 보존) + rebuild·recreate.

### 2026.6.1 (2026-06-04, GREEN)

별도 host-native(비-Docker) 레퍼런스가 같은 hop을 먼저 밟아 **3봇 GREEN** 으로 검증한 뒤 oracle(Docker) 적용. "삽질을 먼저 해둔" 선검증 사이클. Docker 절차: `~/openclaw/Dockerfile` `FROM ...:2026.5.28 → :2026.6.1` + `docker compose build --pull && up -d --force-recreate`. **codex plugin은 base image 번들이라 자동 6.1** — host-native 의 `pnpm -g add openclaw@latest && openclaw plugins update @openclaw/codex` 동시 업글(버전 mismatch = `listRegisteredPluginAgentPromptGuidance is not a function`) 함정 **비해당**.

**핵심 breaking — codex lane 401 → doctor --fix canonical migration (의무)**: 6.1이 *"public OpenAI API-key profiles 를 native Codex app-server auth 로 취급하지 않음"* 으로 바꿔, codex lane(glg `openai/gpt-5.4` · gpt `openai/gpt-5.5`)이 `api.openai.com 401` 로 깨질 수 있다. `openclaw doctor --fix` 가 **"Migrated legacy OpenAI Codex auth profile config to the canonical OpenAI provider"** (`~/.openclaw/agents/main/agent/auth-profiles.json` → provider `openai`, backup `.openai-provider-unification`) 로 복구. 업그레이드 직후 `doctor`가 `Legacy openai-codex/* session route state detected. needs repair` 로 표면화 → `--fix` 적용 후 소멸. (NEXT §6 "업그레이드 직후 doctor --fix 의무"의 6.1 사례.)

**state migration (6.1 자동, SQLite 통합)**: plugin install index + 500 plugin-state sidecar + task registry/delivery/flow rows + telegram update-offset/sent-message/dispatch-dedupe 전부 → shared SQLite, legacy 는 `.migrated` 로 archive(데이터 손실 없음). 1건(`telegram.bot-info-cache/bbot`)은 shared state 에 6 rows 이미 존재해 sidecar in-place 유지 — harmless WARN.

**per-agent stale OAuth shadow 정리**: `doctor --fix` 2회차가 bbot/gemini 등 per-agent 복사본 5건을 `Removed stale OAuth auth profile shadow … inherits main auth` 로 제거 — oracle `~/.claude` 공유 mount 패턴(아래 "운영 결정 이력" 2026-05-31 항목과 동일 메커니즘, 6.1에서도 재확인). 제거 후 bbot 재호출 GREEN.

**SecretRefs advisory (6.1 신규) = oracle 비해당**: secret(telegram/openai/openrouter) 전부 `.env` 경유라 `openclaw.json` 에 평문 없음 → advisory 미발생. 그 host-native 레퍼런스는 mattermost 토큰이 평문이라 `plaintext secret-bearing config → SecretRefs` advisory 가 떴던 것(`openclaw secrets configure` 권고, action 아님). mattermost 컨테이너 주소 churn(그 레퍼런스 고유) 도 oracle 비해당.

**tokenjuice/Copilot externalize**: 6.1이 official npm plugin 으로 분리. 우리 미설치라 무관 — 설치해도 `agentToolResultMiddleware` 가 bundled-only 게이트(registry origin≠bundled 거부)라 거부됨(그 레퍼런스가 시도→롤백으로 검증).

**검증**: `OpenClaw 2026.6.1`, ready 4.9s, 13 plugins, healthy. doctor **Errors 0 / Missing requirements 0**. 라이브 headless(`openclaw agent --agent <id> --json`, `--deliver` 없이): glg `winner=openai/gpt-5.4 fallbackUsed=false runner=embedded`(실 한국어 응답), gpt `openai/gpt-5.5`, main+bbot `claude-cli/claude-opus-4-8 runner=cli`, mini `claude-cli/claude-sonnet-4-6 runner=cli`. gemini(ACP route, 빈응답 미해결, 삭제 예정)는 회귀 대상 아님 — skip. WARN 분류: non-loopback bind(harmless 기존)·discord 미설치(harmless)·Personal Codex CLI assets isolated-homes(harmless info). 롤백: Dockerfile FROM 5.28 환원(주석 보존) + rebuild·recreate.

### 2026.5.28 (2026-05-31, GREEN)

Docker rebuild: `~/openclaw/Dockerfile` `FROM ...:2026.5.27 → :2026.5.28` + `docker compose build --pull && up -d --force-recreate`. codex plugin은 stock(번들)이라 base bump와 함께 자동 5.28. 디스크 제약 대비 dangling prune 선행(3.38GB 회수, `/` 82%).

5.28 핵심: **Claude Opus 4.8 정식 카탈로그**(`anthropic/claude-opus-4-8`, default+alias:opus) — 05-29 승급 때의 legacy `claude-cli/*` prefix가 비로소 canonical `anthropic/* + agentRuntime claude-cli`로 정착하는 전제 / doctor가 non-canonical `api_key` auth profile을 canonical로 재작성 + **per-agent auth health 라벨**(stale OAuth shadow 진단) / Codex model migration 시 explicit agentRuntime pin 보존 / Claude CLI transcript probe retry · live tool progress watchdog. Breaking(우리 비해당): Haiku 4.5→Sonnet 자동 migrate 중단, workspace dotenv provider credential 무시.

**Breaking 함정 (crash loop 발생)**: 5.28이 `agents.defaults.agentRuntime`(defaults 직속 top-level 키)를 **Unrecognized key로 거부** → recreate 직후 게이트웨이 `Invalid config / Gateway failed to start` crash loop(봇 다운). 원인은 정공법 편집이 아니라 5.27이 받던 기존 defaults 형태. 해소: defaults 직속 `agentRuntime` 제거(우리 claude 모델은 이미 model-scoped `agentRuntime: claude-cli`를 가져 무해 — 오히려 pi-shell-acp/deepseek가 default runtime을 잘못 상속하던 latent bug 제거). 재현 시 업그레이드 직후 `openclaw doctor`로 정확한 invalid 필드 확인 후 surgical 제거 → restart. (NEXT §6 "업그레이드 직후 doctor --fix 의무"의 구체 사례.)

검증: `OpenClaw 2026.5.28`, ready 4.6s, 13 plugins, healthy. 라이브 headless(`openclaw agent --agent <id> --json`, `--deliver` 없이): main `winner=claude-cli/claude-opus-4-8 fallbackUsed=false runner=cli`, bbot 동일(opus-4-8), mini `claude-cli/claude-sonnet-4-6`. doctor Errors 0 / Missing requirements 0. 롤백: Dockerfile FROM 5.27 환원(주석 보존) + rebuild·recreate.

### 2026.5.27 (2026-05-29, GREEN)

별도 host-native(비-Docker) 레퍼런스 배포가 먼저 5.27 검증 완료한 것을 reference로 oracle(Docker) 적용. Docker 절차는 `~/openclaw/Dockerfile` `FROM ...:2026.5.22 → :2026.5.27` + `docker compose build --pull && up -d --force-recreate` 한 번. **codex plugin은 `stock:codex/index.js`(베이스 이미지 번들)라 base bump와 함께 자동 5.27** — host-native 레퍼런스의 별도 `@openclaw/codex` 버전 정합 함정 비해당.

5.27 핵심: Codex OAuth compaction을 OpenAI-Codex 경로로 라우팅(host-native 레퍼런스가 맞은 `No_API_key_found_for_provider_openai during compaction` 수정 — oracle glg/gpt/subagents/active-memory recall lane 영향) / Codex runtime model 선해결 / app-server client 생존성 / gateway hot path cache / **신규 strict 검증**(gateway timeout·model limit·directory limit·message option·webhook의 loose·malformed numeric 거부 — 우리 config 스캔 string-numeric 0건, 통과) / memory embedding provider registration deprecated(compat, 기능 영향 없음).

검증: `OpenClaw 2026.5.27`, codex plugin 2026.5.27, ready 5.4s, 12 plugins, healthy. 라이브: main `winner=claude-cli/claude-opus-4-7 fallbackUsed=false`("hi"), glg `winner=openai-codex/gpt-5.4 fallbackUsed=false`("안녕", compaction/API-key 에러 0 → **OAuth 재인증 불필요**). memorySearch 308 chunks(4096d)·의미검색 score 정상. telegram 6봇 isolated polling 기동. 유일 WARN = `plugins.entries.discord` 미설치(harmless, 기존 잔재). 롤백: Dockerfile FROM 5.22 환원(주석 보존) + rebuild·recreate.

5.27 후에도 **bbot/gemini(pi-shell-acp ACP 경로)는 빈 응답** — child 정상 spawn/exit(code=0) + context budget(1M) 계산까지 OpenClaw 메커니즘은 정상인데 claude가 0 토큰 반환. ANTHROPIC_API_KEY UNSET(OAuth Max 경로 정상)이라, 이는 5.27 탓이 아니라 2026-05-26 기록된 기존 이슈 — pi-shell-acp가 same Claude SDK를 wrap → Anthropic third-party harness 식별 → extra usage 풀 강제 → 빈 응답. (→ bbot은 같은 날 claude-cli native로 전환, 아래 "운영 결정" 참조.)

### 2026.5.22 (hop, `8a2f8ef` stamp)

claude-cli provider가 raw `@anthropic-ai/sdk@0.97.1`(API client만)로 슬림화 — `claude` binary 별도 install 필요(`npm i -g @anthropic-ai/claude-code` Dockerfile RUN). 5.20까지는 `@anthropic-ai/claude-agent-sdk` v0.3.143(SDK + 번들 binary) 자동 install이었음. **EPIPE 함정**: 5.22 image는 `claude` binary 안 들고 옴 → `command:"claude"`가 PATH에서 못 찾으면 child 4ms 만에 exit → parent stdin EPIPE → "⚠️ Agent failed before reply". Dockerfile에 명시 필요. (상세 incident: [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md))

### 2026.5.12 (2026-05-15)

codex provider 외부화 + model ID 정규화 + OAuth profile 암호화 + plugins.allow 명시 — 정공법 4종(아래 "운영 결정 이력") 모두 적용. ready 8.8s, 10 plugins(5.7의 9 + codex), 6봇 polling 정상 기동. Telegram isolated polling 6 spool dir로 분리(`/home/node/.openclaw/telegram/ingress-spool-{default,glg,gpt,gemini,mini,bbot}`) — 5.12 신규 "isolated polling, durable local spooling". memory streaming RSS 252→27 MiB. memorySearch(`qwen3-embedding-8b` via OpenRouter, 4096d) 한글 query 정상 매칭 검증.

**Trip-up**: 첫 boot 후 default 봇 `getMe` fetch-timeout 1건 → isolated polling cycle stuck → restart로 해소. 5.12 isolated polling은 일시적 timeout에 polling thread를 죽일 수 있어 boot 직후 fetch-timeout 발생 시 즉시 restart 필요(per-account isolated restart는 CLI 옵션 없음).

### 2026.5.7 (2026-05-08 두 번째)

Codex OAuth 라우트 보존(5.5 doctor rewrite 버그는 5.6에서 revert). `agent model: openai-codex/gpt-5.4` 그대로. ready 5.7s, 6 텔레그램 봇 정상 기동.

### 2026.5.2 baseline (2026-05-08)

ACPX externalize(`@openclaw/acpx` beta), 우리는 disabled. active-memory disabled. 6 agents 임베딩 baseline: 총 2540 chunks(1234 memory + 1306 sessions).

---

## 운영 결정 이력

### bbot fable-5 재승격 + mini sonnet-5 승격 (2026-07-12)

6.11 라이브에서 **bbot `opus-4-8` → `claude-fable-5`**, **mini `sonnet-4-6` → `claude-sonnet-5`** 승격. 둘 다 claude-cli 구독 동적 해결(재빌드 불필요), primary 경로 서빙 검증 `fallbackUsed=false`.

- **fable-5 서빙 재개**: 2026-06-13엔 Fable 5가 구독/CLI에서 서빙 실패(auto-fallback deepseek 정체성 훼손)로 opus-4-8 환원했으나, upstream v2026.6.6 adaptive-thinking 어댑터 fix([issue #91805](https://github.com/openclaw/openclaw/issues/91805) / [PR #91882](https://github.com/openclaw/openclaw/pull/91882)) + 현재 6.11에서 서빙 재개 확인(claude-cli, thinking=high 강제, Opus 4.8 안전 폴백).
- **안전 승격 절차**: primary=opus 유지한 채 `agent --agent bbot --model anthropic/claude-fable-5`를 isolated session·no-deliver로 돌려 `winnerModel=claude-fable-5 fallbackUsed=false success` 확인 → 그 뒤에만 primary=fable로 promote. 정체성 훼손을 실사용자에 노출하지 않는 gate.
- **오버라이드 게이트 재확인**: `--model` override 허용 = `agents.defaults.models` 글로벌 카탈로그(per-agent `models`는 runtime 바인딩 전용). fable을 defaults.models 끝(catch-all #1=gpt-5.5 불변)에 등록해 probe 개방 + `/model fable` 전 봇 개방 — 2026-05-26 "override allow-list가 primary 기준" 함정과 정합.
- **6.11 hot-reload 부분성**: `config set`이 agents.list를 파일에 hot-reload하나 gateway serving/override-allowlist 인메모리는 restart라야 rebuild. idle 확인 후 `docker compose restart`.

### gemini 네이티브 부활 + ACP 완전 제거 (2026-06-10)

gemini는 그간 **유일한 ACP 잔존 봇**으로 `pi-shell-acp/gemini-3.1-pro-preview`(외부 gemini CLI를 ACP child로 spawn)에 의존했고, child ~2s 무출력 exit(빈응답, [pi-shell-acp #27](https://github.com/junghan0611/pi-shell-acp/issues/27)) 미해결로 "삭제 후보"였다. 6.5 업그레이드 조사 중 **OpenClaw 네이티브 `google` provider(stock 익스텐션, enabled)** + **`google-gemini-cli` OAuth**가 이 박스에 이미 깔려 있음을 확인 → ACP 우회 없이 정공법 부활.

- **API 아닌 Pro 쿼터 — provider prefix가 과금 경로를 가른다**: `google`(api-key, env `GEMINI_API_KEY`)와 `google-gemini-cli`(OAuth 구독, `usage: Pro 100% left · Flash 100% left`)는 **별개 provider**. 모델 ID prefix가 결정 — `google/gemini-…`=api-key, **`google-gemini-cli/gemini-…`=OAuth**. Pro 쿼터를 쓰려면 모델을 `google-gemini-cli/gemini-3.1-pro-preview`로 둔다. `GEMINI_API_KEY`는 어떤 챗 모델도 안 가리키고 이미지(나노바나나) 전용.
- **함정 (frequently-breaks 사례, 2026-06-10 실착)**: 처음엔 `google/gemini-3.1-pro-preview` + `auth.order.google=["google-gemini-cli:…"]` 핀으로 OAuth를 강제하려 했으나 **안 먹었다** — `auth.order`는 *같은 provider 내* 프로필 순서지 cross-provider 선택이 아니다(`google`≠`google-gemini-cli`). 헤드리스 `openclaw agent --json` 테스트는 `provider=google-gemini-cli`로 보였는데, 그 순간 OpenClaw가 config에 **transient `agentRuntime.id=google-gemini-cli`** 를 끼워넣은 상태였고, 이후 restart 사이클에서 그게 빠지자 텔레그램 `/status`가 **`🔑 api-key (env: GEMINI_API_KEY)`** 로 드러났다. **교훈: hot-reload가 config를 계속 다시 쓰므로 헤드리스 1회 관측 ≠ 안정 런타임 — `/status`의 `🔑` auth 라인이 진실.** 해소: 모델 prefix `google-gemini-cli/`로 변경 + `auth.order.google` 제거 → `/status` `🔑 oauth`. 추가로 `defaults.models`에 OpenClaw가 자동 파생한 `google/gemini-…`(api-key prefix + OAuth runtime 혼합) 잔재도 `google-gemini-cli/`로 정정, config 전수검사로 `google/` 0 확인. `GEMINI_API_KEY`의 이미지 경로 영향은 여전히 미재검증([NEXT.md §1](NEXT.md)).
- **밑단 creds**: `~/.gemini`가 이미 `active: gtgkjh@gmail.com`(Pro, `antigravity-cli/` 동거). OpenClaw 프로필만 옛 junghanacs(stale)라 **공식 `openclaw models auth login --provider google-gemini-cli`(TTY 인터랙티브)** 로 gtgkjh 동기화. `--device-code`는 이 provider에 없는 메서드라 실패(`Unknown auth method`) → 인터랙티브 메서드 메뉴에서 `sync`(기존 `~/.gemini` creds import, 브라우저 불필요) 선택이 정답.
- **에이전트 canonical 전환**: `model.primary=google-gemini-cli/gemini-3.1-pro-preview`, `fallbacks:[]`(안 되면 안 씀 — 정공법 원칙), agentRuntime 없음(provider prefix가 runner=cli 바인딩). 라이브 검증: `provider=google-gemini-cli model=gemini-3.1-pro-preview fallbackUsed=false stopReason=completed refusal=false` + 실 한국어 응답 + `/status` `🔑 oauth`(옛 ACP 빈응답·api-key 둘 다 탈출).
- **pi-shell-acp 제거**: 사용처 0 → `plugins.entries.pi-shell-acp.enabled=false`(런타임 14 plugins에서 빠지고 `google` 자리잡음) + main의 죽은 `pi-shell-acp/*` picker 3개 제거. **함정: 엔트리를 *삭제*하면 기본 로드로 복귀**(2026-06-10 확인) → acpx처럼 엔트리 present + `enabled:false` 유지가 정답. doctor Errors 0.
- **forward 리스크**: gemini-cli는 Antigravity(agy)로 통합 예정. 그땐 OpenClaw 업스트림(`antigravity`/agy provider)을 따라 프로필만 마이그레이션 — 손으로 creds 복사하는 우회가 아니라 공식 provider 추적. `~/.gemini/antigravity-cli/` 이미 존재로 계정 entitlement 준비됨.

### gemini agy 이관 드리프트 실측 + glg 5.5 재승격 (2026-06-13)

6.6 업그레이드 중 위 "forward 리스크"가 **드리프트로 현실화**. 이 항목은 *흔들림을 사안으로 고정*하는 닻 — gemini 설정이 또 바뀌어 보일 때 "버그"가 아니라 "agy 이관 사안"으로 인지하기 위한 좌표.

- **doctor가 gemini를 금지경로로 자동 재작성 (실측)**: `doctor --fix`(6.6)가 `model.primary`를 `google-gemini-cli/gemini-3.1-pro-preview` → `google/gemini-3.1-pro-preview`로, `models` 맵에 `google/gemini-3.1-pro-preview { agentRuntime.id: google-gemini-cli }`를 추가. `google/`는 api-key(나노바나나 이미지 전용) provider라 **금지경로**. agent list는 google/를 가리키는데 카탈로그/probe엔 깨끗이 안 잡히는 **모호 상태** → 되돌림(`config set primary google-gemini-cli/…` + `config unset 'agents.list.<idx>.models["google/…"]'` + restart). 라이브 `google-gemini-cli/` 복원 확인.
- **운영 원칙 (ORACLE.md per-agent auth 함정에 박음)**: ① 업글/`doctor --fix` 후 `agents list`로 gemini prefix 재확인, `google/`면 되돌림. ② **이건 한시적 방어** — 자꾸 바뀐다고 당황 말 것, "agy 이관 사안"으로 인지·검토. ③ agy 이관 공식화(gemini-cli 완전 deprecate) 시 `google-gemini-cli/` 전제 전체를 한 번에 재작성 — 그때가 진짜 이사. 그 전까지 OAuth(`google-gemini-cli/`)가 기준선.
- **별건 — OAuth 스코프-403**: 이번 세션에서 gemini 무응답의 직접 원인은 드리프트가 아니라 `gtgkjh@gmail.com` OAuth 프로필의 `insufficient authentication scopes [403]`(토큰 만료 아님). fix는 device-code 재로그인(`models auth login --agent main --provider google-gemini-cli --device-code --force`, headless라 GLG 수동) — 노트북 작업으로 이월.
- **glg 가족봇 5.4 → 5.5 재승격**: 2026-06-10 강등(cross-DM 판단 과잉 억제·비용 1/2)의 되돌림. **cross-DM 가드(원문-only 전달 규칙) 완료로 강등 사유 해소** → 가족 실무 답변 품질 우선. `config set agents.list.<glg>.model.primary openai/gpt-5.5` + restart. 기본값 변경은 **신규 세션부터** — 세션은 telegram user-id 단위로 분리되고 각 세션이 저장된 model을 유지하므로, 진행 중 DM(예: 아내 세션)은 `/model` 또는 세션 리셋 전까지 5.4 유지(영향 격리 확인).

### Opus 4.8 canonical 정공법 + per-agent auth inherit (2026-05-31)

05-29의 `claude-cli/<id>` prefix는 4.8 공식 카탈로그 지원 전의 legacy 표기였다. 5.28이 `anthropic/claude-opus-4-8`를 정식 Anthropic 카탈로그 모델로 추가하면서 **canonical 정공법으로 전환**:

- **canonical 형태**: `anthropic/claude-opus-4-8` + `agentRuntime: { id: "claude-cli" }`. provider prefix(`anthropic/`)는 카탈로그 식별자일 뿐 **과금 경로가 아니다** — 과금은 runtime이 결정한다(`claude-cli`=구독 `claude -p`). main/bbot=opus-4-8, mini=sonnet-4-6. 전환 대상은 3봇뿐인데, **oracle은 `subagents.model`이 `openai/gpt-5.4`(Codex)**라 subagent엔 claude auth가 불필요(별도 host-native 레퍼런스는 subagent가 claude sonnet이라 claude 직접 안 쓰는 보조 봇까지 login 필요했던 것과 갈리는 자리).
- **레거시 정리(헷갈림 제거)**: config 전체에서 `claude-cli/*` prefix 0, `opus-4-7`·`opus-4-6` 0(defaults.models 포함, opus는 4.8만), ACP-route `pi-shell-acp/claude-*` picker 엔트리 제거(第3자 harness 과금 풀 → Claude 경로 이중화 해소), legacy `anthropic:default`(token) 프로필 제거(top-level + per-agent bbot/mini). gemini/codex용 `pi-shell-acp/gpt-*`·`gemini`는 유지(gemini 거취 별건).
- **auth는 공식 플로우만**: `openclaw models auth --agent <id> login --provider anthropic --method cli`(TTY, GLG 수동). paste-token·auth-profiles.json 수기편집·`--set-default` 트릭 안 씀.
- **per-agent auth 분기 — host-native 레퍼런스와 정반대 결론**: GLG가 bbot/mini에 login해 per-agent `anthropic:claude-cli` 프로필을 만들었으나, **oracle은 Docker라 `~/.claude`가 전 봇 공유 mount** → main 프로필만 갱신되고 bbot/mini의 login-시점 복사본은 frozen → 5.28 doctor가 **stale OAuth shadow**로 진단. `openclaw doctor --fix`가 이를 제거하고 **main의 갱신되는 auth를 inherit**시킴. 제거 후 재호출에서 bbot/mini 여전히 GREEN(claude-cli/opus-4-8·sonnet-4-6). → 별도 host-native 레퍼런스의 "봇 수만큼 login 유지"는 **공유 mount가 없는 host-native 전제**라 oracle엔 그대로 적용 안 됨. login 단계 자체는 필요(top-level `anthropic:claude-cli` + `order.anthropic` 등록 = 정공법 기반)했고, doctor가 per-agent 복사본만 정리한 것.
- **검증**: doctor Errors 0 / Missing 0, "Headless Claude auth: OK (oauth)", auth profile `anthropic:claude-cli (provider claude-cli)`. 3봇 라이브 GREEN.
- **부수 발견(별건)**: doctor가 `google-gemini-cli` per-agent 프로필(glg/gpt/gemini/bbot/mini)도 같은 stale shadow로 플래그 — 기존 cruft, claude 아님, gemini 삭제 예정이라 거취 결정 때 정리(NEXT §1).
- **과금 변화 예고**(모델 표기 무관, `claude -p` 경로 공통): ~2026-06-15부터 구독 plan 한도 차감 → 월 Agent SDK 크레딧 소진 후 standard API rate. pi-shell-acp ACP 경로도 동일 크레딧 대상.

### claude-cli native 전환 + opus 4.8 (2026-05-26 ~ 05-29)

OpenClaw native first-class Claude path. Codex와 짝.

**결제 분리의 핵심**: pi-shell-acp가 같은 Claude SDK를 wrap하면 Anthropic이 **third-party harness로 식별** → extra usage 풀로 강제(2026-05-26 pi 테스트: `400 You're out of extra usage`). OpenClaw native claude-cli는 same SDK를 direct import → **Pro/Max 한도로 인식**(자기인식 응답: "Anthropic의 공식 CLI 도구인 Claude Code 환경에서 작동 중", `rate_limit_event.isUsingOverage=false` 검증). 같은 SDK라도 import 깊이 한 단계 차이로 결제 풀이 달라진다.

**1M context (2026-05-26 발견)**: Claude Code 환경(`claude-cli` provider)에선 sonnet 4.6 / opus 4.7/4.8 모두 1M context로 잡힘(`/status` "Context: 159k/1.0m"). third-party API 직접 호출 시 200k와 대조. native claude-cli path는 결제 풀 + capability(1M ctx) 둘 다 third-party와 다른 자리.

**claude-cli 전환 방법**: model.primary를 `claude-cli/<id>`로 바꾸고 agent `models` 카탈로그에 `"claude-cli/<id>": {}` 등록하면 끝 — plugins.allow/entries 수동 등록 불필요(코어 내장 runtime alias, 모델 ID 등장만으로 auto-enable). **함정**: `--model claude-cli/...` CLI override는 "not allowed for agent"로 막힘(override allow-list가 primary 기준) — primary로 지정하면 정상.

**invocation 디테일**: 실제 호출은 `claude -p`(`--input-format stream-json --output-format stream-json --session-id <id> [--resume]` + `--permission-prompt-tool stdio` + `--verbose`). 세션 jsonl은 `~/.claude/projects/-<cwd-encoded>/<session-id>.jsonl` — 호스트 `~/.claude/projects/`와 컨테이너 `/home/node/.claude/projects/`가 mount 공유라 호스트 Claude Code 세션과 같은 디렉토리에 섞임(sub-dir 격리). OAuth는 `/home/node/.claude/.credentials.json`의 `claudeAiOauth`(refresh_token 자동 갱신). workspace-aware skills 정상 — claude code SDK가 workspace cwd를 root로 보고 skill discovery.

타임라인:
- **2026-05-26** — main `claude-cli/claude-opus-4-7` + mini `claude-cli/claude-sonnet-4-6` 텔레그램 turn GREEN. workspace-aware skill 호출 정상.
- **2026-05-29** — bbot `pi-shell-acp/claude-opus-4-7` → `claude-cli/claude-opus-4-8` 전환. third-party harness extra-usage 빈응답 탈출, Max 한도 인식. claude ACP 경로 정리 완료(gemini만 ACP 잔존).
- **2026-05-29 (GLG 결정)** — main(default) + bbot opus 4.8 승급, 4.7 폐기. 컨테이너 `claude` 바이너리 2.1.156이 `--help`에 `claude-opus-4-8` 명시 + 라이브 `winner=claude-cli/claude-opus-4-8 fallbackUsed=false`, 봇 자기보고 `claude-opus-4-8` 확인.

### Fallback 정공법 (2026-05-26)

모든 봇 `fallbacks: []` 비움(`agents.defaults.model.fallbacks: []` 포함). 정공법은 **안 되면 안 되는 거 — 응답 막히면 모델 자체를 바꾼다**. Codex sidecar stuck / extra usage 소진 등으로 다른 path로 자동 fallback(quota inflation / 다른 path 소진 연쇄) 차단. 5.12 baseline의 `fallbacks: ["openai/gpt-5.4"]` 명시 정책 폐기.

### verboseDefault 정책 (2026-05-29, full→on 환원)

`agents.defaults.verboseDefault: "on"` 전역. 2026-05-27 `full`로 올렸다가, full은 도구 출력 자체까지 텔레그램에 stream해 응답이 과도하게 길어진다는 운영 판단으로 `on`으로 환원. `on`은 도구 호출 시점/sub-agent trace 안내는 유지하되 raw 도구 stdout 본문은 채널에 붙이지 않는다. 값 변경 후 gateway restart로 확정 적용(`config change detected; evaluating reload (agents.defaults.verboseDefault)` 로그 확인). 봇별 `/verbose full|on|off`로 session-level 토글 가능.

### Streaming 정책 (2026-05-16, 05-26 확장)

pi-shell-acp / claude-cli 라우트 봇 모두 **streaming=off 권장**. partial mode는 editMessageText 사이클이 mid-stream wrong-final 회귀 시점에 본문을 짧은 metadata(active-memory diagnostic 등)로 replace해 답변이 "보였다 사라짐"(2026-05-16 04:01 incident). off는 final 1회 flush라 plugin role/abnormal guard와 합치고 디버그도 쉽다. `channels.telegram.accounts.{default,mini}.streaming.mode: off`. gemini는 turn 검증 중이라 partial 유지.

### Tool-trace inline 해소 (2026-05-16)

`~/.pi/agent/settings.json`의 `piShellAcpProvider.showToolNotifications: true → false` 한 줄로 정착. 이전엔 pi backend가 final assistant text 안에 `[tool:start] Skill / [tool:done] ...` trace를 inline string으로 박았는데(plugin `fa3b8f7` block-type filter는 통과 — 단일 `text` block 내부 inline이라 strip 불가), pi-CLI child가 매 turn spawn 시 settings 새로 읽는 구조라 gateway restart 없이 즉시 적용. workspace-local 새 파일 불필요.

### 5.12 정공법 4종 (2026-05-15)

5.12 업그레이드에서 강제된 4가지 정공법.

**1. model ID 정규화**: `openai-codex/*` provider/model이 deprecate. 새 형식은 `openai/*` + `agentRuntime.id="codex"` marker. model ID는 OpenAI catalog로 통합, OAuth path 라우팅은 별도 marker. 호스트 `codex login` OAuth profile은 그대로 보존(`auth.profiles."openai-codex:junghanacs@gmail.com"` 키 이름 그대로). **재로그인 불필요**. 적용: `openclaw doctor --fix --force --yes --non-interactive`(in-container, 65 paths, atomic). doctor가 놓치는 곳 — per-agent `agents.list[].model` bare string(strict 검증 잡힘, 수동 object 변환), nested plugin config(`plugins.entries.active-memory.config.model`, 수동 patch).

**2. OAuth profile 암호화**: OAuth profile credential을 disk plain JSON 대신 AES 암호화. 암호화 key는 stateDir(`~/.openclaw`) 외부 — XDG `$HOME/.config/openclaw/auth-profile-secret-key`. **Docker 추가 mount 필수**: `./auth-profile-secrets:/home/node/.config/openclaw`. 누락 시 codex harness 등록 실패 → 모든 OAuth 봇 응답 불가. host key file 별도 백업 필요 — 분실 시 모든 OAuth profile 재로그인.

**3. plugins.allow 명시**: codex가 `@openclaw/codex` 별도 plugin으로 외부화. `plugins.allow` 빈 상태면 "non-bundled plugins may auto-load" WARN. 사용 plugin 전체 명시: `["telegram","perplexity","google","anthropic","openai","github-copilot","active-memory","memory-core","deepseek","codex","browser","canvas","device-pair","file-transfer","phone-control","talk-voice"]`. `["codex"]`만 박으면 명시 안 한 bundled(active-memory 등) 모두 disabled되어 봇 polling/응답 깨짐.

**4. fallback chain** (이후 2026-05-26 "Fallback 정공법"으로 폐기): 당시엔 `agents.{defaults,list[]}.model.fallbacks: ["openai/gpt-5.4"]` 명시했으나, 자동 fallback이 quota inflation을 부른다는 판단으로 `fallbacks: []`로 전환.

### 임베딩 baseline 전환 (2026-05-08, 4B → 8B 4096d)

OpenRouter `qwen/qwen3-embedding-4b`(2560d) → `qwen3-embedding-8b`(4096d). 가격 4B $0.02/M → 8B **$0.01/M(절반)**, native dim 2560 → 4096(matryoshka truncate 안 함). 절차: `memorySearch.model` 변경 + `~/openclaw/config/memory/*.sqlite{,-shm,-wal}` 삭제 + restart → schema 자동 4096d 재생성 + **reindex 필수**(4B와 8B 임베딩 공간 직교). 6 agents force reindex: 총 4982 chunks(1234 memory + 3748 sessions), 소요 ~21분, storage 621M → 975M(1.57×). OpenRouter privacy에서 8B endpoint 허용 필요(default 차단 시 "No endpoints available matching your guardrail restrictions").

5.7 baseline(2026-05-08): 6 agents → 총 4981 chunks(+187% sessions vs 5.2) — 5.7 transcript-hygiene이 delivered assistant replies를 disk에 보존, indexing이 full transcript를 봄.

### active-memory 도입·관찰 (2026-05-08 ~ 05-16)

활성화 타임라인: 5.7+8B baseline에서 gpt 단독 24h 관찰(2026-05-08 17:58 KST 시작) → 2026-05-09 12:59 main/glg/mini 추가 → 15:55 mini 제외(가벼운/빠른 turn 용도라 5–10s recall latency·비용 인플레이션 안 어울림) → **2026-05-16 bbot 추가**(Phase 1.8 β 통과 + plugin fa3b8f7 user-role echo final flip 차단 가드 적용 후 ACP path 호환성 확보). recall sub-agent는 `openai/gpt-5.4-mini` lane으로 분리해 메인 lane과 OAuth quota 격리.

24h 관찰 결과(2026-05-08 08:58 ~ 05-09 03:45 UTC, gpt 봇 14 invocation): status ok 4회(28.6%) / empty 10회(71.4%) / timeout 0회. elapsedMs min 5388 / max 13256 / 평균 ~8.3s(13.2s spike 1건은 동시 `event_loop_delay 1678ms` liveness warning과 상관, Oracle ARM 일시 부하). summaryChars(ok) 164/178/203/216 — 220 한도 내, 한국어→영어 요약 정상. 해석: Codex OAuth path는 모델 크기 무관 5–10s latency 본질, `setupGraceTimeoutMs=30000`이 매번 5s timeoutMs 덮어 timeout 0건, strict promptStyle이 false-positive 차단. 현재 운영 config는 [AGENTS.md §3 Active memory](AGENTS.md) 참조.

### Forge 레이어 가동 (2026-05-27)

`forge.junghanacs.com`(Forgejo 15.0.2 LTS, postgres 16-alpine, Caddy + Let's Encrypt) Oracle 가동 + alskdjf work forge. 봇멘트의 코드면 확장. 운영 ownership은 forge-config repo, 이 repo는 `docker/forge/` 인프라만. 검증: 30초 인증서 발급, glg-bot 응답 OK, round-trip sandbox 검증, 함정 3개(`INSTALL_LOCK=false` env / `write:user` scope / 단일 파일 bind mount inode caching) 봇로그 박제. 진행 중 후속은 [NEXT.md §0](NEXT.md).

---

## 이력 작성 원칙

1. AGENTS.md에 날짜가 박히면 이 파일로 옮길 때다. AGENTS.md는 "지금 어떤 상태인가"만 답한다.
2. NEXT.md의 ✅ 완료 항목이 쌓이면 이 파일로 흘려보낸다.
3. 활성 함정(다음 세션이 또 밟을 것)은 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md)로, 지나간 버전 사건은 이 파일로.
4. 정보 손실 금지 — 옮기는 것이지 버리는 것이 아니다.
