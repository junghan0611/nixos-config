# NEXT.md — 다음 할 일

운영 baseline은 [AGENTS.md](AGENTS.md). 후속 작업 / 미완 검증은 여기에. 닫힌 항목은 [CHANGELOG.md](CHANGELOG.md)로 흘려보낸다 — 최근 발행 [v2026.10.30](https://github.com/junghan0611/nixos-config/releases/tag/v2026.10.30).

작업 끝나면 항목 지우고, 새로 발견한 후속은 추가. 영속할 사실은 AGENTS.md / docs/openclaw-gotchas.md / `~/openclaw/README.md` change history로 옮긴다.

> **2026-10-26 정리:** 1,114줄이던 NEXT를 닫힌 항목·화석(8.1~10.4 시절 soak, 이미 퇴역한 백업 경로, 끝난 체크리스트)을 빼고 열린 것만 남겼다. 지운 원문은 `git show 07849d5:NEXT.md`에 그대로 있다. 아래 §이월 판단 대기는 옛 항목 중 아직 닫혔다는 근거가 없는 것만 한 줄씩 남긴 목록이다.

---

# RAIL — 현재 좌표

- [x] **1. OpenClaw 10.7 이관 → 뒷정리 → NEXT·이슈 정리** — [v2026.10.26](CHANGELOG.md)·[v2026.10.28](CHANGELOG.md) 기록
- [x] **2. OpenClaw 10.8 교체 + 첫 자연 메멘토 관측** — 10-27 23:08 교체, 10-28 01:26 ok/delivered, [v2026.10.28](CHANGELOG.md)
- [x] **3. 10.9 운영 확인·교차검토·임시 정리** — [v2026.10.30](CHANGELOG.md)에 이관
- [ ] **4. 연속성·비용·세션 증식 기준의 깨움 설계** ← CURRENT: 주말 GLG 판단, [#13](https://github.com/junghan0611/nixos-config/issues/13)·llmlog 20261028T092543
- [ ] **5. 기존 미해결·복구 자산 판단** ← PAUSED: 강제 검증 금지 · D1 퇴역은 GLG 선택, e122는 soak 뒤 (A/B/C 정리 완료, CHANGELOG v2026.10.28)

현재 좌표: 1–3 완료 → 4 주말 판단 대기 → 5 미해결 보존

## NOW — 10.9 기준의 깨움 설계, 적용은 별도 승인

- **상태:** OpenClaw10.9(`709acab4…`) 운영 확인과 승인된 임시2폴더/끝난7helper 정리는 닫았다. 상세는 [CHANGELOG v2026.10.30](CHANGELOG.md)·ROADMAP, 비공개 영수증 `.agent-reports/openclaw-upgrade-20261030/`. 기존 FAIL1과 경고·dirty는 별도다.
- **Next:** [#13](https://github.com/junghan0611/nixos-config/issues/13)과 [10.9 기준점 댓글](https://github.com/junghan0611/nixos-config/issues/13#issuecomment-6515293984)을 읽고 **연속성 유지 + 전체 맥락 반복 입력 비용 제어 + 매 tick 새 세션/파일 증식 비선호**를 만족할 방식을 고른다. fresh 기본/역할/주기/예산은 미정이다. light는 bootstrap만 줄이고 history 상한이 아니므로 지속 작업 세션·선택적 회수·runtime별 compaction을 분리해 비교한다. 파일럿은 한 봇·범위·관측/중단 기준을 명시 승인한 뒤다.
- **Read:** 비공개 llmlog `20261028T092543` — 깨우기·퇴근·기억·검증: 연속성과 맥락 비용, 세션 증식의 기준 → #13. 기억 생산/Andenken 회수는#5, mini 역할은#10과 연결하며 자동으로 기능을 켜거나 이슈를 닫지 않는다.
- **미해결:** verify **39PASS/FAIL1**의 session 실패 요약은10.9 교체 전·직후·첫 자연 실행 뒤 동일했지만 최초 원인·귀속은 미확정이다. 기준 확장·행 삭제·reset 없이 native 표면으로 조사한다. auth-unknown·slow SQLite·slow lifecycle 경고도 남았다.10.9 초기 tini ELOOP2회/RC2, MaxListeners(exit listeners11)1회는 해결 증명이 아니다. glg/mini/bbot dirty 자연 수렴·실대화 품질도 미검증이며 forceindex/추가 smoke는 승인되지 않았다.
- **보존·판단:** 현재10.9/base, 직전10.8 rollback와pre-port원본3파일, 기존10.7 e122, DB24 cold24+7e39 복귀 짝·검수 영수증은 보존했다. **D1** cold24+7e39/17dab/9d63 퇴역은 DB24 복구 능력 상실을 포함한 별도 선택이다. **D2** e122(+61ff base)도 별도 선택이다. 예전 회수량 추정은 재사용하지 말고 직전에 참조/용량을 다시 재며, 결정하면 ORACLE·ROADMAP·runtime README의 경로를 함께 맞춘다. 비공개 openclaw-config의 기존 혼재 WIP는 공개 릴리스와 분리해 별도 commit 범위를 정한다.

## ChatGPT Linux 프리뷰 — 다음 버전업 때 확인

- 현재 운영 경계는 [README](README.md#desktop-and-development)로 승격했다. 패키지는 literal rev 고정이라 일반 `nix flake update`/switch만으로 오르지 않는다. `nixpkgs-ghostty` rev를 옮길 때 Ghostty도 함께 검수하고, stable이 Linux 패키지를 지원하면 예외 회수를 검토한다.
- **공유 상태:** 기존 CLI에 문제가 생기면 앱과 공유하는 `~/.codex`의 설정/상태 변화부터 확인한다. 분리나 인증 변경은 별도 판단이며, DB를 직접 수선하지 않는다.
- **캐시 수명(미측정):** 패키지의 `share/user-tmpfiles.d/chatgpt.conf`가 HM 프로필 경로에서 `systemd-tmpfiles --user`에 잡히는지 확인하지 않았다. 안 잡히면 버전마다 `~/.cache/chatgpt/bundled-plugins-v2/<옛 키>`가 남는다. 자동 삭제로 넓히지 않고 버전업 때 확인한다.

## Ghostty — 타 기기 반영 시 참고

- thinkpad 1.4.0 switch·기존 설정 검증은 완료했고 GLG가 사용 결과를 수용했다(2026-10-31). 설정·바인딩은 그대로다. laptop/nuc는 선언만 바뀌었으므로 해당 기기에서 필요할 때 별도로 rebuild한다. 원격 적용은 하지 않았다.
- Oracle에는 Ghostty 패키지·설정 drv가 없음을 평가로 확인했다. 다음 Oracle rebuild에서는 과거 설정 링크1개가 제거된다(GUI 설치 없음). stable이1.4 이상을 제공하면 전용 input/overlay 회수를 검토한다. `ghostty +ssh` 실연결은 아직 하지 않았고 서버 terminfo 쓰기는 별도 판단이다.

## 보존·판단 후속 — 10-26 뒷정리에서 이월

- **별도 판단 후속(지금 할 일 아님):**
  - C 이미지(10.4-tools, 레이어 전부 7e39와 공유 → 회수 ~0) — 태그를 정리하고 싶을 때만.
  - SDK 1.3→1.4 롤백 자산 `~/entwurf-sdk13-backup-20261023T025052`(265MB, durable 세션 37개 sqlite+wal+shm 묶음) **보존**. 퇴역 조건 = 이 호스트에서 1.4 정착 + SDK1.3 롤백 불요를 GLG/entwurf 담당이 결정. 부분 퇴역 금지. 근거 절차 entwurf `docs/setup-clean-host.md` "Moving durable sessions from the Pi 1.3 SDK to 1.4".
  - 옛 복구 경로 정정: 10-26 당시 `~/openclaw/backups/`는 비어 있었고 과거 NEXT의10.2 cold v19 경로는 없다(현재의10.9 candidate 영수증은 별개다)(퇴역 경위 미확인). 10.2 run(8fc7d3ca)의 config 옆 bak도 현재 0개, run manifest만 남음.
- **보호 경계:** 실제 agent DB는 25다. native run manifest `session-sqlite-migration-runs/startup-migration-1c8434b2-….json`의 archivePath는 역사 기록이지 복구 원본이 아니다. DB24로 내리는 복귀는 cold24 + old 이미지와 컷오버(10-25) 후 새 데이터 보존 판단이 함께 필요하다. ZAI/xAI/codex·Gemini 입력/heartbeat 정지를 해제하지 않는다. 메멘토 3h 정기 루프는 잘 돌고 있다 — 건드리지 않는다. 10-25·10-26에 은퇴한 경로는 재실행하지 않는다.
- **Do not:** 전체 safe/deep·Nix GC·`docker * prune`·재부팅·재시작·doctor repair·모델 smoke·수동 cron run·인증 변경·annex 이관. 삭제 승인은 정확 경로 집합 단위, 직전 재확인 후 실행하고 `df` 실측으로 보고.

## 열린 운영 후속 — OpenClaw 10.7

- **미검수:** family cron 기존 오류4의 원인·재발 여부(10-28 08:00 실행·전송 경로는 관측), mini/Sonnet 실응답, Andenken private hit→source와 색인 수렴. Fable 메멘토·family 한 경로 성공으로 모든 모델/도구를 인증하지 않는다. 재임베딩・재로그인・추가 유료 모델/키 우회 없음.
- **미해결:** 초기 tini/ELOOP 근본 원인(10.2 0회·10.3 4회·10.7 기동 시 관측, 재시작 정책이 회복), 주간 GC의 복귀 세대 보존, Pi TTY daemon 수동 기동. [Andenken#18](https://github.com/junghan0611/andenken/issues/18) 스토리지 권고는 타 리포 데이터 삭제나 기억 설계 변경 허가가 아니다.
- **bbot memory admission 패치:** 10.9 한정 v4로 이식됨(10-30, 소스 blob은10.7/10.8과 동일 — 상류 미수정). 다음 버전업마다 상류 수정 확인 → 패치 회수/재이식. 노트북 재수확·prune·verify·발행은 agent-config 담당자 몫. 오토B 중지・`--force`・DB 직접 수정 금지.
- **Andenken readback:** B가 실제 private 히트에서 `run.sh excerpt:session`을 쓸 때 확인([계약](https://github.com/junghan0611/agent-config/issues/31#issuecomment-6260069262)). pin10.33.0·runner/parser 동결, 10.7 base 기본 pnpm은 12.15.0. 강제 모델 턴・재임베딩 금지.
- **Utility 보조 호출:** 공통 utility는 명시 `openai/gpt-6-luna`/runtime `openclaw`([자동화 SSOT §Utility](docs/openclaw-automations.md#utility-보조-호출--운영자에게-알려진-목적만)). 자연 사용에서 helper rail·소비자 목적만 관찰, 새 미설명 소비자는 GLG와 먼저 논의.
- **도구 후속:** 실네트워크 YouTube 요약·PDF(현 이미지에 uvx/markitdown 없음)는 필요할 때 판단. private 리포 소스 커밋은 별도 승인(Dockerfile·README·`summarize-bot.sh`·`config/claude-skills/summarize` 링크 4개만, 타 작업 config 변경과 섞지 않음). Oracle의 netlify-cli·typescript-language-server 기설치본 제거는 별도 승인.
- **Telegram DM 토픽 첫 실대화 검수:** 운영자가 새 토픽 → 토픽별 세션·같은 토픽 답변 확인([운영 문서](docs/openclaw-telegram-topics.md)). 기존 DM reset·privacy 전역 해제 금지.
- **음성 전사 보류:** [#12](https://github.com/junghan0611/nixos-config/issues/12). 추가 비용0・Oracle 로컬 모델 제외(GLG). `tools.media.models`를 비우지 않는다.
- **Do not touch:** `plugins.entries.codex.enabled:false`·`acp.enabled=false`·`plugins.entries.acpx.enabled=false` 유지. 복사 상태 실행은 `--network none`. `gateway.trustedProxies`의 `172.26.0.1/32` 유지. Active Memory·dreaming 켜지 않음. 안드로이드 페어링 삭제로 scope 고치기 금지. entwurf `.assembled` 마운트・tmux 소켓 마운트 금지. bbot heartbeat `{every:"0m"}` 유지(cadence는 cron 소유).

## 열린 운영 후속 — 사람이 알아채는 구조와 상류

- **봇 무응답 통지(옛 RAIL 5):** 세션 `status=failed`가 N분 지속되거나 spooled retry가 반복되면 사람에게 알리는 구조. upstream 몫인지 우리 cron 한 줄인지 먼저 판정([자동화 SSOT](docs/openclaw-automations.md)에 얹을 자리). 오늘 메멘토 auto-disable(10회 billing)은 `lastFailureAlertAtMs`가 남았으나 GLG가 먼저 본 경로는 아니었다 — 같은 질문의 새 사례.
- **상류 리포트 후보(옛 RAIL 6):** 기억 검색 RW 세션·`embedding` TEXT 저장·세션 mtime 감쇠·세션 캡 부재·deleted/reset 아카이브 색인·`chunkTokens` 휴리스틱(9/6 확정 6건), rate-limit run의 세션 락 미해제·Android heartbeat automation 상세 오류(후보 2건). 각 항목의 현행 10.7 재현 여부부터 확인 후 제출. 근거 원문 `git show 07849d5:NEXT.md` §상류·§회수 품질.
- **doctor 셋(옛 RAIL 10):** glg `USER.md` 파일당 상한 잘림(`bootstrapMaxChars`) · `tmux` 커스텀 스킬 번들 덮기 의도 · `AgentSelectionRequiredError`가 doctor health 한 칸을 막음. 10.7에서 재측정 후 처리.
- **bbot Android admin scope:** 폰은 cron 읽기 전용(정상). 직접 편집이 필요할 때만 scope 재연결 승인.

## #11 이후 웹 퍼블리시 — 7·8단계 보류

- [#11](https://github.com/junghan0611/nixos-config/issues/11)은 09-30 닫혔고 homepage 쪽은 [homepage#2](https://github.com/junghan0611/homepage/issues/2)·[#3](https://github.com/junghan0611/homepage/issues/3)로 이관됐다. 역할: oracle=상시 배포 플랫폼, nixos-config=계정·토큰·DNS·터널·도구.
- **7·8단계(독립 junghanacs 터널 → ax 정적 호스팅·map 내림 → Caddy·Authelia·80/443 철거)는 GLG 10-02 보류.** 착수 전 정리: 경로별 접근제어·실제 클라이언트·롤백·`proxy` 네트워크 생성 주체·**DNSSEC 해제 순서(DS 먼저 지우고 TTL 3600s 뒤)**. aions 터널 변경 금지. 공식 `cf` 쓰기에는 `-z <zone ID>`.
- aionsclubs.org DNSSEC DS 반영 `AD` 확인(10-01 당시 미반영) — 미확인 상태.
- 비공개 영수증: oracle `~/web-publish/`(IP·보안 메모, 리포·공개 이슈로 옮기지 않음).

## git-annex 기반 세션 코퍼스 보관 체계

- **대상:** `~/repos/gh/session`(기기 통합 세션 코퍼스, 10-25 약5.1GiB, `.git` 부재·`MANIFEST.json` 존재) hot/cold 배치·비공개 annex 경계 설계. `git-annex`는 선언/네프로필 평가만 완료, init/add/drop/remote/이동은 하지 않았다.
- **먼저 결정:** Oracle 잔류 범위, 목적지와 가용량, 로컬 drop 뒤 독립 사본 수, 무결성/복원 증거, 평시/피크 예산. 회사 계정 저장소를 유일 보관처로 삼지 않는다.
- **소유자 계약:** Andenken·agent-config의 `MANIFEST.json`/SHA256·append-only·gather/replicate·reader 경로 유지 방법을 검토. 이번엔 배치·계약·검증 계획까지만, 시험 복사·원본 이동/drop은 각각 별도 승인.

# 이월 판단 대기 — 옛 항목 중 닫힌 근거가 없는 것

원문 맥락은 `git show 07849d5:NEXT.md`의 해당 절. 착수 전에 현재 10.7·현 호스트에서 여전히 사실인지부터 다시 잰다.

**압축 때 개별 재판정하지 않은 옛 절**(미체크 항목이 남아 있었음 — 닫힘 근거 아님): §4 8B 4096d 검색 품질 검증(native 검색 전제의 구 scope — 현행 적용성 미확인, [#5](https://github.com/junghan0611/nixos-config/issues/5) 재정의 이후 그대로 재개하지 않음) · §5 HA 데이터 import(lifetract 배턴) · §oracle `/home` 회수 근본 · §ACP 잔재 청소 · §AGENTS.md/gotchas.md로 옮길 자리. 이 줄은 그 절들을 다시 읽어 지우거나 한 줄로 승격할 때 함께 정리한다.

**보안 부채 (우선):**
- 🔴 GitHub Copilot 옛 토큰 2개(`ghu_…`·`gho_…`) GitHub 측 권한 취소 — 로컬 삭제만으로 무효화되지 않는다. (§github-copilot)
- 🔴 claw gateway token 회전 — 8/6 배포 중 평문이 트랜스크립트에 남음. 회전 후 브라우저 재입력. (§claw)
- `channels.mattermost`가 botToken을 든 채 남아 있음(10-26 `config get channels` 키 확인) — 안 쓰면 unset으로 평문 축소. (§7.1 잔여)
- `anthropic:default [anthropic/token]` 비-OAuth 프로필(glg/gpt/gemini) 정리 판단. (§모델 정렬)
- 공유 `~/.claude` rw — 컨테이너가 호스트 플러그인 상태에 쓸 수 있음. 하위 경로별 축소 판단. (§앱 후속)

**OpenClaw 운영 (낮은 우선):**
- 아내 07:00 cron(`morning-family-schedule-reminder-wife`, disabled) 재활성 시점 — GLG 판단. `daily_real_estate_auction_study_brief_miir`는 켜기 전 model 명시. (§8.1 회귀)
- 4봇(main·glg·gpt·mini) heartbeat 재활성 — GLG 예정, 검수 목적의 의도적 off. [#10](https://github.com/junghan0611/nixos-config/issues/10) mini 확장과 함께. 10.7에서 Workshop `propose`·review job 6개가 사라져 #10 4단계는 재정의 필요(2026-10-26 코멘트). 선행: `skills.workshop.allowSymlinkTargetWrites`가 10.7에서 Unknown path — 후계 guard를 v2026.10.7 고정 소스로 정태 확인(미검증, 쓰기 테스트는 GLG 승인 후).
- active-memory 거취(현재 off, 폐기도 선택지) · typing 재발 관찰 · `tools.sessions.visibility="all"` 재검토. (§8.1·§8.2)
- [[#5](https://github.com/junghan0611/nixos-config/issues/5) 검토 상자로 이관, 미검증] `memory.search.sources=["sessions"]` 축소 결정(대가: MEMORY/USER가 의미 검색에서 빠짐) · FTS-only 한 봇 시험 · `memory_embedding_cache` orphan+VACUUM(~600MB 추정, 정지 창 필요) · 정기 `memory index` 승격. (§기억축)
- glg 가족봇 Sonnet 5 soak — 감정 있는 실제 턴에서 대칭 규칙 유지 여부·역할 낭독 반복·compact 요약의 법적 프레임 잔존 관찰. (§glg 가족봇)
- thinking 판단: claude-cli 봇은 thinkingLevel이 안 물린다는 기록(`extensions/anthropic/cli-backend.ts`, 10.7 재확인 전) · bbot 세션 `think:xhigh` 정식화/하향 · gpt `thinkingDefault=medium` 인상 관찰 · luna/terra lane 품질 soak. (§glg 가족봇·§7.1 잔여)
- `run.sh t)` SSH 터널 은퇴 여부(trustedProxies 변경 뒤 403). (§앱 후속)
- telegram stop-timeout 데드락 — 업그레이드마다 상류 수정 확인, gotchas 미기록. (§2 버전 hop)
- 스킬 심볼릭 전면 전환 설계(device 이식성·`extraDirs` vs 심볼릭·pi-skills 화이트리스트) · gogcli SKILL.md 내용 분기. (§스킬 심볼릭)
- 컨테이너 cron이 호스트 시민을 깨울 수 있는가 — 지금 재지 않음. (§시계)
- OpenClaw 세션을 andenken 코퍼스에 편입·크로스에이전트 기억 일원화 — 수확 축(`semantic-memory` `search-openclaw`, 재임베딩 없는 harvest)으로 이미 서 있다. 남은 계약 재검토는 [#5](https://github.com/junghan0611/nixos-config/issues/5). (§기억망)
- 이미지생성 `GEMINI_API_KEY` 경로 미재검증. (§pi-shell-acp)

**호스트・공개면:**
- `10.0.0.157` caddy 바인딩 하드코딩(DHCP 변경 시 caddy 무응답) · tailscale serve 443 공존 근본 판단. (§부팅 레이스)
- uid 전체 SIGTERM 재발 시 즉시 `sudo audit-query term` · `diskclean.sh` 저널 200M 단계와 선언적 1G 정합. (§SIGTERM)
- claw HSTS `max-age` 상향 · family 계정 negative test · `gateway.trustedProxies` 범위 축소(compose static IP). (§claw)
- authelia map 실브라우저 로그인 1회(아내). (§authelia)
- ax umami·remark 스니펫(정본은 담당자 `apply/ax`) · 크롤러 방문 실측 회신. (§ax)
- Forge `pg_dump` 백업 cron · fail2ban jail. (§Forge)
- caddy·authelia가 repo 워킹트리를 라이브 마운트한다는 사실을 gotchas/스킬에 정정. (§NixOS 26.05)
- Emacs 31.1: oracle·thinkpad 완료, nuc/laptop은 다음 rebuild. 죽은 `emacs-nox` 코드 3곳·데스크톱 중복·doomemacs-config preview flake 은퇴는 해당 담당자 판단. (§Emacs)

**데스크톱:**
- thinkpad 마이크 UCM 블록 재부팅 검증 · 상류 [alsa-ucm-conf#785](https://github.com/alsa-project/alsa-ucm-conf/issues/785) 수정 시 제거. (§마이크)
- datasette 오버레이 회수 조건(`asgi-csrf` broken 해제) · 쓰기/폼 POST 사용 시 오버라이드 부족. (§datasette)
- `diskclean.sh deep --dry-run`의 nuc/laptop 실측 · `deep`은 `.zig-cache`/`.direnv`를 통째로 지우므로 담당자 먼저 · pnpm store 고아량 미측정. (§디스크)
- 키크론 V10 M1–M5 매크로·거슬리는 키·칩셋 확인 — 천천히. 키맵은 `users/junghan/keychron/`. (§키크론)
