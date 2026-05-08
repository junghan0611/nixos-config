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

## 2. active-memory 24h 관찰 (gpt only)

(2026-05-08 17:58 UTC 활성) 단계적 활성. `agents: ["gpt"]` only, model `openai-codex/gpt-5.4-mini`, queryMode `message`, promptStyle `strict`, timeoutMs 5000 + setupGraceTimeoutMs 30000, maxSummaryChars 220. 보존 baseline (Groq pin) 폐기 — codex OAuth single-quota 일원화로 단순화.

첫 호출 측정:
- cold first-call: elapsed 7993ms / status=empty
- warm second-call: elapsed 7339ms / status=ok / summaryChars=164 (한국어→영어 요약 작동)
- 해석: codex OAuth path는 모델 크기와 무관하게 5–10s latency 본질. 매번 7s대 → cold/warm 구분 미미.

관찰 항목:

- [ ] **24h gpt 봇 응답 패턴 추적**
  - status 분포 (`ok` vs `empty` vs `timeout`) — `logging: true` 로그에서 집계
  - elapsed 분포 — warm 호출이 정말 7s대인지, 더 짧아지는지, 아니면 가끔 spike
  - 회상이 들어간 turn (status=ok)에서 main 답변 품질 향상 정성 평가
- [ ] **timeout 빈도가 높으면 처치**
  - 5000ms 자주 초과 → setupGraceTimeoutMs는 cold만 적용인지 매 호출 적용인지 docs 재확인
  - 빈도 높으면 timeoutMs 7000 또는 8000으로 완화
- [ ] **회상 품질 정성 평가**
  - "이전 얘기 이어서" 같은 turn에서 자연스러운 컨텍스트 주입되는지
  - false-positive (관련 없는 회상) 발생 여부 — promptStyle:strict 효과 확인
- [ ] **단계 확장 결정 (24h 후)**
  - 안정성 OK → `agents: ["gpt", "glg"]`로 가족 봇 추가. 단 가족 응답성 trade-off 신중. mini agent는 자체가 빠른 모델이라 active-memory 추가 의미 적음 (skip 권장).
  - 안정성 NG → 비활성 후 docs/openclaw-gotchas.md에 새 사유 stamp. 또는 model을 다른 빠른 endpoint (예: `google/gemini-3-flash`)로 변경 후 재시도
- [ ] **24h 결과 stamp**
  - `~/openclaw/README.md` change history에 결과 entry 추가
  - AGENTS.md §3 active memory 섹션 운영 데이터 갱신

## 3. (참고) gemini agent 정리

비긴급. AGENTS.md §3 Model routing에 "Copilot 잔재(`gemini` agent)는 **삭제 예정**" 표시. 5.7 운영 안정 확인 후 별도 사이클에서 처리.

- [ ] gpt-5.4로 통합할지 (workspace-gemini → workspace-gpt로 흡수) 또는 agent 자체 삭제할지 결정
- [ ] 텔레그램 봇 `@glg_gemini_bot` 회수 절차 (BotFather)
- [ ] workspace-gemini 인덱스 데이터 archival
