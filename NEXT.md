# NEXT.md — 다음 할 일

운영 baseline은 [AGENTS.md](AGENTS.md). 후속 작업 / 미완 검증은 여기에.

작업 끝나면 항목 지우고, 새로 발견한 후속은 추가. 영속할 사실은 AGENTS.md / docs/openclaw-gotchas.md / `~/openclaw/README.md` change history로 옮긴다.

---

## 0. Forge — 포지 레이어 인프라 (활성, 2026-05-27 가동)

`forge.junghanacs.com` (Forgejo 15.0.2 LTS, postgres 16-alpine, Caddy + Let's Encrypt) Oracle 가동. 봇멘트의 코드면 확장. 설계: 노트 `20260527T073823`.

### 운영 책임 경계

| 자리 | 책임 |
|---|---|
| **이 repo** `docker/forge/` | Docker compose, Caddy 블록, host-specific 인프라 (oracle 박힘, alskdjf 예정) |
| **`forge-config` repo** | 운영 ownership — 라벨/footer/봇 행동 규약 + bin/forge CLI + agent skill SSOT |
| **`agent-config/skills/forge`** | thin pointer → forge-config repo (앞으로 추가) |

### 다음 한 걸음

- [ ] **alskdjf 추가** — 같은 compose 구조 복사, DOMAIN/데이터 path만 호스트별 변경. SETUP.org 그대로 재사용 가능
- [ ] **gotchas 박제** — `INSTALL_LOCK=false` env 함정 / 단일 파일 bind mount inode caching → `docker/forge/SETUP.org` 트러블슈팅 섹션은 이미 채워짐. 운영 사실로 진화하면 별도 docs/forge-gotchas.md 분리
- [ ] **백업 cron 도입** — `pg_dump` + `tar` 일별 자동 (현재 수동)
- [ ] **fail2ban Forgejo jail** — 도메인 노출 후 공격 패턴 관찰하고 활성

### 운영 책임 아님

- ❌ 라벨 정책 / footer 규약 / agent 행동 → forge-config repo
- ❌ bin/forge CLI / agent skill → forge-config repo
- ❌ 7-spike 로드맵 → agent-config #13 + forge-config/NEXT.md

---

## 1. pi-shell-acp 의존 정리 사이클 (활성, 2026-05-26 시작)

claude-cli native가 third-party harness 식별 회피 + Pro/Max 한도 + 1M context + workspace-aware skills 모두 충족 → pi-shell-acp wrap path의 필요성 크게 감소. 정리 사이클 진행 중.

### 검증된 자리 (2026-05-26)

- main `claude-cli/claude-opus-4-7` + mini `claude-cli/claude-sonnet-4-6` 텔레그램 turn GREEN
- 1M context 잡힘 (third-party API 200k와 본질적 차이)
- workspace-aware skill 호출 정상
- `verboseDefault: on` 전역 — 봇 내부 동작 검토 가능
- pi-shell-acp Issue #25 분석 요청 작성: <https://github.com/junghan0611/pi-shell-acp/issues/25>

### Trigger 대기

- [ ] **pi-shell-acp Issue #25 분석 결과** (담당자 OpenClaw 5.22 dist 분석 → A/B/C 정책 결정)
- [ ] **bbot turn 5-7d soak GREEN** (claude-cli 전환 안정성 확인)

### Trigger 후 검토 자리

| 자리 | 검토 내용 |
|---|---|
| bbot 전환 | `pi-shell-acp/claude-opus-4-7` → `claude-cli/claude-opus-4-7`. 동일 모델, path만 변경 |
| gemini 전환 | `pi-shell-acp/gemini-3.1-pro-preview` → 별도 `gemini-cli` provider 등록 가능한지 확인 (`@google/gemini-cli` image에 있음). 또는 agent 자체 삭제 (gpt-5.4로 통합 / 텔레그램 봇 회수 / workspace-gemini archival) |
| compose mount 정리 | `~/.pi/agent`, `~/.claude-plugin/skills` 등 claude-cli 전환 후 의미 줄어듬. 필요한 mount만 남김 |
| AGENTS.md §2 ACP route stance | "pi backend 자치권" stance 재검토. claude-cli native가 first-class라 stance 의미 변화 |
| gotchas.md ACPX 비활성 자리 | claude-cli native와 함께 재정리 |
| pi-shell-acp 활용 자리 | 정말 필요한 자리(다른 cloud / 다른 모델 via pi backend)만 남김 vs 완전 deprecation |

---

## 2. 5.22 후속 측정 (다음 세션)

5.22 hop 완료 (`8a2f8ef` stamp). 운영은 안정이나 다음 자리 측정:

- [ ] **subagent bootstrap context 축소 (#85283)** — active-memory recall sub-agent (5.4-mini lane) `status=empty` 비율 변화. 14d soak baseline 비교
- [ ] **`@anthropic-ai/claude-code` 버전 추적** — 현재 2.1.150. Dockerfile pin 여부 검토
- [ ] **OAuth refresh 자동 검증** — Anthropic `expiresAt` 8h마다 새로 받는지 24h 관찰
- [ ] **active-memory 35s timeout 빈도** — claude-cli 환경에서 mini lane recall이 30~35s까지 늘어남 (직전 baseline 5-10s). subagent context 축소와 연관 가능

---

## 3. active-memory 관찰 후속 (장기)

24h baseline 통과 (2026-05-08~09, gpt 14 invocation: ok 4 / empty 10 / timeout 0 / elapsed ~8.3s).

확장 후 관찰 (mini가 `claude-cli/sonnet-4-6` 검증 lane으로 빠진 상태 — 현재 active-memory 대상: main/glg/gpt/bbot):

- [ ] **glg(가족 봇) 응답 latency 체감** — 가족 사용 turn 후 피드백. "느려졌다" 호소 시 glg만 제외
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
