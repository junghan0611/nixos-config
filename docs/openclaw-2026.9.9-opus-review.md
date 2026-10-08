# OpenClaw 2026.9.9 — Opus 독립 검수

Author: claude-opus-5-5 (Claude Code, entwurf sibling `20261008T195403-5c3d19`, 2026-10-08) — not GLG direct; review as a separate viewpoint.
대상: coordinator 검토 [openclaw-2026.9.9-review.md](openclaw-2026.9.9-review.md)를 권위가 아니라 검증할 주장 집합으로 읽고, 최종 태그 `v2026.9.9`(`bcfc8881`)를 `v2026.9.8`(`fc23bc86`)과 직접 대조했다.

## 결론 — isolated candidate validation으로 진행, cutover-ready 아님

**운영은 패치된 9.8 유지.** 9.9는 채택 후보가 맞지만, 아래 두 blocker는 검증 계획 자체를 바꾼다.

1. **컨테이너 기동이 매번 `doctor --fix --non-interactive`를 실행한다.** 따라서 "schema 19/24 동일 = 무마이그레이션, doctor는 read-only만"은 과대해석이다. FROM bump 후 recreate하는 순간, 9.9에서 다시 쓴 Doctor 수리 경로가 운영 state에 그대로 실행된다.
2. **`/home`이 94%다(여유 5.9G).** state dir 4.8G의 cold backup을 같은 FS에 두면 여유가 약 1.1G만 남는다.

memory hotfix는 9.9에서도 여전히 필요하다. 배포된 npm 9.9 번들에 **수정 없는 patch를 적용해 10/10을 통과**했으므로 이관할 수 있다. 다만 Docker 이미지 dist에서는 아직 측정하지 않았다.

## Findings (심각도순)

| ID | 심각도 | 요지 | 처분 |
|---|---|---|---|
| F1 | **Blocker** (계획 정정) | 이미지 activation이 매 기동마다 `doctor --fix`를 실행 → 9.9의 바뀐 Doctor 수리가 첫 부팅에 자동으로 돈다 | 후보 검증은 cold state **사본**에서 activation Doctor를 실행해 측정한다. image-only rollback은 금지 |
| F2 | **Blocker** (호스트) | `/home` 94%, 여유 5.9G vs state 4.8G | cold backup은 다른 FS에 두거나 먼저 공간을 확보한다 |
| F3 | High | cron-parent hotfix는 여전히 필요하고 이관 가능(npm 9.9 실측). Docker dist는 미측정 | 버전 가드를 **정확히 9.9 하나로** 바꾸고 후보 빌드에서 10 단언 + `--baseline` 증명 |
| F4 | High (정책 drift) | anthropic `defaultUtilityModel` haiku-4-5 → **haiku-5-5**. 우리 config에 utilityModel이 없어 glg/mini/bbot의 utility 호출이 자동으로 새 모델을 탄다 | 컷오버 **전에** 별도로 결정한다(수용 또는 명시 핀). 이번에는 변경하지 않음 |
| F5 | High (동반 drift) | 재빌드하면 Claude Code(2.1.288→현재 2.1.293)와 npm@latest도 함께 바뀐다 | 후보에서 claude-code 핀 여부 결정, 버전 기록 |
| F6 | Medium | Telegram 확장은 miniapp 4파일 외 동일. 대신 공유 배달 경로가 바뀌었고 통합 검사는 면제됐다 | 아래 최소 smoke matrix 실행 |
| F7 | Medium (주장 정정) | `/controlui`는 우리 config(`gateway.tailscale.mode=off`)에서 버튼이 아니라 URL 오류를 낸다. 9.8도 같음 | 기대값을 "URL 오류 문구"로 둔다. allowFrom 확대·tailscale mode 변경은 별도 결정 |
| F8 | Medium | DB: schema SQL·additive column은 net 동일. 동일 버전 수리는 shape-gated(memory) 또는 Doctor 전용(transcript archive)인데 F1 때문에 실제로 실행된다 | 사본 실측. October beta(state 20)는 live state에 절대 붙이지 않는다 |
| F9 | Observation | cron: v20 delivery fence는 최종 커밋에서 빠졌고 scheduled 배달 currency 단언은 남았다. thinking hydration은 5초 race | 다음 memento·아침 알림 영수증 확인 |
| F10 | Observation | `/model`·sessions.patch·model policy 코드가 9.8과 동일 → 9.9가 6.1-sol 선택 거부를 바꿀 근거 없음 | codex 활성 금지 유지. 기동 후 codex disabled 재확인 |
| F11 | Observation | 9.9 arm64 이미지 게시 확인(revision=최종 태그). postpublish evidence에 Docker readback 항목 없음 | FROM을 digest로 고정 |
| F12 | Observation (문서 drift) | ORACLE "LLM 호출 분기"의 main=opus·claude-cli는 live(main=6.1-sol)와 다름. NEXT의 `/home 75%`도 현재 94% | 담당 문서 갱신 후보(이번 범위 밖) |

---

### F1 — activation Doctor: "무마이그레이션"의 실제 의미

- **소스** `v2026.9.9:docker-entrypoint.mjs:1` *"Image activation owns unattended retained-volume repair"*, `:94-95` foreground `gateway`이면 `openclaw.mjs doctor --fix --non-interactive`를 먼저 spawn한다. 실패하면 `:112` `process.exit(...)`로 gateway를 띄우지 않는다. 이 파일은 9.8과 byte-identical이다(측정: `git diff --stat` 빈 출력).
- **여기서 측정**: live `openclaw-gateway` Entrypoint는 `["tini","-s","--","node","/app/docker-entrypoint.mjs"]`, Cmd는 `node openclaw.mjs gateway --bind lan --port 18789`. live compose는 command만 덮고 entrypoint는 덮지 않는다(`~/openclaw/docker-compose.yml:86`). `openclaw-custom:9.7-rollback`도 같은 entrypoint다. 9.9 arm64 이미지 config blob(registry metadata, layer pull 없음)도 같은 Entrypoint를 가진다.
- 동일 버전에서도 바뀐 Doctor 수리 경로: canonical transcript archive 수리·publication(`src/infra/state-migrations.transcript-archive-publication.ts` 신규 361줄, recovery key `historical-canonical-transcript-archive-recovery-v1` `:23` — 9.8 태그에서 grep 0건), `transcript-directives-archives.ts`(+550/-), Doctor 준비 단계의 `prepareCanonicalTranscriptArchiveMigrations`(`src/flows/doctor-health.ts:183`), media persistence 검증 스캔, `doctor-migration-backup.ts` 재작성(+201). 문서 `docs/cli/doctor/state-migrations.md`(+12): 배치 실패 시 해당 archive를 보고하고 멈추며 재실행하면 cursor부터 이어간다.
- 운영 의미: 첫 9.9 부팅은 (a) 수리가 끝날 때까지 ready가 늦어지고(9.7 실측 ~103초, gotchas §9.7 — 상속 영수증), (b) 수리가 실패하면 restart loop에 빠질 수 있으며, (c) 9.8로 롤백해도 **9.8의 doctor --fix가 9.9가 손댄 state 위에서 다시 실행된다.** 그래서 롤백은 "pre-9.9 cold state + 9.8 패치 이미지" 짝으로만 한다.
- `doctor --fix 금지 / read-only만`이라는 우리 runbook 표현은 컨테이너 기동에는 적용되지 않는다. 수동 Doctor 실행만 통제할 수 있다.

### F2 — 디스크 (여기서 측정, 20:0x KST)

`df -h`: `/home`(state·backups) **94%, 여유 5.9G**; `/`(`/var/lib/docker`) 85%, 여유 15G. `du -sh`: `~/openclaw/config` **4.8G**, `~/openclaw/backups` 2.6G, `openclaw-custom:latest` 4.4GB. Doctor의 SQLite snapshot 백업(예: `*.doctor-gateway-token.*.bak`, pre-migration backup)은 state 옆에 쓰이므로 용량을 소스에서 상한 지을 수 없다. NEXT의 "/home 75%"는 더 이상 유효하지 않다.

### F3 — memory cron-parent hotfix: 여전히 필요, 이관 가능

| 검사 | 결과 | 증거 상태 |
|---|---|---|
| 상류 수정 여부 | `session-transcript-corpus.ts`·`session-key-utils.ts`가 태그 간 identical. classifier `:177` 이하가 `isCronRunSessionKey` 2회 | 소스, 여기서 측정 |
| 배포 번들 classifier | npm 9.8 `session-files-ZD7NizlY.mjs`와 npm 9.9 `session-files-DVVT4Ngb.mjs`의 `readParentSessionKeys`…`toSessionStoreCorpusEntry` 구간 **byte-identical(1330 bytes)** | 여기서 측정 (tarball sha512가 npm `dist.integrity`와 일치) |
| key chunk·export alias | `session-key-BC4m_Ly5.mjs`가 **docker 9.8 live = npm 9.8 = npm 9.9 byte-identical**, `isCronRunSessionKey as b`, `isCronSessionKey as x` | 여기서 측정 |
| 버그 재현 | 미패치 npm 9.9 dist: `test-memory-cron-parent.mjs --baseline` → `baseline reproduces parent omission: 10 assertions passed` | 여기서 측정 |
| 이관 | repo `patch_text`를 **수정 없이** import해 scratch 사본에 적용(버전 가드만 scratch 하네스에서 우회). import·classifier drift guard 통과, 멱등 → `patched parent admission: 10 assertions passed` | 여기서 측정 |
| Docker 9.9 dist | **미측정.** 9.8에서도 docker(`session-files-BNKNwDcU.mjs`)와 npm(`…ZD7NizlY.mjs`)의 corpus chunk 이름이 달랐다. patch는 glob 기반이라 이름 차이는 견디지만 docker 번들 내용의 동일성은 증명하지 않았다 | — |

Scratch 영수증(host-local): `/tmp/opus99-npm.aqstwD/`(9개 파일 import closure + corpus chunk), 하네스 `/tmp/opus99-scripts/run_parity.py`. repo의 patch/test는 고치지 않았다.

**안전 이관에 필요한 정확한 검증** (제안 — 사실이 아니라 결정할 항목):
1. `patch-memory-cron-parent.py:44`의 가드를 `"2026.9.8"` → **`"2026.9.9"` 정확 일치 하나**로 바꾼다. 범위·제거는 하지 않는다. 다른 guard(import 정규식, `isCronRunSessionKey(` 정확히 2회, export `isCronSessionKey as x`, corpus chunk 정확히 1개)는 그대로 둔다. 상류가 고치면 count guard가 빌드를 거부하므로, 이 가드가 곧 회수 신호다.
2. 후보 빌드 로그에 `memory-cron-parent-admission-v1: applied/verified`와 `10 assertions passed`가 남아야 한다.
3. **추가 제안**: 미패치 base 이미지 dist에 `--baseline`을 1회 실행해 "아직 필요함"을 증명한다(Dockerfile은 현재 patched 모드만 실행한다).
4. 컷오버 후: 6봇 `memory status --json`에서 `dirty:false`·source별 indexed=eligible·identity valid를 확인하고, pre-cutover 백업과 chunk ID 집합을 대조한다.

**제외 부작용**: patch는 cron 부모와, `parentSessionKey`/`spawnedBy` 사슬이 cron 모양 키(pruned 포함)에 닿는 모든 후손을 `sessionKind:cron`으로 제외한다. 사람 DM 키 안의 `:cron:`은 매칭하지 않는다(`isCronSessionKey`는 `parsed.rest`의 접두사만 본다, `session-key-utils.ts:75`; test case 있음). 이 매칭은 대소문자를 구분하지 않고 run 정규식(`:41`)은 구분한다. 비대칭이지만 보수적 방향이다. archive·retained 인스턴스도 같은 분류 집합을 쓴다(`session-transcript-corpus.ts:424`, `:284`). `manager-session-sync-state.ts:27`의 archived-key 검사는 run-only로 남지만, 그보다 먼저 entry 분류가 제외한다. 잔여 위험: 앞으로 실내용을 가진 cron-후손 세션(예: `spawnedBy`=cron base key인 subagent)이 생기면 색인에서 빠지고, 이미 색인된 세션은 stale로 정리된다. 9.8 배포 때 bbot 3277·glg 1320 chunk ID가 전부 보존됐다는 기록은 gotchas의 상속 영수증이며 재측정하지 않았다. 현재 그런 후손이 몇 개인지는 DB를 읽어야 해서 측정하지 않았다.

### F4 — utility model: 결정 없이 일어나는 모델 변경

- **소스** `extensions/anthropic/openclaw.plugin.json:196` `defaultUtilityModel: claude-haiku-5-5`(9.8: `claude-haiku-4-5`), `:422` alias `haiku`→5.5. `src/agents/utility-model.ts:80,100`: 설정이 없으면 primary provider의 `defaultUtilityModel`로 자동 라우팅한다(titles·progress narration·session summaries·observer 등).
- **여기서 측정**: config에 `agents.defaults.utilityModel`·per-agent utilityModel이 **없다**. glg/mini/bbot primary는 `anthropic/*`. live 9.8 로그 168h에 `provider=anthropic api=anthropic-messages model=claude-haiku-4-5 status=200`이 **7건** 있다. 즉 utility 호출은 실제로 일어나고 config의 `modelPolicy.allow`(haiku 없음)를 거치지 않는다.
- 9.9에서는 같은 rail로 `claude-haiku-5-5`가 자동 호출된다. 그 anthropic auth profile이 구독인지 API 키인지는 자격증명이라 확인하지 않았다(**미측정**). main/gpt(openai)·gemini(zai)의 utility 기본값은 바뀌지 않았다(openai manifest 미변경 — 소스 측정).
- 처분: 수용할지, 현재 값으로 명시 핀할지, `""`로 끌지를 **GLG가 컷오버 전에 결정한다.** 이 검수는 아무것도 바꾸지 않았다.

### F5 — 재빌드의 동반 변화

`docker/openclaw/Dockerfile:272-275`는 `@anthropic-ai/claude-code`를 버전 없이 설치한다. live는 `2.1.288`이고 현재 npm latest는 `2.1.293`이다(여기서 측정). 상류 Dockerfile `:269`의 `npm install --global npm@latest` 때문에 이미지마다 npm이 바뀔 수 있다(live 12.2.0, 현재 latest 12.2.0). 9.9의 Claude CLI subagent 분류(`extensions/anthropic/cli.runtime.ts:263,308`)는 CC가 `owned_by_subagent`를 내보내야 동작한다. 그 필드가 어느 CC 버전부터 나오는지는 미측정이다. Dockerfile의 3단 gate(`--allow-scripts`·`install.cjs`·`claude --version`)는 유효하며 fail-closed다.

### F6 — Telegram: "두 파일 동일"보다 강한 근거와, 남는 공유 경로

- **여기서 측정**: `extensions/telegram` 비-test 변경은 `package.json`과 `src/miniapp/{command,owner,page,url}.ts`뿐이다. DM 토픽·forum·polling·배달 어댑터는 9.8과 동일하다.
- 그러나 Telegram 배달 사슬의 **공유 코어**가 바뀌었다:
  - `src/channels/turn/durable-delivery-runtime.ts:45`: filtered registry view에서도 현재 registry scope로 최종 배달한다(#163742, 모든 채널).
  - `src/config/sessions/metadata.ts:249`: internal(Control UI 등) 턴이 바운드된 외부 delivery origin을 덮어쓰지 않는다(#151786).
  - `dispatch-from-config.lifecycle.ts`: pre-dispatch abort release(#164230).
  - `inbound-meta.ts`: requester hint가 context block 안으로 이동해 prompt bytes가 바뀐다.
  - `agent-runner-cli-candidate.ts:119`의 CLI 스레딩 변경은 `sameChannelThreadRequired`를 설정하는 어댑터에만 영향을 준다. grep 결과 slack·mattermost뿐이므로 **Telegram에는 no-op**이다(소스 측정).
- 외부 영수증: release notes `Telegram integration checks: waived … not run`, postpublish `telegramWaiver=2026.9.9-owner-approved`.
- **최소 smoke matrix** (운영자 수동 발신. 새 bot 설정·메시지는 이 검수에서 보내지 않음):

| 면 | 대상 | 기대 |
|---|---|---|
| 기존 flat DM | 6계정 각 1턴 | 같은 DM 응답, 기존 세션 키 유지 |
| 새 DM 토픽 | 6계정 각 1토픽(전원 has_topics_enabled) | 같은 토픽 응답·토픽별 세션 |
| forum 그룹 토픽 | glg 그룹: 멘션 / 무멘션 / 봇 답글 | 멘션·답글만 같은 토픽 응답, 무멘션 무응답 |
| Control UI → Telegram 바운드 세션 | 웹에서 1턴 후 Telegram 1턴 | 이후 Telegram 응답 위치 불변(F6 metadata) |
| `/controlui` | owner DM / group 비owner | URL 오류 문구 / 제한 문구(F7) |
| `/dashboard` | owner DM | Mini App이 아니라 공통 세션 대시보드 동작. 관찰만 |
| cron | 다음 memento·08:00 가족 알림 | run ok, 배달 계정·대상 불변 |

### F7 — `/controlui` 기대값 정정과 권한 경계

- `extensions/telegram/src/miniapp/url.ts:25`: `gateway.tailscale.mode`가 `serve|funnel`이 아니면 URL 오류를 던진다. 9.8도 동일한 분기다. **여기서 측정**: config `gateway.tailscale.mode=off`이고 Tailscale은 호스트 레벨에서 운용된다(ORACLE). 따라서 coordinator 검토의 "새 실행 버튼 요청, 기존 Mini App URL 유지 가능"은 우리 설치본에서 성립하지 않는다. 버튼은 9.8에서도 나오지 않았을 것으로 판단한다(소스 추론, 실기 미검증).
- owner 판정(`owner.ts:17,29`)은 account `allowFrom` + `commands.ownerAllowFrom`만 본다. **여기서 측정(개수만)**: 6계정 allowFrom 각 1개(숫자), `ownerAllowFrom` 1개(wildcard 없음), `accessGroups` 없음 → `owner.ts`의 access-group 리팩터는 no-op이다. glg 그룹 `allowFrom`(2명)은 owner 판정에 들어가지 않으므로 **그룹 구성원이 operator로 확대되지 않는다.**
- 9.9의 `/dashboard`는 공통 세션 대시보드(`command.ts:13`에서 Mini App 이름이 `controlui`로 분리). 습관적 `/dashboard`는 이제 세션 대시보드를 만든다.

### F8 — DB: 번호 동일의 범위

- 최종 `package.json:7-8` state 19·agent 24. `bcfc8881`은 브랜치 중간의 v20(`cron_run_receipts.delivery_attempt_state`) 마이그레이션을 **제거**한 커밋이다(diff 측정). 9.8↔9.9 net으로는 `src/state/*.sql`·`openclaw-state-db-additive-columns.ts`·`*generated*`에 **변경이 없다**(측정). 따라서 9.8로 되돌려도 "newer schema" 거부는 일어나지 않을 것으로 추론한다(실기 미검증).
- memory embedding cache 수리: `memory-schema-storage-migration.ts:373`에서 legacy shape가 아니면 즉시 반환한다. agent 경로는 `previousVersion < AGENT_STORAGE_SCHEMA_VERSION(23)`일 때만 실행된다(`openclaw-agent-db-schema.ts:350`, contract `:30`). 우리 DB는 v24이므로 **no-op이 예상되지만 shape는 미측정**(DB 직접 조회 금지). legacy 행이 있다면 9.9는 >1MB/invalid 항목을 empty-vector가 아니라 **skip+경고**로 처리한다(`:233`, `:276`). cache 항목만 해당하므로 재임베딩 비용도 그 행으로 한정된다.
- transcript archive·media 수리는 Doctor 전용이지만 F1 때문에 activation 때 실행된다 → 사본 실측이 필요하다.
- `docs/ci/release-validation/install-smoke-and-docker-e2e.md:105`: October beta가 state 20으로 올린 DB는 9.9가 **변경 없이 거부**한다. 10.x beta를 live state에 붙이지 않는다. 다음 stable hop에서는 v20이 다시 들어올 가능성이 높으므로 그때 cold backup이 필수다(제안).
- config: zod schema(`src/config/zod-schema*`)는 9.8과 identical(측정). retired-key 검사는 순수 리팩터(`retired-config-formats.ts:8`, 목록 동일). 새 config 마이그레이션 규칙은 없다.

### F9 — cron (최종 태그 기준)

`bcfc8881`은 v20 fence(`delivery-attempt-fence.ts`, `run-receipt-delivery.ts`, `server-cron-completion.ts`)를 제거했다. scheduled message-tool 배달의 currency 단언은 남겼다(`message-action-runner.ts:448`). 9.8 대비 net 변화:
- stale timeout run-id fence(`server-cron.ts:952`)
- thinking catalog hydration 5초 race(`model-selection.ts:34` — 초과하면 admitted catalog 사용)
- cron tool dotted key canonicalization

memento(isolated, `thinking:xhigh` 명시, claude-cli Fable)에서 hydration 초과가 실효 thinking을 바꾸는지는 미측정이다. 다음 run 영수증의 model·status·배달로 확인한다.

### F10 — `/model`·codex

`src/gateway/sessions-patch.ts`(harness 검증 `:641`), `src/auto-reply/reply/commands-models*.ts`, `src/agents/{model-selection,operator-model-policy,sticky-model-selection}.ts`, `plugin-auto-enable.shared.ts`, `harness/runtime-plugin.ts` 모두 **diff 없음**(측정). `runtime-plugin-load-plan.ts`의 codex 강제 활성 분기(`:348`)는 9.8 `:378-386`과 같은 로직을 추출한 것이다. → 9.9는 6.1-sol 선택 거부를 고칠 근거가 없다. 기동 후 `plugins list`에서 codex가 disabled인지 다시 확인한다(config `plugins.allow`에는 codex가 있고 `entries.codex.enabled=false` — 측정).

### F11 — 게시물 사실

registry metadata(여기서 측정, layer pull 없음):
- `ghcr.io/openclaw/openclaw:2026.9.9` index `sha256:7f10d5cc975a90b65192eaa099454fe33ce8ce2390806c61c65cd868e9ef730d`, arm64 manifest `sha256:f75083cde787…`
- label `revision=bcfc88812a35…`, `version=2026.9.9`, `NODE_VERSION=24.21.0`(live와 동일), base digest는 상류 Dockerfile 고정값과 동일
- 상류 `Dockerfile`은 9.8과 identical
- 로컬 `ghcr.io/openclaw/openclaw:2026.9.8`의 RepoDigest = 게시 index `d0ded1dd…`

postpublish evidence에는 npm·plugin readback이 있지만 Docker readback 항목은 없다(외부 artifact). Android는 8.2 핀 그대로이며 이번 train에서 생략됐다.

## coordinator 검토 주장 대조

| 주장 | 판정 |
|---|---|
| 185커밋·1,111파일, SHA 2개 | 확인(측정) |
| corpus/key-utils 동일 → hotfix 미해결, 9.9 FROM만 바꾸면 빌드 실패 | 확인. 여기에 **npm 9.9 번들 실측 이관 성공**을 추가(F3) |
| Telegram helpers.ts·channel.ts 동일 | 확인하고 강화: miniapp 외 Telegram 비-test 전부 동일. 대신 공유 배달 경로 변경을 추가(F6) |
| `/controlui` 분리, 실행 버튼 요청 가능 | **정정**: tailscale mode off라 URL 오류가 기대값(F7) |
| owner는 숫자 allowFrom 필요, 그룹 확대 금지 | 확인. accessGroups 없음·그룹 allowFrom 미참조 측정 |
| sessions-patch 동일, `/model` 미해결 | 확인하고 강화: model 명령·policy 파일 전부 동일(F10) |
| state 19/agent 24, 번호 동일 ≠ 수리 0 | 확인하고 **핵심 보강**: 수리가 activation에서 자동 실행됨(F1) |
| Node engines·pnpm 동일 | 확인하고 강화: 상류 Dockerfile·Node 24.21.0 동일. npm@latest·CC 미핀은 남는다(F5) |
| 컷오버 단계 2 "정지·cold backup·승격" | 보강: 디스크(F2), 롤백도 doctor --fix를 탄다(F1) |
| (없음) | 추가: utility model drift(F4), 후보 gateway 동시 기동 위험(아래 G2) |

## 결정·게이트 (제안 — GLG 판단 대상)

- **G0 결정**: F4 utility model, F5 claude-code 핀, F2 백업 위치/공간 확보, F3 가드 `"2026.9.9"` 교체 승인.
- **G1 후보 빌드** (digest 고정 FROM): patch 로그·10 단언·`--baseline` 증명·`claude --version`·npm 버전 기록.
- **G2 격리 activation**: cold state의 **사본**에 후보 이미지로 `doctor --fix --non-interactive`만 실행한다(exit·소요시간·경고·쓰기 내역·생성된 백업 크기 기록), 이어서 `config validate`·`config schema` diff. ⚠️ live와 같은 Telegram 토큰으로 후보 **gateway를 띄우지 않는다.** polling 충돌·이중 응답·cron 이중 실행이 생긴다. 기본 entrypoint+gateway cmd로 사본을 기동하는 것도 같은 이유로 금지한다.
- **G3 컷오버**(별도 승인): `gateway.suspend.prepare` ready·active 0 → 정지 → `docker ps`로 정지 확인 → 공간이 있는 FS에 cold backup → `9.8-dirty-fix` 롤백 태그 고정 → recreate → activation Doctor 로그·ready 확인.
- **G4 사후**: F6 matrix, 6봇 memory status·chunk 대조, utility 호출 status(F4), `plugins list`의 codex disabled.

## 이번에 하지 않은 것

- 이미지 pull/build, 후보 컨테이너 실행
- Doctor(read-only 포함) 실행, live config/state/세션/자동화/권한 변경
- DB 직접 조회(memory cache shape·cron 후손 수 미측정)
- Telegram·모델 실응답·live inference
- Bot API 호출

npm tarball(무결성 검증)은 9개 모듈과 corpus chunk만 scratch에 추출해 노드로 단언만 실행했다. registry는 manifest·config blob만 읽었다. live에서는 entrypoint·버전·로그 grep(haiku 건수)·config 선택 필드(개수·모드만)를 read-only로 봤다. **Docker 9.9 dist의 hotfix 적용, 실제 activation Doctor 결과, Telegram/모델/DB 실기 동작은 검증하지 않았다.**
