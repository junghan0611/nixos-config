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

## 현재 위치 (2026-05-29 기준)

- ✅ **OpenClaw 2026.5.27 baseline** (2026-05-29) — Docker 이미지 5.22→5.27, ready 5.4s, 12 plugins, 6봇 isolated polling. Codex OAuth compaction 경로 수정 반영.
- ✅ **main(default) + bbot opus 4.8 승급** (2026-05-29, GLG 결정) — 둘 다 `claude-cli/claude-opus-4-8`, opus 4.7 폐기.
- ✅ **bbot pi-shell-acp → claude-cli native 전환** (2026-05-29) — third-party harness extra-usage 빈응답 탈출. claude ACP 경로 정리 완료 (gemini만 ACP 잔존).
- ✅ **verboseDefault `full` → `on` 환원** (2026-05-29) — full은 도구 raw stdout까지 stream해 응답 과다.
- ✅ **Forge 레이어 가동** (2026-05-27) — `forge.junghanacs.com` Forgejo 15.0.2 + alskdjf work forge. 상세는 [NEXT.md §0](NEXT.md).
- 🔵 **다음** — gemini 거취 결정(삭제 vs #27 해결), bbot opus-4.8 soak GREEN, pi-shell-acp 의존 정리 마무리. → [NEXT.md](NEXT.md).

---

## OpenClaw 업그레이드 이력

> 절차 / 검증 / 함정은 사이클별로 박는다. 활성 함정은 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md)로 승격된다.

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
