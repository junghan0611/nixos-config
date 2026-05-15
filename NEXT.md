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

## 4. pi-shell-acp OpenClaw plugin — Phase 1.8 β keystone 통과 후 잔여

**2026-05-15 14:00 KST — Phase 1.8 β host passthrough Oracle 첫 통과.** Plugin `pi-shell-acp@0.6.0-prerelease.0` loaded, `text-inference: pi-shell-acp` capability 등록, `pi -p ... --provider pi-shell-acp --model claude-sonnet-4-6 --no-tools --no-session` direct turn GREEN (Claude Code cache write 10503). 영속 운영 baseline은 AGENTS.md / openclaw-gotchas.md / `~/openclaw/README.md` change history에 별도 stamp 예정.

통과한 사전조건 (요약, 영속 기록 옮긴 후 이 블록 자체는 지울 것):
- Host pi-shell-acp `8476104` (`main` 추적, `~/.pi/agent/git/github.com/junghan0611/pi-shell-acp`).
- UID 매핑: host `junghan` UID 1000 / container `node` UID 1000 — bind-mount rw 무사 작동 확인. GID 100↔1000 불일치는 owner-bit write로 무관.
- Dockerfile 3-layer (`@earendil-works/pi-coding-agent` + `@zed-industries/codex-acp` + `@google/gemini-cli`) `npm install -g` 27s.
- Compose: `~/.pi/agent` rw bind-mount + `/home/junghan/.pi/agent` compatibility mount (host absolute path 호환) + `~/.codex` rw + `~/.gemini` rw.
- Plugin install: `openclaw plugins install <plugin-dir> --link --dangerously-force-unsafe-install` → `plugins.allow` / `plugins.entries.pi-shell-acp.enabled=true` 자동 박힘.
- 11 plugins ready 9.0s.

남은 검증 / 후속:
- [ ] **실 봇 turn 검증**: 별도 테스트 agent 추가 또는 `/model pi-shell-acp/claude-sonnet-4-6` in-thread 전환. 가족 봇 config는 건드리지 말 것. 텔레그램에서 GLG 직접.
- [ ] **나머지 picker 5종**: `claude-opus-4-7`, `gpt-5.4`, `gpt-5.5`, `gemini-3.1-pro-preview` 각 1턴씩. Codex/Gemini는 host auth refresh 한 번 더 확인 후.
- [ ] **풀세트 6축 검증**: skill manifest (3a) + skill invocation (3b) + 세션 자기인식 + workspace 인식 — 어제 thinkpad lab 6축 통과선 Oracle 환경 재현 여부. β라 통과선 풀세트가 정상 기대치.
- [ ] **`models list` CLI surface 부재 문서화**: dynamic resolution path 의도된 동작. operator가 헷갈리지 않게 plugin AGENTS.md 또는 README에 한 줄 추가. (Cross-repo follow-up)
- [ ] **α 별도 advanced smoke (공개 기본값)**: trusted host 가정 없이 in-container login + named volume(4a) 경로가 일반 사용자에게 정직한 default UX인지 별도 사이클에서 확인. 통과선은 1/1b/2/세션 자기인식만.
- [ ] **백업 정책 — `~/openclaw/config/plugins/installs.json`**: plugin install이 이 파일도 변경함. private repo `~/openclaw`에는 commit, public `nixos-config/docker/openclaw/`에는 옮기지 않음 (기존 openclaw.json과 동일 정책).

Cross-repo follow-up:
- [ ] `pi-shell-acp` Phase 2 후보: Codex도 Claude처럼 `require.resolve("@zed-industries/codex-acp/package.json")` fallback 추가. 현재 Codex는 PATH-only라 Docker 실수 포인트가 크다.
- [ ] `pi-shell-acp` 문서에 Docker auth boundary 섹션 추가 여부 확인: "backend CLI auth는 backend가 소유, pi-shell-acp는 token을 읽거나 변환하지 않음."
- [ ] `agent-config` 임시 정책 추적: 0.6.0 prerelease / Oracle 검증 동안 server-mode가 `pi-shell-acp` main을 추적(`agent-config` 5f17d70). Phase 3 release 후에는 다시 ref pinning으로 복귀할지 결정.
- [ ] `plugins/openclaw/README.md` Install layers 항목 보강: settings.json의 host absolute path 호환성 — Docker 환경에서 compose에 `/home/junghan/.pi/agent` 또는 동등 path 두 번째 mount 필요할 수 있다는 함정 한 줄. β 운영 시 첫 smoke에서 발견.
