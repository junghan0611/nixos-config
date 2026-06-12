# ORACLE.md — Oracle / OpenClaw 운영 핸드북

> **언제 이 문서를 여는가**: `oracle` 디바이스 작업 또는 OpenClaw 관련 작업일 때만. nixos-config의 다른 디바이스(nuc/laptop/thinkpad) 작업에는 불필요 — 그땐 [AGENTS.md](AGENTS.md)만으로 충분하다.
>
> 관련: [AGENTS.md](AGENTS.md) (디바이스 공통/식별) · [ROADMAP.md](ROADMAP.md) (OpenClaw 버전·운영 이력) · [NEXT.md](NEXT.md) (후속) · [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) (함정 카탈로그).

When a workflow mistake recurs, record it under [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) so the next session does not repeat it. Operational retrieval mistakes count too (e.g. OpenClaw release tags need a `v` prefix).

---

## Oracle is different

Oracle is a lean cloud runtime dedicated to keeping OpenClaw alive. Treat Oracle work as service reliability work. Real users depend on it including family members who cannot recover from config mistakes manually. Storage is limited — prioritize OpenClaw continuity, clean old generations, be conservative with disk growth.

Correctness starts with location awareness. On `oracle`, that awareness extends to bot survival.

---

## 1. Ownership model

### Repos in the orbit

| Repo | Path | Role |
|---|---|---|
| Private runtime SSOT | `~/openclaw/` | live `openclaw.json`, auth state, workspaces, runtime Docker files |
| Public operator / backup | `~/repos/gh/nixos-config/` | Dockerfile / compose backups, host NixOS context, operator briefs — **mother repo** |
| Public companion | `~/repos/gh/openglg-config/` | portable service stack (Caddy/Authelia/Postgres/...) + portable home-manager (`home/`) that lands on any Debian/Ubuntu host without NixOS |

Live truth lives in `~/openclaw/`. Public backup / reference lives in nixos-config. Never leak secrets or auth state into the public repo. Do not assume the public copy is live, and do not assume the live copy is publishable.

**Companion boundary (openglg-config)**: anything that must run on a non-NixOS host (cloud VPS, AVF VM, foreign machine) belongs in `openglg-config`. Anything tied to the NixOS host itself (kernel, system services, system home-manager, hardware) belongs in nixos-config. Do not duplicate state across the two — pick one home for each setting.

### What lives where

| Item | Runtime SSOT | Public repo |
|---|---|---|
| `openclaw.json` | `~/openclaw/config/openclaw.json` | never commit |
| `.env` / secrets | `~/openclaw/.env` | never commit |
| Dockerfile | `~/openclaw/Dockerfile` | `docker/openclaw/Dockerfile` backup |
| compose file | `~/openclaw/docker-compose.yml` | `docker/openclaw/docker-compose.yml` backup |
| operational docs | `~/openclaw/README.md` | summarized guidance here |

### Why nixos-config owns openclaw operations

OpenClaw upstream is a 1-person project (steipete). Documentation left there does not survive. This repo owns the Oracle machine end-to-end — disk, security, service health, budget incident prevention — so the host-container boundary is stated here:

- Host stays hard; Docker is a replaceable runtime.
- Budget incidents (past 100k KRW Gemini embedding bomb) are blocked at the host key lifecycle, not inside the container.
- Container state can always be nuked via `--force-recreate`; SSOT paths stay clear.
- Real operational failures get recorded under [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) so the next agent does not repeat them.

### ACP 제거 완료 (2026-06-10) — 이 배포에 ACP 없음

마지막 ACP 사용처였던 gemini가 **네이티브 `google-gemini-cli` provider(OAuth, Pro 쿼터)로 전환**되면서, `pi-shell-acp` plugin은 사용처 0 → `plugins.entries.pi-shell-acp.enabled=false`로 제거(acpx와 동일 패턴, 런타임 plugin 목록에서 빠짐). main의 죽은 `pi-shell-acp/*` picker 엔트리도 제거. acpx도 여전히 disabled(`plugins.entries.acpx.enabled=false` + `acp.enabled=false`).

- **현재 모든 봇이 OpenClaw 네이티브 provider/runtime**: claude-cli(main/bbot/mini), codex(glg/gpt), google-gemini-cli(gemini). third-party ACP harness 의존 0.
- 전환 서사 / 옛 pi-shell-acp stance(backend 자치권 등) / 빈응답 사건은 [ROADMAP.md](ROADMAP.md) 운영 결정 이력으로 이관.
- pi-shell-acp 엔트리는 삭제하지 않고 `enabled:false`로 남긴다 — **엔트리를 지우면 기본 로드로 복귀**하기 때문(2026-06-10 확인). 끄려면 반드시 엔트리 present + `enabled:false`.

---

## 2. Runtime shape

### Workspace mapping

- `workspace/` → main
- `workspace-glg/` → glg (힣봇)
- `workspace-gpt/` → gpt
- `workspace-gemini/` → gemini
- `workspace-mini/` → mini
- `workspace-bbot/` → bbot

Invariants: main uses `workspace/` (not `workspace-main/`); `workspace-bbot/` is a split-out B workspace.

### Model routing (현재: OpenClaw 2026.6.5 baseline)

> 버전 업그레이드 이력 / 운영 결정 연혁 (5.2→5.28, claude-cli 전환, 정공법들, 6.1 codex auth canonical migration)은 [ROADMAP.md](ROADMAP.md)로 이관. 이 섹션은 *현재 라우팅 상태*만 답한다.

**LLM 호출 — 분기**:
- **main**: Anthropic Max via canonical `anthropic/claude-opus-4-8` + `agentRuntime claude-cli` (Claude Code CLI spawn, `default_claude_max_20x` rate tier)
- **glg / gpt**: Codex OAuth ($100 plan)
- **mini**: Codex OAuth, but **직접 대화 X** — active-memory 영역 보조 lane으로 격리
- **gemini**: 네이티브 `google-gemini-cli` provider OAuth (Pro 쿼터, **API 아님** — `google/` api-key와 별개 provider). 2026-06-10 ACP→네이티브 전환

Anthropic flat-rate / Copilot 양쪽 다 안 씀 (`github-copilot` OAuth 프로필은 잔재, 미사용).

**Fallback**: 모든 봇 `fallbacks: []`. 정공법은 **안 되면 안 되는 거 — 응답 막히면 자동 fallback이 아니라 모델 자체를 바꾼다**. 자동 fallback이 부르는 quota inflation / 다른 path 소진 연쇄를 차단. 근거·이력은 [ROADMAP.md](ROADMAP.md).

**Live model IDs** (provider 접두사: `openai/*`+`agentRuntime.id=codex` = Codex OAuth, `anthropic/*`+`agentRuntime.id=claude-cli` = Claude Code CLI spawn(구독), **`google-gemini-cli/*` = Gemini 구독 쿼터(OAuth, runner=cli)** — `google/*`(api-key env `GEMINI_API_KEY`)와 **별개 provider**, 챗봇은 `google/` 절대 안 씀). **canonical 정공법(5.28, 2026-05-31)**: legacy `claude-cli/*` prefix 폐기 — provider prefix가 과금 경로를 결정(`google/`=api-key vs `google-gemini-cli/`=OAuth):

| Agent | Model | Workspace | Streaming | Active memory | 비고 |
|---|---|---|---|---|---|
| **main** | `anthropic/claude-opus-4-8` | `workspace/` | off | ✓ | `@junghan_openclaw_bot`. claude-cli runtime, Max 20x, 1M context |
| glg (가족) | `openai/gpt-5.5` | `workspace-glg/` | partial | — | `@glg_junghanacs_bot`. Codex OAuth. 2026-06-13 5.4→5.5 재승격(cross-DM 가드 완료 → 강등 사유 해소, 가족 실무 답변 품질 우선). ※ 2026-06-10 5.5→5.4 강등(cross-DM 사건 후 판단 과잉 억제·비용 1/2)의 되돌림. 기본값 변경은 신규 세션부터 적용 — 기존 DM 세션은 저장된 model 유지(`/model` 또는 세션 리셋 시 픽업). active-memory 제외(응답성 우선) |
| gpt | `openai/gpt-5.5` | `workspace-gpt/` | partial | ✓ | 개인 — 5.5 단일 봇 트라이얼 |
| **bbot** | `anthropic/claude-fable-5` | `workspace-bbot/` | off | ✓ | `@glg_b_bot`. claude-cli runtime native. 2026-06-13 opus-4-8 → **fable-5 승격**(6.6 + 번들 claude CLI 2.1.175 지원, canonical `anthropic/claude-fable-5` + `agentRuntime.id=claude-cli`). 라이브 검증 `runner=cli fallbackUsed=false` |
| mini | `anthropic/claude-sonnet-4-6` | `workspace-mini/` | off | — | sonnet 4.6 단독. active-memory 제외 검증 lane |
| **gemini** | `google-gemini-cli/gemini-3.1-pro-preview` | `workspace-gemini/` | partial | — | `@glg_gemini_bot`. **네이티브** `google-gemini-cli` OAuth(`gtgkjh@gmail.com`, **Pro 쿼터**, runner=cli). **fallback 없음**. **provider prefix가 OAuth 결정** — `google/`(api-key) 아닌 `google-gemini-cli/` 必(`auth.order.google` 핀은 cross-provider라 안 먹음). `/status` `🔑 oauth` 검증. 2026-06-10 ACP 탈출 |
| subagents | `openai/gpt-5.4` | — | — | — | active-memory recall lane은 `openai/gpt-5.4-mini`로 분리 (main lane quota 보호) |

> **claude-cli 결제 분리 원리** (운영 핵심): pi-shell-acp가 같은 Claude SDK를 wrap하면 Anthropic이 **third-party harness로 식별** → extra usage 풀 강제 → 빈 응답. OpenClaw native claude-cli runtime은 same SDK를 direct import → **Pro/Max 한도로 인식 + 1M context**. 같은 SDK라도 import 깊이 한 단계 차이로 결제 풀이 달라진다. **canonical 등록(5.28)**: model.primary/카탈로그를 `anthropic/<id>`로 두고 `{ "agentRuntime": { "id": "claude-cli" } }`를 붙이면 끝 — provider prefix `anthropic/`는 카탈로그 식별자일 뿐, runtime이 `claude-cli`면 구독 경로. legacy `claude-cli/<id>` prefix는 폐기(doctor/update가 canonical로 auto-migrate — profile 먼저 등록 필수). EPIPE·streaming off·전환 타임라인은 [ROADMAP.md](ROADMAP.md).

> **per-agent auth 함정 (oracle Docker 고유, 2026-05-31)**: Claude 쓰는 봇은 공식 login 1회 필요 — `openclaw models auth --agent <id> login --provider anthropic --method cli`(TTY, GLG 수동) → top-level `anthropic:claude-cli` 프로필 + `order.anthropic` 등록. **단 oracle은 `~/.claude`가 전 봇 공유 mount**라, login이 만든 per-agent 프로필 복사본은 frozen → 5.28 doctor가 **stale OAuth shadow**로 판정. `openclaw doctor --fix`가 per-agent 복사본을 제거하고 main의 갱신되는 auth를 inherit시킨다(제거 후에도 GREEN 확인). → 별도 host-native 레퍼런스(공유 mount 없음)의 "봇 수만큼 login 유지"와 **정반대 결론** — oracle은 login으로 기반만 깔고 doctor가 복사본을 정리. subagent는 Codex(`openai/gpt-5.4`)라 claude login은 main/bbot/mini 3봇만.

> **gemini 무응답 = OAuth 스코프-403 함정 (2026-06-13)**: gemini 봇이 조용하면 십중팔구 `google-gemini-cli` OAuth 문제다. `models status --probe`로 진단 — 토큰 `expired`/`expiring`만 보고 끝내지 말 것. 실제 막힘은 `Google Generative AI API error (403): insufficient authentication scopes [PERMISSION_DENIED]`로 뜬다(프로필은 살아있는데 발급 스코프가 모자라 거부). **fix는 재로그인 1수 — device-code + force** (headless oracle엔 브라우저 없음, GLG가 URL+코드로 수동):
> ```bash
> docker exec -it openclaw-gateway node openclaw.mjs models auth login \
>   --agent main --provider google-gemini-cli --device-code --force
> ```
> 프로필은 `main` sqlite SSOT(다른 봇이 inherit). `--force`로 스코프 깨진 기존 프로필을 비우고 새로 발급. 재로그인 후 `models status --probe`로 `google-gemini-cli/gemini-3.1-pro-preview` GREEN 확인.
>
> **절대 하지 말 것 — api-key 폴백 금지**: `GEMINI_API_KEY`(=`google` provider)는 **나노바나나2 플래시(이미지 생성) 전용**이다(line 219). gemini 챗봇을 `google/`로 돌리는 건 우회가 아니라 **오설정** — 무료 Pro 쿼터를 버리고 이미지용 키를 텍스트에 잘못 쓰는 것. probe에서 `google/gemini-2.5-flash`가 `ok`로 떠도 그건 이미지 키 경로일 뿐, 챗봇 fix가 아니다. gemini는 **OAuth 외길**, fallback 없음.
>
> **⚠️ gemini provider 이관 진행 중 — 당분간 드리프트 구조적 (2026-06-13~)**: `google-gemini-cli` provider는 **deprecation 경로**다 — gemini-cli가 사라지고 **agy(Antigravity) 기반으로 이관 예정**. 그래서 당분간 gemini 모델 prefix/provider는 **계속 흔들린다**. 구체적으로 `doctor --fix`(또는 6.6+ 업그레이드 시 자동 마이그레이션)가 gemini를 `google-gemini-cli/gemini-3.1-pro-preview` → `google/gemini-3.1-pro-preview` + `agentRuntime.id=google-gemini-cli`로 **자동 재작성하는 것을 2026-06-13 6.6 업글에서 확인**(되돌림). **운영 원칙**: ① 업글/`doctor --fix` 후 `agents list`로 gemini 모델 prefix를 **반드시 재확인**, `google/`로 바뀌어 있으면 위 "api-key 폴백 금지"대로 `google-gemini-cli/`로 되돌린다(config set primary + `config unset 'agents.list.<idx>.models["google/..."]'`). ② **단, 이건 한시적 방어다** — gemini 설정이 자꾸 바뀐다고 당황하지 말 것. "또 흔들리네"가 아니라 **"아, 그 agy 이관 사안이구나"** 하고 인지하고, 변경 내용을 이 함정 블록과 대조해 *의도된 이관인지 / 잘못된 드리프트인지* 검토한다. ③ agy 이관이 공식화되면(gemini-cli 완전 deprecate) 이 블록과 line 89/98/114/219의 `google-gemini-cli/` 전제 전체를 한 번에 재작성한다 — 그때가 진짜 이사. 그 전까지는 OAuth(`google-gemini-cli/`) 유지가 기준선.

보조 모델 (`/model <id>`로 in-thread 전환):

- `openai/gpt-5.5-pro` (977k 컨텍스트, pro tier — quota/속도 미검증)
- `deepseek/deepseek-v4-pro` / `deepseek-v4-flash` (`DEEPSEEK_API_KEY` 회사 quota, 2026-04-27~)

> 운영 컨텍스트 메모: catalog 표기가 `266k/1025k` 같은 "이론치/확장치"로 보여도 라이브 `/status`는 보통 200k로 잡힌다. 5.4 vs 5.5 컨텍스트 트레이드오프는 사실상 없음.

> Codex Plus ($100/mo) 메시지당 크레딧 (출처: developers.openai.com/codex/pricing): `5.4-mini` 2 / `5.4` 7 / `5.5` 14. 즉 **5.4-mini=0.29x, 5.5=2.0x** of 5.4. 배치 원칙: 가벼운 turn은 5.4-mini, **개인(gpt)은 5.5, 가족(glg)은 5.4**(glg 2026-06-10 5.5→5.4 강등 — cross-DM 판단 과잉 사건 후 "딱 할일만", 5.5=2x 비용 회수), active-memory recall lane은 항상 5.4-mini로 분리해 main lane quota 보호.

이미지 생성: `openai/gpt-image-2` via Codex OAuth (default since 2026-04-25). Google Imagen은 agent-directed 호출 시 사용 가능 (`GEMINI_API_KEY`로 banana/`gemini-3-flash-preview-image`). gemini 챗봇은 `google-gemini-cli/` provider prefix로 **OAuth(Pro 쿼터)만 탄다**(`/status` `🔑 oauth` 검증). `GEMINI_API_KEY`(=`google` api-key provider)는 **어떤 챗 모델도 안 가리키고** 이미지(나노바나나) 전용으로만 env 유지 — 단 이미지 경로 동작은 **미재검증**([NEXT.md §1](NEXT.md)).

ACPX + pi-shell-acp 둘 다 disabled (`plugins.entries.{acpx,pi-shell-acp}.enabled=false` + `acp.enabled=false`). pi-shell-acp는 **엔트리 지우면 기본 로드로 복귀**하니 반드시 present + `enabled:false` 유지. 재활성 절차는 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md).

라이브 값 확인:

```bash
python3 - <<'PY'
import json, pathlib
c = json.loads(pathlib.Path('~/openclaw/config/openclaw.json').expanduser().read_text())
for a in c.get('agents', {}).get('list', []):
    print(a.get('id'), a.get('model'))
PY
```

### Active memory — 현재 main/gpt/bbot 활성

운영 config:
- `agents: ["main", "gpt", "bbot"]` — 3개 활성 (glg 2026-06-09 제외: recall 훅이 가족 응답을 16~35s 지연시켜 응답성 우선으로 제거. mini/gemini 제외)
- `model: "openai/gpt-5.4-mini"` — recall lane을 mini로 분리, main lane과 OAuth quota 경합 회피
- `queryMode: "message"` + `promptStyle: "strict"` — 응답성 우선, false-positive 최소화
- `timeoutMs: 5000` + `setupGraceTimeoutMs: 30000` — Oracle ARM resource-tight cold-start 보호
- `maxSummaryChars: 220` (docs default, 한국어→영어 요약 가능), `thinking: "off"`, `persistTranscripts: false`, `logging: true`

도입 타임라인·24h 관찰 결과(latency 분포, status ok/empty 비율)는 [ROADMAP.md](ROADMAP.md) "active-memory 도입·관찰". 비활성 절차 / 함정은 [docs/openclaw-gotchas.md "비활성 — active-memory"](docs/openclaw-gotchas.md).

### Memory / embedding layers

Oracle has two disjoint recall layers. Same embedding family (Qwen3-Embedding) but model size differs since 2026-05-08 16:00 — OpenClaw moved to 8B native 4096d, andenken still on 4B 2560d (separate migration cycle).

| Layer | Provider | Model | Dim | Storage | Bot access |
|---|---|---|---|---|---|
| OpenClaw session+memory | OpenRouter | `qwen/qwen3-embedding-8b` | **4096** | `~/openclaw/config/memory/{agentId}.sqlite` (sqlite-vec + FTS5 trigram) | native `memorySearch` |
| andenken (org KB + sessions) | OpenRouter (query) / local vLLM (index) | `qwen/qwen3-embedding-4b` | 2560 | LanceDB (indexing host) | **skill needed — not deployed** |

- `agents.defaults.memorySearch.experimental.sessionMemory: true` since 2026-05-08 — sessions transcript indexing finally activated. Before that the `sources: ["sessions"]` line was being silently dropped by `normalizeSources()` because the experimental gate was closed. Verify with `openclaw memory status --agent <id>` showing `Sources: memory, sessions` and a non-zero `sessions ·` row under `By source:`.
- baseline reindex chunk 수치 이력 (5.2 → 5.7 → 8B 4096d 전환 절차 + chunk 분포 + storage)은 [ROADMAP.md](ROADMAP.md) "임베딩 baseline 전환". 현재 baseline = 8B 4096d, 총 ~4982 chunks. **재현 함정**: 8B 전환 시 `~/openclaw/config/memory/*.sqlite{,-shm,-wal}` 삭제 + restart로 schema 4096d 재생성 후 **reindex 필수**(4B↔8B 임베딩 공간 직교). OpenRouter privacy에서 8B endpoint 허용 필요(default 차단 시 "No endpoints available matching your guardrail restrictions").
- 진단: `memory status --deep --json` 의 `vector` 객체 (`enabled / storeAvailable / semanticAvailable / available / extensionPath`) — sqlite-vec 로딩과 embedding provider 별도 진단, `vec0.so` 경로 확인.
- FTS tokenizer = `trigram` for CJK. Korean particle stripping (25 particles, longest-match-first) automatic in query expansion.
- `~/org:/home/node/org:ro` is for file access (denotecli / bibcli / botlog), not embedding. Do not remove.
- andenken layer is still separate by *storage* (LanceDB vs sqlite), *corpus* (org KB vs OpenClaw sessions/memory), and **since 2026-05-08 16:00 also by *model*** (4B vs 8B) until andenken follows. To give bots semantic org search, deploy the `semantic-memory` skill from `~/repos/gh/agent-config/skills/` with LanceDB reachable from Oracle — but cross-store retrieval will be slightly miscalibrated until both layers share a model again.
- This baseline is the comparison point for andenken bake-off (first-result precision, freshness, CJK short query, operator trust). OpenClaw is SSOT; andenken follows.

### Mount permission model (since 2026-04-25)

The `ro`/`rw` boundary was widened to reduce host-hop friction for agent edits. Rollback safety relies on git, not on filesystem enforcement.

| Area | Mode | Rollback surface |
|---|---|---|
| `~/repos/gh` | **rw** | git (each repo). `git status` surfaces unintended writes immediately. |
| `~/repos/3rd` | rw | git + "third-party, disposable" nature |
| `~/repos/work` | ro | intentional — company code never modified through bot hand |
| `~/org` (root) | ro | protects `diary.org`, `archives/`, `authinfo.gpg`, etc. |
| `~/org/botlog`, `~/org/llmlog` | rw | bot activity output — always rw |
| `~/org/meta`, `~/org/bib`, `~/org/notes` | **rw** | new; git-managed (`~/org` is a Denote git repo). |

**Post-deploy habit**: after a rw-expanding change, monitor each affected repo's `git status` for the first hour. Unintended writes in `~/org/diary.org` or other `:ro` regions should be impossible — if you see one, the mount config regressed.

---

## 3. Env / secret SSOT

Budget-safe key lifecycle is part of host survival. Past incident: 100k KRW Gemini embedding bomb.

### Key flow

```
~/.env.local              ← host SSOT (export form, budget-controlled)
    ↓  (value sync)
~/openclaw/.env           ← Docker env_file
    ↓  (container start)
openclaw-gateway env
```

`~/.env.local` is the master. Only budget-capped keys go there. On compromise: revoke in Google Cloud Console → clear from `.env.local` → sync to `~/openclaw/.env`.

### docker compose env precedence

When `docker-compose.yml` has `GEMINI_API_KEY=${GEMINI_API_KEY}`:

1. **shell env wins** — if the shell that ran `docker compose` has it set, that value is injected.
2. Otherwise the `env_file:` file is used.
3. Else, empty.

Implication: if `docker compose up` runs from a shell that never sourced `.env.local`, the `~/openclaw/.env` value is used. Shell-state dependence is fragile, so **keep `~/openclaw/.env` identical to `.env.local`** at all times.

### Reflection rules

| Action | Picks up new env? |
|---|---|
| `docker compose restart` | **No** — reuses existing container env |
| `docker compose up -d --force-recreate` | **Yes** — required when env changed |

### Bomb prevention

- Set a Google Cloud billing cap (e.g. $10/month) before putting a new Gemini key in `.env.local`.
- Keep only budget-controlled keys in `.env.local`.
- Do not leave a revoked key in `~/openclaw/.env` while the new key lives only in `.env.local` — shell state will silently flip the container between the two on restart. Sync both files.
- **Same variable name does not mean same value.** `~/.env.local` and `~/openclaw/.env` can both have `OPENROUTER_API_KEY=...` with *different* values pointing at different OpenRouter accounts or different privacy policies. Verify with suffix-4 comparison (no secret leak), e.g. `${KEY:0:8}...${KEY: -4}` from each source. 2026-05-08 incident: host `~/.env.local` had a working key (...0304) but `~/openclaw/.env` had a different key (...5fe4) blocked by OpenRouter privacy policy → all six agents failed `memory index` with `404 No endpoints available matching your guardrail restrictions`. Sync both *and* sanity `curl /embeddings` from inside the container before reindex.

### Secret inventory

| Var | Use | Source |
|---|---|---|
| `OPENROUTER_API_KEY` | memorySearch embedding (Qwen3-Embedding-8B 4096d, all agents), web search (perplexity) | `~/.env.local` SSOT → `~/openclaw/.env` (sync values, not just names) |
| `GEMINI_API_KEY` | image generation only (banana / `gemini-3-flash-preview-image`). **Not** memorySearch since 2026-05-08 (replaced by OpenRouter Qwen3) | `~/.env.local` SSOT |
| `GROQ_API_KEY` | active-memory primary (currently disabled) | `~/.env.local` SSOT |
| `TELEGRAM_BOT_TOKEN_*` | per-bot Telegram | `~/openclaw/.env` (gitignore) |
| `OPENAI_CODEX_*` | Codex OAuth — actual LLM serving for all agents (Anthropic flat-rate blocked, Copilot disabled) | `~/openclaw/.env` (gitignore) |

---

## 4. Operational workflow

### Warn = Error — every gateway warning must be investigated

Treat **every** OpenClaw gateway WARN as an Error until proven harmless. Silent retry loops have no log signature and look identical to "idle" CPU activity from the outside. The cost of investigating a warn is minutes; the cost of letting one ride through an upgrade can be hours of family-bot downtime.

이 원칙을 낳은 구체 사건(4.24 task registry / bonjour silent loop)은 [docs/openclaw-gotchas.md "역사 — Warn = Error 원칙의 근거"](docs/openclaw-gotchas.md)에 박제. 다음 함정만 운영 절차로 남긴다:

- Any `database disk image is malformed` on **any** SQLite under `~/openclaw/config/`: do not assume a single corruption. Run integrity check across the set:

  ```bash
  for f in ~/openclaw/config/tasks/runs.sqlite \
           ~/openclaw/config/memory/*.sqlite \
           ~/openclaw/config/flows/registry.sqlite; do
    [ -f "$f" ] && echo "$(basename $f): $(sqlite3 "$f" 'PRAGMA integrity_check;' 2>&1 | head -1)"
  done
  ```

  `runs.sqlite` and `flows/registry.sqlite` are ephemeral — safe to delete. Per-bot `memory/*.sqlite` carry workspace recall and should be repaired (`.dump` + reload) rather than deleted if possible.

Operational rule:

1. On any gateway WARN, before declaring the gateway "ready", re-read the WARN line aloud in the upgrade log.
2. Decide explicitly: harmless / suspect / critical. No "we'll see" answers.
3. If suspect or critical, file a TODO in `~/sync/org/llmlog/` with the exact warn text and a hypothesis — do not just close the terminal.

The 4.24 cycle paid in user-visible bot downtime for two warns ignored over the prior cycles. The cost of this rule is one extra minute per upgrade.

### Change policy for OpenClaw behavior

Prioritize continuity over elegance.

- Change the default model only when that is the real need.
- Do not silently delete old model entries because the default changed.
- Preserve manual reversibility for the operator.
- Do not introduce failover unless explicitly requested.
- Test real execution, not just config syntax.

Family-facing bots: avoid workflows that require manual model switching unless the operator explicitly chose ACP for that conversation. Prefer the least-surprising behavior. Optimize for stable replies.

### Approval / exec policy

NixOS host + Docker isolation already provide the safety boundary. Disabling approval prompts that block normal operation is acceptable. Keep bot interaction smooth; verify post-change behavior with real bot tests. Do not stop at `docker ps` for behavior-sensitive changes — a live reply test is required.

### Upgrade workflow

Discussion-first. Do not upgrade blindly.

1. Inspect current live version.
2. Read `~/openclaw/README.md` change history.
3. Fetch upstream release / compare pages.
   - `https://github.com/openclaw/openclaw/releases/tag/v<version>`
   - `https://github.com/openclaw/openclaw/compare/v<from>...v<to>`
4. Identify what matters for this deployment: embeddings, memory search, Telegram, sessions, auth, approval prompts, runtime compatibility.
5. Predict likely breakage before touching anything.
6. Update runtime files in `~/openclaw/`.
7. Validate the bots with real prompts.
8. Sync public-safe Dockerfile / compose into `nixos-config/docker/openclaw/`.
9. Commit both repos. 업그레이드 결과는 [ROADMAP.md](ROADMAP.md)에 사이클로 박는다.

### Restart vs recreate

| Change | Action |
|---|---|
| `openclaw.json` | restart |
| Dockerfile content | rebuild + recreate |
| `docker-compose.yml` service config | restart (usually) |
| OpenClaw version (base image) | `docker compose build --pull` + `up -d --force-recreate` |
| Volume mounts (`~/.claude`, compatibility symlinks, skill overlays) | **recreate required** |
| Env variables | **recreate required** |
| Adding / removing skill directories | restart |
| workspace text files (`AGENTS.md`, `SOUL.md`, `USER.md`, `MEMORY.md`) | none |
| SKILL.md content only | none |

Recreate command:

```bash
cd ~/openclaw && docker compose up -d --force-recreate openclaw-gateway
```

### Validation after any OpenClaw change

- container health (`docker ps` + `docker inspect ... Health.Status`)
- gateway ready line in logs
- real-prompt tests against affected agents
- Telegram-facing bots still answer
- family-facing bots still behave as expected

### Commit policy

Commit both layers when work spans them:
- `~/openclaw/` for live operational changes (runtime docs, Dockerfile, compose — never `openclaw.json` / `.env`)
- `nixos-config/` for public structure / docs / backups

Stamp every commit with agenda and Google Chat notification per the convention in `~/.pi/agent/skills/pi-skills/agenda/scripts/agenda-stamp.sh`.

---

## 5. Skills deployment

```
agent-config (SSOT)
  └── pi-skills/ (source + build)
        ↓ git pull on Oracle
~/pi-skills/ (Oracle local)
        ↓ run.sh k)
~/openclaw/config/workspace*/skills/ (per-bot deploy)
```

Operator entrypoint: `run.sh k)` (Oracle only).

### Inventory

| Class | Skills | Notes |
|---|---|---|
| npm (bundled `node_modules`) | brave-search, youtube-transcript, medium-extractor, transcribe, summarize | copy whole tree |
| CLI (binary / shell) | denotecli, ghcli, bibcli, gogcli, gitcli, lifetract, dictcli | exclude `node_modules` |

### Per-agent policy

모든 봇 동일 스킬 (2026-05-09부터). 봇 직관 우선 — agenda/commit/botlog 같은 turn-routine 스크립트는 모든 봇이 자기 `workspace/skills/`에서 찾을 수 있어야 한다. mini 최소 정책(`MINI_SKILLS=(denotecli)`)은 issue #6에서 보고된 mini 봇 stamp 실패 사례로 폐기.

| Agent | Workspace | Skill scope |
|---|---|---|
| main | `workspace/` | all |
| glg | `workspace-glg/` | all |
| gpt | `workspace-gpt/` | all |
| gemini | `workspace-gemini/` | all |
| mini | `workspace-mini/` | all |
| bbot | `workspace-bbot/` | all |

### Deployment rules

- `run.sh k)` installs to `main` first, then rsyncs to glg / gpt / gemini / mini / bbot, then syncs to `claude-skills/`.
- Adding or removing skill directories requires a gateway restart.
- SKILL.md content-only changes load dynamically (no restart).
- Go binaries are built for arm64 in pi-skills and deployed outside git.

### Workspace skills vs Claude native skills

Two separate systems that do not auto-sync.

- `workspace*/skills/` — OpenClaw workspace skill system.
- `~/.claude/skills` — Claude ACP sessions discover skills here.

Current workaround on Oracle: `config/claude-skills/` is mounted to `/home/node/.claude/skills` for ACP sessions. `claude-skills/` is a union of `agent-config/skills` and `workspace-bbot/skills`. `~/.claude` must be **rw** (Claude writes `session-env/` and `projects/`). Long-term path: MCP bridge exposing workspace skills as tools so the overlay becomes unnecessary.

---

## 6. Gotchas

운영 중 자주 부딪히는 함정 + incident 정책 근거는 별도 파일로 분리:

→ [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md)

활성 (현재 deployment에 적용) / 비활성 (재활성 시 참고) / 역사 (resolved/superseded) 카테고리.

대표 항목:

- **활성**: bonjour disable, 비-default 모델 추가 절차, rw mount 롤백, Codex catalog drift, dreaming heartbeat decoupling, ACP common failures, **키 매핑 함정 (같은 변수명·다른 값)**
- **비활성**: active-memory (disabled since 5.2), ACPX 4건 (disabled since 5.2)
- **역사**: Warn=Error 원칙 근거 (4.24 task registry/bonjour), 4.24→4.26/4.29 lazy-staging (resolved on 5.2), latency regression (superseded), GlueClaw injection (provider deleted)

---

## 7. Commands (oracle / openclaw)

```bash
# live OpenClaw agent models
python3 - <<'PY'
import json, pathlib
c = json.loads(pathlib.Path('~/openclaw/config/openclaw.json').expanduser().read_text())
for a in c.get('agents', {}).get('list', []):
    print(a.get('id'), a.get('model'))
PY

# restart vs recreate
cd ~/openclaw && docker compose restart openclaw-gateway
cd ~/openclaw && docker compose up -d --force-recreate openclaw-gateway   # env / mount changes

# OpenClaw upgrade (image rebuild + recreate)
cd ~/openclaw && docker compose build --pull openclaw-gateway && docker compose up -d --force-recreate openclaw-gateway

# upstream release / compare
# https://github.com/openclaw/openclaw/releases/tag/v<version>
# https://github.com/openclaw/openclaw/compare/v<from>...v<to>
```

> 공통 명령(device & time, nixos-rebuild, operator menu)은 [AGENTS.md](AGENTS.md) Commands.
