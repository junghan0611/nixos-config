# NEXT.md — 다음 할 일

운영 baseline은 [AGENTS.md](AGENTS.md). 후속 작업 / 미완 검증은 여기에. 닫힌 항목은 [CHANGELOG.md](CHANGELOG.md)로 흘려보낸다 — 최근 발행 [v2026.11.16-openclaw.1](https://github.com/junghan0611/nixos-config/releases/tag/v2026.11.16-openclaw.1).

작업 끝나면 항목 지우고, 새로 발견한 후속은 추가. 영속할 사실은 AGENTS.md / docs/openclaw-gotchas.md / `~/openclaw/README.md` change history로 옮긴다.

> **2026-10-26 정리:** 1,114줄이던 NEXT를 닫힌 항목·화석(8.1~10.4 시절 soak, 이미 퇴역한 백업 경로, 끝난 체크리스트)을 빼고 열린 것만 남겼다. 지운 원문은 `git show 07849d5:NEXT.md`에 그대로 있다. 아래 §이월 판단 대기는 옛 항목 중 아직 닫혔다는 근거가 없는 것만 한 줄씩 남긴 목록이다.

---

# RAIL — 현재 좌표

- [x] **1. OpenClaw 10.7 이관 → 뒷정리 → NEXT·이슈 정리** — [v2026.10.26](CHANGELOG.md)·[v2026.10.28](CHANGELOG.md) 기록
- [x] **2. OpenClaw 10.8 교체 + 첫 자연 메멘토 관측** — 10-27 23:08 교체, 10-28 01:26 ok/delivered, [v2026.10.28](CHANGELOG.md)
- [x] **3. 10.9 운영 확인·교차검토·임시 정리** — [v2026.10.30](CHANGELOG.md)에 이관
- [x] **3b. OpenClaw 11.3 메이저 컷오버 + claude-cli 모델 정리 + 현재값 SSOT 단일화** — [v2026.11.14](CHANGELOG.md), 잔여 관측은 아래 §OpenClaw 11.3
- [x] **3c. 11-15·16 정비: entwurf 책상 A창(#160), bbot memento 6h, defaults·gemini → 6.1-sol, #17 시도·원복, rclone 콜드 기반** — [v2026.11.16](CHANGELOG.md)
- [ ] **4. 연속성·비용·세션 증식 기준의 깨움 설계** ← CURRENT: 주말 GLG 판단, [#13](https://github.com/junghan0611/nixos-config/issues/13)·llmlog 20261028T092543
- [x] **5. 기존 복구 자산 판단** — D1(cold24+10.4)·D2(e122)를 포함한 옛 10.x 복귀 자산을 2026-11-14 GLG 승인으로 퇴역(10.9-cc322 `b3bbcd9c`와 마지막 cold B도 같은 날 추가 퇴역, 이 컷오버의 10.9 전체 데이터 복귀점 없음)([v2026.11.14](CHANGELOG.md)). 미해결 관측은 §이월 관측

현재 좌표: 1–3·3b·3c 완료 → 4 깨움 설계 판단 대기(11.3 기준 재확인 필요). 5 복귀 자산 퇴역 완료, 미해결 관측은 별도.

#14 Oracle RDP는 별도 레인이다. 구성·사용법은 [ORACLE.md §5.5](ORACLE.md#55-공유-gui-작업실--rdp-14), 남은 것은 아래 §#14.
Oracle 계획 재부팅은 11-04 읽기 전용 사전점검까지 하고 보류했다 — 아래 §Oracle 계획 재부팅.

## 추가 사용자 초안 검토

- [ ] `docs/additional-users.md`와 `tests/additional-users.nix`의 비활성 초안을 GLG가 검토한다. 운영자 교체와 실제 계정 생성·switch는 별도 승인이다.

## Cyborg 입사 준비

- [ ] [CYBORG.md](CYBORG.md) 절차로 회사 실기기를 설치하고 첫 부팅·하드웨어 수집·Intel/NVIDIA·외부 모니터·오디오·절전·Ollama를 검증한다. ISO 재빌드 없이 준비된 매체 사용; 리포를 가져온 뒤 `#cyborg` switch는 GLG가 판단한다. RX 470 데스크톱 실측과 설치 첫 실패의 미상 원인은 문서에 구분했다.
- [ ] 다음 ISO를 만들 때만 라이브 XFCE 자동 잠금 방지를 실제로 검증한다. 현재 매체는 변경 전이다. 오프라인 설치 및 Teams 실행도 아직 미검증.
- [ ] `nuc` XFCE 대체 부팅 선택지는 평가만 완료했으며 미적용·미커밋이다. `laptop` 실제 SSH 키 접속도 적용 전 확인한다.
- [ ] 이전 레벨 6 ISO #446의 Nix 스토어 본체 회수 여부는 별도 판단한다.

## 터치패드 제어

- [ ] Cyborg 실기기 X11에서 `touchpad status`로 자동 탐색을 확인한다. 이름이 다르거나 후보가 여럿이면 `xinput list`로 확인하고 `touchpad status '장치 이름'`으로 지정한다. Samsung laptop의 on/off/toggle은 확인했다.

## Sway 실험 — 후순위

- [ ] 설치 안정화 후 테스트 기기를 정해 Sway를 별도 선택지로 검토한다. i3 기본값 유지; 반납한 ThinkPad는 제외. 스크래치패드 IPC, 모니터 자동 배치, 한글 입력, Teams 화면 공유를 검증한다.

## OpenClaw 11.3 (11-13 메이저 컷오버) 관측·갈무리

현재 운영 버전은 [ORACLE.md](ORACLE.md) `LIVE` 줄로 판정한다(여기에 복제하지 않는다). 경과는 [ORACLE.md](ORACLE.md) Model routing 첫 문단, 영수증은 비공개 `~/openclaw/backups/cutover-11.3-20261113/`·`.agent-reports/openclaw-v2026.11.3-review/`.

- [ ] 실사용: 모델 정리(11-14) 뒤 glg·mini sonnet-5-5 첫 실제 대화 턴을 메타로 확인한다(모닝 cron 11-15 08:00은 sonnet-5-5 ok/delivered로 확인됨, `cron runs` 11-16).
- [ ] **11.4 교체(11-16) 사후 관측:** 다음 자연 메멘토 20:30·모닝 cron 11-17 08:00 ok/delivered, glg·mini·main 실제 턴, RestartCount 0 유지. 뒷정리는 11-16 완료(이미지 롤백 수단 없음 — CHANGELOG Unreleased).
- [ ] **memory 인덱스 동결 — 결정 필요** (11-16: 11.4에 #196378 rebuild 수정 포함 → 선택지 A의 대기 조건 해소, #196505는 열림) (11-14 읽기 전용 검수, 비공개 `.agent-reports/openclaw-v2026.11.3-review/memory-axis-20261114.md`): 6봇 인덱스가 전부 chunking **5** 그대로이고 컷오버 뒤 새 행 **0**, 재구축·capacity·임베딩 로그 0(로그 관측이며 OpenRouter 청구액은 따로 확인하지 않았다). `tools.deny=["memory_search"]`라 search 경계 repair가 발화하지 않는 것으로 보인다(가설). 비용은 0이지만 **새 봇 기억이 인덱스와 Andenken openclaw 수확으로 흐르지 않는다.** Andenken export가 읽는 4테이블·컬럼은 v27에 그대로 있어 수확 자체는 호환. 선택지: (A) upstream #196378이 든 stable까지 동결 유지 (B) gateway 정지 후 offline `memory index --force`로 통제 재구축 — bbot 6426×4096d는 #196505 실패 규모대, 경계 바뀐 청크만큼 OpenRouter 재임베딩, 재구축 뒤 청크 id가 바뀌면 append-only Andenken에 v5·v6 중복 유입 가능(가설, andenken 담당과 계약 확인 필요). `memory status` CLI는 gateway 실행 중 거부, verify memory 절은 11.3에서 unavailable.
- [ ] W4 권고: 첫 재구축 뒤 memory index에 cron 부모·자식 세션 0건 확인(읽기 전용, 10.9 기준값과 비교).
- [ ] **다음 의도된 recreate 때 함께 뺄 것 (GLG 11-14·15 확인, 잊지 말 것):** compose의 `~/.codex` 마운트(`:139`) — OpenClaw에서 Codex를 쓰지 않는다(GLG: GPT는 OpenClaw 인터페이스, 지원 모델은 Claude·GPT). `~/.gemini`(`:140`)는 **#17(agy ACP) 결정 전까지 빼지 않는다** — agy 로그인 토큰이 `~/.gemini/antigravity-cli/`에 있고 컨테이너가 이 마운트로 읽는다(gemini 봇 운영 정지와 별개). 낡은 compose `:131` 주석 갱신. 마운트 변경은 recreate가 필요하므로 단독으로 하지 않고, recreate가 필요한 다른 작업과 묶어 GLG 승인 뒤에 한다.
- [ ] **#17 agy(Antigravity) via acpx — 11-16 시도 후 원복, 보류 (GLG: "정확히 파악할때까지 그쪽 세션은 안건들일거야… 안되면 뭔가 만들지 않도록하자"):** 막힌 곳은 업스트림 Telegram DM-topic 바인딩 — `/acp spawn --bind here`는 `chatId:topic:thread`로 묶는데 인바운드 DM 라우트는 scope `dm`→bare chatId라 일반 DM이 바인딩을 못 찾고 네이티브 모델로 간다(`topic-conversation.ts:10-38`, `conversation-route.ts:64-69`, `channel.ts:263-296`, `bot-message-context.ts:300-310`; config로 못 고침). 원복 상태: `acp.enabled:false`(allowedAgents `["claude"]`), gemini `runtime` 제거·account disabled. 2026-11-17 GLG 승인으로 acpx 2026.11.3을 `plugins uninstall`(entry·allow·install record·npm 디렉터리 794M)하고 `~/openclaw/config/agy/`(pin 프록시·agy 바이너리 239M)도 지웠다. 재개 시 pin 프록시는 openclaw-config 이력 7f3cb3a에서 복원하고 agy·acpx는 새로 설치한다. 건드리지 않음: 바인딩된 ACP 세션 `agent:gemini:acp:1eacb22e…`, node 세션 `agent:gemini:node-1fd06883a3db`. 업스트림 이슈는 내지 않는다(GLG 11-16). 사실·근거는 [#17](https://github.com/junghan0611/nixos-config/issues/17).
- [ ] **재빌드·plain `compose up` 금지(현 상태)**: compose config-hash가 restart:no override 기준 → override 없는 up은 recreate → #195208 경합/tini ELOOP 재노출. 다음 recreate는 의도된 작업으로만.
- [ ] 남은 정리 후보: 컨테이너 쓰기층 `.update-captures` 1.61G(/, recreate 때만 사라짐). recreate 승인 없음. (11-14 퇴역 내역은 [v2026.11.14](CHANGELOG.md)·v2026.11.16.)
- [ ] 근본원인 미수정 기록: upstream #195208, tini ELOOP.

## 이월 관측

- [ ] verify FAIL 1: session 실패행이 10-27부터 남아 있고, 10-30·11-13·11-14(11.3 verify)에서 count와 시각이 같다. 원인 조사는 별도 승인으로 한다.

## 깨움 설계 (10.9 시점에 작성 — 11.3에서 재확인 필요), 적용은 별도 승인

- **상태:** OpenClaw10.9(`709acab4…`) 운영 확인과 승인된 임시2폴더/끝난7helper 정리는 닫았다. 상세는 [CHANGELOG v2026.10.30](CHANGELOG.md)·ROADMAP, 비공개 영수증 `.agent-reports/openclaw-upgrade-20261030/`. 기존 FAIL1과 경고·dirty는 별도다.
- **entwurf #160 책상 세션 — 운영 몫(11-15 GLG 결정):** 책상이 버티게 하는 운영 규칙 넷을 [gotchas 책상 절](docs/openclaw-gotchas.md)·`openclaw` 스킬 §12에 적었다. 11-15 12:01 leaf 읽기: `session.resetByType`·`resetByChannel`·`compaction.maxActiveTranscriptBytes` 모두 미설정. **남은 것(각각 GLG 승인):** lab에서 sessions.create/pin RPC 이름과 operator.write scope · `/reset` 첫 줄 편지 관측 · 설치 직후 pinnedAt/spawnedBy/parent 확인 · 설치 뒤 몇 주 전사 크기 관측(maxActiveTranscriptBytes 판단). entwurf 쪽은 고정 key↔garden과 compaction 뒤 같은 garden 답신 측정만. 실사용 A 창은 11-15 완료(v2026.11.16, [openclaw-entwurf-desk.md](docs/openclaw-entwurf-desk.md)). **남은 것:** 13단계 영수증은 entwurf 릴리즈 커밋 뒤 재측정(ff08d4·GLG 순서) · 다음 집 mini(선언 allow 한 줄 + 10–13, 각 GLG 승인) · 책상 전사 크기·`/reset`·압축 뒤 같은 garden 답신(F2) 관측.
- **bbot memento:** cron 유지·6h(`30 2,8,14,20 * * *` KST) — 결정 근거는 [ROADMAP 운영 결정 이력](ROADMAP.md), 함정은 [gotchas 11.3 절](docs/openclaw-gotchas.md). 첫 6h 비트(11-15 08:33)·첫 day-close(11-16 02:32) ok/delivered. 다른 봇 깨우기는 봇별로 따로 잰다(entwurf #160 이후).
- [ ] **정비 임시물:** `/tmp/oc-src-v2026.11.3`·`/tmp/hb-audit-20261114/`는 11-16 삭제 완료. 남은 것은 #160 쪽 임시물 `/tmp/oc-847611d.jKXry1`(소스 사본)·`/tmp/ff08d4-next/`는 ff08d4(entwurf) 소유라 그쪽과 정리 시점을 맞춘다.
- **Next:** [#13](https://github.com/junghan0611/nixos-config/issues/13)과 [10.9 기준점 댓글](https://github.com/junghan0611/nixos-config/issues/13#issuecomment-6515293984)을 읽고 **연속성 유지 + 전체 맥락 반복 입력 비용 제어 + 매 tick 새 세션/파일 증식 비선호**를 만족할 방식을 고른다. fresh 기본/역할/주기/예산은 미정이다. light는 bootstrap만 줄이고 history 상한이 아니므로 지속 작업 세션·선택적 회수·runtime별 compaction을 분리해 비교한다. 파일럿은 한 봇·범위·관측/중단 기준을 명시 승인한 뒤다.
- **Read:** 비공개 llmlog `20261028T092543` — 깨우기·퇴근·기억·검증: 연속성과 맥락 비용, 세션 증식의 기준 → #13. 기억 생산/Andenken 회수는 #5(11-16 #13으로 흡수), mini 역할은 #10과 연결하며 자동으로 기능을 켜거나 이슈를 닫지 않는다.
- **미해결:** verify **39PASS/FAIL1**의 session 실패 요약은10.9 교체 전·직후·첫 자연 실행 뒤 동일했지만 최초 원인·귀속은 미확정이다. 기준 확장·행 삭제·reset 없이 native 표면으로 조사한다. auth-unknown·slow SQLite·slow lifecycle 경고도 남았다.10.9 초기 tini ELOOP2회/RC2, MaxListeners(exit listeners11)1회는 해결 증명이 아니다. glg/mini/bbot dirty 자연 수렴·실대화 품질도 미검증이며 forceindex/추가 smoke는 승인되지 않았다.
- **보존·판단(11-14 종결):** D1·D2와 10.9/10.8 복귀 이미지를 모두 퇴역했다. `b3bbcd9c`와 cold B까지 퇴역해 이 컷오버의 10.9 전체 데이터 복귀점은 없다(ORACLE.md 11.3 문단). 소스 재빌드는 삭제한 데이터를 복구하지 않는다. 비공개 openclaw-config는 11.3 반영분만 커밋하고 config/ 아래 기존 혼재 WIP는 별도로 둔다.

## #14 Oracle RDP — 남은 관측

- **배포 상태:** junghan 단일 세션 이전(gen78)과 DISPLAY 보완(gen79)은 [CHANGELOG v2026.11.13](CHANGELOG.md)에 기록했다. 79가 current이자 부트 기본값이고 booted는 아직 72다. 사용법은 [ORACLE.md §5.5](ORACLE.md#55-공유-gui-작업실--rdp-14).
- **미검증:**
  - 이 구성으로 재부팅한 적이 없다(아래 §Oracle 계획 재부팅, 보류). 다음 재부팅 때 확인할 순서: 새 세대 부팅 → xrdp 루프백 → `run.sh R` connector → junghan 로그인. 그때까지 72가 부팅 검증된 복귀 경로다. 72 퇴역은 그 뒤 별도 판단이다.
  - 지금 세션 692는 16:5x에 GLG가 RDP 터미널에서 직접 고쳤다. `dbus-update-activation-environment --systemd DISPLAY XAUTHORITY` 뒤 두 unit을 재시작했다. 그 결과:
    - `xdg-desktop-portal-gtk`가 active다(16:53:15).
    - `xfce4-notifyd` unit은 "Another notification daemon is running"으로 끝난다. 세션 스코프에서 XFCE가 직접 띄운 xfce4-notifyd(16:13)가 이미 알림 이름을 갖고 있기 때문이다. 16:13의 notifyd 실패도 같은 중복 활성화였다.
    - user manager 환경에는 DISPLAY가 들어갔다. XAUTHORITY는 세션에 없어서 건너뛰었다.
  - autostart `import-display.desktop`은 다음 XFCE 로그인부터 적용된다. 첫 활성화와의 순서 race는 미실측이다. 로그아웃 뒤 user manager에 죽은 DISPLAY가 남는 것도 미해결이다. 완전한 수정이 아니다.
  - Agent Chrome은 GLG가 16:53 무렵 다시 띄웠다(uid 1000, 127.0.0.1:9222, 프로필 `~/.local/share/agent-chrome`). 16:25에 한 번 닫힌 사이 기본 프로필 Chrome에서 한 로그인은 CDP로 공유되지 않는다. 에이전트와 함께 쓸 로그인은 Agent Chrome에서 한다. 메뉴에 "공동 Agent Chrome" 런처를 보이게 둘지는 별도 제안이다.
  - 에이전트 env(HM PATH·EDITOR)가 RDP 터미널에 실리는지 실측하지 않았다. 확인 명령: `command -v pi claude; echo "$EDITOR"`.
- **미해결:** 로그인 화면 xrdp 연결별 자식 SIGSEGV 2회(`xrdp_wm_mouse_touch`, 11-04 11:32·11:34)의 원인은 미상이다. XFCE가 junghan 세션에 `ssh-agent`와 gnome-keyring을 따로 띄운다. 기존 SSH·tmux 세션의 agent와는 별개다.
- **GUI Emacs (owner 판단):**
  - Oracle Emacs는 nox다. RDP 터미널에서 `emacsclient -s pi -t`로 기존 Doom에 붙는다.
  - GLG 시험용 로컬 런처 `~/.local/share/applications/doomemacs.desktop`가 있다. 선언 밖이고 emacs.nix doomemacs 항목을 복사한 것이다. 결과는 미확인이다. `EMACS=emacs`가 nox를 집으므로 tty 없이 종료될 수 있다.
  - GUI 빌드 안 두 가지와 위험은 doomemacs-config owner가 판단한다. 하나는 `emacs31-gtk3`을 따로 두는 것(335.8 MiB 다운로드, 1.2 GiB)이고, 다른 하나는 `pi`를 GUI 빌드로 바꾸는 것이다. GTK는 X 연결이 끊기면 복구하지 못한다(Emacs PROBLEMS:169). `server` 데몬은 어떤 안에서도 건드리지 않는다.
- **보존:**
  - `/home/browser`(uid 1990 숫자 소유)와 그 Chrome 프로필, `~/.config/oracle-rdp/browser.hash`. 퇴역은 별도 판단이다.
  - Cloudflare 쪽 Access 앱·터널·DNS. 바꿀 때는 dry-run과 승인을 거친다.
  - 비공개 영수증 `.agent-reports/issue-14-oracle-rdp/`, `.agent-reports/issue-14-junghan-rdp/`.
  - 브랜치 `issue-14-oracle-rdp`·`issue-14-junghan-rdp`. 정리는 별도 판단이다.
  - #14를 닫을지는 GLG 판단이다.
- **범위 밖:** 11-04 아침 agenda hang(호스트 Emacs `server` 데몬, 재기동으로 복구)의 최초 원인과 geworfen의 emacsclient 좀비 ~963은 geworfen 레인 몫이다. 검토 의견은 [#16 댓글](https://github.com/junghan0611/nixos-config/issues/16#issuecomment-6618346772)에 있고, GLG가 지금은 하지 않기로 했다.

## Oracle 계획 재부팅 — 보류 (11-04 읽기 전용 사전점검까지)

- **상태:** 11-04 14:43–14:50 KST에 [`oracle-reboot`](.claude/skills/oracle-reboot/SKILL.md) §1·§3의 읽기 전용 사전점검만 했다. 실제 재부팅·suspend·추가 삭제는 0이고, GLG가 다음으로 미뤘다. 재부팅 승인과 시간창은 아직 없다. 당시 current와 부트 기본값은 gen77(main `0b927ab`), booted는 gen72였고, 세대 링크와 부트 엔트리는 72·77 두 개다. 77은 아직 부팅해 보지 않았다.
- **측정 요점:** 72·77은 같은 kernel·initrd·params를 쓰고 `/boot`에 그 파일이 있다. 구성 전체가 같다는 뜻은 아니다. `systemctl reboot`가 sudo NOPASSWD임은 조회로만 확인했다. SSH(공개키 전용)와 tailscale은 enabled, 공개면은 기대값과 일치, OpenClaw 10.9 RPC health는 ok, 운영 중지 provider·heartbeat도 그대로다. **OCI 콘솔 접근 준비는 확인하지 않았다.** 부팅 메뉴에서 72를 고르려면 콘솔이 필요하다. 콘솔이 없으면 77로 부팅한 뒤 SSH에서 store-path로 돌아간다([ORACLE.md §5.5](ORACLE.md#55-공유-gui-작업실--rdp-14)).
- **재부팅하면 사라지는 것:** RAM에 있는 XFCE·Chrome 창, 그리고 모든 tmux 하네스 세션(자동 재개 없음). Chrome 프로필은 디스크에 남는다.
- **수동 복구 주체:**
  - agenda용 Emacs `server`: geworfen 정본 `~/repos/gh/geworfen/ops/tmux/agent-emacs.sh start`.
  - RDP: Oracle에서 `run.sh` → R → 1(3시간). GUI 세션은 GLG가 처음 로그인할 때 생긴다.
  - sorge: 소유 리포 정본대로 수동 재개(`./run.sh inbox`). connector를 직접 띄우는 명령은 정본에서 확인하지 못했으므로 sorge 담당 몫이다.
  - Docker·translation-server·sshd·tailscaled·xrdp는 enabled다. 그래도 실제로 복귀했는지는 재접속 뒤 스킬 §5로 따로 확인한다.
- **GC 정정:** 설치된 Nix 2.34.8 매뉴얼에 따르면 `--delete-older-than 30d`는 cutoff보다 오래된 세대 중 가장 최근 것 하나를 남긴다. 지금 세대는 72·77뿐이라 주간 GC가 72를 곧바로 지우지 않는다. 그러므로 날짜 때문에 재부팅을 서두를 이유는 없다(앞선 권고는 철회). 새 세대가 생기거나 시간이 지나면 다시 잰다.
- **다음 한 수:**
  1. 스킬과 아래 영수증을 읽는다.
  2. live preflight·접근·수동 복구 주체를 다시 확정한다.
  3. GLG의 실행 승인과 시간창을 받는다.
  4. 직전에 새 영수증 디렉터리·boot-id·실제 RPC 유휴 TTL 게이트를 거친 뒤, 같은 셸에서 reboot한다.

  이번 응답이나 hold를 재사용하지 않으며, 지금 `gateway.suspend.prepare`를 하지 않는다. RDP connector는 시간이 지나면 끝나 있을 수 있으니 상태를 가정하지 말고 `run.sh R` → 2로 확인한다. 72 삭제 승인은 없다. 77 부팅을 검증한 뒤 따로 판단한다.
- **영수증:** Oracle 로컬 비공개 `.agent-reports/oracle-maintenance/20261104T144353.YJyNRd/` — boot-id·부트·접근·복구 주체·OpenClaw·공개면·storage-review·추가 읽기.

## SSH — 타 기기 검토

- laptop도 공통 SSH 비밀번호 인증 설정을 상속하는지와 외부 노출/접속 요구를 별도 확인한다. 이번 차단은 thinkpad만이며 네트워크 장비의 포트 전달·출발지 제한은 변경하지 않았다.

## ChatGPT Linux 프리뷰 — 다음 버전업 때 확인

- 현재 운영 경계는 [README](README.md#desktop-and-development)로 승격했다. 패키지는 literal rev 고정이라 일반 `nix flake update`/switch만으로 오르지 않는다. `nixpkgs-ghostty` rev를 옮길 때 Ghostty도 함께 검수하고, stable이 Linux 패키지를 지원하면 예외 회수를 검토한다.
- **공유 상태:** 기존 CLI에 문제가 생기면 앱과 공유하는 `~/.codex`의 설정/상태 변화부터 확인한다. 분리나 인증 변경은 별도 판단이며, DB를 직접 수선하지 않는다.
- **캐시 수명(미측정):** 패키지의 `share/user-tmpfiles.d/chatgpt.conf`가 HM 프로필 경로에서 `systemd-tmpfiles --user`에 잡히는지 확인하지 않았다. 안 잡히면 버전마다 `~/.cache/chatgpt/bundled-plugins-v2/<옛 키>`가 남는다. 자동 삭제로 넓히지 않고 버전업 때 확인한다.

## Ghostty — 타 기기 반영 시 참고

- thinkpad 1.4.0 switch·기존 설정 검증은 완료했고 GLG가 사용 결과를 수용했다(2026-10-31). 설정·바인딩은 그대로다. laptop/nuc는 선언만 바뀌었으므로 해당 기기에서 필요할 때 별도로 rebuild한다. 원격 적용은 하지 않았다.
- stable이1.4 이상을 제공하면 전용 input/overlay 회수를 검토한다. `ghostty +ssh` 실연결은 아직 하지 않았고 서버 terminfo 쓰기는 별도 판단이다.

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
- **Do not touch:** `plugins.entries.codex.enabled:false`·`acp.enabled=false` 유지. acpx는 설치하지 않는다(2026-11-17 제거). 복사 상태 실행은 `--network none`. `gateway.trustedProxies`의 `172.26.0.1/32` 유지. Active Memory·dreaming 켜지 않음. 안드로이드 페어링 삭제로 scope 고치기 금지. entwurf `.assembled` 마운트・tmux 소켓 마운트 금지. bbot heartbeat `{every:"0m"}` 유지(cadence는 cron 소유).

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

- **대상:** `~/repos/gh/session`(기기 통합 세션 코퍼스). 11-15 laptop 실측: 12 GiB·파일 7,066개, git-annex(SHA256E) 리포, origin `thinkpad`, 커밋 서명 없음. hot/cold 배치·비공개 annex 경계 설계.
- **콜드 목적지 준비됨(11-15):** Google Drive `gdrive:` — 설정·실측·새 기기 절차는 [data-retirement §11](docs/data-retirement.md#11-콜드-저장소--google-driverclone). laptop·oracle 인증 완료, oracle은 11-15 rebuild(system-80)로 선언 반영(`rclone v1.74.4`). agent-config 745332에 정본 경로와 사실을 전달했다(11-15, 담당 지정 아님).
- **로드맵(GLG 11-15): 데이터부터 넣고 단계적으로.** ① 이관 담당 정하기(agent-config 후보) → nixos-config는 기반 기술을 세팅하고 그 담당이 쓸 **스킬**을 같이 만든다 ② 첫 이관(도구 미정: rclone 직접 / git-annex special remote — `git-annex-remote-rclone` nixpkgs 판은 낡아 별도 설치 필요할 수 있음) ③ 무결성·신뢰: annex SHA256 + checkpoint 커밋 GPG 서명 + 히스토리 외부 증인 ④ 암호화(annex `encryption=` 또는 rclone crypt). 암호화는 저장소 변조 탐지·기밀성일 뿐 "누가 말했나"를 보장하지 않는다 — 그 축은 ③.
- [ ] laptop syncthing password-store 사본(`~/sync/emacs/password-store`, `.gpg-id`·`.git` 깨짐) 거취 — 이제 정본 아님, 정리 여부 GLG 판단.
- **먼저 결정:** Oracle 잔류 범위, 목적지와 가용량, 로컬 drop 뒤 독립 사본 수, 무결성/복원 증거, 평시/피크 예산. 회사 계정 저장소를 유일 보관처로 삼지 않는다.
- **소유자 계약:** Andenken·agent-config의 `MANIFEST.json`/SHA256·append-only·gather/replicate·reader 경로 유지 방법을 검토. 이번엔 배치·계약·검증 계획까지만, 시험 복사·원본 이동/drop은 각각 별도 승인.

# 이월 판단 대기 — 옛 항목 중 닫힌 근거가 없는 것

원문 맥락은 `git show 07849d5:NEXT.md`의 해당 절. 착수 전에 현재 10.7·현 호스트에서 여전히 사실인지부터 다시 잰다.

**압축 때 개별 재판정하지 않은 옛 절**(미체크 항목이 남아 있었음 — 닫힘 근거 아님): §4 8B 4096d 검색 품질 검증(native 검색 전제의 구 scope — 현행 적용성 미확인, [#5](https://github.com/junghan0611/nixos-config/issues/5)(→#13 흡수) 재정의 이후 그대로 재개하지 않음) · §5 HA 데이터 import(lifetract 배턴) · §oracle `/home` 회수 근본 · §ACP 잔재 청소 · §AGENTS.md/gotchas.md로 옮길 자리. 이 줄은 그 절들을 다시 읽어 지우거나 한 줄로 승격할 때 함께 정리한다.

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
- [[#13](https://github.com/junghan0611/nixos-config/issues/13)(#5 흡수) 검토 상자로 이관, 미검증] `memory.search.sources=["sessions"]` 축소 결정(대가: MEMORY/USER가 의미 검색에서 빠짐) · FTS-only 한 봇 시험 · `memory_embedding_cache` orphan+VACUUM(~600MB 추정, 정지 창 필요) · 정기 `memory index` 승격. (§기억축)
- glg 가족봇 Sonnet 5 soak — 감정 있는 실제 턴에서 대칭 규칙 유지 여부·역할 낭독 반복·compact 요약의 법적 프레임 잔존 관찰. (§glg 가족봇)
- thinking 판단: claude-cli 봇은 thinkingLevel이 안 물린다는 기록(`extensions/anthropic/cli-backend.ts`, 10.7 재확인 전) · bbot 세션 `think:xhigh` 정식화/하향 · gpt `thinkingDefault=medium` 인상 관찰 · luna/terra lane 품질 soak. (§glg 가족봇·§7.1 잔여)
- `run.sh t)` SSH 터널 은퇴 여부(trustedProxies 변경 뒤 403). (§앱 후속)
- telegram stop-timeout 데드락 — 업그레이드마다 상류 수정 확인, gotchas 미기록. (§2 버전 hop)
- 스킬 심볼릭 전면 전환 설계(device 이식성·`extraDirs` vs 심볼릭·pi-skills 화이트리스트) · gogcli SKILL.md 내용 분기. (§스킬 심볼릭)
- 컨테이너 cron이 호스트 시민을 깨울 수 있는가 — 지금 재지 않음. (§시계)
- OpenClaw 세션을 andenken 코퍼스에 편입·크로스에이전트 기억 일원화 — 수확 축(`semantic-memory` `search-openclaw`, 재임베딩 없는 harvest)으로 이미 서 있다. 남은 계약 재검토는 [#13](https://github.com/junghan0611/nixos-config/issues/13)(#5 흡수). (§기억망)
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
