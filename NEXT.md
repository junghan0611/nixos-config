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

## 7. OpenClaw 5.18 baseline + 5.20 검토 (2026-05-22)

### 5.18 운영 baseline (Stage 1/2 통과 2026-05-19, soak GREEN)

5.12 → 5.18 host + plugin 0.7.0 surface 합본 통과. detail은 git history (`ef4da1e` 5.18 host bump + `9bbe78e` compose ACP child env + `1d991ff` 5.18 runtime drift snapshot) + 백업 `~/openclaw-backups/pre-5.18-20260519-172825/`. soak 24h 통과 — 회귀 0건.

영속화 destination (다음 정리 사이클):
- `AGENTS.md` §3 model routing: 5.18 baseline stamp
- `AGENTS.md` §5 또는 `docs/openclaw-gotchas.md`: **"5.x → 5.y host upgrade마다 recreate 직후 `doctor --fix --yes --non-interactive` 의무 1회"** — OAuth profile sidecar → inline migration. 미실행 시 Codex OAuth lane 4 봇 (main/glg/gpt/mini) 전부 `FailoverError: No API key found for provider "openai-codex"` 응답 실패. bbot/gemini는 backend CLI auth라 별도 영향 없음
- `~/openclaw/README.md` change history: 5.18 + Node 22.19 base + plugin 0.7.0 surface 동기화 stamp

부수 추적 (비긴급, 별도 사이클):
- main agent orphan transcript 1건 (`485e865f-...`) — `doctor --fix`로 *.deleted 처리
- `commands.ownerAllowFrom` 미설정 — owner-only commands 자리
- `~/.openclaw chmod 700` 권장
- gateway `0.0.0.0` bind WARN — caddy + auth로 가리는 자리, 정공법

### 5.18 → 5.20 직진 결정 (2026-05-22, idle window)

릴리즈: <https://github.com/openclaw/openclaw/releases/tag/v2026.5.20>. 5.19 거대 리팩토링 + 5.20 안정화 chain. hejdev6 담당자 검증 + Oracle live 사전 점검으로 차단 사유 0건 확인 → 직진.

#### 5.19 (Codex OAuth/app-server 거대 리팩토링)

- **#354** `openai/*` → `openai-codex` resolve 시 Codex provider 자동 통과 + OAuth profile 자동 bootstrap. 이전 `No API key found` 자동 해소
- **#310** `doctor --fix`가 legacy `oauthRef` → inline credentials **자동 마이그레이션** — 우리 5.18 Stage 2에서 손으로 박은 정공법(`auth-profiles.json.oauth-ref.<ts>.bak`)이 5.19에서 자동화됨
- 🚨 **#148 Codex app-server scope 분리** — native Codex가 base/personality 소유, OpenClaw는 runtime context + delivery guidance만 contribute. **어제 박은 AGENTS.md §2 architectural stance ↔ #148 identical direction**. 우리 stance가 upstream과 align됨 → §2에 "5.19 #148 align" 한 줄 보강 자리
- #156 채팅 안에서 `/codex plugins list/enable/disable` — config 편집 없이 plugin 토글
- #332 oversized 네이티브 Codex thread 자동 rotation before resume — long-context 봇 stuck 회피
- #366-367 Telegram `/verbose` Codex tool progress 가시성 — 봇 군단 운영 win
- #243 stale session diagnostics + Codex OAuth fallback state 회복 — NEXT §4 stuck-recovery 회로 강화
- #137 Node 22.19 floor — Oracle `v24.14.0` 통과 ✅
- #220 Linux host bwrap/network namespace 정책 충돌 시 sandboxed Codex turn 실패 risk — 5.20 #247/#248로 후속 완화

#### 5.20 (안정화 + harness bump)

- **#47** 번들 Codex harness `@openai/codex` 0.132.0
- **#125** `/codex account` precedence — `config.auth.order` > stale `lastGood`. **order 명시 시 lastGood 무시 / order 없으면 lastGood 여전히 fallback** (담당자 검증 정정 — 내 원분석 "order 없으면 lastGood 무력화" 비약. 우리 환경 risk 가벼움)
- #114 encrypted Responses reasoning replay provenance-bound
- #82 Codex `image_generate` 120s watchdog (이전 30s 폴백 해결)
- #88 before/after_compaction hook 30s timeout
- **#45** Skill `cat SKILL.md && printf ... && <skill-wrapper>` allowlist 제거 — read tool 강제. Oracle grep 결과 **0건** ✅
- #96 Docker official release image keep list에 codex plugin 보존
- **#247** sandboxed Codex code-mode turn에서 OpenClaw sandbox가 outbound egress 허용 시 network access 보존
- **#248** sandboxed workspace-write turn에서 writable Docker bind mounts honor — Docker sandbox 호환성 정공법 개선. risk가 5.18보다 줄어듬

#### hejdev6 ground truth (2026-05-22 담당자 보고)

| 영역 | 5.19 | 5.20 |
|---|---|---|
| turn (voc Codex 첫 turn) | 43.27s | **11.85s ← 큰 단축** |
| 부팅 listen | 3.1s | **22.7s ← 늘어남** |

부팅 vs turn **분리 관측 의무** (담당자 정정): 부팅은 일회성(plugin init / auth resolve / secrets startup), turn-time bwrap은 매 turn. hejdev6 22.7s는 bwrap 안 쓰는 host-native 환경에서도 발생 — bwrap 단독 인과 아님. 어제 내 "로딩/turn 느려짐 stamp"는 부정확.

사고 한 번: hejdev6 `auth.profiles` 빔 → 5.20 #125가 같은 영역 막는 방향. 우리는 main 봇 SSOT inline 완전 박힘 + gpt 봇 lastGood만 `openai-codex` 빠진 상태 (5.21 snapshot drift) — risk 영역 가벼움.

#### 사전 점검 결과 (Oracle live, 2026-05-22 11:35 KST)

| 점검 | 결과 |
|---|---|
| Node 버전 (5.19 #137 floor v22.19) | `v24.14.0` ✅ |
| Skill `cat SKILL.md && printf...` 패턴 grep | **0건** ✅ |
| 현 sandbox 설정 | `plugins.entries.codex.config.appServer.sandbox` / `agents.defaults.sandbox` / top-level `sandbox` 모두 NOT SET → default 동작. 5.20 #247/#248로 default도 5.18보다 안전 |

→ **차단 사유 0건**.

#### 직진 시퀀스 5건

1. **사전 백업** (5.18 Stage 2 동일 패턴) — `~/openclaw-backups/pre-5.20-<timestamp>/`:
   - `~/openclaw/config/memory/*.sqlite{,-shm,-wal}` (8B 4096d 재구축 1290s 회피)
   - `~/openclaw/auth-profile-secrets/` (분실 = 전 봇 재로그인)
   - 3 repo HEAD (`openclaw` + `nixos-config` + `pi-shell-acp` overlay)

2. **`openclaw.json` 두 자리 명시** (담당자 검증 정정 — 정공법 위치 정확히):
   ```json
   "auth": {
     "order": { "openai-codex": ["openai-codex:junghanacs@gmail.com"] },
     "profiles": { /* 기존 4종 그대로 */ }
   },
   "plugins": { "entries": { "codex": {
     "config": { "appServer": { "sandbox": "danger-full-access" } }
   } } }
   ```
   - `auth.order`: top-level (schema `properties.auth.properties.order`, propertyNames=provider id → profile id array)
   - `plugins.entries.codex.config.appServer.sandbox`: enum `read-only` / `workspace-write` / `danger-full-access`. 5.20 #247/#248 덕에 default도 안전 — 박는 게 필수는 아니나 **conservative 선택** (Cloud VM + Docker namespace + bwrap 3중 중 bwrap 무력화)

3. **Dockerfile FROM `2026.5.18` → `2026.5.20`** (롤백 주석 5.18로 갱신) → `docker compose build --pull` + `up -d --force-recreate`. ready 시간 측정 (5.18 baseline 36.3s cold)

4. **recreate 직후 즉시 OAuth migration**: `docker exec openclaw-gateway openclaw doctor --fix --yes --non-interactive` (5.19 #310 자동 마이그레이션 활용. main 봇 이미 완전 inline이라 `oauth-ref.<ts>.bak` 새로 안 쌓일 가능성)

5. **검증 매트릭스**:
   - 6 봇 polling boot OK (5.18 baseline 12 plugins, 5.20 bundled Policy 추가 가능)
   - bbot/gemini cold turn latency (5.18 baseline 9.8s / 24.6s) — **부팅 ready vs turn latency 분리**
   - main/glg/gpt active-memory recall status 회귀 X
   - bundled Policy plugin (#80407) channel conformance/lint 영향
   - memory index `--deep --json` vector 진단

회귀 시 Dockerfile FROM 5.18로 되돌리고 build+recreate (10분 이내). 백업 디렉토리에서 memory sqlite restore.

#### 영속화 (직진 통과 후, 다음 정리 사이클)

- `AGENTS.md` §3 model routing: 5.18 → 5.20 baseline stamp
- `AGENTS.md` §2 ACP route stance: 5.19 #148 align 한 줄 보강 (upstream과 동일 방향)
- `docs/openclaw-gotchas.md`: top-level `auth.order` 정공법 + plugin sandbox config 정공법 + Node floor + skill prefix 패턴 점검
- `~/openclaw/README.md` change history: 5.20 + harness 0.132 stamp

### 스킬 배포 후속 — logickocli 신규 (2026-05-22)

`run.sh k`로 6 workspace (main/glg/gpt/gemini/mini/bbot) + claude-skills 25 skills 균일 동기화. SKILL.md 3종 갱신 (botlog / lifetract / semantic-memory) + bibcli bin 갱신은 hot reload 처리됨. **logickocli 신규 1건** — AGENTS.md §6 "Adding skill directories requires restart" 적용 자리.

- [ ] **gateway restart 1회 — logickocli 디렉토리 인식**. `cd ~/openclaw && docker compose restart openclaw-gateway`. 5.18 baseline ready 36.3s cold / 9~11s warm 참고
- [ ] 한 봇으로 logickocli 호출 turn 확인 (자연 trigger 또는 직접 prompt)

### Stage 3 (plugin-side freeze 해제) — 변동 없음

pi-shell-acp 코어 0.7.0 publish 라운드 완료 + Phase 3 진입 stamp 대기. §4 잔여 ⏸ 항목 + 새 추적 후보 3건 (분신 env hallucination / socketPath placeholder / PI_SESSION_ID stale)은 그때 unfreeze.

---

## 8. OpenClaw 5.22 직진 GREEN (2026-05-26)

릴리즈: <https://github.com/openclaw/openclaw/releases/tag/v2026.5.22>. 5.20 → 5.22 직진 완료.

### 결과

| 자리 | 결과 |
|---|---|
| Pull 5.22 | 47s (직전 `compose build --pull` 18분 stuck — daemon hang, kill 후 직접 pull로 회복) |
| Build | 1m58s → 40s (cache 활용 rebuild) |
| Recreate ready | 9s |
| **Dockerfile patch** | `@anthropic-ai/claude-code` 추가 — 5.22가 더 이상 `claude` binary 번들 안 함 (5.20까지 `@anthropic-ai/claude-agent-sdk` SDK+binary, 5.22는 raw `@anthropic-ai/sdk@0.97.1`만). 누락 시 EPIPE 즉시 abort. **release notes 누락 자리** |
| Streaming policy 확장 | `claude-cli` 라우트도 pi-shell-acp 5-16 incident 동일 패턴 ("답변 보였다 사라짐") → `channels.telegram.accounts.default.streaming.mode: off` |
| Agent CLI turn | "claude-cli/claude-sonnet-4-6 · OpenClaw 2026.5.22" 응답 |
| 텔레그램 turn | 깨끗하게 도착 (streaming off 후) |

영속 stamp는 AGENTS.md §3 (5.22 baseline) + claude-cli provider note + docs/openclaw-gotchas.md (EPIPE 활성 항목)로 이관.

### 남은 후속 (다음 세션 측정 자리)

- **subagent bootstrap context 축소 (#85283) 측정**: active-memory recall sub-agent (5.4-mini lane) `status=empty` 비율 변화. 14d soak baseline 비교
- **`@anthropic-ai/claude-code` 버전 추적**: 현재 2.1.150. Dockerfile pin 여부 검토
- **OAuth refresh 자동 검증**: `expiresAt` 8h마다 새로 받는지 24h 관찰
- **active-memory 35s timeout 빈도**: claude-cli 환경에서 mini lane recall이 30~35s까지 늘어남 (직전 baseline 5-10s). subagent context 축소와 연관 가능

### 직전 §8 release notes 분석 (참고용 보존)

릴리즈: <https://github.com/openclaw/openclaw/releases/tag/v2026.5.22> (2026-05-24 01:12 UTC published). 5.20 baseline GREEN(commit `3686dfb`) 후 하루 만의 minor hop. 다음 세션에서 직진 여부 판단.

### 핵심 — 우리가 손으로 잡은 자리의 자동화

| 영역 | 5.22 변화 | 우리 컨텍스트 |
|---|---|---|
| **Codex OAuth sidecar (Auth/Codex)** | embedded runner secrets-runtime auth loaders가 legacy OAuth sidecar 자동 인식. Telegram replies / cron-triggered / **isolated sub-agent lanes** 모두 `doctor` 거치지 않고 `#83312 refresh-and-rewrite` migration 자동 도달 | 5.18 incident (cd45fbbc 세션, doctor --fix로 4봇 main/glg/gpt/mini auth-profiles.json 마이그레이션) 자리. 5.19 #310 host-level 자동화의 sub-agent lane 보강. **active-memory recall sub-agent (mini lane) 도 자동 처리** |
| **dreaming side-effect gate** | `dreaming.enabled=false`일 때 recall tracking이 dreaming 부산물 안 씀 (#84436) | 우리 `thinking=off, persistTranscripts=false`와 정합. 부수 잡음 제거 자리 |
| **Memory-core dreaming session keys** | stable narrative subagent session keys per workspace/phase. `dreaming-narrative-*` 누적 fix (#68252/#69187/#70402) | dreaming off라 즉시 win은 아니지만 향후 활성화 시 안전 |

### ACP path (bbot/gemini)

| 영역 | 5.22 변화 | 우리 컨텍스트 |
|---|---|---|
| **sessions_spawn orphan cleanup** | parent session reset/delete 시 child ACP session 자동 정리. orphan `claude-agent-acp` 누적으로 인한 memory exhaustion 회피 (fixes #68916) | **bbot/gemini pi-shell-acp route 직접 영향**. §4 잔여 검증에 메모리 안정성 축 +1 |
| **embedded sessions_spawn child handoff terminal progress** | accepted handoff을 terminal progress로 인식. false non-deliverable failures 해소 (#85054) | Phase 1.8 bbot turn에서 봤던 패턴과 같은 자리 |
| **pi-coding-agent auto-retry off** | OpenClaw 자체 retry/failover와 nested SDK retry 충돌 회피 (#73781) | pi-shell-acp route 장기 안정성 |

### Telegram isolated polling (5.12 함정 자동화)

| 영역 | 5.22 변화 | 우리 컨텍스트 |
|---|---|---|
| **pollingStallThresholdMs honor (default isolated path)** | silent worker 자동 restart (fixes #83950) | **5.12 baseline AGENTS.md §3 stamp**: "isolated polling은 boot 직후 fetch-timeout 발생 시 polling thread를 죽일 수 있어 즉시 restart 필요" — 자동 회복 가능. **gotchas.md 갱신 자리** |
| **dead-letter poisoned spool** | poisoned update 1건이 같은 lane 후속 차단 안 함 (#85470) | 6 봇 spool 격리 강화 |
| **replay dedupe** | isolated-ingress replay 중복 dispatch 방지 (#84886) | |

### Gateway 성능 (ARM cold-start)

| 영역 | 5.22 변화 | 우리 컨텍스트 |
|---|---|---|
| plugin metadata snapshot reuse | startup/config/model/channel/setup/secret reader가 immutable snapshot 공유 | 5.20 ready 46s baseline 대비 단축 가능. 측정 자리 |
| lazy-load startup-idle plugin work | core gateway method handlers + ACPX runtime lazy | acpx disabled라 부분 적용 |
| `/models` per-call 20s → 5ms (~4100×) | provider auth-state map pre-warm (#84816) | `/status`/`/models` 응답성 |
| deferred prewarm after readiness | 초기 gateway tool/session 요청이 auth discovery에 막히지 않음 (#85272) | boot 직후 부하 감소 |

### ⚠️ 주의 자리 — 직진 전 검증

| 영역 | 5.22 변화 | 우리 컨텍스트 |
|---|---|---|
| **Retired catalog prune + doctor migration** | retired Groq/Copilot/OpenAI/xAI/old Claude catalog 제거 + doctor가 current provider refs로 업그레이드 | **5.20 #96 keep list로 우리가 보존한 자리와 충돌 가능**. 업그레이드 후 `doctor --fix` 직접 돌리면 catalog가 다시 떨어질 risk. **dry-run 먼저** (config diff 비교) |
| **Subagent bootstrap context 축소 (#85283)** | default sub-agent에 `AGENTS.md` + `TOOLS.md`만 전달. persona/identity/user/memory/heartbeat/setup 제외 | active-memory recall sub-agent (5.4-mini lane) context 축소 → `status=empty` 비율 변화 가능. §2 14d baseline 비교에 측정 변수 추가 자리 |
| **plugins discovery `-plugin` suffix strip (#85170)** | package name → manifest id 매칭 자동 | pi-shell-acp `@openclaw/pi-shell-acp-plugin` 이름 영향 확인 자리 (현재 link install이라 영향 없을 가능성 높지만 검토) |

### 직진 vs hejdev6 사전 검증 — 다음 세션 판단

- **직진 근거**: 5.20 → 5.22 hop이 짧고 (3일), 우리가 손으로 잡은 자리 자동화 위주. 신규 destructive 변화 없음
- **hejdev6 사전 검증 근거**: catalog prune (L79) + subagent context 축소 (L34) 두 자리는 우리 환경에 측정 가능한 영향. hejdev6 담당자에서 미리 확인 가능하면 risk 줄어듬
- **결정 자리**: 5.20 baseline 14일 soak 진행 중인 점 고려. 안정성 우선 vs 자동화 가치 trade-off

### 직진 시퀀스 (선택 시)

1. **사전 백업** — `~/openclaw-backups/pre-5.22-<timestamp>/`: memory sqlite + auth-profile-secrets + Dockerfile.5.20 + openclaw.json.5.20 + 3 repo HEAD (5.20 직진 패턴 동일)
2. **Dockerfile FROM `2026.5.22`** (롤백 주석 5.20으로 갱신) → `docker compose build --pull` + `up -d --force-recreate`. ready 시간 측정 (5.20 baseline 46s cold)
3. **`doctor --fix --yes --non-interactive`** 전 — **config dry-run**: `python3` diff로 catalog prune 영향 확인. keep list와 충돌 시 keep list 재명시
4. **6 봇 polling boot OK** + bbot/gemini cold turn latency + main/glg/gpt active-memory recall status 회귀 X
5. **신규 측정 축**: `/models` 응답시간 (5.22 perf claim 검증, 5.20 baseline 측정 필요)

회귀 시 Dockerfile FROM 5.20으로 되돌리고 build+recreate. memory sqlite restore.

### 영속화 (직진 통과 후, 다음 정리 사이클)

- `AGENTS.md` §3 model routing: 5.20 → 5.22 baseline stamp
- `AGENTS.md` §3 Telegram polling stamp: "5.22부터 isolated polling stall 자동 restart" — boot 직후 fetch-timeout 수동 restart 의무 해제 가능 여부 확인 후 갱신
- `docs/openclaw-gotchas.md`: catalog prune ↔ keep list 충돌 검증 결과 추가
- `~/openclaw/README.md` change history: 5.22 stamp
