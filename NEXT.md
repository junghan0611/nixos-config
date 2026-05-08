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
