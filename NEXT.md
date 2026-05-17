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

## 4. pi-shell-acp OpenClaw plugin — Phase 1.8 β 완전 통과

**2026-05-15 18:08 KST — bbot이 `pi-shell-acp/claude-opus-4-7` primary로 텔레그램 turn 완전 통과. workspace 파일(`SOUL.md`/`USER.md`/`memory/*`) 직접 read + 컨텍스트 응답 생성: "오랜만이야, 정한..." 진짜 대화. Phase 1.8 keystone 닫음.**

### 산을 넘은 fix chain

| commit | 내용 | 영향 |
|---|---|---|
| `98c8741` | delivery contract bridge (message tool synthetic toolCall) | spawn 통과해도 final text→message toolCall 정합 |
| `7071f4d` | exit→close fallback (500ms 강제 finalize) | child가 죽어도 stream pending 안 됨 |
| **`02c9c36`** | **stdout parser spin-loop fix** (`while (nl >= 0)` → `while (true) { const nl=...; if (nl<0) break; }`) | **진짜 원인 — JSON parse loop의 nl 재계산 누락이 CPU 100%, event loop 80s 막힘, exit/close listener 미발사** |
| `4e8237c` | docker-lab repro 샘플 추가 (docs only) | 재현 환경 보존 |

### 통과 검증 (Oracle live)

```
[DIAG] turn msgs=3 roles=user,assistant,user deliveryViaMessageTool=0
[DIAG] pre-spawn signalAborted=0 model=claude-opus-4-7
[DIAG] child spawned pid=99 timeoutMs=60000
[DIAG] child exit pid=99 code=0 signal=null         ← 7s clean exit
[DIAG] child finalize kind=close hasFinal=1
       cacheRead=9704 cacheWrite=9996 output=83 token
[telegram] sendMessage ok chat=123861330 message=327
```

### 현재 Oracle 상태

- bbot: `pi-shell-acp/claude-opus-4-7` ✅ live
- gemini: `pi-shell-acp/gemini-3.1-pro-preview` (검증 미완 — bbot GREEN 후 후순위)
- main: picker 5개 enroll (gpt-5.5 primary 유지)
- glg/gpt/mini: 그대로
- Plugin pi-shell-acp `0.6.0-prerelease.0`, install path `~/.pi/agent/git/.../plugins/openclaw` (link mode)
- Host overlay HEAD `4e8237c` main 추적

### 영속화 — 다음 사이클에 AGENTS.md / docs로 옮길 사실

이 블록은 NEXT.md 휘발성이므로 다음 사이클 마무리 시 영속 기록으로 옮기고 지울 것:

- Dockerfile 3-layer (`@earendil-works/pi-coding-agent` + `@zed-industries/codex-acp` + `@google/gemini-cli`) `npm install -g`
- compose 4-mount (`~/.pi/agent` rw + `/home/junghan/.pi/agent` compatibility + `~/.codex` rw + `~/.gemini` rw)
- plugin install: `openclaw plugins install <path> --link --dangerously-force-unsafe-install` → `plugins.allow` / `plugins.entries.<id>.enabled=true` 자동 박힘
- β path = host passthrough, trusted single-user. 공개 default는 α (in-container login + named volumes)


### 남은 잔여 작업 (Phase 1.8 keystone 후 부속)

- [ ] **gemini agent 봇 turn 검증**: bbot GREEN과 동일 path로 `@glg_gemini_bot` turn 확인. Copilot 의존 완전 끊고 pi-shell-acp/Gemini CLI 정상 작동.
- [ ] **main picker `/model pi-shell-acp/...` 전환 turn**: 5개 모델 각 단발 turn 검증.
- [ ] **풀세트 6축 검증 (β 통과선)**: skill manifest (3a) + skill invocation (3b) + 세션 자기인식 + workspace 인식. bbot이 이미 workspace read한 정황으로 거의 통과 상태.
- [ ] **plugin config `spawnTimeoutSeconds` 전달 갭**: openclaw.json `plugins.entries.pi-shell-acp.config.spawnTimeoutSeconds=600` 박았는데 plugin DIAG `timeoutMs=60000` (default 60s) 출력. spin-loop fix 후엔 60s로도 충분하지만 갭 자체는 추적 대상.
- [ ] **adad76af session 누적 ack 청소 정책**: 이전 stuck cycle trajectory에 "Note: I'll respond..." 5건 누적. 현재 새 session `fb3331af` 사용 중이지만 stale session archive 정책 검토.

### 영속 기록 옮길 destination (다음 정리 사이클)

- `~/openclaw/README.md` change history: Phase 1.8 β 완전 통과 stamp
- `nixos-config/AGENTS.md` §3 model routing: bbot=opus-4-7 / gemini=pi-shell-acp 갱신
- `nixos-config/docs/openclaw-gotchas.md`: 5.12 + pi-shell-acp prerelease 정합 + 4-layer install + β path 운영 룰

### Cross-repo follow-up

- [ ] `pi-shell-acp` Phase 2 후보: Codex도 Claude처럼 `require.resolve("@zed-industries/codex-acp/package.json")` fallback 추가. 현재 Codex는 PATH-only라 Docker 실수 포인트가 크다.
- [ ] `pi-shell-acp` 문서에 Docker auth boundary 섹션 추가 여부 확인: "backend CLI auth는 backend가 소유, pi-shell-acp는 token을 읽거나 변환하지 않음."
- [ ] `agent-config` 임시 정책 추적: 0.6.0 prerelease 동안 server-mode가 `pi-shell-acp` main 추적(`agent-config` 5f17d70). Phase 3 release 후 ref pinning 복귀 결정.
- [ ] `plugins/openclaw/README.md` Install layers 항목 보강: settings.json의 host absolute path 호환성 — Docker 환경에서 compose에 `/home/junghan/.pi/agent` 동등 path 두 번째 mount 필요 함정 한 줄.
- [ ] α 별도 advanced smoke (공개 기본값): 통과선 1/1b/2/세션 자기인식만. 별도 사이클.

## 5. Home Assistant on Oracle Docker — Health Connect → lifetract 자동화

**2026-05-17 — 의사결정 완료, 구축 대기.** Samsung Health 수면 데이터를 데일리로 lifetract에 흡수하는 자동화. Tasker/Flutter/Kotlin 자체 앱 검토 끝에 *HA Companion App + 자체 HA 인스턴스* 단일 경로로 압축. 의사결정 근거 전문: `~/org/llmlog/20260517T160459--healthconnect-ha-lifetract-자동화-경로-검토__healthconnect_homeassistant_iot_lifetract_llmlog_nixos.org`.

이 주제는 IoT 실무 dogfooding 가치가 커서 **관심 추적 대상**. homeagent-config 검증과도 직접 연결.

**✅ 진행 게이트 통과** (2026-05-17): §6 정리로 디스크 97% → 67%, 32G 여유.

### 결정 사항

- 호스팅: Oracle ARM Docker (openclaw 패턴 재사용)
- 도메인: `ha.junghanacs.com` (health 아님 — HA는 자동화 허브로 확장). Netlify DNS에 A 레코드 추가 → Oracle 퍼블릭 IP → caddy 자동 LE 발급
- 데이터 경로: Galaxy Fold4 → Samsung Health → Health Connect → HA Companion App → HA Core → lifetract
- lifetract import 1차: REST polling, 1일 1회 cron (recorder DB direct / MQTT는 PoC 이후)
- 도커 패턴: `docker/homeassistant/docker-compose.yml` 신규, `proxy` external network 가입, `~/docker-data/homeassistant/config` 볼륨 — remark42 단일 컨테이너 패턴 복제

### 구축 액션 (§6 통과 후)

- [x] `docker/homeassistant/docker-compose.yml` (remark42 패턴 복제, `proxy` external network, expose 8123)
- [x] Caddy site block: `ha.junghanacs.com` → `homeassistant:8123` (LE 자동 발급 확인)
- [x] `configuration.yaml` 사전 작성 — `use_x_forwarded_for: true` + `trusted_proxies: [172.18.0.0/16, 127.0.0.1, ::1]` (실측 docker proxy subnet) + `external_url`
- [x] `recorder.purge_keep_days: 30` + automation/script/updater exclude
- [x] `ip_ban_enabled: true` + `login_attempts_threshold: 5` (config에 박음)
- [x] Netlify DNS: `ha.junghanacs.com` A 레코드 (사용자 처리)
- [x] HA 첫 부팅 + onboarding 페이지 도달 확인 (`GET /` → 302 /onboarding)
- [ ] **초기 admin 2FA(TOTP) 활성화** — Settings → People → Security (사용자 UI 작업, config 불가)
- [ ] Fold4 Companion App URL 등록 → Health Connect 센서 활성화 (Sleep Duration 우선)
- [ ] PoC: 수면 1개 메트릭 end-to-end (Fold4 → HA → lifetract API) 검증
- [ ] HA Long-lived access token 발급 → lifetract import 스크립트 설계
- [ ] PoC 통과 후 메트릭 확장 (Heart Rate / HRV / Steps / Weight)

### Gotcha 발견 (2026-05-17)

- **Caddyfile bind-mount inode 교체**: 호스트 `Edit`/`Write`가 atomic rename으로 inode 교체 → caddy 컨테이너는 옛 inode 잡고 있어서 `caddy reload`가 "config is unchanged"로 종료. 해결: `docker compose restart caddy`로 재바인딩. AGENTS.md gotcha 항목 후보.

### 메모 — Health Connect 노출 범위

HA Companion App (2024+)이 잡는 것: Sleep Duration/Stages, Heart Rate (avg/min/max/resting), HRV, Steps, Distance, Active/Total Calories, Active Time, Weight, Body Fat, Hydration, VO2 Max, Blood Pressure, Oxygen Saturation. *Samsung 독점 스트레스 점수는 Health Connect로 안 넘어옴* — 필요 시 별도 ADB 백업 경로 검토.

### Cross-repo 연계

- [ ] `lifetract` repo: HA REST polling import 스크립트 (기존 Samsung Health CSV import와 병행 가능하게 — 점진 마이그레이션)
- [ ] `homeagent-config`: HA 인스턴스가 외부에 뜨면 homeagent 플랫폼의 dogfooding/통합 테스트 환경으로 재활용 검토
- [ ] `agent-config`: lifetract 스킬 doc에 HA 경로 활성화 시점 갱신

### 영속화 destination (PoC 통과 후)

- `nixos-config/AGENTS.md`: Oracle 운영 컨테이너 목록에 homeassistant 추가
- `nixos-config/docs/`: HA 운영 노트 (trusted_proxies, 2FA, recorder 정책)
- `lifetract` skill: HA REST 경로 첫 클래스 입력으로 승격

## 6. Oracle 디스크 정리 — HA 도입 선결조건 ✅

**2026-05-17 완료.** 97% → 67%, +28GB 회수. §5 HA 게이트 해제.

### 회수 결과 (2026-05-17)

```
              before          after
df Used%      97%             67%
Avail         3.3GB           32GB
Images        29.39GB (20)    4.925GB (7)
Build cache   7.687GB (207)   0
Reclaimable   27.46GB (93%)   0B (0%)
```

배운 점: `docker system df`의 reclaimable 명목치는 layer 공유 무시. 27GB 명목 → 실회수는 image prune 2.4GB + **builder prune 7.687GB**가 본 회수원. 다음 사이클에는 빌드캐시부터 본다.

### 절차 (참고용 기록)

- [x] llmlog 결정 정리 (`20260517T160459`)
- [x] 사용자: oracle에서 `./run.sh` → `C)` Cleanup ALL (nix gc + 시스템 캐시 → 0.4G 회수)
- [x] run.sh `C)`에 docker prune 단계 통합 (oracle 호스트 분기) — 다음 사이클에서 한 흐름
- [x] `docker image prune -a -f --filter "until=24h"` — dangling 11 + node + openclaw base untag → 2.1GB
- [x] `docker builder prune -a -f` — 207 build cache → 7.687GB
- [x] 회수량 측정 + `df -h /` 결과 stamp
- [ ] (선택) `~/docker-data/{mattermost,synapse}` archival — 비활성 후 데이터 잔존 (사용자 결정 필요, 비긴급)

### 영속화 (다음 정리 사이클)

- `nixos-config/AGENTS.md` §7 Gotchas에 **"OpenClaw 업그레이드 사이클마다 dangling 이미지 + build cache 누적 → run.sh C)로 정기 prune"** 룰 추가
- "`docker system df` reclaimable 명목치 ≠ 실 회수량, builder prune이 본 회수원" 메모 추가
- run.sh `C)` Docker 통합은 AGENTS.md commands 섹션에서 언급
