# OpenClaw 운영 Gotcha 모음

`AGENTS.md`에서 분리된 현장 디버깅/incident 참고. nixos-config가 OpenClaw 담당자이므로 이 파일이 SSOT.

세 카테고리:

- **활성** — 운영 중 자주 부딪힘. 현재 deployment(5.2)에 그대로 적용.
- **비활성** — 기능 자체가 disabled. 재활성화 시 다시 참고.
- **역사** — resolved/superseded. 정책 근거를 보존하기 위해 남김.

---

## 활성

### claude-cli provider — `claude` binary not on PATH → EPIPE on every turn (2026-05-26)

OpenClaw 5.20 (`dist/cli-backend-CO2SZJAY.js`)이 `claude-cli` provider를 자동 등록하면서 spawn args를 `command: "claude"`로 박는다. PATH에서 `claude`를 찾는데, image는 `@anthropic-ai/claude-agent-sdk` (+ `@anthropic-ai/claude-agent-sdk-linux-arm64/claude` 번들 binary)만 install 하고 `node_modules/.bin/claude` symlink는 만들지 않음 (SDK package.json에 `bin` field 없음). 결과:

```
spawn("claude", ...) → ENOENT
child exits in ~4ms
parent stdin write → EPIPE
log: "claude live session close: reason=abort" + "model fallback decision: reason=timeout detail=write EPIPE"
telegram UX: "⚠️ Agent failed before reply: write EPIPE. Please try again, or use /new to start a fresh session."
```

함정 자리:
- `openclaw infer model run --model claude-cli/...` 은 **잘 작동**. 다른 dispatch path (one-shot capability) 사용.
- `openclaw agent --agent <id>` + 텔레그램 inbound 둘 다 같은 live session path → 둘 다 EPIPE.
- `/status` 도 정상 표시 (model lookup만 하고 spawn 안 함).

Fix (정공법, env 변경 — force-recreate 필요):

```yaml
# docker-compose.yml — gateway service AND child env (두 자리)
- PATH=/app/node_modules/@anthropic-ai/claude-agent-sdk-linux-arm64:/home/junghan/.pi/agent/claude-plugin/skills/bibcli:.../bin
```

SDK 디렉토리에는 `claude` + LICENSE/README/package.json만 있어서 다른 binary와 충돌 0. `node_modules`가 image 안이라 영구.

대안 (안 채택): host `npm i -g @anthropic-ai/claude-code` 후 mount — 호스트 의존 늘어남. Dockerfile에 `npm i -g` 추가도 가능 — image 재빌드 비용.

### bonjour plugin — disable on Oracle Cloud + Docker (since 2026-04-24)

OpenClaw 2026.4.24 split bonjour LAN discovery into a default-on plugin (`@homebridge/ciao`). On Oracle Cloud + Docker with IPv6 disabled (our setup), the mDNS probe fails and emits `Unhandled promise rejection: CIAO PROBING CANCELLED` every ~30s, taking gateway down with it (restart loop). LAN discovery has no value to us — we reach gateway via SSH tunnel, not Bonjour.

Fix: set `plugins.entries.bonjour: { enabled: false }` in `openclaw.json`. Plugin count drops from 9 back to 8 (matching 4.23 behavior). No functional loss.

### Adding non-default models (since 2026-04-27)

OpenClaw 2026.4.24 narrowed default `openclaw models list` to *configured* rows only, and 4.24's `/models add` slash command is deprecated. To make a new model usable from `/model <id>` slash command:

1. Sync the provider API key from `~/.env.local` to `~/openclaw/.env` (preserves the SSOT pairing rule).
2. Add `provider/model-id: {}` under `agents.defaults.models` in `openclaw.json`.
3. `docker compose restart openclaw-gateway`.
4. Verify with `node openclaw.mjs models` (note: no subcommand) — look for the model in the `Configured models` line.

`models list --all` exists but is slow (>60s timeout in our container) — don't rely on it for verification.

### rw mount expansion — git is the rollback surface (2026-04-25)

Since the 4.23 upgrade, `~/repos/gh:rw` and `~/org/{meta,bib,notes}:rw` are open. There is no filesystem enforcement against unintended writes — rollback relies on `git status` / `git diff` / `git restore`.

- Monitor the first hour after any rw-expanding mount change.
- An unintended write into `~/org/diary.org` (or anything else under `~/org:ro`) means the mount config regressed.
- `~/repos/work` remains ro deliberately — never widen this without consulting the company code-safety policy.
- `nixos-config` is a symlink inside `~/repos/gh/` (→ `~/nixos-config`). Container cannot follow it. Agent edits to nixos-config must route through the host, not the bot runtime.

### Codex catalog — models.json drift on upgrade is expected (2026-04-25)

OpenClaw 2026.4.23 synthesizes the `openai-codex/gpt-5.5` OAuth row automatically. After the upgrade, `git diff config/agents/*/agent/models.json` shows `gpt-5.4 → gpt-5.5` in the Codex provider block. This is catalog-layer drift; the **serving model** is still `openai-codex/gpt-5.4` because `agents.list[].model` pins it explicitly. Verify with:

```bash
python3 - <<'PY'
import json, pathlib
c = json.loads(pathlib.Path('/home/junghan/openclaw/config/openclaw.json').read_text())
for a in c['agents']['list']:
    print(a['id'], a.get('model'))
PY
```

### Dreaming — decoupled from heartbeat (since 2026.4.23)

Upstream #70737 moves dreaming into an isolated lightweight agent turn. It now runs even when `heartbeat` is off for the default agent and is no longer skipped by `heartbeat.activeHours`. `openclaw doctor --fix` migrates stale main-session dreaming jobs in persisted cron configs to the new shape. Our deployment had no stale entries at 4.22 → 4.23 upgrade.

### ACP common failures

- `Authentication required` — confirm `~/.claude` is mounted; a simple `restart` after mount changes is not enough, recreate is.
- Only a few skills visible — broken absolute symlinks inside `~/.claude` pointing at `/home/junghan/repos/gh/...`. Add `~/repos/gh` as a compatibility mount; overlay `claude-skills` to `/home/node/.claude/skills`.
- `session-env ... ENOENT` — `~/.claude` must be **rw**.
- `ACP max concurrent sessions reached` — raise `acp.maxConcurrentSessions` or close stale sessions. Current setting: 3.
- `docker compose restart` alone insufficient after mount or env change — use `up -d --force-recreate`.

### Key pairing — same name, different value (2026-05-08)

`~/.env.local` (호스트 SSOT)와 `~/openclaw/.env` (Docker env_file)에 같은 변수명 `OPENROUTER_API_KEY`가 *서로 다른 값*으로 들어 있을 수 있다. 호스트 키는 정상이지만 컨테이너 키가 OpenRouter privacy/data policy로 막혀 있으면 모든 임베딩이 `404 No endpoints available matching your guardrail restrictions`로 실패.

운영 검증 절차:
- 키 sync는 변수명만 비교하지 말고 *값*까지 비교 (suffix 4자리만 보여 시크릿 노출 없이 일치 여부 확인).
- OpenClaw가 `${VAR}` 자동 보간하므로 한 곳(`~/openclaw/.env`)만 sync되면 충분. recreate 필요 (restart는 env 새로 안 읽음).
- 컨테이너 내부에서 직접 `curl /embeddings` 한 번 200 응답 확인 후 reindex 시작. 키 정상 + 정책 통과 확인 없이 reindex 들어가면 6 agent 모두 동시 실패.

---

## 비활성 — 재활성화 시 참고

### active-memory — model choice matters (currently disabled since 2026-05-03)

5.2 안정성 검증 동안 `plugins.entries.active-memory.enabled: false`로 둠. 재활성 시 baseline은 `~/openclaw/config/openclaw.json` 기존 config (Groq paid tier `gpt-oss-120b` primary, `google/gemini-3-flash` fallback, `timeoutMs: 15000`, `agents: ["glg", "gpt"]`).

운영 발견 (재활성 전 알아둘 것):

- `openai-codex/gpt-5.4-mini` hits a 31.5s Codex CLI subprocess cold-start. Plugin `timeoutMs` is not honored across the subprocess boundary. Do not use Codex models in blocking hot-path plugins.
- `timeoutMs=8000` is too tight for groq — saw 9.7s boundary timeouts. Use 15000 (upstream default).
- Upstream `3f90d9266` (v2026.4.21) graceful degrade keeps replies alive on timeout; active-memory is an assist layer, not a critical path.
- **Groq free tier TPM=8K로 `gpt-oss-120b` 실사용 불가** (2026-04-23 관측). active-memory 프롬프트는 queryChars 1K라도 전체 input이 ~35K tok이라 매 호출 `413 Request too large`. 해결책: Groq Console에서 **paid tier 전환** ($10 선불, pay-per-use). 전환 후 호출당 ~7원, 응답 ~11s.
- **`modelFallback`은 `rate_limit` 케이스에서 자동 승계되지 않음** — 관측상 `decision=surface_error reason=rate_limit profile=-`로 끝나고 fallback 모델로 재시도하지 않음. 에러 메시지 본문이 그대로 summary로 노출되어 `summaryChars=50` 같은 작은 값으로 찍힘. `timeout`이나 일반 장애에서만 fallback이 탄다.
- **Gemini 3 Flash Lite는 Flash보다 느릴 수 있다** (2026-04-23 관측: Flash 13.4s vs Flash Lite 17.9s→timeout). 이름과 달리 active-memory의 input-heavy 워크로드(input:output ≈ 500:1)에서는 Lite의 TTFT가 더 길었음. Groq LPU의 decode 강점도 이 워크로드에서는 prefill이 지배적이라 제한적.

### ACPX — disabled since 2026-05-03

`plugins.entries.acpx.enabled=false` + `acp.enabled=false`. 5.2가 ACPX를 `@openclaw/acpx` beta로 externalize했고 우리는 미설치. 재활성 시점이 오면 `npm i @openclaw/acpx` + 아래 4개 항목 재참조.

#### ACPX — model override does not persist

As of 2026.4.15 + acpx 0.5.3, the ACP session model cannot be written into config. Schema strict fields on `AcpBindingSchema.acp` (`mode, label, cwd, backend`) and `AgentRuntimeAcpSchema` (`agent, backend, mode, cwd`) have no `model`. Only path: the in-chat slash command.

```
/acp spawn claude --bind here --cwd /home/node/.openclaw/workspace
/acp model anthropic/claude-opus-4-6
```

No host bypass exists. `openclaw acp` is only a bridge to external ACP clients; `message send` is one-way; editing `thread-bindings` files cannot substitute for spawn.

TTL recycles every 2h idle (`acp.runtime.ttlMinutes: 120`) and the model override evaporates. Active threads need manual re-set a few times per day until upstream acpx version bump.

2026-04-19 observation: `/acp model anthropic/claude-opus-4-7` CLI says "session ids resolved" but the actual served model is `claude-opus-4-6` — Anthropic flat-rate OAuth silently downgrades. Use `anthropic/claude-opus-4-6` explicitly; 4.7 needs separate billing.

2026-04-24 re-check on v2026.4.22: catalog now normalizes `anthropic/claude-opus-4-7` to 1M context (display-only fix), but routing is still OAuth-tier gated. **Policy: Claude access is company flat-rate OAuth only** — no direct Anthropic API billing. 4.7 live routing is therefore out of our fixable scope; stay on 4.6 until tier changes.

Inspect truth from the host — never from inside an already-bound thread (text there may be forwarded to the Claude session as a user turn):

```bash
cd ~/openclaw && docker exec openclaw-gateway sh -lc 'node openclaw.mjs sessions --all-agents'
cd ~/openclaw && docker exec openclaw-gateway sh -lc 'sed -n "1,200p" /home/node/.openclaw/telegram/thread-bindings-default.json'
cd ~/openclaw && docker exec openclaw-gateway sh -lc 'sed -n "1,200p" /home/node/.openclaw/telegram/thread-bindings-bbot.json'
```

#### ACPX — sessions do not auto-load workspace identity

A fresh `/acp spawn claude --bind here` Claude session does not read `workspace/IDENTITY.md / SOUL.md / USER.md / AGENTS.md / MEMORY.md`. Direct-runtime agents did (GlueClaw path historically), ACPX Claude sessions do not — claude-agent-sdk does not scan the workspace.

Fix on first turn after spawn:

```
workspace의 IDENTITY.md, SOUL.md, USER.md, AGENTS.md, MEMORY.md를 순서대로 읽고 시작하세요
```

Longer term: put a `CLAUDE.md` in workspace, or inject "read workspace/IDENTITY.md first" into `agents.list[].systemPromptOverride`, or use an ACPX bootstrap script when upstream enables it.

#### ACPX — sessions do not know their own runtime

Asking an ACPX Claude session "what runtime are you on" returns whatever `workspace/MEMORY.md` claims — pure doc-driven inference, not ground truth. In 2026-04-19 testing the binding was explicitly `agent:claude:acp:...` on Anthropic Opus 4.6, but the bot reported "not acpx, I am on direct runtime" because MEMORY.md described GlueClaw as default.

Do not trust bot self-introspection. Verify from the host with `/acp status` outside the thread, or `docker exec ... sessions --all-agents`. Long-term: remove "default runtime" prose from workspace docs, or inject a systemPromptOverride like "you cannot know your own runtime; tell the user to check `/acp status`".

#### ACPX — direct vs ACP-bound session confusion in host inspection

`openclaw sessions --all-agents` interleaves two kinds of rows:

- `agent:<id>:telegram:*` — **direct session** for the Telegram DM. Its `Model` column shows the agent's at-rest/fallback model (or a stale state from before the thread was ever `/acp spawn`-ed).
- `agent:claude:acp:*` — **ACP-bound session** actually serving the live bound conversation. This row's `Model` reflects the active `/acp model` override.

The live serving model is the ACP row, not the direct row. 2026-04-24 misread: interpreted a stale `claude-sonnet-4.6` on a `bbot direct` row as the live bbot state, and reported bbot as "fallback-mode" in a commit message. bbot was in fact on `claude-opus-4-6` via ACPX the whole time.

Verification path (least effort first):

1. Ask the bot itself in-thread.
2. Read `/home/node/.openclaw/telegram/thread-bindings-<account>.json` → `targetSessionKey`. If it starts with `agent:claude:acp:`, the live path is ACPX and the serving model lives in that ACP session, not in any `direct` row.

---

## 역사 — resolved / superseded (정책 근거 보존)

### 4.24 warn-ignored incidents — "Warn = Error" 원칙의 근거 (2026-04)

AGENTS.md §5 "Warn = Error" 원칙이 태어난 두 사건. 둘 다 여러 사이클 동안 무해한 startup noise로 치부됐다가 4.24에서 폭발했다.

- **task registry malformed**: `Failed to restore task registry` (`code:"ERR_SQLITE_ERROR" errcode:779 errstr:"database disk image is malformed"`) — 4.21부터 매 gateway start마다 떴고 11일간 "tolerable startup noise"로 방치. 4.24가 restart-continuation을 같은 task registry로 라우팅하면서, malformed `runs.sqlite`가 background warning → 100% CPU silent retry loop로 돌변해 inbound message 처리가 얼어붙음. Fix: gateway 정지 → `~/openclaw/config/tasks/runs.sqlite`를 백업 폴더로 이동 → start (새 DB 자동 생성, in-flight task state만 손실, user data 없음).
- **bonjour probe loop**: `bonjour: watchdog detected non-announced service` — 4.23부터 반복된 warn을 "ARM cloud LAN noise"로 무시. 4.24가 bonjour를 default-on plugin으로 승격하자 같은 probe 실패가 `Unhandled promise rejection: CIAO PROBING CANCELLED` → ~30s restart loop가 됨. Fix: `plugins.entries.bonjour: { enabled: false }` (현재 활성 gotcha로 박제 — 위 "활성" 참조).

교훈: 두 warn을 사이클 내내 무시한 대가는 user-visible 봇 downtime이었다. warn 조사 비용은 분 단위, 방치 비용은 시간 단위.

### 4.24 → 4.26 / 4.29 lazy-staging incident — resolved on 5.2 (2026-05-03)

**RESOLVED on 5.2.** 4.23 → 4.29 attempt on 2026-05-03 reproduced the same lazy-staging hot-path incident — first inbound message triggered `[plugins] alibaba/runway/tts-local-cli staging bundled runtime deps` mid-hot-path with `eventLoopDelayMaxMs=17213.4` and `[telegram] sendChatAction failed`. Same incident class as 4.26. 4.29 brought the diagnostic timeline + slow-host-startup fixes but no structural fix for "scope of plugin runtime preloads". Jumped directly to **5.2** which carries the structural fix:

- `Plugins/runtime: scope broad runtime preloads to the effective plugin ids derived from config, startup planning, configured channels, slots, and auto-enable rules instead of importing every discoverable plugin`
- `Tools/plugins: cache plugin tool descriptors captured from api.registerTool(...) so repeated prompt-time planning can skip plugin runtime loading while execution still loads the live plugin tool` (#76079)

5.2 verified: ready 7.3s first boot / 5.3s warm boot, CPU 0.23% idle, MEM 246 MiB, **zero `staging bundled runtime deps` lines on hot path**. Family-bot smoke test passed. Single 24s liveness spike on first cold-message only (Codex OAuth + 49k context hydration), idle thereafter. Full operational record in `~/openclaw/README.md` Change history (entry dated 2026-05-03 / version 5.2).

**Operational lessons retained** (these still apply for any future jump where structural fix is unproven):

- *No more two-version jumps on family-traffic gateway* unless the target version has a verified structural fix and we have a no-traffic window.
- *Stage on a non-family agent first* when uncertain.
- *Family responsiveness is the SLO.* If the operator notices latency, that is a P0 — investigate before the next upgrade ships, not after.
- *Trust the structural-fix release tag* but bench-test on a no-traffic window first. "Latest is best" was wrong for 4.24/4.25/4.26/4.29 (no fix), correct for 5.2 (fix shipped).

### 4.24 → 4.26 latency regression — wait-and-watch (2026-04-28, superseded by 5.2)

A two-version jump from 4.24 to 4.26 produced a service-quality incident on the family-traffic gateway. Operator and family reported "responses that used to come instantly now take all day." Multiple `[diagnostic] stuck session` entries with gateway PID showing **102% CPU** on a single node thread. Resolved by emergency rollback to 4.23, which was the latest known-good for both response latency *and* `gpt-image-2` Codex-OAuth image generation. Fully superseded by 5.2 structural fix above; the policy "no two-version jumps on family traffic" born in this incident remains in effect.

### GlueClaw — runtime auto-injected providers from repo presence (resolved by deletion)

OpenClaw plugin discovery walks mounted volumes. Any `openclaw.plugin.json` in a mounted path is a candidate provider. `~/repos/gh/glueclaw/openclaw.plugin.json` was re-injecting `glueclaw` / `sc` providers into every agent's `models.json` on container start, even though `641d497` had removed them at config level. Deleting the local repo broke the injection path. The GitHub fork (`junghan0611/glueclaw`) is preserved as history.

Lesson: if a provider is not wanted, the source directory must leave the mount, not just the config.
