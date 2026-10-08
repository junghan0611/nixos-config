# OpenClaw 2026.9.9 검토 — 9.8 운영 기준

2026-10-08 KST, pi-durable. **채택 후보지만 단순 FROM bump는 불가.** 이번 작업은 릴리즈·소스 검토이며 이미지 pull/build, Gateway 변경, Doctor 수리, 모델 변경은 하지 않았다.

## 현재 결정 — 9.9 업데이트 보류

운영자 결정(2026-10-08): **“업데이트 하지말자. 기다리자.”** 패치된 9.8을 유지한다. 아래의 격리 검증·컷오버 단계는 검토 당시의 제안이며 실행 승인이나 현재 할 일이 아니다. 재검토 요청 전에는 이미지 작업·Doctor 수리·모델/utility 변경·업데이트를 시작하지 않는다.

## Opus 교차검수 반영 — 20:08 KST

[독립 검수](openclaw-2026.9.9-opus-review.md)(수신 artifact SHA-256 `8e4d6bf87beb4fa53c81610dd2173c7c9aa568ad78e11f9d31ddb04e22178820`) 완료. **패치된 9.8 유지 → 조건을 정리한 뒤 격리 후보 검증**, 아직 컷오버 승인은 아니다.

- 여기서 재확인: `docker-entrypoint.mjs:94–96`은 기동 때 자동 `doctor --fix --non-interactive`를 실행한다. 9.8과 같은 entrypoint여도 9.9의 수리 코드는 다르다. 번호 동일을 쓰기 없음으로 읽지 않고, 격리 state 사본에서 Doctor의 실제 쓰기·복구 가능성을 검증한다.
- 여기서 재측정: `/home` **94%·여유 5.9G**, `/`(Docker) **85%·15G**. Opus의 state 4.8G 측정(F2)은 상속 영수증이다. 현재 백업 위치·공간 계획 없이 cold backup과 새 이미지 작업을 시작하지 않는다. 무단 삭제·prune는 하지 않는다.
- 여기서 소스·선택 config 재확인: Anthropic `defaultUtilityModel`은 Haiku 4.5→5.5로 바뀌고 우리 utilityModel 명시는 없다. **대화 primary를 유지해도 utility 기본값은 바뀐다.** Opus의 기존 Haiku 4.5 호출 7건(F4)은 상속 영수증이며 인증/과금 레일은 아직 미측정이다. API 형식명만으로 종량제라고 단정하지 않는다. 수용/기존값 핀/비활성은 별도 결정이다.
- Opus 측정(F3): npm 9.9 미패치 baseline 10/10과 기존 patch_text 적용 후 10/10·멱등 검증을 확보했다. 이는 이관의 긍정 근거지만 Docker 9.9 dist는 미검증이다. 후보의 Claude Code 비핀 설치도 별도 버전 변화(F5)를 만들므로 OpenClaw 변경과 구분한다.
- 여기서 소스·config 재확인: 우리 `gateway.tailscale.mode=off`이므로 `/controlui`의 기대값은 버튼이 아니라 URL 설정 오류다. 호스트 Tailscale 운영과 OpenClaw 내장 모드는 다르며 이번에 이를 켜지 않는다.

## 검토 좌표·증거 상태

- 여기서 측정: 라이브 CLI `OpenClaw 2026.9.8 (fc23bc8)`; 기준 태그 `fc23bc864e4553c2d215e479eeec47b67a0bf943`, 검토 태그 `bcfc88812a35243893585dbeca87ca41b48272ca`. 3rd 클론 HEAD는 9.8에 유지하고 9.9 태그만 fetch했다.
- 여기서 측정: 정확한 `v2026.9.8..v2026.9.9`는 **185커밋·1,111파일**. 노트의 14 PR은 편집·감사 대상 범위이며, 실제 최종 태그에는 추가 백포트·검증 수선이 포함돼 있다. 파일 수를 사용자 기능 수로 읽지 않는다.
- 외부 영수증: [릴리즈](https://github.com/openclaw/openclaw/releases/tag/v2026.9.9)는 2026-10-08 19:23 KST 게시. 첨부 postpublish evidence는 npm 서명·provenance 일치를 보고하고, manifest의 target SHA는 위 태그와 일치한다. 이를 우리 이미지 검증을 수행한 것으로 간주하지 않는다.
- 여기서 선택 필드만 측정: main/gpt `openai/gpt-6.1-sol`, glg/mini Sonnet 5, bbot Fable 5.1, gemini `zai/glm-5.3`; codex plugin disabled, Workshop autonomous mode `propose`. 자격증명·개인/방 ID는 수집·공개하지 않았다.
- 재검토용 원본·diff는 host-local `/tmp/openclaw-9-9-review/`; 아래 태그 링크가 영속 근거다.

## 우리에게 유효한 수정

| 수정 | 운영상 의미·한계 |
|---|---|
| [#164049](https://github.com/openclaw/openclaw/pull/164049), rooted cron·Workshop review의 prepared runtime 재사용 | 해당 경로가 Gateway 메인 스레드를 장시간 점유하던 문제를 줄인다. execution root의 파일 접근 제한은 유지한다. 모든 일반 cron이 빨라진다는 주장은 아니다. |
| [#163704](https://github.com/openclaw/openclaw/pull/163704), stale cron timeout의 run-id fence | 끝난 cron의 뒤늦은 cleanup이 같은 세션의 다음 사용자 턴을 취소하는 것을 막는다. 우리 memento는 isolated이므로 원 신고의 shared-session 조건과 구분한다. |
| [#164230](https://github.com/openclaw/openclaw/pull/164230), queued cancellation admission 해제 | 대기 중인 다음 턴을 취소했을 때 현재 턴의 완료가 막히는 문제를 수선한다. |
| Claude CLI subagent notification 분류 | [최종 태그의 cli.runtime.ts](https://github.com/openclaw/openclaw/blob/v2026.9.9/extensions/anthropic/cli.runtime.ts)에서 subagent 완료가 부모의 결과 큐 슬롯을 소비하지 않게 바뀌었다. Sonnet/Fable 서빙 회귀 검수 대상이다. |
| WAL ownership·Doctor/update 수선 | live DB의 불안정한 전체 복제 대신 소유권을 검사하고 장시간 수리의 응답성을 개선한다. 수동 Docker 컷오버의 정지·cold backup은 여전히 필요하다. |
| managed Codex app-server 0.160.0 / GPT-6.1 Sol | 네이티브 Codex 카탈로그·실행 지원이다. 현재 우리의 codex-disabled·내장 openclaw 서빙 경로를 자동으로 고치거나 전환하는 것은 아니다. |

## 채택 전에 반드시 처리할 것

### 1. cron 기억 admission 패치는 아직 필요하다

여기서 태그 간 diff로 측정: [session-transcript-corpus.ts](https://github.com/openclaw/openclaw/blob/v2026.9.9/packages/memory-host-sdk/src/host/session-transcript-corpus.ts#L177-L219)와 [session-key-utils.ts](https://github.com/openclaw/openclaw/blob/v2026.9.9/src/sessions/session-key-utils.ts)는 9.8과 byte-identical이다. classifier는 여전히 부모까지 식별하는 `isCronSessionKey`가 아니라 `isCronRunSessionKey`를 두 곳에서 사용한다. 오늘 수선한 원인은 상류에서 닫히지 않았다.

로컬 [패치](../docker/openclaw/patch-memory-cron-parent.py)는 package version이 9.8이 아니면 거부한다. 따라서 `FROM ...:2026.9.9`만 바꾸면 빌드가 실패한다. 이 가드를 없애서 통과시키지 않는다. 9.9 **실제 배포물**의 import/export·classifier 형태를 확인한 뒤 버전 한정 패치를 재검토하고 [10개 회귀 단언](../docker/openclaw/test-memory-cron-parent.mjs)을 다시 통과시켜야 한다. 소스의 동일성은 의미상의 이관 근거이지, emitted bundle 호환성 검증을 대신하지 않는다.

### 2. Telegram 통합 검사가 릴리즈에서 면제됐다

릴리즈 노트와 첨부 evidence의 `telegramWaiver:2026.9.9-owner-approved`에 명시: source QA·Package Acceptance·published-package E2E의 Telegram 검사는 실행하지 않았다. PR #161369 자체의 Test Server 증거는 존재하지만 **최종 태그 전체의 통합 검사와 별개**다.

여기서 태그 간 diff로 측정: DM 토픽 판정의 `extensions/telegram/src/bot/helpers.ts`와 연결 시작의 `channel.ts`는 9.8과 동일하다. 이는 새 토픽 기능 변경이 없다는 좁은 근거이며, 공통 세션·Gateway 변경까지 무회귀라고 증명하지 않는다. 기존 DM, 새 DM 토픽, 그룹 토픽의 호출/응답 위치를 우리 환경에서 검수해야 한다. 6계정 probe만으로 이 검수를 대체하지 않는다.

### 3. Control UI 진입 명령은 `/controlui`

[#161369](https://github.com/openclaw/openclaw/pull/161369), [최종 command.ts](https://github.com/openclaw/openclaw/blob/v2026.9.9/extensions/telegram/src/miniapp/command.ts): Mini App은 `/controlui`; `/dashboard`는 공통 세션 대시보드 생성/갱신으로 분리됐고 Mini App 별칭으로 남지 않는다. 다만 **우리 설치본**은 `gateway.tailscale.mode=off`이므로 [url.ts:24–26](https://github.com/openclaw/openclaw/blob/v2026.9.9/extensions/telegram/src/miniapp/url.ts#L24-L26)의 URL 설정 오류가 예상된다(실기 미검증). 일반 제품의 '새 버튼 요청·기존 URL 유지'를 현재 환경의 동작 보장으로 읽지 않는다. 내장 serve/funnel 활성은 별도 승인 사항이다.

[owner.ts](https://github.com/openclaw/openclaw/blob/v2026.9.9/extensions/telegram/src/miniapp/owner.ts): 해당 계정의 effective `allowFrom` 또는 `commands.ownerAllowFrom`에 명시적 숫자 사용자 매칭이 필요하며 wildcard/username만으로는 owner 권한을 주지 않는다. **그룹의 대화 허용을 Gateway 운영 권한으로 확대하지 않는다.**

### 4. `/model` 제한은 해결됐다고 보지 않는다

여기서 태그 간 diff로 측정: `src/gateway/sessions-patch.ts`, OpenAI route contract와 plugin manifest는 9.8과 동일하다. [sessions-patch.ts:619–642](https://github.com/openclaw/openclaw/blob/v2026.9.9/src/gateway/sessions-patch.ts#L619-L642)의 harness 가용성 검증도 남아 있다. `openai-provider.ts`의 변경은 managed client version 0.158.0→0.160.0이다. 현재 codex plugin이 꺼져 있으므로 기존 6.1-sol 세션 선택 거부의 해결을 보장할 근거가 없다. 기존 primary·사용자 핀을 유지하고, codex를 켜서 우회하지 않는다.

## DB·플랫폼 경계

- 여기서 태그 간 소스 측정: [state contract](https://github.com/openclaw/openclaw/blob/v2026.9.9/src/state/openclaw-state-db-contract.ts#L22) **19**, [agent contract](https://github.com/openclaw/openclaw/blob/v2026.9.9/src/state/openclaw-agent-db-contract.ts#L29) **24**, 9.8과 동일. 마지막 릴리즈 커밋도 state 19 유지 수선이다. **번호 동일 ≠ Doctor/동일 버전 수리 0건**이다. legacy transcript·memory cache repair 구현은 바뀌었으므로 실제 이미지·격리 config 검증 전에는 무마이그레이션 컷오버로 확정하지 않는다.
- 태그의 Node engines·pnpm 핀은 9.8과 동일. 이것만으로 base image의 Node/npm 버전이나 Claude binary 설치 성공을 보장하지 않는다. 기존 `allow-scripts`·명시 install·`claude --version` 게이트를 유지한다.
- 외부 노트: Android APK는 버전 핀 8.2와 release train이 달라 생략됐다. 이 Gateway 릴리즈에 맞춰 앱 갱신·재페어링을 강요하지 않는다.

## 다음 한 걸음 — 아직 실행하지 않음

1. 먼저 공간·백업 위치, utility 모델 정책, Claude Code 버전 핀을 결정한다. 이후 승인된 격리 9.9 이미지에서 hotfix 이관·baseline/10개 단언, schema/config/retired-key·Claude 설치를 검증하고, cold state **사본**에서 activation Doctor의 결과·쓰기·백업 크기를 측정한다. 운영 state를 후보 이미지에 RW로 붙이지 않는다. **live 토큰을 든 후보 Gateway를 병렬로 띄우지 않는다**(polling·배달·cron 충돌).
2. 통과 후 **별도 컷오버 승인**: 실제 idle/drain 확인 → 정지·cold backup → 현재 패치된 9.8 이미지와 백업을 복구 짝으로 확보 → 승격. 모델·자동화·privacy 정책은 별도 변경하지 않는다.
3. 기동 뒤 6봇 구독 경로 실응답, 기존 DM·새 DM 토픽·그룹 토픽·`/controlui`, memory clean·청크 보존·다음 memento를 확인한다. Active Memory 활성·강제 재색인·DB 직접 수정·이전 세션 삭제는 하지 않는다.
