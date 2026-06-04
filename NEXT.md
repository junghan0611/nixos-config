# NEXT.md — 다음 할 일

운영 baseline은 [AGENTS.md](AGENTS.md). 후속 작업 / 미완 검증은 여기에.

작업 끝나면 항목 지우고, 새로 발견한 후속은 추가. 영속할 사실은 AGENTS.md / docs/openclaw-gotchas.md / `~/openclaw/README.md` change history로 옮긴다.

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

## 1. pi-shell-acp 의존 정리 사이클 (활성, 2026-05-26 시작)

claude-cli native가 third-party harness 식별 회피 + Pro/Max 한도 + 1M context + workspace-aware skills 모두 충족 → pi-shell-acp wrap path의 필요성 크게 감소. 정리 사이클 진행 중.

> 완료분(2026-05-26 검증 자리, 2026-05-29 bbot native 전환·opus 4.8 승급·verbose full→on·pi-shell-acp 12 commits 최신화, **2026-05-31 OpenClaw 5.28 업그레이드 + Opus 4.8 canonical 정공법 전환 + per-agent auth inherit + 레거시 정리**)은 [ROADMAP.md](ROADMAP.md) "운영 결정 이력"으로 이관. pi-shell-acp Issue #25 분석 요청: <https://github.com/junghan0611/pi-shell-acp/issues/25>.

### 다음 한 걸음

- [ ] **gemini ACP 빈응답 — pi-shell-acp Issue #27** (<https://github.com/junghan0611/pi-shell-acp/issues/27>). pi-shell-acp 최신화 후에도 gemini child ~2s 무출력 exit(placeholder recovery, isError). auth(GEMINI_API_KEY+OAuth creds)·gemini CLI 0.44.1 정상 존재 → gemini-path visible-body 회수 / backend turn-start 영역. **지금 손 못 댐, 이슈로만 추적**. gemini는 삭제 후보라 우선순위 낮음
- [ ] **gemini 거취 결정 (검토 1순위)** — (a) agent 삭제 (텔레그램 봇 회수 / workspace-gemini archival + `pi-shell-acp/gpt-*`·`gemini` picker 엔트리·관련 compose mount 정리) vs (b) #27 해결 후 ACP 유지. claude-cli 비해당(Gemini 모델군)이라 native 전환 불가. **이번 5.28 정공법 전환에서 gemini만 legacy ACP 잔존** — main/bbot/mini는 canonical 완료. 거취 결정이 ACP route stance(AGENTS/ORACLE §2)와 compose mount 정리의 trigger.
- [ ] **gemini stale OAuth shadow 정리** — 5.28 doctor가 `google-gemini-cli` per-agent 프로필(glg/gpt/gemini/bbot/mini)을 stale shadow로 플래그(claude의 `anthropic:claude-cli` shadow는 `doctor --fix`로 이미 제거, main inherit). 이건 claude 아닌 기존 cruft 라 이번 scope 밖 — gemini 거취 결정 시 `doctor --fix`로 함께 정리(현재 Errors 0, 비긴급)
- [ ] **bbot turn 5-7d soak GREEN** (canonical `anthropic/claude-opus-4-8` + claude-cli runtime 안정성 확인. 5.28 전환 직후 headless GREEN, 텔레그램 실사용 soak 관찰)
- [ ] **pi-shell-acp Issue #25 분석 결과** (담당자 OpenClaw dist 분석 → A/B/C 정책)

### 정리 후 검토 자리 (claude ACP 정리 완료 후)

| 자리 | 검토 내용 |
|---|---|
| compose mount 정리 | `~/.pi/agent`, `~/.claude-plugin/skills` 등 — gemini가 마지막 ACP 사용처. gemini 거취 결정 후 필요한 mount만 남김 |
| AGENTS.md §2 ACP route stance | "pi backend 자치권" stance 재검토. claude-cli native가 first-class + claude ACP 정리 완료라 stance 의미 변화 |
| gotchas.md ACPX 비활성 자리 | claude-cli native와 함께 재정리 |
| pi-shell-acp 활용 자리 | gemini(#27) 외 정말 필요한 자리만 남김 vs 완전 deprecation |

---

## 2. 버전 hop 후속 측정 (다음 세션)

6.1 hop 완료 (2026-06-04, headless 5봇 GREEN, [ROADMAP](ROADMAP.md) "2026.6.1"). 운영은 안정이나 다음 자리 측정:

- [ ] **6.1 텔레그램 실사용 soak** — headless GREEN 확인됐으나 실 텔레그램 turn 관찰 필요. 특히 **codex lane glg(가족 봇)** — 6.1 codex auth canonical migration 후 실대화에서 401/empty 없는지. claude lane(main/bbot/mini)도 5-7d soak. codex thread compaction(긴 turn 후 `thread not found`) 회귀 여부도 같이.
- [ ] **6.1 state SQLite 통합 안정성** — plugin/task/telegram state가 shared SQLite로 이관됨(legacy `.migrated` archive). 며칠 후 `.migrated` 잔재 정리 가능 여부 + sqlite 통합 후 telegram dedupe/offset 정상 동작 확인.
- [ ] **subagent bootstrap context 축소 (#85283)** — active-memory recall sub-agent (5.4-mini lane) `status=empty` 비율 변화. 14d soak baseline 비교
- [ ] **`@anthropic-ai/claude-code` 버전 추적** — 5.27 image 재빌드 후 컨테이너 `claude` 2.1.156 (5.22 시점 2.1.150). `--help`에 `claude-opus-4-8` 명시 → opus 4.8 지원. Dockerfile pin 여부 검토
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

---

## 8. NixOS 26.05 업그레이드 (디바이스 베이스, 데드라인 있음)

25.11 "Xantusia" EOL = **2026-06-30** (보안 업데이트 중단). 26.05 "Yarara"는 2026년 5월 말 릴리즈됨. 한 달 안에 올려야 한다. OpenClaw 축과 별개의 디바이스 베이스 작업.

> **⚠️ flake.lock 공유 = 단일 결합점 (2026-06-02 확인)**. repo 하나의 `flake.lock`을 모든 디바이스가 공유한다. nixpkgs/home-manager를 26.05로 bump + `nix flake update` → lock에 26.05 rev가 박힌다. **이 lock을 push하는 순간**, oracle이 pull 후 `switch`하면 바로 26.05로 올라간다. 따라서 **thinkpad 검증 전엔 26.05 lock을 절대 push하지 않는다**. thinkpad `test` 통과 ≠ oracle 통과 — oracle은 hosts/oracle·OpenClaw 때문에 26.05 breaking이 따로 터질 수 있어, oracle에서도 `nixos-rebuild build .#oracle`로 먼저 빌드 확인 후 switch.

- [x] **디스크 선결조건 해소 (2026-06-02)** — thinkpad 90%→75% (46G→107G). build-opi5 52G 삭제 + nix GC 3일/optimise 4.2G/journal 2.2G. 26.05 빌드는 새 클로저(~36G)를 store에 추가하므로 여유 필수였음. → 이제 안전
- [ ] **타이밍** — `.0` 초기 안정화 1~2주 후, 6월 중순~25일 권장 (EOL 전 여유)
- [ ] **flake bump** — `nixpkgs` `nixos-25.11` → `nixos-26.05`, home-manager `release-25.11` → `release-26.05`. `nixpkgs-pinned`(rev 고정)는 무관. **stateVersion 25.05는 그대로 둔다**(최초 설치 마커, 올리지 않음)
- [ ] **thinkpad 선검증 (필수 게이트)** — bump + `nix flake update` 후 **로컬에서** `sudo nixos-rebuild test --flake .#thinkpad` (재부팅 없이, 실패 시 자동 원복). 정상 확인 전엔 lock push 금지. test → switch → 며칠 안정화까지가 게이트
- [ ] **breaking 검토** — 26.05는 systemd initrd default → 부팅 경로 변화. release notes 확인 후 디바이스별 부팅 검증. `nixpkgs-pinned`(Edge URL 우회) 26.05에서 재확인
- [ ] **순서 (리스크 차등)** — thinkpad(검증 게이트) → laptop → nuc(home server) → **oracle 마지막**(봇 런타임 서비스-크리티컬, `build .#oracle` 선확인 후 switch)
- [ ] **태그** — 업그레이드 검증 완료 커밋에 `v2026.6.xx` (tag-release 스킬). 26.05 전환은 CHANGELOG `Changed` 한 줄

---

## 9. 디스크 정리 후속 (2026-06-02, thinkpad)

`run.sh C)` 공격적 정리로 개선 완료(3일 GC + optimise + pnpm prune + 전 디바이스 docker + journal vacuum). 남은 큰 덩어리 — 필요 시 추가 회수:

- [ ] **yocto downloads 21G + sstate-cache 11G** — OPi5 재빌드 캐시. 재빌드 계획 없으면 32G 회수 가능 (`homeagent-config/yocto/`)
- [ ] **work/ 임베디드(rockchip) 빌드 repo 31G** — 빌드 산출물 추정. 정리 대상이면 회수, 확인 필요 (repo명은 PRIVATE)
- [ ] **pnpm store 18G** — 개선된 `C)` 한 번 돌리면 `pnpm store prune`으로 미참조분 회수
- [ ] **store 78G 구조적** — nixpkgs 3트리(25.11 + unstable + pinned) 동시 보유. 26.05 전환 + unstable 정리 시 변화
