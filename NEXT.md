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
  - 5.7+4B 사이클에서 6 agents 모두 `dirty=true` → incremental 1회로 해소됐던 패턴. 8B에서도 동일하면 upstream issue로 보고.

## 2. active-memory 확장 후속 (main/glg/gpt/mini)

(2026-05-09 12:59 KST 확장) gpt 단독 24h 관찰 OK → main/glg/mini 추가. gemini(삭제 예정)/bbot(ACP path) 제외. 24h 결과는 AGENTS.md §3 active memory 섹션에 stamp 완료.

24h 관찰 결과 (2026-05-08 08:58 ~ 2026-05-09 03:45 UTC, gpt 14 invocation):
- status: ok 4 / empty 10 / timeout 0
- elapsedMs: min 5388 / max 13256 / 평균 ~8.3s
- summaryChars (ok): 164 / 178 / 203 / 216 — 모두 220 한도 내
- 13.2s spike 1건은 동시 발생 `event_loop_delay 1678ms` liveness warning과 상관

확장 후 후속 관찰:

- [ ] **glg(가족 봇) 응답 latency 체감 변화**
  - 가족 사용 turn 후 가족 피드백 수집. "느려졌다" 류 호소 발생하면 glg만 다시 제외
  - active-memory recall sub-agent 자체가 5–10s 본질이라 main 응답 자체에 추가되는 latency가 아님 — 메인 응답 시작 직전 한 번 도는 구조
- [ ] **main agent 회상 품질 정성 평가**
  - main은 가장 generalist deep work라 회상이 가장 유의미할 가능성. status=ok 비율 추적
- [ ] **mini agent에서 의미 있는지 재검증**
  - mini는 format/proofread 전용이라 "이전 대화 이어서" 패턴이 거의 없음. status=empty가 압도적이면 mini만 제외 검토
- [ ] **확장 후 14일 baseline**
  - 4개 봇 합산 invocation/day, status 분포, elapsed 분포 집계
  - timeout 빈도 0% 유지되는지 — 다중 봇 동시 호출 시 OAuth quota 경합 검증

## 3. (참고) gemini agent 정리

비긴급. AGENTS.md §3 Model routing에 "Copilot 잔재(`gemini` agent)는 **삭제 예정**" 표시. 5.7 운영 안정 확인 후 별도 사이클에서 처리.

- [ ] gpt-5.4로 통합할지 (workspace-gemini → workspace-gpt로 흡수) 또는 agent 자체 삭제할지 결정
- [ ] 텔레그램 봇 `@glg_gemini_bot` 회수 절차 (BotFather)
- [ ] workspace-gemini 인덱스 데이터 archival

## 4. pi-shell-acp OpenClaw plugin — Phase 1.8 β infra GREEN, 봇 endpoint 미해결

**2026-05-15 — Phase 1.8 β host passthrough Oracle 인프라까지 첫 통과, 봇 endpoint integration은 stub 한계로 미해결. bbot/gemini는 옛 model로 임시 원복, β infra(mount/Dockerfile/plugin install/picker) 유지.**

### 통과한 항목

- Host pi-shell-acp `8476104→98c8741→7071f4d` (main 추적, `~/.pi/agent/git/github.com/junghan0611/pi-shell-acp`).
- UID 매핑: host `junghan` UID 1000 / container `node` UID 1000 — bind-mount rw 무사. GID 100↔1000 불일치는 owner-bit write로 무관.
- Dockerfile 3-layer (`@earendil-works/pi-coding-agent` + `@zed-industries/codex-acp` + `@google/gemini-cli`) `npm install -g` 27s.
- Compose: `~/.pi/agent` rw + `/home/junghan/.pi/agent` compatibility mount (host absolute path 호환) + `~/.codex` rw + `~/.gemini` rw.
- Plugin install: `openclaw plugins install <plugin-dir> --link --dangerously-force-unsafe-install` → `plugins.allow` / `plugins.entries.pi-shell-acp.enabled=true` 자동 박힘. `plugins inspect` Status: loaded, capability `text-inference: pi-shell-acp`.
- 11 plugins ready 9.0s. Direct turn `pi -p ... --provider pi-shell-acp --model claude-sonnet-4-6` GREEN (cache write 10503 → 19,247).

### 미해결 — 봇 endpoint integration (stub PoC 한계)

bbot/gemini를 `pi-shell-acp/claude-opus-4-7` / `pi-shell-acp/gemini-3.1-pro-preview`로 박았을 때 텔레그램 inbound가 stuck. 패치 두 사이클 시도:

1. **98c8741 — delivery contract bridge**: OpenClaw가 inbound prompt에 "Delivery: to send a message, use the `message` tool" inject. child pi는 `--no-tools`로 spawn돼 message tool 모름 → 응답을 buffer 후 close에서 synthetic toolCall로 변환. unit test 통과. Oracle 적용은 close 도달 전 child가 die해서 검증 못 함.
2. **7071f4d — exit→close fallback**: child가 exit해도 stdio close 안 와서 stream pending인 케이스. 500ms 후 강제 finalize. Oracle 적용 결과 `child exit` log 자체가 안 찍힘 — Node `child.on("exit")` listener까지 이벤트가 도달 안 함.

발견된 깊은 원인 후보 (다음 사이클 입력):
- **OpenClaw가 plugin createStreamFn 호출 시 `options.signal`에 이미 abort된 AbortSignal 전달 가능성** — plugin의 `signal.addEventListener("abort", () => child.kill("SIGTERM"))` 즉시 fire → spawn 직후 SIGTERM. 첫 patch에 박았던 `signalAborted` debug log가 lab push에 누락되어 미확인. 다음 사이클에서 가장 먼저 박을 것.
- **plugin config `spawnTimeoutSeconds` 600 → plugin은 60000ms 사용**: openclaw.json `plugins.entries.pi-shell-acp.config.spawnTimeoutSeconds=600` 박았으나 plugin이 `factoryCtx.pluginConfig || factoryCtx.config || factoryCtx.settings`에서 못 받음. OpenClaw가 plugin config를 어디 key로 전달하는지 확인 필요.
- **`processing,q=1` 같은 entity 동시 active+queued**: OpenClaw turn loop이 응답 없으면 무한 retry 패턴. turn-level abort timeout 정책이 plugin spawnTimeout보다 짧을 가능성.
- Liveness warning `event_loop_delay 79926ms` `eventLoopUtilization=0.975` — 봇 turn 처리 중 event loop 80초 막힘.

### 직접 호출 vs 봇 호출 차이 (재진단 입력)

- 직접 `docker exec ... pi -p ... --provider pi-shell-acp --model claude-opus-4-7`: GREEN 5–10s, cache hit/write 정상.
- 봇 path: child spawn 후 1초 내 zombie, exit/close 이벤트 plugin listener까지 안 도달.
- 동일 env (`PI_OFFLINE=1` + `NODE_COMPILE_CACHE` + `OPENCLAW_NO_RESPAWN=1` + `OPENCLAW_PACKAGED_COMPILE_CACHE_RESPAWNED=1`) + 동일 cwd (`/home/node/.openclaw/workspace-bbot`) + 동일 plugin require path → 직접 호출은 여전히 GREEN. 차이는 OpenClaw가 plugin streamFn 호출 시 박는 `options` 객체(특히 `signal`).

### 발견한 plugin config 전달 갭

`openclaw.json` 의 `plugins.entries.pi-shell-acp.config.spawnTimeoutSeconds=600` 박았는데 plugin DIAG가 `timeoutMs=60000` (default 60s) 출력. OpenClaw가 plugin config를 어느 path/shape로 전달하는지 lab에서 검증 필요.

### 현재 Oracle 상태 (원복 후)

- bbot: `openai/gpt-5.4` (codex agentRuntime, 원래 상태)
- gemini: `github-copilot/gemini-3.1-pro-preview` (Copilot 잔재, 원래 상태)
- main: `openai/gpt-5.5` (picker 5개 제거)
- glg/gpt/mini: 변경 없음
- Plugin pi-shell-acp 자체는 `plugins.allow` + `entries.enabled=true` 유지 → 다음 사이클에 lab에서 통합 patch 가져오면 바로 재활성 가능.
- spawnTimeoutSeconds=600 config는 유지 (다음 사이클에서 config 전달 갭 검증용).
- Dockerfile 3-layer / compose 4-mount는 유지 — β infra는 그대로 살림.

### 다음 사이클 입력 (lab 통합 patch 준비)

- [ ] **봇 spawn signal 추적 debug 추가** (가장 우선): pre-spawn에 `signalAborted` 출력, signal abort listener fire 시점 console.log, `setInterval(() => { try { process.kill(child.pid, 0) } catch { finalizeChild('orphan',...) } }, 1000)` 폴링 fallback. 첫 turn에서 진짜 SIGTERM 출처 잡기.
- [ ] **plugin config 전달 갭 진단**: OpenClaw 5.12에서 `plugins.entries.<id>.config`가 plugin factoryCtx에 어떤 path로 전달되는지 확인. 600 박힌 게 plugin에 안 흘러 들어가는 이유.
- [ ] **Phase 1.4 ts refactor 우선순위 재검토**: stub PoC 한계가 race condition에 직격. ACP transport 직접 처리로 child pi spawn 자체 제거하면 race 사라짐. 단 그 작업 자체 규모 큼.
- [ ] **lab에서 통합 patch 검증 흐름**: lab gateway (Docker 안 OpenClaw 5.12 with 우리 patch)에서 봇 turn까지 재현해서 GREEN 확인 후 push. Oracle 단방향 적용만 반복하지 말 것.
- [ ] **풀세트 6축 검증 재시도** (lab 통합 patch 적용 후): skill manifest (3a) + skill invocation (3b) + 세션 자기인식 + workspace 인식. β라 풀세트가 통과선.

### Cross-repo follow-up

- [ ] `pi-shell-acp` Phase 2 후보: Codex도 Claude처럼 `require.resolve("@zed-industries/codex-acp/package.json")` fallback 추가. 현재 Codex는 PATH-only라 Docker 실수 포인트가 크다.
- [ ] `pi-shell-acp` 문서에 Docker auth boundary 섹션 추가 여부 확인: "backend CLI auth는 backend가 소유, pi-shell-acp는 token을 읽거나 변환하지 않음."
- [ ] `agent-config` 임시 정책 추적: 0.6.0 prerelease / Oracle 검증 동안 server-mode가 `pi-shell-acp` main을 추적(`agent-config` 5f17d70). Phase 3 release 후에는 다시 ref pinning으로 복귀할지 결정.
- [ ] `plugins/openclaw/README.md` Install layers 항목 보강: settings.json의 host absolute path 호환성 — Docker 환경에서 compose에 `/home/junghan/.pi/agent` 또는 동등 path 두 번째 mount 필요할 수 있다는 함정 한 줄. β 운영 시 첫 smoke에서 발견.
- [ ] α 별도 advanced smoke (공개 기본값): 통과선은 1/1b/2/세션 자기인식만. 별도 사이클.
