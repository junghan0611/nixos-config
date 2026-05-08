# NEXT.md — 다음 할 일

운영 baseline은 [AGENTS.md](AGENTS.md). 후속 작업 / 미완 검증은 여기에.

작업 끝나면 항목 지우고, 새로 발견한 후속은 추가. 결정/근거/날짜는 항목 본문에 남기되, 지워질 항목이라는 점을 잊지 말 것 — 영속할 사실은 AGENTS.md / docs/openclaw-gotchas.md / `~/openclaw/README.md` change history로 옮긴다.

---

## 1. 현재 임베딩 로직 검증 (5.7 baseline 직후)

5.2 → 5.7 (2026-05-08) 직후 sessions chunks **+187%** (1306 → 3747). memory chunks 1234 동일. 메커니즘은 5.7 transcript-hygiene 디스크 보존 강화로 sanitization이 outbound payload에만 적용. AGENTS.md §3 Memory layers 참조. 같은 비용에 검색 풀 1.9배라는 운영 효과는 정량 확인됐지만 **검색 품질**과 **andenken 비교**는 아직.

검증 항목:

- [ ] **5.7로 새로 회상되는 turn 사례 수집**
  - 5.2 baseline에서는 sanitization으로 빠졌을 만한 turns (특히 main/gpt의 tool-call 응답)을 5.7에서 query로 직접 hit하는지
  - 후보 query: `docker compose`, `memory status`, `flake.lock`, `force-recreate` 등 도구 호출 위주
  - 결과: 어떤 sessions chunks가 hit되는지 path + score 기록
- [ ] **5.7 false-positive 추적**
  - 새로 추가된 chunks가 의미상 노이즈로 작동하지 않는지 (top hit이 무관한 sessions chunk로 밀리는 경우)
  - 가족 봇 (glg) 회상 품질 dip 여부 — 가족 직접 대화는 1.13× 증가만 있었으므로 이론상 영향 적지만 score 분포는 변함
- [ ] **andenken bake-off 재실시** (AGENTS.md §3 Memory layers 마지막 단락)
  - 같은 query를 OpenClaw 5.7 (sqlite-vec 2560d) ↔ andenken (LanceDB 2560d) 양쪽에 던짐
  - 평가축: first-result precision, freshness (최근 sessions 회상력), CJK short query, operator trust
  - storage/corpus 분리 그대로: OpenClaw은 sessions+memory, andenken은 org KB+pi sessions. 서로 다른 corpus라 단순 score 비교가 아니라 *목적별 도달 시간* 측정
  - 결과 기록: `~/org/llmlog/` 새 노트 (denote 형식)
- [ ] **5.2 vs 5.7 동일 chunking 가설 확인**
  - memory chunks 1234 정확히 일치는 우연일 수 없지만, 별도 확인 가치 있음. `memory/` 입력 파일 1개 골라서 chunks 분포 spot-check (file당 chunks)
- [ ] **`--force` 직후 dirty=true 현상 원인**
  - 5.7에서 force reindex 후 모든 agent에 `dirty: true`. incremental 한 번 돌리면 false. metadata sync 시차로 추정했지만 정확한 원인 모름. 다음 주기 force 시 동일 재현되는지 확인 → 재현되면 upstream issue로 보고

## 2. active-memory 재활성화 검토

5.2 안정성 검증 동안 비활성. 5.7 운영 안정 확인됨 (ready 5.7s, 가족 봇 응답 정상). 재활성 가능 시점.

근거 위치:
- 비활성 이력: `docs/openclaw-gotchas.md` "비활성 — active-memory" (line 79~)
- 5.7 변경: "Active Memory: require admin scope for global memory toggles" (보안 강화)
- 기존 baseline config (보존됨): Groq paid tier `gpt-oss-120b` primary + `google/gemini-3-flash` fallback, `timeoutMs: 15000`, `agents: ["glg", "gpt"]`

검증 항목:

- [ ] **재활성 전 docs 재숙독** — `docs/openclaw-gotchas.md` 비활성 섹션 함정 정리 (Groq free tier TPM=8K로 `gpt-oss-120b` 불가, Gemini 3 Flash Lite는 prefill-bound 워크로드에서 Flash보다 느림 등)
- [ ] **5.7 active-memory 동작 변화 확인**
  - admin scope 요구 (5.7) → 우리 config가 admin scope 충족하는지
  - 5.5/5.6/5.7 다른 active-memory 관련 변경 없는지 release note 재확인
- [ ] **기존 baseline 그대로 활성**
  - `plugins.entries.active-memory.enabled: true`
  - 모델/timeout/agents 그대로
  - force-recreate (env 변경 시) or restart (config만 변경 시)
- [ ] **활성 직후 24h 관찰**
  - 가족 봇 (glg) 응답 latency 5.2 baseline 대비 증가 여부
  - active-memory 호출당 비용 (Groq paid tier) 추적
  - timeout / fallback 발생률
  - 회상 품질 향상 신호 (예: 이전 대화 더 자연스럽게 이어가는지)
- [ ] **trade-off 평가 후 결정**
  - 응답 시간 비용 < 회상 품질 이득 → 유지
  - 응답 시간 비용 > 회상 품질 이득 → 다시 비활성, gotchas.md에 새 사유 기록
  - 결정 사유 `~/openclaw/README.md` change history에 stamp

## 3. (참고) gemini agent 정리

비긴급. AGENTS.md §3 Model routing에 "Copilot 잔재(`gemini` agent)는 **삭제 예정**" 표시. 5.7 운영 안정 확인 후 별도 사이클에서 처리.

- [ ] gpt-5.4로 통합할지 (workspace-gemini → workspace-gpt로 흡수) 또는 agent 자체 삭제할지 결정
- [ ] 텔레그램 봇 `@glg_gemini_bot` 회수 절차 (BotFather)
- [ ] workspace-gemini 인덱스 데이터 archival
