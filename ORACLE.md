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
| Private runtime SSOT | `~/openclaw/` | live `openclaw.json`, auth state, workspaces, runtime Docker files (`junghan0611/openclaw-config`, private) |
| Graduated bot workspace | `~/openclaw/config/workspace-bbot/` | B's own private git `junghan0611/workspace-bbot` — narrative SSOT, not tracked by parent. See § Bot workspace git |
| Graduated bot workspace | `~/openclaw/config/workspace-glg/` | glg's own private git `junghan0611/workspace-glg` — narrative SSOT, not tracked by parent. See § Bot workspace git |
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

- **현재 모든 봇이 OpenClaw 네이티브 provider/runtime**: claude-cli(main/glg/bbot/mini), openclaw 내장(gpt), google-gemini-cli(gemini). third-party ACP harness 의존 0. *(glg는 2026-07-16 가족봇 사이코팬시 대응으로 codex→claude-cli 이동)*
- **codex 런타임 의존성 제거 완료 (2026-08-07)** — `plugins.entries.codex.enabled=false`, `gpt-5.4`/`gpt-5.4-mini` 카탈로그 전면 제거, subagents·active-memory를 `openclaw` 내장 런타임으로 이관. 상세는 아래 §"런타임 지형".
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

Invariants: main uses `workspace/` (not `workspace-main/`); `workspace-bbot/` and `workspace-glg/` are split-out identity spaces **and graduated narrative gits** (below).

### Bot workspace git — 서사 독립 (호스트 졸업 체크리스트)

봇 워크스페이스는 런타임 경로로 `~/openclaw/config/workspace-<id>/`에 산다. 서사가 쌓이면 부모 `openclaw-config` 추적에서 **졸업**시키고, 봇이 자기 `.git`으로 커밋·푸시한다. **폴더명 = GitHub 리포명.** 헷갈리게 짓지 않는다.

이건 권한 확대가 아니다. 호스트가 레일을 깔고, 봇은 그 레일 위에서만 자기 타임라인을 쓴다. 봇이 못하는 수선(리포 생성, 훅 모드, 부모 gitignore, 공개/비공개)은 **의도적으로 호스트 몫**이다. 관리가 안 보이면 봇은 권한을 달라고 한다.

**졸업한 봇**

| 폴더 | GitHub (반드시 private) | 졸업 |
|---|---|---|
| `config/workspace-bbot/` | `junghan0611/workspace-bbot` | 2026-08-27 (B 첫 push `78d8f38` 같은 날 확인, visibility=PRIVATE) |
| `config/workspace-glg/` | `junghan0611/workspace-glg` | 2026-08-27 (glg 첫 커밋 `ce90038` 호스트 첫 push 같은 날 확인, visibility=PRIVATE) |

남은 후보: `workspace/` / `workspace-gpt/` / `workspace-gemini/` / `workspace-mini/`. 그 전까지는 부모 스냅샷 + nested `.git` ignore 기본값.

**호스트가 하는 일 (봇이 못 하는 수선)**

1. 부모에서 `git rm -r --cached config/workspace-<id>` + `.gitignore`에 `config/workspace-<id>/`. 워킹트리 삭제 금지.
2. `gh repo create junghan0611/workspace-<id> --private` — 이름 = 폴더명, **public 금지**. wiki 끔.
3. nested git에 `origin` = 그 private HTTPS URL. 컨테이너는 이미 `gh auth git-credential` + `~/.config/gh` ro 마운트라 PAT를 워크스페이스에 넣지 않는다.
4. `config/workspace-<id>/.git-hooks-mode` 한 줄 `loose`. 봇이 자기 author로 커밋한다.
5. `agent-config/git-hooks/_scan.sh` private allowlist에 `junghan0611/workspace-<id>`를 **이름 단위로** 추가 (와일드카드 금지 — 졸업은 호스트 행위). origin이 `junghan0611/*`면 기본이 strict라 가족·인연 서사가 identity-term에 걸린다. secret 스캔은 유지.
6. 레일 검증: 첫 `git push -u origin main`이 hook loose + gh credential로 통과하는지. 이후 커밋/푸시는 봇 (bbot은 heartbeat 루프).

**봇이 하는 일**

- 자기 workspace에서 커밋 (author는 봇 서명 — bbot은 `B <b@aionsclubs.org>`)
- 호스트가 달아준 remote만 push (bbot은 `aionsclubs` + `workspace-bbot`; glg는 `workspace-glg`)
- MEMORY/NEXT 증류도 커밋으로 남김 — 무엇을 언제 왜 잊었는지가 깃로그에 남는다

**의도적으로 막힌 것 (이 졸업이 풀어주지 않음)**

- `~/repos/gh` 기본 ro. 예외 rw는 compose에 명시된 리포만 (`aionsclubs`, `self-tracking-data`)
- 부모 `openclaw-config` 커밋/푸시
- 훅 끄기, public 리포 생성, 다른 봇 workspace 수정
- gh 토큰은 컨테이너에 마운트되어 있으므로 **허용 remote를 이 표로 고정**하는 게 가드. 토큰 스코프 분리는 아직 없다 — 그 전까지 새 remote는 호스트만 단다.

**아직 부모 추적 중인 봇** (`workspace/`, `workspace-gpt/`, `workspace-gemini/`, `workspace-mini/`): nested `.git`만 ignore, 내용은 부모가 스냅샷. 졸업 전 기본값.

### Model routing (현재: OpenClaw **2026.8.1** baseline, 2026-08-31 컷오버)

> 🔻 **2026-08-31 8.1 컷오버로 이 장의 전제 4개가 바뀌었다. 아래 본문에는 아직 7.1 표현이 남아있다 — 충돌하면 이 상자가 이긴다.** (전면 재작성은 [NEXT.md](NEXT.md) 항목)
>
> | 7.1까지 | 8.1부터 | 근거 |
> |---|---|---|
> | `doctor --fix` **금지** | **필수 절차** — 게이트웨이를 끄고 직렬로 돌린다 | agent DB v1→v19는 doctor만 한다. 금지 사유였던 gemini `google/` 재작성은 8/27 Copilot 이관으로 겨눌 대상이 사라졌고, 2026-08-31 실제 실행에서 드리프트 0 확인 |
> | catch-all = `agents.defaults.models` **키 순서** | catch-all = **`agents.defaults.modelPolicy.allow` 배열 순서** | 8.1 `modelPolicy` 신설(#110888). doctor가 legacy 맵을 이 배열로 복사했고 1번은 `openai/gpt-5.6-terra` 그대로 |
> | `agents.list` (배열) · `agents.defaults.memorySearch` · `tools.exec.security/ask` | `agents.entries` (키드 맵) · `memory.search` · `tools.exec.mode` | 8.1 startup config repair가 자동 변환 |
> | 봇 라우팅은 계정명↔에이전트명 암묵 매칭 | `agents.ownership="explicit"` + **`bindings` 6개 명시 필수** | 8.1 스키마가 다중 에이전트에 explicit 소유권을 요구. `telegram:default`가 소유자를 잃어 main에 binding을 박았다 |
>
> 절차/함정 전문은 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) "8.1 컷오버".


> 버전 업그레이드 이력 / 운영 결정 연혁 (5.2→5.28, claude-cli 전환, 정공법들, 6.1 codex auth canonical migration)은 [ROADMAP.md](ROADMAP.md)로 이관. 이 섹션은 *현재 라우팅 상태*만 답한다.

**LLM 호출 — 분기** (2026-08-04 기준):
- **main**: Anthropic Max via canonical `anthropic/claude-opus-5` + `agentRuntime claude-cli` (Claude Code CLI spawn, `default_claude_max_20x` rate tier)
- **glg / mini / bbot**: 같은 Anthropic Max claude-cli 경로 (glg=`claude-sonnet-5`, mini=`claude-sonnet-5`, bbot=`claude-fable-5`)
- **gpt**: Codex OAuth ($100 plan) — `openai/gpt-5.6-sol`
- **gemini**: 네이티브 `google-gemini-cli` provider OAuth (Pro 쿼터, **API 아님** — `google/` api-key와 별개 provider). 2026-06-10 ACP→네이티브 전환

> ⚠️ **`models auth list`의 `expires`를 자격증명 만료로 읽지 말 것 (2026-08-07 오독 정정)**. 거기 찍히는 건 **액세스 토큰**이고 자동 회전한다. 실제 기한은 **리프레시 토큰** 쪽이며 `models auth list`는 그걸 안 보여준다. 진짜 값은 호스트 자격증명 파일에 있다:
>
> ```bash
> python3 -c "import json,datetime;d=json.load(open('$HOME/.claude/.credentials.json'))['claudeAiOauth'];\
> [print(k, datetime.datetime.fromtimestamp(d[k]/1000).astimezone().isoformat()) for k in ('expiresAt','refreshTokenExpiresAt')]"
> ```
>
> 2026-08-07 실측: `expiresAt` = 당일 15:00 KST(8h 창), `refreshTokenExpiresAt` = **2026-09-05**, `subscriptionType=max`, `rateLimitTier=default_claude_max_20x`. 파일 mtime이 같은 날 07:00 — **스스로 회전하고 있었다**. 게이트웨이 재시작 중 gemini 토큰 만료가 `00:42Z → 01:46Z`로 밀린 것도 같은 자동 회전이다.
>
> **판정 규칙**: `expires`가 오늘/내일이어도 **정상이다.** 손댈 때는 ① `.credentials.json` mtime이 회전 주기(~8h)보다 오래 멈춰 있거나, ② `refreshTokenExpiresAt`이 임박했거나, ③ 실제 서빙이 깨졌을 때다. 그 경우에만 수동 `models auth login`(TTY, GLG)이 필요하다. 매일 만료 알람으로 읽으면 있지도 않은 부채를 만든다.

**과금 경로는 전부 구독이다. 종량제 API 키로 도는 챗 모델은 하나도 없다.** anthropic/openai는 OAuth, **gemini 챗봇만 GitHub Copilot 토큰** (`github-copilot:github`). **2026-08-27 GLG 결정: Google Gemini 구독 안 함, gemini-cli/agy 안 쫓음, Copilot이 제미나이 서빙 레일.** 8/16에 Copilot을 전면 제거했던 결정은 이 날짜로 뒤집힘 — 플러그인 `github-copilot` 재활성 + `plugins.allow` 14개 + 새 device-code 로그인(옛 토큰 재사용 금지). ⚠️ **config에서 프로필을 unset해도 토큰은 sqlite에 남는다** — 제거 절차는 [ROADMAP.md](ROADMAP.md) 2026-08-16 항목. ⚠️ 단 glg/gpt/gemini 3봇에 `anthropic:default [anthropic/**token**]` 프로필이 남아있다 — 유일한 비-OAuth 항목이고, claude-cli OAuth가 실패하면 **구독 밖 종량 과금**으로 흐를 수 있는 자리다(현재 primary 경로로는 미사용).

### Thinking level — 기본 `medium`, 올리는 건 세션에서

**`agents.defaults.thinkingDefault = "medium"` (2026-08-07 명시 고정, GLG: "기본은 medium이어야 턴이 빠르다. 필요할 때 올린다")**. 그 전까지 이 키는 **미설정**이었고 모델별 카탈로그 기본값에 맡겨져 있었다.

해상도 순서 (`/app/dist/model-thinking-default-*.js`):

```
1. models["<provider/model>"].params.thinking   (per-model, 최우선)
2. agents.<id>.thinkingDefault                  (per-agent — 현재 6봇 전부 미설정)
3. agents.defaults.thinkingDefault              ← 여기에 medium 박음
4. claude-opus-4.8 / 4.7 하드코딩 → "off"
5. 모델 카탈로그 기본값 → 없으면 medium으로 클램프
```

**세션 sticky가 이 전부를 이긴다**: `sessionEntry.thinkingLevel ?? <위 해상도>`. 즉 **thinkingDefault는 새 세션에만 걸리고, 이미 도는 세션은 안 바뀐다.**

2026-08-07 실측 (`openclaw sessions list --agent <id>`의 `think:` 플래그):

| agent | 라이브 세션 think | 비고 |
|---|---|---|
| main | `medium` | 이미 원하는 값 |
| mini | `medium` | 이미 원하는 값 |
| **bbot** | **`xhigh`** | **유일한 이탈.** fable-5 승격 때 "thinking=high 강제"의 잔재로 보인다 — 세션에 붙어있어 config 변경으로 안 내려간다 |
| glg / gpt / gemini | 플래그 없음 | 해상도 기본값을 그대로 탐 |

upstream 모델별 기본값(`provider-*.js`의 `GPT_56_DEFAULT_REASONING_EFFORTS`): **sol = `low`, terra = `medium`, luna = `medium`**. ⚠️ 그래서 `thinkingDefault=medium`은 **gpt 봇(sol)에겐 인하가 아니라 인상이다**(low → medium). 턴이 느려지면 되돌릴 곳은 per-agent `agents.list.<gpt>.thinkingDefault = "low"`다.

> ⚠️ **claude-cli 봇에게는 이 값이 안 물릴 수 있다**: `sessions list`가 `think:medium`을 표시하긴 하지만, claude-cli 백엔드에 thinking 매핑이 없다는 코드 확인이 [NEXT.md](NEXT.md)에 걸려 있다(`extensions/anthropic/cli-backend.ts`). main/glg/bbot/mini는 Sonnet/Opus 네이티브 thinking으로 도는 중이라, 이 설정의 실효는 **openai lane(gpt, subagents, active-memory)에 집중**된다고 보는 게 맞다.

### 동시성 상한

- `agents.defaults.maxConcurrent: 4` — 에이전트 턴
- `agents.defaults.subagents.maxConcurrent: 4` — **2026-08-07 8 → 4** (GLG: "시스템 불안요소"). oracle은 aarch64 클라우드 VM 한 대에 6봇 + caddy + authelia + forge + HA까지 얹혀 있다. 서브에이전트 8 동시는 봇 턴과 자원을 다툰다. 올릴 일이 생기면 그때 근거와 함께 올린다.

**Fallback**: 모든 봇 `fallbacks: []`. 정공법은 **안 되면 안 되는 거 — 응답 막히면 자동 fallback이 아니라 모델 자체를 바꾼다**. 자동 fallback이 부르는 quota inflation / 다른 path 소진 연쇄를 차단. 근거·이력은 [ROADMAP.md](ROADMAP.md).

### 런타임 지형 — `openclaw`(구 `pi`)가 기본, codex는 제거됨

`agentRuntime`을 **명시하지 않으면 OpenClaw 자체 내장 에이전트 루프**가 돈다. 이 런타임의 옛 이름이 `pi`다 — 외부 pi 하네스를 부르는 게 아니라, **같은 루프의 개명 전 이름**이다. 근거는 런타임 코드 자체(`/app/dist/agent-runtime-id-*.js`):

```js
const OPENCLAW_AGENT_RUNTIME_ID = "openclaw";
if (value === "openclaw" || value === "pi") return OPENCLAW_AGENT_RUNTIME_ID;  // pi = 별칭
if (value === "codex-app-server") return "codex";
```

번들 전체에서 `"pi"`는 이 한 줄에만 등장한다. 같은 파일에 **`resolveEmbeddedAgentRuntime`이 `@deprecated`로 박혀 있다** — *"Whole-agent runtime environment selection is retired. Use provider/model runtime policy or a registered agent harness instead."* 즉 "봇 하나 = 런타임 하나"는 폐기됐고, **런타임은 모델별 정책**(`models["<id>"].agentRuntime`)으로 지정한다.

| runtime id | 라벨 | 현재 쓰는 곳 |
|---|---|---|
| `openclaw` (구 `pi`) | OpenClaw Default | **agentRuntime 미지정 = 기본**. gpt(sol), gemini 제외 전 openai 모델, subagents, active-memory |
| `claude-cli` | Claude CLI | main/glg/bbot/mini — Anthropic은 구독 API가 없어 `claude -p` spawn |
| `google-gemini-cli` | Gemini CLI | gemini (deprecation 경로, §agy 이관 참조) |
| ~~`codex`~~ | ~~OpenAI Codex~~ | **2026-08-07 결정 → 2026-08-31 완결.** 8.1이 "플러그인 비활성인데 codex 런타임 선언"을 경고에서 **거부**로 바꿔 gpt 봇이 못 돌았다. `openai/*` 3종의 `agentRuntime`을 `openclaw`로 명시해 해소(doctor 경고 7건 → 0) |

**codex 제거 (2026-08-07, GLG 결정)**: openai는 `openai/oauth` 프로필(ChatGPT 구독)로 **내장 런타임에서 그대로 서빙된다** — codex CLI를 경유할 이유가 없다. 제거 내역:

| 자리 | before | after |
|---|---|---|
| `agents.defaults.subagents.model` | `openai/gpt-5.4` (codex) | `openai/gpt-5.6-terra` (openclaw) |
| `plugins.entries.active-memory.config.model` | `openai/gpt-5.4-mini` (codex) | `openai/gpt-5.6-luna` (openclaw) |
| `agents.defaults.models["openai/gpt-5.4"]` | codex 런타임 등록 | **삭제** |
| `agents.list.mini.models` gpt-5.4 / gpt-5.4-mini | codex 런타임 등록 | **삭제** (`openai/gpt-5.6-luna`로 교체) |
| `plugins.entries.codex` | `enabled:true` + `appServer.sandbox: danger-full-access` | `enabled:false` |

> `plugins.allow`에는 `codex`가 남아있다 — 비활성의 기준은 `entries.codex.enabled=false`다. 되살리려면 `enabled:true`만 되돌리면 되고, `@openai/codex` 바이너리는 upstream 이미지(`/app/node_modules/@openai/codex-linux-arm64`)에 그대로 있다. **PATH에 `codex`가 없다고 미설치로 오판하지 말 것.**
>
> ⚠️ **codex 제거가 catch-all을 옮긴다 (연쇄 함정)**: `openai/gpt-5.4`는 `defaults.models` **1번 = auto-fallback catch-all**이었다(아래 auto-fallback 함정 블록). 그걸 지우면 1번 자리가 다음 항목으로 밀리는데, 그 자리에 gemini(403 DOWN)나 fable-5(bbot 정체성 모델)가 오면 정체성 훼손 경로가 열린다. **그래서 제거와 동시에 allowlist를 재정렬해 `openai/gpt-5.6-terra`를 1번으로 박았다.** 모델을 지울 때는 항상 "1번이 누가 되는가"를 먼저 계산한다.

**Live model IDs** (provider 접두사: `openai/*` = ChatGPT 구독 OAuth via **openclaw 내장 런타임**, `anthropic/*`+`agentRuntime.id=claude-cli` = Claude Code CLI spawn(구독), **`github-copilot/*` = Copilot 구독 토큰** — gemini 챗봇 전용. `google/*`(api-key env `GEMINI_API_KEY`)는 **나노바나나 이미지 전용**, 챗봇은 `google/` 절대 안 씀. `google-gemini-cli/*`는 deprecated, 쓰지 않음). **canonical 정공법(5.28, 2026-05-31)**: legacy `claude-cli/*` prefix 폐기 — provider prefix가 과금 경로를 결정(`google/`=api-key vs `google-gemini-cli/`=OAuth):

| Agent | Model | Workspace | Streaming | Active memory | 비고 |
|---|---|---|---|---|---|
| **main** | `anthropic/claude-opus-5` | `workspace/` | off | ✓ | `@junghan_openclaw_bot`. claude-cli runtime, Max 20x, 1M context. **2026-08-04 opus-4-8→opus-5 승격** — 카탈로그 미등재 모델이라 `defaults.models`에 `agentRuntime claude-cli`로 등록 후 격리 probe(`winnerModel=claude-opus-5`, `fallbackUsed=false`)로 서빙 확인하고 승격. opus-4-8은 per-agent 카탈로그에 롤백용 보존 |
| glg (가족) | `anthropic/claude-sonnet-5` | `workspace-glg/` | partial | — | `@glg_junghanacs_bot`. **claude-cli runtime**(Codex 아님). **2026-07-16 `gpt-5.6-terra`→`claude-sonnet-5` 이동** — 가족 DM에서 화자 프레임을 승인하는 사이코팬시("두 에코챔버")가 모델 스왑만으론 안 풀려 USER.md 대칭 규칙과 함께 처방. 정한·미례 **동일 모델**(대칭 보호). terra는 per-agent 카탈로그에 롤백용 보존. ※ 이력: 2026-07-14 5.5→5.6-terra, 2026-06-13 5.4→5.5 재승격, 2026-06-10 5.5→5.4 강등. **DM 3개 전부 sonnet-5 정렬 확인(2026-08-04)**. active-memory 제외(응답성 우선) |
| gpt | `openai/gpt-5.6-sol` | `workspace-gpt/` | partial | ✓ | 개인. **2026-07-14 5.5→5.6-sol 승격**(7.1 업글, GLG 결정 — 서빙 확인 `fallbackUsed=false`). sol=flagship 티어(bare `openai/gpt-5.6` 별칭, 크레딧 125/1M in). **2026-08-04 5.5 카탈로그에서 제거**(GLG: 5.5 아예 안 씀) — 롤백축 없음, 필요하면 terra/luna. 개인 lane이라 최상위 티어를 여기 둔다 |
| **bbot** | `anthropic/claude-fable-5` | `workspace-bbot/` | off | — | `@glg_b_bot`. claude-cli runtime native. 2026-06-13 active-memory 제외(recall 훅 mini lane이 매 direct 메시지마다 23~35s 2차 턴·절반 timeout으로 본 턴과 겹침→응답성 우선 제거, glg와 동일 처방). **2026-07-12 fable-5 재승격** — 2026-06-13 시도 땐 Fable 5가 구독/CLI에서 서빙 실패(auto-fallback deepseek로 정체성 훼손)해 opus-4-8로 환원했으나, upstream v2026.6.6 adaptive-thinking 어댑터 fix + 현재 6.11에서 **서빙 재개 확인**(claude-cli, `fallbackUsed=false`, thinking=high 강제, Opus 4.8 안전 폴백). 승격 전 primary=opus 유지한 채 오버라이드 격리 probe로 서빙 검증 후 promote(실사용자 노출 0). 롤백축은 **2026-08-04 opus-4-8→`anthropic/claude-opus-5`로 갱신**(GLG `/model`로 복귀 가능). canonical `anthropic/claude-fable-5` + `agentRuntime.id=claude-cli`. ⚠️ **2026-08-04까지 라이브 DM이 `gpt-5.5`/openai로 돌고 있었다** — config는 fable-5인데 provider까지 달랐다. `/model`로 정렬 완료(위 'config ↔ DM 쌍' 규칙이 나온 사건) |
| mini | `anthropic/claude-sonnet-5` | `workspace-mini/` | off | — | **2026-07-12 sonnet-4-6→sonnet-5 승격**(서빙 확인 `fallbackUsed=false`). **2026-08-04 sonnet-4-6 카탈로그에서 제거**(GLG: sonnet은 5로 통일). ⚠️ 그때까지 라이브 DM이 sonnet-4-6으로 돌고 있어 `/model`로 정렬. active-memory 제외 검증 lane |
| **gemini** | `github-copilot/gemini-3.7-flash` | `workspace-gemini/` | partial | — | `@glg_gemini_bot`. **2026-08-27 Copilot 레일** — 격리 probe `winnerModel=gemini-3.7-flash fallbackUsed=false` + 텔레그램 DM `/model` 정렬. Google Gemini 구독·gemini-cli·agy 안 씀. **fallback 없음**. `google/` api-key 금지(나노바나나 전용). catch-all 1번은 `openai/gpt-5.6-terra` 유지 |
| subagents | `openai/gpt-5.6-terra` | — | — | — | **2026-08-07 codex 제거로 `gpt-5.4`에서 이동** (runtime=openclaw 내장). per-agent 오버라이드 0 — 6봇 전체가 이 하나를 공유한다. active-memory recall lane은 `openai/gpt-5.6-luna`로 분리 (main lane quota 보호) |

#### ⚠️ 모델 세팅은 **config ↔ DM 쌍**으로 관리한다 (2026-08-04 확립)

**이 표는 "의도"일 뿐, 라이브 진실이 아니다.** DM 세션은 `sessions.json`에 자기 `model`/`modelProvider`를 **따로 pin해서 들고 있고, config primary를 바꿔도 그 pin은 안 풀린다.** 그래서 config만 고치면 "승격했다고 믿는데 실제 대화는 옛 모델로 도는" 상태가 조용히 몇 주씩 간다.

**실제로 그렇게 벌어졌다 (2026-08-04 발견)**: bbot은 config가 `anthropic/claude-fable-5`(claude-cli)인데 **라이브 DM은 `gpt-5.5`를 openai/Codex로** 돌고 있었다 — 모델도 provider도 다른, 사실상 다른 봇. mini도 config `sonnet-5` / DM `sonnet-4-6`으로 어긋나 있었다. 두 승격 모두 probe는 통과했었다. **probe 통과는 승격 완료가 아니다.**

**모델을 바꿀 때 반드시 두 짝을 다 움직인다:**

```bash
# ① config 먼저 (primary + per-agent 카탈로그)
docker exec openclaw-gateway openclaw config set agents.list.<idx>.model.primary <model>

# ② 그 다음 DM 세션 pin 해제 — 텔레그램 발송 없이(--deliver 없음) CLI로 친다
docker exec openclaw-gateway openclaw agent --agent <id> \
  --session-key "agent:<id>:telegram:<ch>:direct:<userId>" \
  --message "/model <model>" --timeout 540

# ③ 검증은 config가 아니라 세션 목록으로 — Model/Runtime 컬럼이 라이브 진실이다
docker exec openclaw-gateway openclaw sessions list --agent <id>
```

- **순서가 중요하다**: `/model`은 세션의 pin을 *제거*해 config primary를 따라가게 만든다(mini 실측: `model`/`modelProvider` 필드가 사라짐). config를 먼저 안 고치면 옛 primary로 떨어진다.
- **`/reset`·`/new`로는 안 풀린다** — pin은 세션 리셋과 별개 축이다. `/model`이 정공법.
- **⏱ 큰 컨텍스트 DM은 `--timeout`을 넉넉히**. main(271k)은 120s로 안 끝나 적용 실패했다 — 540s로 재시도해야 붙었다. ③으로 반드시 확인.

> #### 🔴 `/model`은 DM 세션을 굴릴 수 있다 — 대가는 시간이 아니라 **라이브 맥락**이다 (2026-08-04 실측)
>
> 처음엔 timeout의 대가가 "적용 실패, 다시 하면 됨"인 줄 알았다. **아니다.** 세션이 새로 굴러 `sessionId`가 바뀌고 **라이브 대화가 빈 맥락에서 다시 시작**된다. 원인은 둘이고, 성격이 다르다:
>
> | 봇 | 명령 | 결과 | 원인 |
> |---|---|---|---|
> | mini | `/model` (claude-cli → claude-cli) | **세션 유지** | 같은 provider 내 모델 교체 |
> | main | `/model` (claude-cli → claude-cli) | **ROLLED** | **timeout**. 히스토리 47k자를 새 CLI 세션에 재생(`historyPrompt=present`, `reuse=invalidated:message-policy`)하다 120s 초과 → `CLI session cleared after failed reused turn: reason=timeout` → 재시도는 `historyPrompt=none`으로 새 세션 |
> | bbot | `/model` (openai/codex → claude-cli) | **ROLLED** | **provider 전환**. codex 세션은 claude-cli로 이어붙지 않는다 |
>
> - **트랜스크립트는 유실되지 않는다** — 옛 `.jsonl`은 디스크에 그대로 남고(main 117KB/94줄, bbot 29KB/15줄) `usageFamilySessionIds` 체인도 계보를 보존한다. 잃는 건 *라이브 스레드가 들고 있던 맥락*이다. 봇은 그 구간을 "기억층에 빈 구간"으로 느낀다(bbot이 실제로 그렇게 자가 보고했다).
> - **`sessions list`의 Tokens 컬럼 분모가 같이 바뀐다** — main은 `271k/1049k` → `56k/264k`가 됐는데, 분모 변화(1049k→264k)는 **모델 컨텍스트 창 차이**(opus-4-8 vs opus-5)지 손실이 아니다. 분자만 보고 판단하지 말 것.
> - **처방**: ① provider를 넘는 전환(codex↔claude-cli)은 롤을 **각오하고** 한다 — 피할 방법이 없다. ② 같은 provider 내 교체는 **timeout만 안 나면 세션이 산다** → 큰 컨텍스트일수록 넉넉히(main 기준 540s). ③ 실사용자 DM을 굴리기 전에 GLG에게 알린다. ④ 굴러간 뒤 맥락이 꼭 필요하면 옛 `.jsonl`이 살아있으니 `sessions compact`/수동 요약으로 회수 가능.
- **`sessions list`의 Model 컬럼이 표와 다르면, 표가 아니라 세션이 진실이다.** 업그레이드·승격 후 이 표와 `sessions list`를 대조하는 것을 체크리스트에 넣는다.

> **claude-cli 결제 분리 원리** (운영 핵심): pi-shell-acp가 같은 Claude SDK를 wrap하면 Anthropic이 **third-party harness로 식별** → extra usage 풀 강제 → 빈 응답. OpenClaw native claude-cli runtime은 same SDK를 direct import → **Pro/Max 한도로 인식 + 1M context**. 같은 SDK라도 import 깊이 한 단계 차이로 결제 풀이 달라진다. **canonical 등록(5.28)**: model.primary/카탈로그를 `anthropic/<id>`로 두고 `{ "agentRuntime": { "id": "claude-cli" } }`를 붙이면 끝 — provider prefix `anthropic/`는 카탈로그 식별자일 뿐, runtime이 `claude-cli`면 구독 경로. legacy `claude-cli/<id>` prefix는 폐기(doctor/update가 canonical로 auto-migrate — profile 먼저 등록 필수). EPIPE·streaming off·전환 타임라인은 [ROADMAP.md](ROADMAP.md).

> **per-agent auth 함정 (oracle Docker 고유, 2026-05-31)**: Claude 쓰는 봇은 공식 login 1회 필요 — `openclaw models auth --agent <id> login --provider anthropic --method cli`(TTY, GLG 수동) → top-level `anthropic:claude-cli` 프로필 + `order.anthropic` 등록. **단 oracle은 `~/.claude`가 전 봇 공유 mount**라, login이 만든 per-agent 프로필 복사본은 frozen → 5.28 doctor가 **stale OAuth shadow**로 판정. `openclaw doctor --fix`가 per-agent 복사본을 제거하고 main의 갱신되는 auth를 inherit시킨다(제거 후에도 GREEN 확인). → 별도 host-native 레퍼런스(공유 mount 없음)의 "봇 수만큼 login 유지"와 **정반대 결론** — oracle은 login으로 기반만 깔고 doctor가 복사본을 정리. subagent는 openclaw 내장 런타임(`openai/gpt-5.6-terra`, ChatGPT OAuth)이라 claude login은 main/bbot/mini 3봇만.

> **2026-08-27 현재 서빙 경로: `github-copilot/gemini-3.7-flash`.** gemini-cli는 deprecated라 복원하지 않는다. 아래 403/`exec: gemini: not found`/agy 블록은 DOWN 시절 화석 — 챗봇을 `google-gemini-cli/`나 `google/`로 되돌리지 말 것. ~~`doctor --fix` 금지는 그대로(누르면 또 `google/`로 쓴다)~~ → **2026-08-31 폐기.** 이 금지는 gemini가 `google-gemini-cli/`였을 때의 방어였다. Copilot 레일로 옮긴 뒤엔 재작성이 겨눌 대상이 없고, 8.1 컷오버에서 `doctor --fix`를 실제로 돌려 **6봇 prefix 드리프트 0**을 확인했다. 8.1에서 이건 금지가 아니라 **필수**다.
>
> **⚠️ 2026-08-06 실측 — 당시 gemini DOWN의 근인은 403이 아니라 `exec: gemini: not found`다.** prewarm 턴이 `GatewayClientRequestError: FailoverError: gemini: 1: exec: gemini: not found`로 떨어진다. 즉 OAuth 이전에 **CLI 바이너리 자체가 컨테이너에 없다** — 2026-07-01(6.11) node-gyp hang 대응으로 Dockerfile `npm install -g`에서 `@google/gemini-cli`를 뺀 것의 직접적 귀결이다(아래 "이미지 재빌드 node-gyp hang" 항목과 같은 사건). 결론(DOWN 유지)은 그대로지만 **사유는 바뀌었다**: 아래 403 서사는 *바이너리가 있던 시절*의 진단이다. agy 이관으로 부활시킬 땐 Dockerfile 복원이 첫 단계이고, 403이 여전한지는 그 다음에야 확인 가능하다.
>
> **gemini 무응답 = OAuth 스코프-403, 재로그인으로도 안 풀림 → DOWN 유지 (2026-06-13, 아래는 바이너리가 있던 시절의 진단)**: gemini 봇이 조용하면 `google-gemini-cli` OAuth 문제다. `models status --probe`에서 `Google Generative AI API error (403): insufficient authentication scopes [PERMISSION_DENIED]`로 뜬다(프로필은 살아있는데 발급 스코프가 Generative AI API를 못 덮음). **재로그인 명령(올바른 인자 순서 — `--agent`는 `auth`와 `login` *사이*, GLG 확정)**:
> ```bash
> docker exec -it openclaw-gateway node openclaw.mjs models auth --agent main login \
>   --provider google-gemini-cli --force
> ```
> (`--device-code`는 이 provider 메서드 아님 — 빼고 `--force`만. 인터랙티브 메뉴 뜨면 `~/.gemini` creds import. 프로필은 `main` sqlite SSOT, 다른 봇 inherit.)
>
> **그러나 2026-06-13 실측: 재로그인은 완료(`Gemini CLI OAuth complete`)되는데 probe는 여전히 403.** 발급된 OAuth 토큰 스코프 자체가 OpenClaw의 `google-gemini-cli` 호출 경로(Generative AI API)를 못 덮는다 — **agy(Antigravity) 이관이 OAuth 스코프 레벨에서 gemini-cli를 깬 것.** 즉 재로그인은 *fix가 아니다*. **방침(GLG): API(`google/`)로 억지로 살리지 말 것 — 나노바나나 키 오용 금지. gemini 챗봇은 안 되는 대로 DOWN 유지하고 agy provider 연동을 기다린다([NEXT.md](NEXT.md)).** ⚠️ 부수효과: 위 재로그인 명령이 config를 드리프트시킨다 — `google/gemini-3.1-pro-preview`를 allowlist에 추가하고 `gemini` 별칭을 그 금지경로로 붙인다. 로그인 후 반드시 `config unset 'agents.defaults.models["google/gemini-3.1-pro-preview"]'` + restart로 정리(2026-06-13 정리 완료, Configured 4개/별칭 2개 복귀).
>
> **절대 하지 말 것 — api-key 폴백 금지**: `GEMINI_API_KEY`(=`google` provider)는 **나노바나나2 플래시(이미지 생성) 전용**이다(line 219). gemini 챗봇을 `google/`로 돌리는 건 우회가 아니라 **오설정** — 무료 Pro 쿼터를 버리고 이미지용 키를 텍스트에 잘못 쓰는 것. probe에서 `google/gemini-2.5-flash`가 `ok`로 떠도 그건 이미지 키 경로일 뿐, 챗봇 fix가 아니다. gemini는 **OAuth 외길**, fallback 없음.
>
> **⚠️ gemini provider 이관 진행 중 — 당분간 드리프트 구조적 (2026-06-13~)**: `google-gemini-cli` provider는 **deprecation 경로**다 — gemini-cli가 사라지고 **agy(Antigravity) 기반으로 이관 예정**. 그래서 당분간 gemini 모델 prefix/provider는 **계속 흔들린다**. 구체적으로 `doctor --fix`(또는 6.6+ 업그레이드 시 자동 마이그레이션)가 gemini를 `google-gemini-cli/gemini-3.1-pro-preview` → `google/gemini-3.1-pro-preview` + `agentRuntime.id=google-gemini-cli`로 **자동 재작성하는 것을 2026-06-13 6.6 / 2026-06-17 6.8 업글에서 연속 확인**(매번 되돌림 — `config set agents.list.3.model.primary google-gemini-cli/...` + `config unset agents.list.3.models["google/..."]` + restart). **6.8 릴리즈에 agy/antigravity provider 미등장 확인** — 이관 미공식, 베이스라인은 여전히 `google-gemini-cli/`. **2026-07-14 7.1 업글 실측 — 함정의 모양이 바뀌었다**: 컨테이너 자동 마이그레이션은 gemini를 **건드리지 않았다(드리프트 0)**. 대신 read-only `doctor`의 **changes-preview에 그 재작성이 "대기 상태"로 찍혀 있다** — *"Moved agents.list.gemini.model legacy runtime primary refs to canonical provider refs and selected google-gemini-cli runtime"*. 즉 **7.1에서 위험은 업글이 아니라 `--fix` 버튼 자체다. 누르는 순간 `google/`로 넘어간다.** 7.1에도 agy/antigravity provider는 미등장. **운영 원칙**: ① 업글/`doctor --fix` 후 `agents list`로 gemini 모델 prefix를 **반드시 재확인**, `google/`로 바뀌어 있으면 위 "api-key 폴백 금지"대로 `google-gemini-cli/`로 되돌린다(config set primary + `config unset 'agents.list.<idx>.models["google/..."]'`). ② **단, 이건 한시적 방어다** — gemini 설정이 자꾸 바뀐다고 당황하지 말 것. "또 흔들리네"가 아니라 **"아, 그 agy 이관 사안이구나"** 하고 인지하고, 변경 내용을 이 함정 블록과 대조해 *의도된 이관인지 / 잘못된 드리프트인지* 검토한다. ③ agy 이관이 공식화되면(gemini-cli 완전 deprecate) 이 블록과 line 89/98/114/219의 `google-gemini-cli/` 전제 전체를 한 번에 재작성한다 — 그때가 진짜 이사. 그 전까지는 OAuth(`google-gemini-cli/`) 유지가 기준선.

> **⚠️ auto-fallback catch-all 함정 — primary 실패 시 봇 정체성 훼손 (2026-06-13)**: OpenClaw 모델 해상도는 `primary → model.fallbacks(순서) → auto-fallback`. configured primary가 실패(서빙 불가/overload)하고 `fallbacks`가 비어있으면, auto-fallback이 **글로벌 allowlist(`agents.defaults.models`) 첫 작동모델**로 떨어진다(`modelOverrideSource: "auto"`). **user `/model` 선택만 fail-closed**(도달 불가 시 가시적 실패), configured primary는 항상 이 체인을 탄다. **2026-06-13 사건**: bbot을 fable-5로 올렸다가 Fable 5 서빙 실패 → allowlist 1번이던 `deepseek/deepseek-v4-pro`가 catch-all로 잡혀 **bbot이 deepseek로 응답**(정체성 훼손, "차라리 무응답이 낫다"). **조치**: allowlist에서 deepseek pro/flash **제거**(참조 봇 0) → `openai/gpt-5.5`(=default·1번)가 catch-all. **원칙**: ① allowlist 1번은 "정체성 훼손이 가장 덜한 catch-all"이어야 한다 — **2026-08-04 gpt-5.5 전면 제거로 catch-all은 `openai/gpt-5.4`, `defaults.model.primary`는 `openai/gpt-5.6-terra`로 이동**(둘 다 codex 구독, 5.5와 같은 훼손 프로파일). ⚠️ allowlist **키 순서는 `config set --replace`로 지정해도 안 먹는다** — OpenClaw가 기존 순서를 유지하며 정규화하므로, 1번 자리를 바꾸려면 순서가 아니라 *구성*을 바꿔야 한다. ② 서빙 미보장 모델(fable 등)을 **primary로 박지 말 것** — `/model`로 세션에서 시험하고, 살아나면 그때 primary 승격. ③ deepseek은 어떤 봇 정체성에도 안 맞아 allowlist에서 영구 제외(필요 시 `config set agents.defaults.models '{"deepseek/deepseek-v4-pro":{}}' --strict-json --merge`로 한시 추가, 단 catch-all 1번 자리는 피한다). **(2026-07-12 갱신)**: fable-5는 upstream v2026.6.6 adaptive-thinking 어댑터 fix + 현재 6.11에서 **서빙 재개**돼 bbot primary로 재승격됨 — "fable-5 서빙 실패" 전제는 이 버전에선 해소. 단 원칙 ②(서빙 미보장 모델을 primary로 박지 말 것)는 여전히 유효 — 이번에도 primary=opus 유지한 채 `agent --model` 오버라이드 격리 probe로 서빙(`fallbackUsed=false`)을 먼저 확인한 뒤에만 promote했다. fable을 `defaults.models` 끝(catch-all 아닌 자리)에 등록해 오버라이드 probe + `/model fable` 전 봇 개방.
>
> **(2026-08-07 갱신 — codex 제거로 catch-all 재배치)**: `openai/gpt-5.4` 삭제로 1번 자리가 비어 gemini(403 DOWN)→fable-5로 밀릴 뻔했다. allowlist를 **`terra, sol, luna, gemini, fable-5, opus-5, sonnet-5`** 순으로 재정렬해 catch-all을 `openai/gpt-5.6-terra`(= `defaults.model.primary`와 동일, ChatGPT 구독, 정체성 중립)로 고정. **순서 지정 방법 정정**: "`config set --replace`로 순서가 안 먹는다"는 여전히 맞지만, **`~/openclaw/config/openclaw.json`을 직접 편집하면 순서가 그대로 선다**(이번에 그렇게 했고 `config validate` 통과). 단 OpenClaw가 config를 스스로 재작성하는 경로(`doctor --fix`, 업그레이드 마이그레이션)를 타면 다시 정규화될 수 있으니, **그런 작업 뒤에는 1번 자리를 재확인**한다. **(2026-08-31 8.1 갱신 — 자리가 이사했다)**: catch-all은 이제 `agents.defaults.models` 키 순서가 아니라 **`agents.defaults.modelPolicy.allow` 배열 순서**다. 8.1 마이그레이션이 legacy 맵을 그 배열로 복사하며 순서를 보존했고 1번은 `openai/gpt-5.6-terra` 그대로였다(실측). 앞으로 1번을 바꾸려면 **배열을 직접 편집**한다.

보조 모델 (`/model <id>`로 in-thread 전환):

- `openai/gpt-5.6-luna` (5.6 저가·고속 티어 — 카탈로그 등재됨, 우리 primary엔 미배치. **5.5 대비 토큰 단가 1/5** → 경량 lane 후보. 단 **성능이 5.5보다 항상 낫다고 볼 순 없다** — 비용/속도 최적화 티어라 "싸니까 무조건 위"가 아니다)
- ~~`openai/gpt-5.5` / `gpt-5.5-pro`~~ — **2026-08-04 전면 제거**(GLG 결정: 5.5 아예 안 씀). allowlist·per-agent 카탈로그·`defaults.model.primary` 전부에서 삭제, 잔존 0건.
- ~~`anthropic/claude-sonnet-4-6`~~ — **2026-08-04 제거**(GLG: sonnet은 5로 통일). main/mini 카탈로그 + allowlist에서 삭제.
- `deepseek/deepseek-v4-pro` / `deepseek-v4-flash` (`DEEPSEEK_API_KEY` 회사 quota, 2026-04-27~). **2026-06-22(6.9) provider 외부화로 deepseek 플러그인 번들에서 빠짐 → entry/allow 제거. 부활 시 `openclaw plugins install @openclaw/deepseek-provider` + entry/allow 재추가 필요.**

> 운영 컨텍스트 메모: catalog 표기가 `266k/1025k` 같은 "이론치/확장치"로 보여도 라이브 `/status`는 보통 200k로 잡힌다. 5.4 vs 5.5 컨텍스트 트레이드오프는 사실상 없음. GPT-5.6 세 티어는 카탈로그상 전부 272k / text+image / `xhigh`·`max` reasoning 노출.

> **GPT-5.6 티어 = 같은 모델의 가격·성능 등급** (2026-07-14, 7.1 진입). **비교는 반드시 토큰 단가로 하라** — 메시지당 크레딧(5~40, 프롬프트 길이 의존)과 1M당 크레딧을 섞으면 비용 방향을 거꾸로 읽는다(2026-07-14 실제로 그렇게 헛짚었다).
>
> | 모델 | API $/1M (in/out) | Codex 크레딧 /1M in | 5.5 대비 |
> |---|---|---|---|
> | `gpt-5.5` | $5 / $30 | 125 | 기준 |
> | **`gpt-5.6-sol`** (flagship, bare `gpt-5.6` 별칭) | $5 / $30 | 125 | **동일 단가, 상위 모델** |
> | **`gpt-5.6-terra`** (균형) | $2.50 / $15 | 62.5 | **절반 단가, 5.5와 경쟁 가능한 성능** |
> | `gpt-5.6-luna` (저가·고속) | $1 / $6 | 25 | 1/5 단가, **성능 우위는 보장 안 됨** |
>
> 캐시 read는 각 1/10. **핵심**: sol은 5.5와 같은 값에 더 좋은 모델이고, terra는 5.5급을 절반 값에 준다 — **5.6 승격은 비용 인상이 아니다.** luna만 성능 트레이드오프가 실재한다. **limited preview** — 접근권은 워크스페이스마다 다르므로 `models list --provider openai`로 확인하고, 없으면 OpenClaw가 조용히 강등하지 않고 upstream 접근 오류를 그대로 노출한다.

> Codex Plus ($100/mo) 메시지당 크레딧 (출처: developers.openai.com/codex/pricing): `5.4-mini` 2 / `5.4` 7 / `5.5` 14. **배치 원칙 (2026-07-14 갱신)**: 가벼운 turn은 5.4-mini, **개인(gpt)은 `5.6-sol`, 가족(glg)은 `5.6-terra`**. 근거는 "개인이 비용을 흡수한다"가 아니라 **단가 그 자체다** — sol은 5.5와 동일 단가라 gpt는 값을 더 안 내고 상위 모델을 얻고, terra는 5.5의 절반이라 **가족봇은 오히려 싸졌다**. active-memory recall lane은 분리해 main lane quota 보호 — **2026-08-07 codex 제거로 `5.4-mini` → `5.6-luna`**(subagents도 `5.4` → `5.6-terra`). ⚠️ **크레딧 표는 Codex Plus 기준이라 이 두 lane엔 더 이상 안 맞는다** — 둘 다 이제 codex가 아니라 openclaw 내장 런타임으로 ChatGPT 구독 OAuth를 직접 탄다. 실사용 후 quota 체감을 재관측할 것. ※ 이전 배치(개인 5.5 / 가족 5.4)의 후계 — glg의 2026-06-10 강등 사유(cross-DM 판단 과잉)는 가드 완료로 해소됐다.

이미지 생성: `openai/gpt-image-2` via Codex OAuth (default since 2026-04-25). Google Imagen은 agent-directed 호출 시 사용 가능 (`GEMINI_API_KEY`로 banana/`gemini-3-flash-preview-image`). gemini 챗봇은 `google-gemini-cli/` provider prefix로 **OAuth(Pro 쿼터)만 탄다**(`/status` `🔑 oauth` 검증). `GEMINI_API_KEY`(=`google` api-key provider)는 **어떤 챗 모델도 안 가리키고** 이미지(나노바나나) 전용으로만 env 유지 — 단 이미지 경로 동작은 **미재검증**([NEXT.md §1](NEXT.md)).

텔레그램 렌더링: `channels.telegram.richMessages` **OFF (기본값 — 2026-06-22 글로벌 ON 했다가 당일 되돌림)**. 호환 모드 표준 HTML(굵게/기울임/링크/`코드`/스포일러/블록인용)만 사용 → 어느 클라이언트에서나 정상 + **텍스트 복사 가능**. ⚠️ **되돌린 이유 (교훈)**: `richMessages=true`(Bot API 10.1 rich HTML: 헤딩·표·`<details>`·수식)는 GLG 주력인 **telega(TDLib third-party)** 에서 "unsupported message"로 가려져 **봇 대화 텍스트를 복사할 수 없게 만든다** → "봇 대화를 떠서 에이전트에게 넘기는" 핵심 워크플로가 끊긴다. **핵심은 rich 렌더링이 아니라 소통(복사 가능성)** 이라 OFF가 baseline. telega 리치 지원 매트릭스(T01~T15: 헤딩/표/details/수식/sup·sub/mark/task-list/footnote …, doomemacs-config + TOOLS.md에서 추적)에서 되는 블록이 확정되기 전까지 OFF 유지. 다시 켜려면 top-level `channels.telegram.richMessages=true` + restart (단 telega 복사 불가 trade-off 재발).

ACP는 top-level `acp.enabled=false`로 차단(backend `acpx`). **acpx·pi-shell-acp 엔트리는 둘 다 `plugins.entries`에 없음** — pi-shell-acp는 2026-06-22(6.9) provider 외부화로 완전 제거(entry+allow+load.paths). ~~엔트리 지우면 기본 로드로 복귀~~ 함정은 6.9에서 무효 — 외부화로 default-load 대상 자체가 사라짐(제거 후 clean boot·warnings 0 확인). 재활성 절차는 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md).

> **번들 외부화는 릴리즈마다 반복되는 패턴이다** — 업글 후 boot `Config warnings`에 "plugin not installed: X"가 뜨면 X가 번들에서 빠진 것이다. 전례: pi-shell-acp·deepseek(6.9) → **mattermost(7.1)**. 처방은 둘 중 하나 — 쓰면 `openclaw plugins install @openclaw/<X>`, 안 쓰면 `config unset plugins.entries.<X>`. mattermost는 `enabled:false` 죽은 엔트리여서 제거했다(WARN 0 복귀). **WARN을 방치하지 마라** — "Warn = Error" 원칙이 사는 자리가 정확히 여기다. 부팅 때마다 뜨는 무해한 WARN 하나가 진짜 WARN을 가린다.

라이브 값 확인:

```bash
python3 - <<'PY'
import json, pathlib
c = json.loads(pathlib.Path('~/openclaw/config/openclaw.json').expanduser().read_text())
for a in c.get('agents', {}).get('list', []):
    print(a.get('id'), a.get('model'))
PY
```

### Active memory — 현재 main/gpt 활성

운영 config:
- `agents: ["main"]` — **1개만 활성**. glg 2026-06-09 제외(recall 훅이 가족 응답을 16~35s 지연), **bbot 2026-06-13 제외**, **gpt도 제외 — active-memory가 실질적으로 잘 동작하지 않아 GLG가 뺐다**(2026-08-07 확인). mini/gemini 제외. ⚠️ 문서가 오래 `["main","gpt"]` 2개로 적혀 있었으나 라이브는 main 단독이었다(2026-08-07 실측 후 정정). **즉 현재 active-memory는 main 한 봇에만 남은 실험 lane이다** — 이 전제로 읽을 것. glg 2026-06-09 제외(recall 훅이 가족 응답을 16~35s 지연). **bbot 2026-06-13 제외**(같은 mini-lane 증상: 매 direct 메시지마다 recall lane 2차 턴이 23~35s·절반 timeout으로 본 턴과 겹치고 `incomplete turn` 에러 노출 → 응답성 우선). mini/gemini 제외
- `model: "openai/gpt-5.6-luna"` — recall lane을 분리해 main lane과 OAuth quota 경합 회피. **2026-08-07 `gpt-5.4-mini`(codex)에서 이동** — luna는 openai provider 카탈로그 네이티브(105만 ctx, `thinkingLevelMap.off=none` → 플러그인의 `thinking:"off"`와 정합)라 codex CLI를 안 탄다
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
- `~/org:/home/node/org:rw` is for file access (denotecli / bibcli / botlog / journal), not embedding. Do not remove.
- andenken layer is still separate by *storage* (LanceDB vs sqlite), *corpus* (org KB vs OpenClaw sessions/memory), and **since 2026-05-08 16:00 also by *model*** (4B vs 8B) until andenken follows. To give bots semantic org search, deploy the `semantic-memory` skill from `~/repos/gh/agent-config/skills/` with LanceDB reachable from Oracle — but cross-store retrieval will be slightly miscalibrated until both layers share a model again.
- This baseline is the comparison point for andenken bake-off (first-result precision, freshness, CJK short query, operator trust). OpenClaw is SSOT; andenken follows.

### Mount permission model (since 2026-04-25)

The `ro`/`rw` boundary was widened to reduce host-hop friction for agent edits. Rollback safety relies on git, not on filesystem enforcement.

| Area | Mode | Rollback surface |
|---|---|---|
| `~/repos/gh` | **rw** | git (each repo). `git status` surfaces unintended writes immediately. |
| `~/repos/3rd` | rw | git + "third-party, disposable" nature |
| `~/repos/work` | ro | intentional — company code never modified through bot hand |
| `~/org` | **rw** | whole tree (2026-08-27, GLG). Includes `diary.org`, `archives/`, `authinfo.gpg`. Rollback = git on `~/org`. |

**Post-deploy habit**: after a rw-expanding change, monitor `~/org` `git status` for the first hour. Unintended writes are possible now — git is the rollback surface, not the mount.

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
| `OPENROUTER_API_KEY` | memorySearch embedding (Qwen3-Embedding-8B 4096d, all agents). ~~web search (perplexity)~~ — 2026-06-22(6.9) perplexity 외부화·제거, 웹검색은 런타임 내장(codex=Codex Hosted Search, claude-cli=Claude WebSearch)으로 전환 | `~/.env.local` SSOT → `~/openclaw/.env` (sync values, not just names) |
| `GEMINI_API_KEY` | image generation only (banana / `gemini-3-flash-preview-image`). **Not** memorySearch since 2026-05-08 (replaced by OpenRouter Qwen3) | `~/.env.local` SSOT |
| `GROQ_API_KEY` | active-memory primary (currently disabled) | `~/.env.local` SSOT |
| `TELEGRAM_BOT_TOKEN_*` | per-bot Telegram | `~/openclaw/.env` (gitignore) |
| `OPENAI_CODEX_*` | Codex OAuth — actual LLM serving for all agents (Anthropic flat-rate blocked; Copilot removed 2026-08-16) | `~/openclaw/.env` (gitignore) |

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
agent-config/skills/          ← SSOT (git)
  ↑ pi-skills/* 심볼릭 (호스트 하네스)
  ↑ ~/.claude/skills/* 심볼릭 (호스트 Claude — per-skill, dir 심볼릭 금지)
        ↓ run.sh k)  절대경로 심볼릭 (복사 금지)
~/openclaw/config/workspace*/skills/*
~/openclaw/config/claude-skills/*   ← 컨테이너 ~/.claude/skills 마운트
```

Operator entrypoint: `run.sh k)` (Oracle only). **2026-08-11부터 심볼릭 전량 배포** (복사/`rsync` 폐기).

### Why symlink

- 공간: workspace×6 + claude-skills 복사본(~700M+) → 심볼릭 디렉터리 수 KB + 바이너리 1벌.
- 신선도: agent-config SKILL.md/스크립트 수정이 재배포 없이 전 봇·ACP에 즉시 반영 (`skills.load.watch: true`).
- OpenClaw `skills.load.allowSymlinkTargets`에 SSOT 경로를 열어 심볼릭 following 허용.

### Exclude (봇 미배포)

`telegram` `slack-latest` `jiracli` `memory-sync` `punchout` `browser-tools` `entwurf-peek`

### Per-agent policy

모든 봇 동일 스킬 세트. mini 최소 정책은 폐기(issue #6).

| Agent | Workspace | Notes |
|---|---|---|
| main | `workspace/` | allowlist 없음 |
| glg | `workspace-glg/` | `agents.list[].skills` allowlist 있음 — 신규 스킬 추가 시 allowlist도 갱신 |
| gpt/gemini/mini/bbot | `workspace-*` | allowlist 없음 |

### Deployment rules

- `run.sh k)`: 각 `workspace*/skills` + `claude-skills`를 비운 뒤 `agent-config/skills/<name>` 절대경로 심볼릭 재작성.
- 스킬 **디렉터리 추가/삭제** 또는 `allowSymlinkTargets` 변경 → gateway restart (필요 시 recreate).
- SKILL.md content-only → watch로 동적 로드 (재시작 불필요).
- **절대 복사 금지.** 옛 `rsync --delete` 경로는 gog 실바이너리를 심볼릭으로 덮어 파괴한다.

### `~/.claude/skills` footgun (필수)

호스트 `~/.claude/skills`가 **디렉터리 하나짜리 심볼릭**(→ `agent-config/skills`)이면, compose의
`claude-skills → /home/node/.claude/skills` 마운트가 심볼릭을 resolve하며 **agent-config/skills 자체를
오버레이**한다. 증상: 컨테이너에서 `/home/junghan/repos/gh/agent-config/skills`는 stale 25개,
`/home/node/repos/gh/agent-config/skills`만 진짜 41개.

**고정 형태**: 호스트 `~/.claude/skills` = **실 디렉터리** + per-skill 심볼릭.
`run.sh k)`와 무관하게 이 형태를 유지할 것. 깨지면 gateway recreate 전에 복구.

### Workspace skills vs Claude ACP skills

- `workspace*/skills/` — OpenClaw workspace skill system (심볼릭 → agent-config).
- 컨테이너 `~/.claude/skills` — `config/claude-skills/` 마운트 (같은 심볼릭 세트). Claude ACP가 여기를 본다.
- `~/.claude` 자체는 **rw** (Claude `session-env/`·`projects/` 기록).

### gogcli(gog) — 바이너리만 스킬 트리 밖

상세·진단: [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md) "gogcli 봇 배포".

- **봇 gog 실파일 SSOT = `~/openclaw/bin/gog`** (openclaw-config/bin, 스킬 트리 밖).
- `agent-config/skills/gogcli/gog` → 그 경로 심볼릭. workspace/claude-skills의 gogcli는 agent-config로 심볼릭이므로 한 곳에서 resolve.
- 호스트 마스터는 별도 `~/.local/bin/gog` (`external-packages.sh`). 컨테이너는 `~/.local/bin` 미마운트 → 봇용 실파일 1벌 필요.
- 업그레이드: ① `external-packages.sh`로 호스트 갱신 ② `cp ~/.local/bin/gog ~/openclaw/bin/gog` ③ 끝 (스킬 재배포 불필요).
- 인증 = 호스트 `~/.config/gogcli` rw 마운트 공유. 정적 링크 바이너리(Debian, nix 없음).

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
