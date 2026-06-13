# NEXT.md — 다음 할 일

운영 baseline은 [AGENTS.md](AGENTS.md). 후속 작업 / 미완 검증은 여기에.

작업 끝나면 항목 지우고, 새로 발견한 후속은 추가. 영속할 사실은 AGENTS.md / docs/openclaw-gotchas.md / `~/openclaw/README.md` change history로 옮긴다.

---

## ★ 스킬 심볼릭 배포 전환 (트라이얼 성공, 2026-06-09)

워크스페이스 스킬을 **복사 → 심볼릭(repo SSOT 직결)**로 전환 중. butlercli 1개로 트라이얼 → 성공. 되면 **전체 스킬 심볼릭 전환** 예정.

### 검증된 사실 (butlercli 트라이얼, oracle Docker)
- 메커니즘: `config/workspace-glg/skills/butlercli` → 심볼릭 → `/home/junghan/repos/gh/butlercli/.claude/skills/butlercli`
- **이중 마운트가 핵심**: docker-compose `~/repos/gh:/home/junghan/repos/gh:rw`(원래 ~/.claude 호환용) 덕에 `/home/junghan/...` 절대경로가 host·container 양쪽 resolve. (어제 "심볼릭 깨짐, 복사만" 판단은 이 마운트 간과한 오판)
- openclaw config: `skills.load = { allowSymlinkTargets: ["/home/junghan/repos/gh/butlercli/.claude/skills"], watch: true }`. `allowSymlinkTargets`만으로 심볼릭 following 켜짐(skills엔 `followSymlinks` 없음). `watch:true` = 스킬 편집 hot-reload(재시작 불요).
- 검증: 재시작 후 `skills list --agent glg --json`에 `butlercli source=openclaw-workspace` 등록. **no-drift 즉증** — 담당자가 repo SKILL.md에 AREA OVERVIEW mode 추가한 게 재복사 없이 glg에 바로 반영됨.
- **중첩 심볼릭 + scripts/.env 검증 (2026-06-09)**: 스킬 디렉토리 안 `scripts -> ../../../scripts`(repo-root) 상대심볼릭이 워크스페이스 심볼릭 경유로 컨테이너에서 끝까지 resolve. `python3 scripts/estate_area.py 호매실동`이 심볼릭 CWD에서 실 data.go.kr+NEIS로 307건·중위 4.6억 반환. `.env`는 `_estate_common.py`의 `__file__.resolve()`(심볼릭→repo 실경로)→repo/.env + `~/repos/gh/butlercli/.env` fallback으로 로드 — 심볼릭 무관 robust. → **repo-backed 스킬(scripts/ 포함)이 심볼릭으로 완전 동작 = 전체 전환 템플릿 검증됨**. (glg가 17:00에 본 "scripts 없음"은 담당자가 17:01 scripts심볼릭 추가 직전 스냅샷 — 결함 아닌 타이밍)
- ⚠️ 현재 openclaw-config dirty: `workspace-glg/skills/butlercli`(dir→심볼릭) + `openclaw.json`(skills.load). 커밋은 GLG. 백업 `openclaw.json.bak-symlink-trial-*`.

### 다음 한 걸음 (전체 전환 전 결정거리)
- [ ] **device 이식성 결정** — 심볼릭 타깃/allowSymlinkTargets가 device별 다름(oracle `/home/junghan/repos/gh`, Termux `/storage/repos`). openclaw-config가 device 공유면 committed 심볼릭이 깨짐 → **심볼릭은 gitignore하고 run.sh `k)` deploy가 device별 생성**하는 설계가 robust. (현재 k)는 복사 — 심볼릭 생성 모드로 개편 검토)
- [ ] **스코프 결정** — 심볼릭(per-workspace, glg-only) vs `skills.load.extraDirs`(전역 공유, sibling repo 직접 스캔). repo-backed 스킬(butlercli류)은 심볼릭/extraDirs 적합, pi-skills 공유셋(26종)은 복사가 적합 — 혼합 정책 정리.
- [ ] **pi-skills SSOT 루트 화이트리스트** — 전체 전환 시 `~/.pi/agent/skills/pi-skills`(컨테이너 경로 확인) 도 allowSymlinkTargets에 추가 필요.
- [ ] **glg 외 봇 확장** — 트라이얼은 glg만. 전체 봇(workspace*) 일괄 전환 시 run.sh AGENTS_FULL 루프를 심볼릭 생성으로.
- [ ] butlercli 트라이얼 soak: glg 실사용에서 부동산 질문 시 스킬 정상 트리거·실데이터 응답 확인(라이브 turn).

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

## 1. pi-shell-acp 정리 — 완료, 잔재 청소만 (2026-06-10 ACP 제거)

claude-cli native(main/bbot/mini) + codex(glg/gpt) + **gemini 네이티브 `google-gemini-cli` OAuth 전환(2026-06-10)** 으로 pi-shell-acp 사용처 0 → `plugins.entries.pi-shell-acp.enabled=false`로 제거. **이 배포에 third-party ACP 없음.** 정리 사이클의 본체는 끝났고 mount 잔재 청소만 남음.

> 완료분(2026-05-26~31 자리들, **2026-06-10 gemini 네이티브 부활 + pi-shell-acp 제거**, **6.1→6.5 업그레이드**)은 [ROADMAP.md](ROADMAP.md) "운영 결정 이력"/"OpenClaw 업그레이드 이력"으로 이관. pi-shell-acp Issue #25: <https://github.com/junghan0611/pi-shell-acp/issues/25>.

### 남은 한 걸음 (ACP 잔재 청소)

- [⏸] **gemini 챗봇 DOWN — agy 연동 대기 (억지로 살리지 않는다, 2026-06-13)** — gemini 무응답은 `google-gemini-cli` OAuth의 `insufficient authentication scopes [403]`. **재로그인 시도했으나(2026-06-13, `models auth --agent main login --provider google-gemini-cli --force` 완료) probe는 여전히 403** — 발급 OAuth 스코프 자체가 OpenClaw의 Generative AI API 경로를 못 덮는다. **agy(Antigravity) 이관이 gemini-cli OAuth를 스코프 레벨에서 깬 것.** **방침(GLG): API(`google/`)로 억지로 살리지 말 것. 안 되는 대로 DOWN 유지하고 두고 본다.** 차단 해소 조건 = OpenClaw가 **agy/antigravity provider 연동**을 지원하거나 업스트림이 `google-gemini-cli` 스코프를 고칠 때. 그때 모델을 agy provider로 마이그레이션(손으로 creds 복사 아닌 공식 provider 추적 — ROADMAP 2026-06-10 forward 리스크). ⚠️ 재로그인은 config를 `google/` 드리프트시키니 시도 후 반드시 정리(절차·경계 전체는 ORACLE.md gemini 함정 블록).
  - 관찰: OpenClaw 릴리즈 노트/플러그인에 `antigravity`/`agy` provider 등장 여부 주시. 등장 시 이 항목 재가동.
- [ ] **compose mount 정리** — gemini가 마지막 ACP 사용처였다. `docker-compose.yml`의 ACP 전용 mount(`~/.pi/agent`, `~/.claude-plugin/skills` 등)가 남아있으면 제거(이제 unblocked). 단 claude-skills overlay(§ skills)와 겹치는 mount는 남김 — 헷갈리지 말 것.
- [ ] **pi-shell-acp 엔트리 최종 거취** — `enabled:false`로 무력화 완료. **엔트리 *삭제*는 기본 로드 복귀 함정**(2026-06-10 확인)이라 불가 → present + `enabled:false` 영구 유지가 정답. workspace-gemini archival 여부만 별도 판단(현재 네이티브 gemini가 씀, 유지).
- [ ] **#27 moot 확인** — gemini ACP 빈응답(#27)은 네이티브 전환으로 **우리 운영상 해소**. 이슈 자체는 pi-shell-acp repo에서만 추적. #25 분석은 별건.
- [ ] **bbot turn soak GREEN** (canonical `anthropic/claude-opus-4-8` + claude-cli runtime 텔레그램 실사용 관찰)
- [ ] **gemini Pro 쿼터 soak** — `usage: Pro/Flash 100% left`에서 실사용 시 소진 곡선 관찰. fallback 없으니 쿼터 소진=무응답, `Week % left` 주시.
- [ ] **이미지생성(나노바나나) `GEMINI_API_KEY` 경로 미재검증** — gemini 챗봇이 `google-gemini-cli/` OAuth로 전환된 뒤, `GEMINI_API_KEY`(`google` api-key provider) 기반 이미지생성이 여전히 동작하는지 확인. 두 provider가 분리돼 무관할 가능성 큼(추정). **실제 이미지 호출 1회로 검증 전까지 단정 금지.** (`auth.order.google` 핀은 cross-provider라 안 먹어 제거됨 — 자세한 건 ROADMAP 2026-06-10 함정 항목)

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
