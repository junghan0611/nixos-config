# OpenClaw Version Tracking

## Current State

| Item | Value |
|------|-------|
| **Running version** | `2026.2.17` |
| **Dockerfile FROM** | `ghcr.io/openclaw/openclaw:2026.2.17` |
| **Latest stable** | `2026.2.26` (2026-02-27) |
| **Last attempted** | `2026.2.19` → **롤백** |
| **Gap** | 9 releases behind (2026.2.19 ~ 2026.2.26) |

## 현재 텔레그램 운영 현황

### 에이전트 구성
- **glg 에이전트** → `@glg_junghanacs_bot` (힣봇) — claude-opus-4-6
- **main 에이전트** → `@junghan_openclaw_bot` — 현재 비활성
- 세션 격리: `session.dmScope: per-account-channel-peer`

### 활성 사용자
- 정한님 (123861330) — 운영자, thinking=medium, verbose=on
- 김현진님 (81880552) — 아버지, 가족 일정 안내 용도

### 스킬 (13개, 정상 동작 확인)
bibcli, botlog, brave-search, day-query, denotecli, ghcli, gitcli,
gogcli, lifetract, medium-extractor, punchout, transcribe, youtube-transcript

### 활성 설정
- TTS: Edge ko-KR-HyunsuMultilingualNeural +50%, auto=always
- 스트리밍: partial
- 검색: Perplexity Sonar (OpenRouter)
- 오디오: Groq Whisper (ko)
- Heartbeat: 1h 간격, HEARTBEAT.md 비어있음
- Cron: 미사용

## Rollback History

### 2026.2.19 시도 → 2026.2.17 롤백 (2026-02-21)

**원인**: `isSecureWebSocketUrl()` 보안 강화
- 2026.2.19 변경: "block plaintext `ws://` connections to non-loopback hosts" (#20803)
- Docker에서 gateway가 `--bind lan` (0.0.0.0)으로 동작 → 컨테이너 내부 서브에이전트가 `ws://` 로 게이트웨이에 연결 시도 → non-loopback으로 판정 → 차단
- **증상**: 서브에이전트 스폰/announce 실패

### 이후 관련 수정사항 (릴리스 노트 분석)

| Version | 관련 변경 | 영향도 |
|---------|----------|--------|
| **2026.2.21** | `ws://` non-loopback 거부 유지, loopback 예외 정리 | 직접 해결 아님 |
| **2026.2.22** | `gateway.auth` refactor, Docker `identity` 문제 수정 | Docker 환경 개선 |
| **2026.2.23** | `browser.ssrfPolicy` **BREAKING** 변경 | 확인 필요 |
| **2026.2.24** | Docker `container:<id>` 차단 **BREAKING**, 서브에이전트/announce 개선 | 확인 필요 |
| **2026.2.25** | 서브에이전트 announce 대폭 리팩토링, WebSocket auth 강화 | 서브에이전트 안정성 ↑ |
| **2026.2.26** | `bind=lan` + loopback probe 수정 (#26997) | **핵심 수정 가능성** |

### ws:// + Docker 문제의 해결 가능성

2026.2.26에서 `bind=lan`일 때 co-located probe를 `127.0.0.1`로 강제하는 수정 (#26997). 서브에이전트 spawn ws:// 연결에도 적용되는지가 핵심 테스트 포인트.

## 텔레그램 관련 변경사항 (2026.2.17 → 2026.2.26)

### 기능 개선

| Version | 변경 | 현재 설정과 관련도 |
|---------|------|-----------------|
| **2026.2.21** | streaming 설정 단순화: `channels.telegram.streaming` (boolean) | ⭐⭐ 현재 `streamMode: partial` → 마이그레이션 필요 |
| **2026.2.21** | lifecycle status reactions (queued/thinking/tool/done/error) | ⭐⭐ 에이전트 상태 이모지 리액션 |
| **2026.2.22** | 한국어 FTS stop-word 필터링 (#18899) | ⭐⭐⭐ memory_search 한국어 품질 향상 |
| **2026.2.23** | Telegram reactions soft-fail + snake_case 호환 | ⭐ 안정성 |
| **2026.2.23** | Telegram polling offset 봇별 격리 | ⭐⭐ 멀티 봇(glg+default) 안정성 |
| **2026.2.23** | `/reasoning off` 시 reasoning 텍스트 누출 방지 | ⭐ 보안 |
| **2026.2.23** | per-agent `params` (cacheRetention 등) | ⭐⭐ 에이전트별 캐시 튜닝 |
| **2026.2.24** | typing keepalive — 긴 응답 중 "입력 중..." 유지 | ⭐⭐ UX 개선 |
| **2026.2.24** | Telegram IPv4 우선 미디어 다운로드 | ⭐ Oracle Cloud IPv6 문제 해결 |
| **2026.2.24** | 다국어 stop phrases (한국어 포함) | ⭐ |
| **2026.2.25** | 서브에이전트 announce 안정화 | ⭐⭐⭐ |
| **2026.2.25** | Telegram 미디어+텍스트 혼합 시 preview 보존 | ⭐⭐ TTS+텍스트 동시 전송 안정성 |
| **2026.2.25** | Telegram markdown spoiler 처리 개선 | ⭐ |
| **2026.2.26** | Telegram sendChatAction 401 backoff (봇 삭제 방지) | ⭐⭐⭐ 중요 안정성 |
| **2026.2.26** | Telegram inline button 그룹 지원 | ⭐ |
| **2026.2.26** | Telegram streaming preview 개선 (stale fragment 방지) | ⭐⭐ |
| **2026.2.26** | DM allowlist 계정 상속 강화 | ⭐ 보안 |
| **2026.2.26** | typing TTL safety net (stuck indicator 방지) | ⭐⭐ |

### 보안 강화 (텔레그램)

- **2026.2.24**: DM 인가 후 미디어 다운로드 (비인가 미디어 쓰기 차단)
- **2026.2.25**: Telegram reactions 인가 검사 강화
- **2026.2.25**: group allowlist fail-closed (DM pairing fallback 제거)
- **2026.2.26**: account-scoped pairing isolation

## Upgrade Plan

### Phase 1: 정보 수집 ✅
- [x] 현재 버전 확인 (2026.2.17)
- [x] 릴리스 노트 전수 분석 (2026.2.19 ~ 2026.2.26)
- [x] ws:// 차단 원인 파악
- [x] 텔레그램 관련 변경 분류
- [x] 현재 스킬/세션/설정 상태 확인

### Phase 2: 업그레이드 실행
- [ ] 2026.2.26 이미지 pull
- [ ] Dockerfile 변경 + 빌드
- [ ] 컨테이너 교체 + 서브에이전트 spawn 테스트
- [ ] Telegram DM 대화 테스트 (정한님 세션)
- [ ] streaming 설정 마이그레이션 확인 (`streamMode` → `streaming`)

### Phase 3: 안정화
- [ ] Dockerfile/docker-compose.yml 양쪽 동기화
- [ ] nixos-config 커밋
- [ ] MEMORY.md 버전 정보 수정
- [ ] 이 문서 업데이트

## BREAKING Changes Checklist (2026.2.17 → 2026.2.26)

- [ ] **2026.2.21**: `streamMode` → `streaming` (boolean) 자동 마이그레이션 있음
- [ ] **2026.2.23**: `browser.ssrfPolicy.dangerouslyAllowPrivateNetwork` 기본값 변경 → `openclaw doctor --fix`
- [ ] **2026.2.24**: Docker `network: "container:<id>"` 차단 → 미사용, 무관
- [ ] **2026.2.24→25**: Heartbeat DM 정책 변경 → 2026.2.25에서 `allow` 복원, 무관
- [ ] **2026.2.25**: Telegram group allowlist fail-closed → 현재 `groupPolicy: allowlist` 사용 중, 검증 필요
- [ ] **2026.2.26**: `onboard --reset` scope 변경 → 리셋 안 하면 무관

## Notable Features Worth Adopting

| Version | Feature | 관심도 | 현재 활용 |
|---------|---------|--------|----------|
| 2026.2.22 | 한국어 FTS stop-word (#18899) | ⭐⭐⭐ | memory_search |
| 2026.2.23 | per-agent `params` | ⭐⭐ | cacheRetention 튜닝 |
| 2026.2.23 | `sessions cleanup` disk-budget | ⭐⭐ | 세션 디스크 관리 |
| 2026.2.24 | typing keepalive | ⭐⭐ | UX |
| 2026.2.25 | 서브에이전트 announce 안정화 | ⭐⭐⭐ | 핵심 |
| 2026.2.26 | External Secrets Management | ⭐⭐ | .env 관리 |
| 2026.2.26 | sendChatAction 401 backoff | ⭐⭐⭐ | 봇 안전성 |
