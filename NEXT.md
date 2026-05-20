# NEXT.md — 다음 할 일

운영 baseline은 [AGENTS.md](AGENTS.md). 후속 작업 / 미완 검증은 여기에.

작업 끝나면 항목 지우고, 새로 발견한 후속은 추가. 결정/근거/날짜는 항목 본문에 남기되, 지워질 항목이라는 점을 잊지 말 것 — 영속할 사실은 AGENTS.md / docs/openclaw-gotchas.md / `~/openclaw/README.md` change history로 옮긴다.

---

## 1. 8B 4096d 검색 품질 검증 (8B baseline 직후)

5.7+4B → 5.7+8B 전환 (2026-05-08 16:00). model `qwen/qwen3-embedding-8b`, dim 2560 → **4096 native**. OpenRouter 가격 절반 ($0.02/M → $0.01/M). 4B와 8B 임베딩 공간은 직교 (cos≈0)라 reindex 필수했음.

검증 항목:

- [ ] **5.7+4B baseline ↔ 5.7+8B baseline 동일 query 비교**
  - 5.7+4B에서 측정했던 reference scores: 안녕 0.759, 세션을 0.627 (vec=0.529 text=0.858), 임베딩 0.680
  - 8B에서 동일 query 재실행 → score 분포 비교. 8B가 의미 매칭 더 강하게 잡는지 vs textScore 비중이 너무 커지는지
- [ ] **4096d 차원이 검색 결과 ranking에 미친 영향**
  - 5.7+4B에서 top-3였지만 5.7+8B에서 떨어진 chunks (또는 그 반대) 사례 수집
  - storage 부담: 4B 621M → 8B 약 1GB 예상. 실측
- [ ] **가족 봇 (glg) 실응답 품질**
  - 4096d로 회상이 더 자연스러운지, 또는 차이 없는지
  - 응답 latency 4B 대비 변화 (8B는 모델이 크지만 OpenRouter API 호출이라 우리 쪽 영향은 RTT만)
- [ ] **andenken bake-off 재실시 (model parity 도달 후)**
  - andenken도 8B 4096d로 따라오면 cross-store 검색 일관성 확보
  - 평가축: first-result precision, freshness, CJK short query, operator trust
  - 결과 기록: `~/org/llmlog/` 새 노트 (denote 형식)
- [ ] **`--force` 직후 dirty=true 현상 — 8B 사이클에도 재현되는지**
  - 5.7+4B 사이클에서 6 agents 모두 `dirty=true` → incremental 1회로 해소됐던 패턴
  - **5.18 영향 가능**: changelog L199 `Memory-core: scan persisted memory source sessions on startup, comparing on-disk transcripts against the index and marking only missing/newer/resized files dirty for incremental sync. Fixes #82341.` — 5.18 업그레이드 후 dirty 패턴 자연 해소 가능성. 업그레이드 후 재측정 우선

## 2. active-memory 확장 후속 (main/glg/gpt/mini)

(2026-05-09 12:59 KST 확장) gpt 단독 24h 관찰 OK → main/glg/mini 추가. **2026-05-16 bbot 추가** (Phase 1.8 β 통과 후 ACP path 호환성 확보). gemini(삭제 예정) 제외.

24h 관찰 baseline (2026-05-08 08:58 ~ 2026-05-09 03:45 UTC, gpt 14 invocation):
- status: ok 4 / empty 10 / timeout 0
- elapsedMs: min 5388 / max 13256 / 평균 ~8.3s
- summaryChars (ok): 164 / 178 / 203 / 216 — 모두 220 한도 내

확장 후 후속 관찰:

- [ ] **glg(가족 봇) 응답 latency 체감 변화**
  - 가족 사용 turn 후 가족 피드백 수집. "느려졌다" 류 호소 발생하면 glg만 다시 제외
- [ ] **main agent 회상 품질 정성 평가**
  - main은 가장 generalist deep work라 회상이 가장 유의미할 가능성. status=ok 비율 추적
- [ ] **mini agent에서 의미 있는지 재검증**
  - mini는 format/proofread 전용이라 "이전 대화 이어서" 패턴이 거의 없음. status=empty가 압도적이면 mini만 제외 검토
- [ ] **확장 후 14일 baseline (cutoff 2026-05-23 임박)**
  - 4개 봇 합산 invocation/day, status 분포, elapsed 분포 집계
  - timeout 빈도 0% 유지되는지 — 다중 봇 동시 호출 시 OAuth quota 경합 검증
  - **5.18 영향**: changelog L195/L197/L198 subagent completion handoff fixes — recall sub-agent (5.4-mini lane) 동작에 영향 가능. baseline 비교 자리에서 5.12 vs 5.18 분리해 측정

## 3. (참고) gemini agent 정리

비긴급. AGENTS.md §3 Model routing에 "Copilot 잔재(`gemini` agent)는 **삭제 예정**" 표시. 단 §4에서 pi-shell-acp/Gemini CLI로 전환 검증 진행 중이라 결정 후순위. 5.18 운영 안정 확인 후 별도 사이클.

- [ ] gpt-5.4로 통합할지 (workspace-gemini → workspace-gpt로 흡수) 또는 agent 자체 삭제할지 결정
- [ ] 텔레그램 봇 `@glg_gemini_bot` 회수 절차 (BotFather)
- [ ] workspace-gemini 인덱스 데이터 archival

## 4. pi-shell-acp OpenClaw plugin — Phase 1.8 β 완전 통과

**2026-05-15 18:08 KST — bbot이 `pi-shell-acp/claude-opus-4-7` primary로 텔레그램 turn 완전 통과.** Phase 1.8 keystone 닫음. 핵심 fix chain: `98c8741` delivery contract bridge → `7071f4d` exit→close fallback → **`02c9c36` stdout parser spin-loop fix (진짜 원인)** → `4e8237c` docker-lab repro.

### 현재 Oracle 상태

- bbot: `pi-shell-acp/claude-opus-4-7` ✅ live
- gemini: `pi-shell-acp/gemini-3.1-pro-preview` (검증 미완 — bbot GREEN 후 후순위)
- main: picker 5개 enroll (gpt-5.5 primary 유지)
- glg/gpt/mini: 그대로
- Plugin pi-shell-acp `0.7.0` surface (publish-pending), install path `~/.pi/agent/git/.../plugins/openclaw` (link mode)
- Host overlay HEAD `d4f5772` main 추적 (2026-05-19 Stage 1 pull)

### 영속화 — 다음 사이클에 AGENTS.md / docs로 옮길 사실

이 블록은 NEXT.md 휘발성이므로 다음 사이클 마무리 시 영속 기록으로 옮기고 지울 것:

- Dockerfile 3-layer (`@earendil-works/pi-coding-agent` + `@zed-industries/codex-acp` + `@google/gemini-cli`) `npm install -g`
- compose 4-mount (`~/.pi/agent` rw + `/home/junghan/.pi/agent` compatibility + `~/.codex` rw + `~/.gemini` rw)
- plugin install: `openclaw plugins install <path> --link --dangerously-force-unsafe-install` → `plugins.allow` / `plugins.entries.<id>.enabled=true` 자동 박힘
- β path = host passthrough, trusted single-user. 공개 default는 α (in-container login + named volumes)

### 남은 잔여 작업 (Phase 1.8 keystone 후 부속)

**⏸ FREEZE 모드** (2026-05-19~): pi-shell-acp 코어 0.7.0 npm publish 라운드가 노트북에서 진행 중. 이 라운드 끝날 때까지 plugin-side 디버깅/수정 모두 보류. operational use(git pull로 main 따라가기)는 가능하지만 plugin 코드 *고치는* 작업은 정지. publish 완료 + Phase 3 진입 stamp 후 unfreeze 결정.

- [x] ~~**gemini agent 봇 turn 검증**~~ → **closed 2026-05-19 17:43 KST** (Stage 2 5.18 호스트 업그레이드 직후 자연 검증). `@glg_gemini_bot` 텔레그램 cold turn 정상 응답, DIAG chain 깨끗: `child spawned model=gemini-3.1-pro-preview timeoutMs=600000` → `child exit code=0` (24.6s) → `child finalize kind=close hasFinal=1 abnormal=0 timeoutFired=0`. Copilot 의존 끊고 pi-shell-acp/Gemini CLI 정공법 작동 확인. tool block fence 정합 ✅ (d4f5772 sanitize 적용)
- [ ] ⏸ **main picker `/model pi-shell-acp/...` 전환 turn**: 5개 모델 각 단발 turn 검증
- [ ] ⏸ **풀세트 6축 검증 (β 통과선)**: skill manifest (3a) + skill invocation (3b) + 세션 자기인식 + workspace 인식. bbot이 이미 workspace read한 정황으로 거의 통과 상태
- [x] ~~**plugin config `spawnTimeoutSeconds` 전달 갭**~~ → **closed 2026-05-19** (`cc0c033 fix(plugin/openclaw): resolve pluginConfig via nested OpenClaw path`). FactoryCtx를 OpenClaw `ProviderCreateStreamFnContext` SSOT에 align. issue #18 cold lane bootstrap SIGTERM 본질. Oracle live 검증: `timeoutMs=60000 → 600000` propagate, 새 DIAG 키 3종(ctxKeys/pluginCfgKeys/spawnTimeoutSec) 출력, 첫 turn cold lane 60s 죽음 회귀 0. **메모 정정**: 이전 "spin-loop fix 후엔 60s로도 충분" 평가는 부정확 — issue #18은 cold lane bootstrap 누적 비용(model-switch + spawn + workspace read + opus cold KV miss)이라 spin-loop와 별개. cc0c033으로 해소.
- [ ] ⏸ **adad76af session 누적 ack 청소 정책**: 이전 stuck cycle trajectory에 "Note: I'll respond..." 5건 누적. 현재 새 session `fb3331af` 사용 중이지만 stale session archive 정책 검토

### 운영 사실 — Stage 1 plugin pull 검증 GREEN (2026-05-19, Oracle live)

Host overlay `cd092b7 → d4f5772` pull 후 gateway restart 1회. **8축 검증 다 통과**:

| # | 항목 | 결과 |
|---|---|---|
| 1 | `cc0c033` spawnTimeoutSeconds gap fix (#18) | ✅ `timeoutMs=60000→600000` propagate, DIAG 새 3 키 출력 |
| 2 | `d4f5772` event-mapper fence sanitize | ✅ `[tool:done]` 코드블록 fence 정합, 회귀 없음 |
| 3 | bbot β path 회귀 (cold turn) | ✅ workspace read 풀 응답, 60s 죽음 없음 |
| 4 | MCP surface 라이브 (`pi-tools-bridge`) | ✅ `entwurf_self` / `entwurf_peers` 실호출, envelope 반환 |
| 5 | host alias 컨테이너 누수 | ✅ 0% (4중 격리, plugin `spawn(piBinary, args)` raw exec) |
| 6 | entwurf spawn (`openai-codex/gpt-5.4`) | ✅ Task `023b435a`, 3 turns, $0.0522, registry routing 정확 |
| 7 | entwurf_resume + self-check | ✅ 2 turns, $0.0574, GPT-5.4 정체성 *재검증으로* 확정 |
| 8 | entwurf live/saved surface 분리 실증 | ✅ peers count:0, controlDir 디렉토리 부재 / JSONL `2026-05-19T08-01-32_entwurf-023b435a.jsonl` 47KB alive |

→ Phase 1.8 β의 keystone이 모델만이 아니라 **MCP surface + entwurf workflow + registry routing + live/saved schema 분리까지 전부 라이브**.

#### plugin 실 argv (line 740, alias 누수 검증 부산물)

```
pi -p <userText> --no-session --no-tools --mode json --offline --provider pi-shell-acp --model <modelId>
```

`--entwurf-control` / `--emacs-agent-socket` 0건. control socket / MCP는 settings.json `packages` + `mcpServers` 등록 차원에서 자동 활성. host `~/.bashrc.local` alias는 컨테이너로 흘러갈 길 없음 (compose mount X / 컨테이너 파일 X / 컨테이너 shell alias X / plugin raw spawn).

#### 두 layer 분리 (`--entwurf-control` flag 부재 함의)

| Layer | 활성 조건 | bbot 상태 |
|---|---|---|
| Extension 등록 (MCP tools 노출) | settings `packages: [...pi-shell-acp]` → pi.extensions auto-load | ✅ active |
| Control socket 생성 (외부 send endpoint) | child pi launch 시 `--entwurf-control` flag | ❌ inactive (의도된 가족 봇 보안 자리) |

→ bbot은 텔레그램 안에서만 응답. 다른 pi session에서 send로 침입 불가.

#### 새 추적 후보 3건 (⏸ pi-shell-acp 코어 publish 완료 후 issue 검토)

- **(a) 분신 child env hallucination** — Codex(GPT-5.4) child가 host env `PI_AGENT_ID=pi-shell-acp/claude-opus-4-7` 그대로 상속해서 첫 응답에 자기를 Claude로 자기보고. 운영 함의: 분신 self-identification 시 env 인용 위험. pi-shell-acp 측에서 child env 청소 정책 검토 후보
- **(b) `entwurf_self.socketPath` placeholder 반환** — control socket file이 디스크에 없어도 socketPath가 어쨌든 반환됨 (bbot은 controlDir 디렉토리 자체가 없는데 path 반환). operator 해석 함정. `entwurf_self`가 socket file stat 후 반환하는 게 정확
- **(c) MCP bridge child `PI_SESSION_ID` env stale** — bridge child가 spawn 시점 env 캐시, 부모 pi가 새 session으로 갱신해도 env 반영 안 됨. UUID v7 prefix mismatch (env `019e3f4a` vs entwurf_self `019e3f39`)

#### closed 1건 (2026-05-20)

- ~~**(d) post-#17 active-memory pre_compute silent empty final**~~ → **closed 2026-05-20** ([pi-shell-acp #20](https://github.com/junghan0611/pi-shell-acp/issues/20)). 두 fix 검증 GREEN, Oracle live:
  - `e7eefeb fix(openclaw): recover empty assistant finals` — empty-final recovery 중앙화 + last-resort placeholder
  - `8b25c1e fix(openclaw): use role-preserving prompt context` — JSON-as-data prompt assembly (chat-completion mirroring 근본 차단) + `stripChatCompletionTail()` output sanitizer (defense-in-depth)
  - 검증 매트릭스: bbot turn `pi-shell-acp/claude-opus-4-7` + active-memory, multi-tool botlog request 4804 chars 풀 응답, `recoveryKind=as-is` `abnormal=0`, `partialTextLen=4832 → finalTextLen=4804` (28 char diff = sanitizer 작동 자국), `</environment_details>` leak 0, fabricated `User:` 0, prompt cache 250k 정상 유지
  - 운영 함의: pi-shell-acp `npm pull` 시 host clone (`~/repos/gh/pi-shell-acp`) **외에** plugin overlay (`~/.pi/agent/git/.../pi-shell-acp`)에도 `git pull` 별도 필요 — 컨테이너는 overlay path를 path-link로 로드. 어제(05-19) Stage 1 GREEN도 같은 패턴. dist는 commit에 동봉되므로 build 불필요

### 운영 사실 — openclaw stuck session auto-recovery (2026-05-18 확인, `ee1a046` stamp)

[pi-shell-acp issue #18](https://github.com/junghan0611/pi-shell-acp/issues/18) 발생 직후 main(default) 봇이 codex stream hang으로 605s(10분) stuck → **openclaw 자체 stuck-recovery로 자동 풀림 확인**.

```
recovery=none      ← "아직 발사 안 함" 의미. 무한 stuck 아님
recovery=checking  ← 605s 즈음 자체 timeout 발사
stuck session recovery: action=abort_embedded_run aborted=true drained=true
→ 다음 turn 자연 진입, 새 codex child spawn
```

운영 함의:
- `stalled session ... recovery=none` 로그는 **즉시 액션 필요 아님**. 10분 안에 자체 회복
- 수동 강제 종료(docker exec kill / gateway restart)는 다른 봇 영향 + 매커니즘 중복 → **606s 이전엔 일단 기다리는 게 정공법**
- **5.18 영향**: changelog L59 `Release stability: recover stale session diagnostics and Codex OAuth fallback state so stuck runs and reused refresh tokens clear without blocking follow-up work.` — 이 회로가 추가 강화됨. 5.18 업그레이드 후 stuck-recovery latency 재측정 가능

영속화 옮길 자리: AGENTS.md §5 Operational workflow 또는 §7 Gotchas.

### 영속 기록 옮길 destination (다음 정리 사이클)

- `~/openclaw/README.md` change history: Phase 1.8 β 완전 통과 stamp
- `nixos-config/AGENTS.md` §3 model routing: bbot=opus-4-7 / gemini=pi-shell-acp 갱신
- `nixos-config/docs/openclaw-gotchas.md`: 5.12 + pi-shell-acp prerelease 정합 + 4-layer install + β path 운영 룰

### Cross-repo follow-up

- [x] ~~`pi-shell-acp` Phase 2 후보: Codex도 Claude처럼 `require.resolve("@zed-industries/codex-acp/package.json")` fallback 추가~~ — **0.7.0 cut에 들어감** (`resolveCodexAcpLaunch` 0.7.0 changelog 참고)
- [ ] `pi-shell-acp` 문서에 Docker auth boundary 섹션 추가 여부 확인: "backend CLI auth는 backend가 소유, pi-shell-acp는 token을 읽거나 변환하지 않음"
- [ ] `agent-config` 임시 정책 추적: 0.6.0 prerelease 동안 server-mode가 `pi-shell-acp` main 추적(`agent-config` 5f17d70). **0.7.0 cut됨 → Phase 3 진입 trigger**. publish 라운드 완료 후 ref pinning 복귀 결정
- [ ] `plugins/openclaw/README.md` Install layers 항목 보강: settings.json의 host absolute path 호환성 — Docker 환경에서 compose에 `/home/junghan/.pi/agent` 동등 path 두 번째 mount 필요 함정 한 줄 (⏸ plugin sibling publish 수준 도달 후)
- [ ] α 별도 advanced smoke (공개 기본값): 통과선 1/1b/2/세션 자기인식만. 별도 사이클

## 5. Home Assistant on Oracle Docker — baton pass 완료

**2026-05-17 nixos-config 인프라 layer 닫음.** PoC end-to-end 통과 (`sensor.sm_s942n_s26_glgman_sleep_duration = 427 min`, Health Connect 라이브 16개 센서 활성). 인프라 구축 풀 디테일은 commit `7567b7c` (Dockerfile/compose/Caddy) + commit `53a8d2e` (baton pass stamp) + llmlog `20260517T160459` 참고.

라이브 메트릭 (참고): `sleep_duration`, `heart_rate`, `resting_heart_rate`, `daily_steps`, `steps_sensor`, `daily_distance`, `total_calories_burned`, `weight` ✅ / `hrv`, `oxygen_saturation`, `blood_pressure`, `blood_glucose`, `active_calories_burned` unknown (Samsung 미수집).

### Baton 받은 쪽 (lifetract repo)

여기 nixos-config 측 인프라는 닫음. 다음 단계는 [`~/repos/gh/lifetract`](file:///home/junghan/repos/gh/lifetract):

- [ ] **AGENTS.md 신설** — 현재 없음. 코드는 Mar 17 이후 손 안 댐 → 현재 동작과 문서 일치 여부부터 점검 (2026-05-18 노트북 담당자가 §2 베이스라인 정렬 통과 stamp)
- [ ] HA REST import 스크립트 — `/api/states/sensor.sm_s942n_s26_glgman_*` polling
- [ ] cron 일1회 (NUC 또는 laptop에서)
- [ ] 토큰 로딩: `pass show 2fa/totp/ha/junghanacs` (JWT long-lived access token)

### Gotcha 영속화 옮길 항목

다음 사이클에 [docs/openclaw-gotchas.md](docs/openclaw-gotchas.md):

- **Caddyfile bind-mount inode 교체**: 호스트 `Edit`/`Write`의 atomic rename으로 inode 교체 → caddy 컨테이너가 옛 inode 잡고 있어 `caddy reload`가 "config is unchanged"로 무효 종료. 해결: `docker compose restart caddy`로 재바인딩

### 영속화 destination (PoC 통과 후, 다음 정리 사이클)

- `nixos-config/AGENTS.md`: Oracle 운영 컨테이너 목록에 homeassistant 추가
- `nixos-config/docs/`: HA 운영 노트 (trusted_proxies, 2FA, recorder 정책)
- `lifetract` skill: HA REST 경로 첫 클래스 입력으로 승격

## 6. Oracle 디스크 정리 — 완료 ✅

**2026-05-17 완료** (commit `9214a6e` run.sh C) docker prune 통합). 97% → 67%, +28GB 회수. §5 HA 게이트 해제.

배운 점: `docker system df` reclaimable 명목치는 layer 공유 무시. 27GB 명목 → 실회수는 image prune 2.4GB + **builder prune 7.687GB**가 본 회수원. 다음 사이클에는 빌드캐시부터 본다.

영속화 (다음 정리 사이클):

- `nixos-config/AGENTS.md` §7 Gotchas: **"OpenClaw 업그레이드 사이클마다 dangling 이미지 + build cache 누적 → run.sh C)로 정기 prune"** 룰
- "`docker system df` reclaimable 명목치 ≠ 실 회수량, builder prune이 본 회수원" 메모
- run.sh `C)` Docker 통합은 AGENTS.md commands 섹션에서 언급

남은 잔재 (비긴급, 사용자 결정):

- [ ] `~/docker-data/{mattermost,synapse}` archival — 비활성 후 데이터 잔존

## 7. OpenClaw 5.12 → 5.18 업그레이드 검토 (2026-05-19, **의사결정 대기**)

릴리즈 노트: <https://github.com/openclaw/openclaw/releases/tag/v2026.5.18> (250+ 라인 변경, bug-fix 위주 + Codex 다수 안정화).

**riskiness 사전 판단: low-medium.** major breaking change 없음. 5.12 정공법 (`openai/*` + `agentRuntime.id="codex"`) 그대로 유지 가능. 단 pi-shell-acp `0.6.0-prerelease.0` 쓰는 우리는 ACP wire / Codex app-server 영역 다수 변경에 대해 **검증 우선**.

### 5.12 정공법 강화 (우리에게 좋음)

- **L164** `Agents/Codex: route OpenAI runs that resolve to openai-codex through Codex provider and bootstrap stored OAuth profile.` — 5.12 마이그레이션 follow-up fix. doctor가 못 잡는 nested config가 있어도 runtime이 OAuth profile을 더 잘 찾아감
- **L121** `legacy oauthRef-backed OAuth profiles usable while doctor --fix migrates them back to inline, without creating new sidecar credentials.` — 5.12 OAuth profile 암호화 secret key (`auth-profile-secrets` mount) 와 호환, 재로그인 불필요 보장
- **L122** `load the selected provider owner alongside the Codex harness runtime so openai-codex models resolve when plugin allowlists scope runtime loading. Fixes #83380.` — 5.12 `plugins.allow` 명시 정공법과 직접 연결
- **L99** `OpenAI/Codex: stop rejecting available openai-codex GPT-5.1/5.2/5.3 model refs during config validation.` — 우리 5.4/5.5 직접 영향 적지만 fallback chain 검증 폭 ↑

### Telegram polling reliability (가족 봇 직접 win)

5.12 boot 직후 fetch-timeout 1건 stuck 함정과 같은 영역 다수 패치.

- **L132** `keep isolated long polling below the hard getUpdates request guard so idle bot accounts with high timeoutSeconds do not false-disconnect and restart-loop.`
- **L139** `keep hot-reload restarts from marking polling accounts manually stopped and restart isolated ingress cleanly after worker shutdown.`
- **L123** `fail stalled isolated-ingress handlers into tombstones and abort same-lane reply work before restarting.`
- **L95** `retry HTTP 421 Misdirected Request send failures on a fresh fallback transport.`
- **L94/L52** forum-topic origin / topic ID 보존

→ **가족 봇 안정성 최대 win 영역.** 5.12 함정 거의 해소 기대.

### Memory-core (§1 검증과 직접 연결)

- **L199** `scan persisted memory source sessions on startup, comparing on-disk transcripts against the index and marking only missing/newer/resized files dirty for incremental sync. Fixes #82341.` — 우리 §1 `dirty=true` 후속 자연 해소 가능성. **업그레이드 후 §1 항목 재측정 우선**
- **L136** sqlite-vec load fail vs missing semantic embeddings 진단 분리 — vector.{enabled,storeAvailable,semanticAvailable,available} 정확도 ↑
- **L135** `Memory/QMD: keep lexical search on raw hyphenated queries while normalizing semantic QMD sub-searches.` — Denote ID 검색 영향 가능

### pi-shell-acp Phase 1.8 β 호환성 (**최우선 검증 영역**)

`0.6.0-prerelease.0` plugin이 5.18 host의 ACP wire / Codex app-server와 합치는지.

- **L165** `Agents/ACP: distinguish prompt-submitted and runtime-active child stalls from true interactive waits, including redacted proxy-env diagnostics for Codex ACP no-output runs.`
- **L168** `ACP/Codex: honor terminal ACP turn results so failed Codex/acpx runs are not recorded as successful after only progress text.`
- **L142** `Codex app-server: rotate oversized native Codex threads before resume and cap dynamic tool-result text.`
- **L144** `Agents/Codex: use the Codex runtime context window for OpenAI-model preflight compaction.`
- **L137** Subagents sandbox-peer controller ownership preserve

→ bbot opus-4-7 turn(`fa3b8f7`/`02c9c36`) final/abnormal guard와 같은 카테고리. plugin 측 가드와 host 측 가드 양쪽 강화 방향이라 충돌 가능성은 낮지만 trace 검증 필요. **β path 트라이 turn으로 회귀 확인 필수**.

### Subagent — active-memory recall lane (§2 직접 연결)

- **L195** `keep successful keep-mode completion payloads pending after final-delivery retry exhaustion.`
- **L197** `wait for queued completion handoffs to reach the parent transcript before marking them announced.`
- **L198** `route group/channel subagent completions through message-tool-only handoffs when required.`

→ active-memory recall sub-agent (5.4-mini lane) 호환성 영향. **24h 관찰 baseline 위에 5.12 vs 5.18 분리 재측정**.

### Build / runtime 변경

- **L17** Pi packages 0.75.1 + Node 22.19 minimum — 베이스 이미지가 가져옴, Dockerfile 변경 불필요 (단 `docker compose build --pull`로 새 base 받아야 함)
- **L18** `OPENCLAW_IMAGE_APT_PACKAGES` 신표준 + legacy fallback `OPENCLAW_DOCKER_APT_PACKAGES` — 우리 Dockerfile `RUN apt-get install ...` 직접 박혀 있어 영향 없음

### 우리 안 쓰는 영역 (skip)

Mac app 리디자인 다수 / Discord / Signal / WhatsApp / QQBot / Feishu / xAI / GitHub Copilot / Together / Xiaomi / Moonshot / Browser CDP / Android Talk Mode / meme-maker / python-debugger 등.

### 업그레이드 시퀀스 — split-variable + freeze 정합 (2026-05-19 결정)

**전제 조건**:
- pi-shell-acp 코어 0.7.0이 노트북에서 npm publish 라운드 진행 중 (publish 자체는 pending). 우리는 publish 완료 + Phase 3 진입 stamp까지 **plugin-side 코드 수정 freeze** (§4 잔여 작업 ⏸ 표시).
- OpenClaw plugin sibling (`@junghan0611/openclaw-pi-shell-acp`)은 공개 수준 미달 — operational use(git pull) 외에는 손 안 댐.
- 변수 1개씩만 흔든다. 버전 헷갈리지 않게.

**Stage 1 — plugin git pull only (host 5.12 그대로)** ✅ **통과 2026-05-19**

목적: 0.6.0-prerelease → 0.7.0 surface로 host overlay만 따라가기. host 변수 zero. 검증 매트릭스 8축은 §4 "운영 사실 — Stage 1 plugin pull 검증 GREEN" 섹션 참조.

- [x] 사전 — Oracle 호스트에서 현 plugin overlay HEAD 확인 → `cd092b7` 였음 (NEXT.md `4e8237c` 기록은 stale, 이미 앞서 있었음)
- [x] `git pull` → `cd092b7` → `cc0c033` → `d4f5772`. fast-forward
- [x] plugin link 살아있음 확인 (installs.json: `pluginId=pi-shell-acp`, link mode, source `/home/node/.pi/.../plugins/openclaw`). dist/index.js commit에 포함되어 build 불필요
- [x] `docker compose restart openclaw-gateway` 2회 (cc0c033 후 + d4f5772 후 안전 차원). ready 9~11s
- [x] bbot β path 회귀 검증 — workspace read 풀 응답, 60s 죽음 회귀 0
- [x] **plugin 코드 freeze 모드 유지** — git pull 이후 plugin-side 수정 작업 0건. operational use만

**Stage 2 — host 5.12 → 5.18 (plugin 0.7.0 surface 고정)**

목적: host만 단독 변수. Stage 1 안정 baseline 위에 host 업그레이드. pi-shell-acp는 그대로 박혀 있으니 5.18 ACP wire 변경이 plugin과 합치는지 isolate 검증 가능.

- [ ] **사전 백업**
  - `~/openclaw/config/memory/*.sqlite` 백업 (8B 4096d 재구축 1290s 비용 회피)
  - `~/openclaw/auth-profile-secrets/` 백업 (OAuth profile secret key 분실 = 전 봇 재로그인)
  - `git -C ~/openclaw log --oneline -5` + `git -C ~/repos/gh/nixos-config log --oneline -5` 현 시점 기록
- [ ] **이미지 빌드 + recreate**
  - `~/openclaw/Dockerfile`의 `FROM ghcr.io/openclaw/openclaw:2026.5.12` → `2026.5.18` (롤백용 주석은 5.12로 갱신)
  - `cd ~/openclaw && docker compose build --pull openclaw-gateway`
  - `docker compose up -d --force-recreate openclaw-gateway`
  - ready 시간 측정 (5.12는 8.8s)
- [ ] **6 봇 polling boot 검증 (5.12 함정 회귀 여부)**
  - boot 직후 1분 로그 watch — fetch-timeout / isolated polling stuck / restart-loop 없는지
  - `getMe` 모두 OK 확인
- [ ] **bbot turn 회귀 검증 (5.18 ACP wire 변경 영역)**
  - Stage 1과 동일 단발 turn. DIAG chain 정상
  - 회귀 시: Dockerfile FROM `5.18` → `5.12`로 되돌리고 build+recreate (10분 이내)
- [ ] **doctor --fix 동작 변경 확인**
  - 5.18 doctor가 5.12 정공법 (`openai/*` + `agentRuntime.id="codex"`) 손대는지. config diff 확인 후 수동 unrevert 필요한지 판단
  - L99 `openai-codex/*` legacy ref 허용 변화로 우리 정공법이 다시 legacy로 끌리지 않는지
- [ ] **main/glg/gpt active-memory recall**
  - 4봇 lane status 분포 5.12 baseline (ok 4 / empty 10 / timeout 0) 대비 회귀 없는지
  - timeout 1건이라도 나면 즉시 추적
- [ ] **memory index 진단 (§1 직접 연결)**
  - `openclaw memory status --deep --json` — vector.{enabled,storeAvailable,semanticAvailable} 정확도 ↑ 확인
  - `--force` 직후 dirty=true 패턴 재현 여부 — L199 fix가 우리 사이클에서도 작동하는지
- [ ] **stuck-recovery 회로 (§4 운영 사실 직접 연결)**
  - L59 강화 후 stuck-recovery latency 변화 측정 가능 (단 인위적 trigger 어려움. 자연 발생 시 재기록)

**Stage 3 — plugin-side freeze 해제 (pi-shell-acp 코어 publish 완료 후, 별도 사이클)**

trigger: 노트북 `~/repos/gh/pi-shell-acp`의 `npm publish` 완료 + Phase 3 진입 stamp. 그때 §4 잔여 작업 (⏸ 표시) unfreeze 결정 + plugin sibling publish 가능 수준 도달 시 npm scope 마이그레이션 검토.

### 의사결정 결과 (2026-05-19 17:30 KST)

- **Stage 1 ✅ 통과** (Oracle live, 검증 8축 GREEN — §4 운영 사실 참조)
- **Stage 2 ✅ 통과 (2026-05-19 17:43 KST)** — soak 24h 룰 건너뜀 (가족 봇 사용자 없음 확인). 5.18 host 업그레이드 + plugin 0.7.0 surface 합쳐서 GREEN.

### Stage 2 검증 결과 (Oracle live, 2026-05-19 17:30~17:43 KST)

사전 백업: `~/openclaw-backups/pre-5.18-20260519-172825/` (memory 1.1GB + auth-profile-secret-key + 3 repo HEAD 기록)

Dockerfile FROM `2026.5.12` → `2026.5.18`. build 3m31s (Node 22.19 새 base + Pi 0.75.1 첫 로드). recreate ready 36.3s (5.12 8.8s 대비 cold-start 비용).

| 축 | 결과 |
|---|---|
| Boot 12 plugins (5.12 11 → +perplexity) / 6 봇 polling 정상 | ✅ |
| L132 isolated polling guard 작동 | ✅ `Detected legacy update offset ... discarding stale` 정공법 |
| Telegram menu payload 자동 압축 (88 commands, 5700 char budget) | ✅ |
| bbot `pi-shell-acp/claude-opus-4-7` cold turn | ✅ 9.8s clean exit, `timeoutMs=600000`, `abnormal=0 timeoutFired=0` |
| gemini `pi-shell-acp/gemini-3.1-pro-preview` cold turn (first proper validation) | ✅ 24.6s clean exit, fence 정합 |
| **5.18 신규 hook `prepareNextTurn`** — plugin 0.7.0 호환 | ✅ optsKeys에 추가, ACP wire 깨짐 없음 |
| doctor: 5.12 정공법 자동 변경 0 (model/provider config) | ✅ `pi-shell-acp/...` + `openai/*` + agentRuntime.id=codex 모두 유지 |
| **doctor --fix OAuth migration 의무 (별도)** | ⚠️ 17:42 발견 — 4 봇 (main/glg/gpt/mini) `openai-codex` auth fail → 17:55 `doctor --fix --yes --non-interactive` 적용으로 복구. sidecar → inline 자동 migrate, backup `.oauth-ref.<ts>.bak` 4개 생성, main inline 3653 bytes |
| Skills Eligible 41 / Missing 0 / Blocked 0 | ✅ |
| Plugins Loaded 17 / Errors 0 | ✅ |

**5.12 함정 (fetch-timeout boot stuck) 회귀 0건** — L132 guard가 의도대로 작동.

#### 5.18 운영 함정 발견 — doctor --fix OAuth migration 의무

5.12에서 OAuth profile을 sidecar로 분리(`auth-profile-secrets` mount)했던 자리가 5.18 changelog L121 영역. 5.18은 *legacy sidecar*를 *inline OAuth credentials*로 다시 migrate해야 함. recreate 후 `doctor --fix` 안 돌리면 4 봇 (main/glg/gpt/mini, Codex OAuth lane) 전부 `FailoverError: No API key found for provider "openai-codex"`로 응답 실패. bbot active-memory recall sub-agent도 같은 lane (mini codex) 사용해서 영향. pi-shell-acp 봇 (bbot/gemini) 자체는 backend CLI auth라 별도 영향 없음.

**복구 명령** (in-container):
```bash
docker exec openclaw-gateway openclaw doctor --fix --yes --non-interactive
```

자동 동작:
- `~/.openclaw/agents/<bot>/agent/auth-profiles.json` sidecar refs → inline OAuth credentials 변환
- `auth-profiles.json.oauth-ref.<ts>.bak` 안전 backup 자동 생성 (롤백 가능)
- main agent에 모든 inline credentials, 다른 봇은 main 참조하는 구조 (main 3653 bytes vs others ~1040)
- 부수: `~/.openclaw` permission 700 tighten

**5.7 → 5.12 마이그레이션 때 박은 in-container doctor --fix 패턴**과 동일. 운영 함의: **5.x → 5.y host upgrade마다 recreate 직후 `doctor --fix` 의무 1회 추가** — Stage 2 절차에 추가 박아야 할 자리. 영속화는 `docs/openclaw-gotchas.md` 또는 AGENTS.md §5 Operational workflow.

#### 부수 추적 (24h 안에 별도 처리)

- **anthropic:claude-cli expiring 4h** — bbot이 쓰는 backend CLI auth. host에서 `claude login` 또는 `openclaw models auth login --provider anthropic`
- **google-gemini-cli:junghanacs@gmail.com expiring 54m** — gemini bot backend. host에서 `gemini login`
- stale OAuth profile shadow (bbot/gemini/glg/gpt/mini local shadow vs fresher main) — `doctor --fix` 한 번 더 또는 자연 갱신 확인
- main agent orphan transcript 1건 (`485e865f-...`) — `doctor --fix`로 *.deleted 처리 가능

### Stage 3 (plugin-side freeze 해제) — 변동 없음

pi-shell-acp 코어 0.7.0 publish 라운드 완료 + Phase 3 진입 stamp 대기. §4 잔여 ⏸ 항목 + 새 추적 후보 3건 (분신 env hallucination / socketPath placeholder / PI_SESSION_ID stale)은 그때 unfreeze.

### Doctor 잡힌 minor 자리 (별도 사이클, Stage 2와 무관)

- main agent orphan transcript 1건 (`485e865f-...`) — `openclaw doctor --fix`로 *.deleted 처리 가능
- `commands.ownerAllowFrom` 미설정 — owner-only commands 자리
- `~/.openclaw chmod 700` 권장 — 보안 권장사항
- discord plugin 미설치 — 안 씀, 무시
- gateway `0.0.0.0` bind WARN — caddy 앞단 + auth로 가리는 자리, 정공법

### 영속화 destination (Stage 2 성공 후 — 24h soak 통과 시 다음 사이클에서 옮김)

- `nixos-config/AGENTS.md` §3 baseline: 5.12 → 5.18 운영 사실 stamp
- `nixos-config/AGENTS.md` §5 또는 `docs/openclaw-gotchas.md`: **5.x → 5.y host upgrade 절차에 `doctor --fix --yes --non-interactive` 의무 박기** (OAuth profile sidecar → inline migration. 미실행 시 Codex OAuth lane 4 봇 전부 응답 실패)
- `~/openclaw/README.md` change history: 5.18 업그레이드 + Node 22.19 base + plugin 0.7.0 surface 동기화 + doctor --fix 적용 stamp

### 24h 운영 모니터링 자리 (2026-05-20 17:30 KST까지)

- 자연 가족 turn에서 5.18 회귀 신호 모니터링
- Telegram polling reliability 체감 (L132 win 영역)
- stuck-recovery 자연 발생 시 latency 측정 (L59 강화 검증)
- Memory-core dirty=true 자연 해소 패턴 (L199 검증, §1 항목)
- ~~**bbot active-memory pre_compute silent empty final 회귀**~~ → **closed 2026-05-20** (§4 (d) / pi-shell-acp #20, `e7eefeb` + `8b25c1e` fix chain). 후속 watch: 같은 plugin boundary(prompt assembly / output sanitizer / empty-body invariant)에서 *세 번째* leak class 등장하면 즉시 stamp + 새 issue
- 회귀 신호 발견 시 즉시 NEXT.md에 stamp + 필요 시 Dockerfile FROM `2026.5.12`로 롤백 (10분 이내 가능, 백업 `~/openclaw-backups/pre-5.18-20260519-172825/`)
