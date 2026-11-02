# #14 — Oracle 단일 XFCE·Chrome / Cloudflare RDP 검증

브랜치 `issue-14-oracle-rdp`, 시작점 `55a7db1eb207ed350442f0bd99c3fde95465cd99`.
정본 [#14](https://github.com/junghan0611/nixos-config/issues/14), [GUI 소스 검토](https://github.com/junghan0611/nixos-config/issues/14#issuecomment-6565962793), [Cloudflare 현황·권고](https://github.com/junghan0611/nixos-config/issues/14#issuecomment-6566122474).
main의 깨움 설계(#13)와 별개 검증 레인이다. main 병합 전 이 branch NEXT를 삭제하고 결과·남은 경계를 이슈/운영 문서에 승격한다.

# RAIL — 현재 좌표

- [x] **1. 목적·선례·현황 조사** — 기본 XFCE/GUI·프로필 각1개, CF 우선. 소스 검토와 계정 읽기 보고만 있으며 실제 경로는 미검증.
- [x] **2. 기준선·최소 선언·오프라인 평가** — #10837 기준선과 #10883 후보/다른3기기 범위/assertion/lock 검사 통과. 생성 파일과 실제 동작은 미검증.
- [x] **3. 빌드와 적용/복귀 계획** — r2(browser 전용 primary group)·r3(browser 한정 Chrome autostart/profile) 평가 PASS, 제한 빌드 exit0, 생성물 검수 기대값 일치, 타3기기 toplevel drvPath 시작점과 동일. 영수증 `build-r2-inspect.md`·`scope-drv.log`. CF connector는 미작성.
- [ ] **4. 실제 GUI·Cloudflare 경로 검증** ← **ON HOLD (11-02 16:03 GLG):** CF 앞단 4a·4b PASS, 4c 새 후보 r4(hashedPasswordFile) 코드 검증 완료·커밋. 실환경 적용은 entwurf 릴리즈 보호를 위해 GLG 보류.
- [ ] **5. 연결 단절·재접속·복구·정리** ← PAUSED: 4 성공과 단계별 실행 범위 승인 뒤. 부트/재부팅·퇴역·공개 발행은 자동 포함하지 않음.

현재 좌표: 1–3 완료, 4a·4b PASS, r4 코드 검증 완료 → **GLG 보류**("entwurf 릴리즈 작업이 중요해서 함부로 시스템을 건들기가 위험하다… 저쪽 다 릴리즈하면 하자", 코디 경유). 실무 소유: Opus2 `20261028T083538-8216f4`(10:09 GLG 지시, 코디 경유).

# NOW

- **보류 중 상태(11-02 16:04):** Oracle은 gen72 그대로(서비스·계정 미적용, xrdp·browser 없음). CF 리소스 3개(Access 앱·터널·DNS)는 존재하나 connector 없음 → RDP 경로 닫힘. R4 외부 TCP 왕복 PASS, 실제 RDP·PAM·GUI는 미검증. 아래 승인 묶음(커밋 뒤 switch → post 게이트 → connector 60분 → GLG RDP)은 **지금 실행 보류**. 기다리는 동안 게이트·평가·시스템 조작도 하지 않는다.
- **재개 조건:** GLG가 entwurf 릴리즈 완료와 재개를 직접 지시한 뒤에만. 재개 첫 수는 재확인 — `switch-gate.sh pre`(해시 파일·current/profile gen72 하나뿐·3389/9222 없음·lock·Mem≥6·OpenClaw healthy·eval toplevel = r4 `640x7wiy…`, GC됐으면 재빌드 후 동일성 확인). 그 뒤 switch는 별도 명시 승인.

- **r4 후보 checkpoint(11-02 13:40–13:47, 미커밋):** ① **GLG 직접 보고**(코디 경유, 13:40): Oracle에서 해시 생성 명령 실행 "했다". ② **Opus2 실측** `check-hash.sh` 10항목 PASS(mtime 13:39:45, 74B; 내용 미출력, 영수증 `check-hash.log`) ③ 소스: `xrdp.nix` browser에 `hashedPasswordFile = "/home/junghan/.config/oracle-rdp/browser.hash";` + 주석(최초 생성만 반영·missing=잠김·empty=무암호). check-eval 계약 갱신(경로 정확 일치·store 경로 아님·mutableUsers=true 유지, 다른 암호 옵션 null) → offline eval PASS, `scope-drv` 3기기 drvPath = 55a7db1 동일. ④ plan: 새 drv 4개뿐(users-groups.json·activate·dry-activate·toplevel), 게이트 통과 제한 빌드 exit0 2초 → toplevel **r4 `640x7wiy…`**(GC root 없음). r3→r4 diff-closures 비어 있음. users-groups.json의 browser는 hashedPasswordFile=위 경로, hashedPassword/initial*/password null. 해시 바이트는 users-groups.json·activate·closure 파일·dry 로그 어디에도 0, 이름에 browser.hash인 store 경로 0. ⑤ dry-activate 1회(13:46:45–57, exit0): 출력 toplevel=r4, **'password file … does not exist' 경고 없음**, 예정 변화는 r3와 동일(reload dbus-broker / restart home-manager-junghan·polkit·systemd-udevd / revive xrdp 995·993). 뒤에도 current=gen72, xrdp not-found, 3389/9222 0, browser 부재, OpenClaw healthy restarts=2.
- **Next (r4 이후):** 커밋 승인 → switch 승인(최종 후보 r4·복귀 `switch --rollback`→gen72 재확인) → 적용 직후 3389 루프백만·9222 없음·sesman --config 대조·OpenClaw 확인 → 실제 RDP에는 connector 재기동/상주 선언 별도 승인.
- **(완료된 순서 기록) Next (GLG 복귀 뒤):** ① GLG가 Oracle 자기 터미널에서 `install -d -m 700 ~/.config/oracle-rdp && (umask 077; mkpasswd -m yescrypt > ~/.config/oracle-rdp/browser.hash)` — 평문·해시는 대화/argv/로그로 받지 않는다 ② Opus2가 `check-hash.sh` 실행(pass/fail 메타만) ③ 승인 시 `xrdp.nix` browser에 `hashedPasswordFile = "<절대 문자열 경로>";` 한 줄 + 주석 정정 → eval PASS·`scope-drv.sh` 3기기 동일·toplevel 재확인·원파일 비참조 → 커밋 ④ dry-activate에서 'does not exist' 경고 0 ⑤ switch 승인 ⑥ 실제 RDP 시험에는 connector 재기동/선언 별도 승인. **커밋 `0329e6b` 후보 그대로 switch 금지.**
- **CF 앞단(11-02 12:04–12:06, GLG 승인 W1–W3·R, Opus2 실행):** W1 Access self-hosted 앱 `oracle-rdp`(기존 IdP·GLG 메일 1개 Allow·세션 24h) → W2 locally-managed 터널 `oracle-rdp`(API 생성, secret 로컬 생성, credential `~/.cloudflared/oracle-rdp.json` 0600, secret 사본 삭제) → W3 proxied CNAME(RDP 전용 hostname, 값은 비공개 영수증)→새 터널. 각 rc0 + readback, 기존 aions/sorge 터널·lab 앱·Worker·DNS 불변. 새 ID는 비공개 `cf/run/new-ids.json`에만. R2 임시 connector tmux `issue14-cf-connector`(timeout 3600, ~13:05 자동 종료, 4 연결 등록). **R3 통과(12:05:24):** HTTP·WS·가짜 토큰 모두 302→팀 Access 로그인, 101/200·nonce·origin 도달 0. R1 fixture tmux `issue14-cf-fixture`(127.0.0.1:3389, nonce8 `89cdb9e9`, 만료 12:25:31 예정 → R4 뒤 12:13:56 조기 종료).
- **R4 PASS(12:11–12:13, GLG 사용자 실측 · 코디 경유 전달):** GLG ThinkPad에서 Access approve 확인. `nc -N` 2회: 1회 무출력, 2회 greeting 한 줄만(`ECHO` 없음). 이어 python `create_connection→recv→sendall(b'hi\n')→recv` 1회 출력 두 줄 `ISSUE14-FIXTURE 89cdb9e9…` / `ECHO hi`. 받은 nonce 32hex는 비공개 `cf/nonce.txt`와 정확 일치(Opus2 grep). 백엔드는 연결별 기록이 없어 hi 수신을 독립 확인하지 못함(fixture 설계 한계, connector INFO에 stream 줄 0). 같은 `nc -N`의 직접 loopback 자기검증(12:05:37)은 echo 정상 → CF 경유 `nc -N` echo 누락은 half-close 가설(미측정, 제품 결함 확정 아님). **증명 범위: Access 인증 + CF 경유 외부 TCP 양방향.** RDP·PAM·GUI·재접속 연속성은 미검증.
- **정리(12:13:56):** fixture 자기 PID만 TERM(exit=143, 만료 12:25:31 전 조기 종료라 served 카운트 없음) → 3389 LISTEN/ESTAB 0. connector는 상한대로 13:05:02 timeout 종료(exit=124, tmux 소멸 13:05:09). ERR 18줄은 모두 13:05:02 종료 시각의 연결 해제 로그이고 실행 중 ERR은 0. 남은 cloudflared는 기존 aions·sorge 2개뿐, 3389 LISTEN 0. 연장·재기동 없음 — 지금 RDP 경로에는 connector가 없다. CF 생성물 3개는 유지(삭제는 별도 dry-run/승인).
- **switch 전 미결(12:14 실측):** junghan sudo는 NOPASSWD 7개 명령뿐(`sudo -n -l`) — `sudo passwd browser` 경로 없음. `users.mutableUsers=true`, browser 암호 옵션 전부 null. 암호 설정 방식을 정하기 전 switch하면 xrdp는 뜨지만 RDP 로그인 불가. 권한 우회(systemctl 경유 등)는 하지 않는다. **권고 (b) `hashedPasswordFile`(12:20 소스 검토, 미적용):** perl update-users-groups·mutable=true에서는 shadow에 없는 신규 사용자에게만 반영된다(`update-users-groups.pl:241-247,293-315`). browser는 아직 없음(실측)이므로 **첫 switch 전에 파일이 있어야** 한다. 파일 없음=잠김(이후 파일로는 반영 불가), 빈 파일=무암호 — 둘 다 안전한 실패가 아니다. 사후 암호 변경·사용자 삭제/재생성·mutableUsers 변경은 이번 승인 밖(다른 복구 경로 부재를 확정한 것은 아님). 게이트: `.agent-reports/issue-14-oracle-rdp/check-hash.sh`(pass/fail 메타만 출력 — 존재·일반파일·비어있지 않음·junghan 600·디렉터리 700·정확히 1줄·공백 없음·yescrypt 요소 모양·browser 부재; 더미 good/empty/multi/plain/missing 자기시험 통과) + 후보 eval의 원파일 비참조 + dry-activate 'does not exist' 경고 0. missing/empty/여러 줄이면 switch 금지. 절대 문자열 경로(store·Git 유입 없음), GLG 직접 `mkpasswd -m yescrypt`(5.6.6 기존). **현 커밋 후보 그대로 switch 금지.** connector ~13:05 만료 뒤 연장·재기동 없음 — 실제 RDP 시험 전 별도 승인.

- **(대체됨) 이전 Next:** ④는 12:14 sudo 실측으로 폐기 → 위 hashedPasswordFile 경로. 나머지 원문 — 실환경 직전 정지. GLG 승인에 필요한 것 — ① MemAvailable 하한·새 OOM 시 정지/복귀 범위 ② 사전 존재 drift(gen72 2026-09-30 이후 HM: git-annex 등) 동반 적용 수용 여부 ③ `switch-to-configuration test` 1회와 복귀 명령 ④ browser 암호 설정 방식(GLG 직접 `passwd`) ⑤ Oracle 안 전역/user unit 부수효과(junghan 포함) 수용. 후보 toplevel r3 `0lq3ggs1…`(GC root 없음 — 적용 전 재빌드/재확인). CF connector·credential은 미작성 후속이며 별도 승인.
- **순서 변경(11-02 11:34 GLG):** Cloudflare 경로를 먼저 만들고 전송 고리를 검수한 뒤 Oracle `switch`로 들어간다. 승인 묶음은 `.agent-reports/issue-14-oracle-rdp/CF-APPROVAL-BUNDLE.md`(비공개). 구성: W1 Access 앱+GLG Allow → W2 locally-managed 터널(API 생성, secret은 로컬에서 만듦, cert 반입 없음) → W3 DNS CNAME. 이어 R: 루프백 3389 일회성 nonce fixture(최대 20분) + 임시 connector(최대 60분) → 미인증 거절 → GLG ThinkPad `cloudflared access rdp` 왕복. 그다음 S: `switch`(gen73, boot 기본 변경). 복귀는 `switch --rollback`(→gen72, NOPASSWD). 11:40 기준 dry-run 3건 exit0, CF 쓰기·fixture·connector·switch 0. fixture 왕복은 RDP·PAM·세션 성공의 근거가 아니다.
- **dry-activate 완료(11-02 11:24, 커밋 `0329e6b`, GLG 승인 1회):** exit0, 출력 toplevel = r3 `0lq3ggs1…`. 재시작 예정: home-manager-junghan·polkit·systemd-udevd. reload 예정: dbus-broker. 사용자: xrdp UID995/GID993 **revive**(과거 XRDP 시절 `/var/lib/nixos` 기록). docker·OpenClaw·sshd·tailscaled는 목록에 없음. 실행 뒤에도 current·profile=gen72, xrdp 유닛 not-found, 3389/9222 리슨 없음, OpenClaw healthy(restarts 2) 그대로. 새 유닛(xrdp·sesman·accounts-daemon·colord·udisks2)은 "would start"로 출력되지 않았다(활성화 때 target이 끌어올릴 것으로 추론, 미확인). browser·tsusers 생성 줄도 dry 출력에 없다(평가상 생성 대상). 다음은 GLG가 자리에 있을 때의 `test` 승인 — `APPROVAL-BUNDLE.md` 2단계.
- **승인 묶음(한 장):** `.agent-reports/issue-14-oracle-rdp/APPROVAL-BUNDLE.md` — 가장 작은 다음 명령은 `sudo nixos-rebuild dry-activate --flake .#oracle`(상태 변경 없음). 복귀는 GLG의 `sudo /nix/var/nix/profiles/system/bin/switch-to-configuration test`(gen72). (12:14 정정: profiles에 system-72-link 하나뿐 — gen71 전제는 현재 실측과 맞지 않음. switch 뒤 복귀는 `switch --rollback`→gen72, 직전 세대 pin을 적용 직전 재확인. `test --rollback`은 계속 쓰지 않는다.) 자원 하한 6GiB는 제안이며 미승인.
- **확정 방향(11-02 GLG):** Oracle만, browser 전용 사용자1·전용 group·GUI 세션1·지속 profile1. browser에 sudo/wheel/docker 0, 기존 sudoers 변경 0.
- **선택 감량(측정 뒤 결정):** tumbler→webkitgtk 177MiB, xfce4-settings→xapp→MATE ~130MiB, colord→sane 20MiB, xdg-desktop-portal→flatpak 11MiB. 지금 끄지 않는다.
- **Oracle-only 불변식:** nuc/laptop/thinkpad(이미 i3 사용)의 i3·패키지·서비스·사용자·브라우저/자동시작 변경 0. 소스를 바꿀 때마다 `scope-drv.sh`로 세 기기의 toplevel drvPath를 시작점 55a7db1과 대조해 동일해야 한다(배포 세대 동일성 주장은 아님).
- **Verify:** Oracle에만 적용, i3/LightDM·콘솔 display-manager 미기동, 기본 XFCE, GUI 사용자/세션/지속 Chrome 프로필 각1개. root·운영자·GUI 사용자 외 계정 및 무암호 로그인은 거절한다. sandbox·기본 키링·단절 후 세션을 유지한다. 현재 후보의 결속 기대값은 **127.0.0.1:3389만**이다(ExecStart 명시 override). broad listen+방화벽을 동등한 합격으로 대체하지 않는다. lock·다른3프로필·기존 봇/웹/터널도 확인한다.
- **권한:** GLG의 11-02 직접 요청으로 브랜치와 단계별 검증을 시작한다. 로컬 선언 작성·평가·제한된 빌드 검토와 실제 시스템 적용/계정·인증 변경·CF 쓰기는 다른 게이트다. CF 쓰기는 scoped-token dry-run → 정확한 변경 제시 → 명시 승인 →1회 실행. commit은 GLG 요청마다 1회(0329e6b, 12:30 인계 커밋). push/merge/tag/agenda 승인은 없다.
- **Read:** `AGENTS.md`, `ORACLE.md`, `cloudflare` 스킬, #14 본문/최신 스레드, 현재 pin의 upstream XRDP/XFCE/Cloudflared 모듈. 회사 선례는 읽기 전용이며 코드·비공개 설정·자격증명을 복사하지 않는다.
- **Do not touch:** OpenClaw·Caddy·기존 Access 실험 앱/Worker/DO/서비스 토큰·aions/sorge 터널. 기존 홈/브라우저 profile 복제·Singleton 삭제·새 로그인·CDP9222 외부 공개·`--no-sandbox`·키링 보안 축소·권한 우회·GC/prune·재부팅을 실행하지 않는다.

# 검증 계약 — 예상과 관측을 구분

## 목적과 기본안

- 사람용 i3 환경이나 ChatGPT 앱 구축이 아니라 에이전트가 이어 쓰는 GUI 브라우저가 목적이다. 기본 XFCE와 비특권 GUI 사용자1명을 기준 후보로 두며, 실제 계정 생성/암호 설정은 적용 게이트에서 결정한다.
- 기본 경로 후보: native RDP → client cloudflared + Access → RDP 전용 Tunnel → Oracle XRDP → 같은 XFCE/Chrome. 클라이언트의 cloudflared가 로컬 RDP 포워더를 제공하며 native RDP가 CF hostname:3389에 직접 붙는 방식이 아니다.
- RDP connector는 NixOS 상류 host-side 서비스 후보이며 origin은 `rdp://127.0.0.1:3389`로 명시한다. 기존 조직/IdP를 활용하되 RDP용 앱·정책·hostname·터널만 추가한다. 기존 웹/실험/웹훅 자산은 재사용 명목으로 변경하지 않는다. connector의 상주/필요 시 기동 방식은 적용 전 확정한다.
- CF 브라우저 RDP는 현행 공식 문서가 Windows 서버를 전제로 하므로 Linux XRDP 지원을 확정하지 않는다. WARP/private routing은 등록·경로·Gateway 권한·기존 Tailscale/DNS 영향이 별도인 후보다. 브라우저-only를 위해 VNC/Guacamole 계층부터 추가하지 않는다.
- agent가 host인지 OpenClaw Docker 안인지 명시한다. host Chrome CDP의 loopback은 container localhost와 다르다. 이 연결은 RDP Zero Trust 접근과 별도 계약이며 자동으로 포트/권한을 확대하지 않는다.

## 단계별 합격 근거

1. **평가:** pin 고정, 생성 startwm/sesman.ini/XRDP ExecStart/서비스 그래프·PAM·사용자 그룹을 확인한다. 과거 i3/Xvnc 치환을 되살리지 않는다. xserverbpp 정규화를 사용할 경우 실제 Xorg depth 및 매칭 bpp를 분리한다. browser의 primary group도 운영 계정의 users 그룹과 분리해 재평가한다.
2. **빌드:** dry-run 차이·다운로드·closure·저장 공간·로컬 빌드 범위를 판독한 뒤 제한된 빌드를 수행한다. 생성 ini는 [Xorg] 섹션1개/그 안 bpp1개, 생성 unit은 ExecStart1개인지 확인한다. XFCE의 전역 pinentry/VTE/PAM·desktop 서비스 부수효과도 대조한다. 빌드 성공은 활성화나 GUI 로그인 성공이 아니다. ExecStart override는 nixpkgs 업데이트 때 상류와 다시 대조한다.
3. **적용 승인:** 대상 세대·서비스/계정/인증·포트·CF 생성물·클라이언트 작업·복귀 명령을 제시한다. 적용 직전 기존 서비스·유휴 조건·자원을 재확인하고 boot 기본 변경과 test를 구분한다. **MemAvailable 하한과 새 OOM 발생 시 정지/복귀 범위를 GLG와 합의하기 전에는 적용하지 않는다.** CF credentials는 Git 밖의 런타임 경로 문자열을 사용하며 store에 복사되는 Nix path 리터럴을 쓰지 않는다. 평가에서 credential 참조가 store 경로면 중단한다. 반입 경로·권한도 승인 범위에 포함한다.
4. **로컬 GUI:** 활성화 직후 **암호 설정/로그인 전에** 3389의 루프백 결속과 public/tailnet/bridge 우회 차단부터 확인한다. 중단 조건을 만나면 자신의 변경만 사전 승인된 절차로 되돌린다. iptables 정적 판독과 실제 접속 거절을 구분하고 OpenClaw 컨테이너에서 probe하지 않는다. 최초 인증서 SHA256 지문을 기록·대조하며 무조건 수락하지 않는다. 이어 승인된 GUI 사용자로 최초 세션 생성(sesrun 후보) → Chrome/sandbox/profile/CDP를 확인한다. browser-start.js/Singleton 삭제는 금지하며 attach와 별도 탭을 쓴다. RDP 암호는 argv나 로그로 전달하지 않는다.
5. **CF 보호/설정 반영:** Access 앱과 Allow 정책을 먼저 확인하고 hostname을 공개한다. 미인증·비허용 신원·다른 OS 계정의 거절과 정상 로그인을 분리한다. sesman은 restartIfChanged=false이므로 각 test 후 실행 중인 --config와 생성 유닛을 대조한다. 구 설정이면 성공으로 처리하지 않고 재시작/기존 세션 영향에 대한 별도 승인으로 돌아간다.
6. **연속성:** 연결 → 같은 display/Chrome PID/profile/탭 확인 → CF 전송 종료 → 재인증/재접속 → 동일 세션을 확인한다. 해상도/클라이언트 bpp가 달라도 정규화된 요청으로 동일 세션에 붙는 경로와, 실제 매칭 조건 불일치에서 상한으로 거절되는 경로를 나눈다. 무인 브라우저 사용에 RDP client 상시 연결이 필요한지도 확인한다.
7. **복구/자원:** Chrome 실패·sesman 재시작·로그아웃·재부팅은 각각 별도 조건이며 승인된 것만 시험한다. 재부팅 후 동일 PID/메모리는 보장하지 않고 profile 복원 범위를 확인한다. Xorg/XFCE/Chrome/connector RSS와 기존 서비스 영향을 기록한다. 합의한 자원 하한/새 OOM을 만나면 사전 승인된 GUI 정지·복귀 범위만 실행하며 임의로 다른 프로세스를 종료하지 않는다. 이전 세대로 돌아가도 홈/인증서/세션 등이 자동 삭제된다고 가정하지 않는다.

# RECENT — 읽은 것 / 아직 아닌 것

- 11-02 GLG는 이번 Cloudflare RDP 방식을 직접 사용해 본 적이 없으므로 브랜치에서 단계별 검증하도록 요청했다. 소스상 가능성과 실제 성공을 혼동하지 않는다.
- 오푸스의09:18 scoped-token 읽기 보고: 기존 Zero Trust 조직/IdP/실험 앱과 locally-managed 터널들이 존재, 일부 Targets/WARP/Gateway 읽기는403/10000. 기존 리소스의 IDs·메일·credentials는 이 파일에 넣지 않는다. Workers 월$5는 GLG 직접 보고, 청구 검증 아님.
- 주체: 코디 garden `20261008T152203-145c2f`, 공동검토 형제 `20261028T083538-8216f4`. 형제 보고는 자기보고/그의 측정이며 코디 독립 측정과 구분한다. 기존 형제를 임의로 퇴근시키거나 새 형제를 만들지 않는다.
- 기준선 직접 관측(`baseline.json`): xrdp/xrdp-sesman/display-manager는 not-found/inactive, 3389/9222 리슨 없음, OpenClaw running/healthy/RestartCount2. 현재·booted 세대/lock SHA/자원도 보존했다. 변경 전·후보 선언 평가 모두 통과(`eval-baseline.log`, `eval-candidate.log`): 후보 XRDP/XFCE만true, Xserver/LightDM/CF서비스false, loopback ExecStart, 무암호false, browser 그룹tsusers만/암호선언없음, failedAssertions=[], 다른3기기XRDPfalse, lock 동일. 이는 생성 설정 빌드나 실제 로그인 성공이 아니다. 실제 GUI/RDP/브라우저 실행·시스템 활성화·CF 쓰기·계정 생성은0.
- 11-02 10:10–10:16 Opus2 r2(`build-r2-inspect.md`): primary group 추가 후 평가 PASS. 실행 중 시스템은 gen72(09-30)이고 시작점 55a7db1과 다르다 — 시작점 단독 dry-run은 HM 10개 재빌드 + git-annex fetch(drift, 20826ea). 후보 제한 빌드 10:12–10:14 exit0, store +1.60GiB, closure +1215MiB(Chrome 424). 생성 xrdp.ini [Xorg]1/xserverbpp=32 1, sesman Max1/Root false/GroupCheck true/KillDisconnected false, PAM auth nullok 0, xrdp ExecStart 1개 `tcp://127.0.0.1:3389`, browser group=browser·암호필드 전무. 전역: 새 system unit xrdp·sesman·accounts-daemon·colord·udisks2, pam login+gnome_keyring, bashrc+vte.sh, 모든 사용자 user unit+gcr-ssh-agent/portal/gvfs(전역 SSH_AUTH_SOCK export 없음). docker·sshd·tailscaled·nix-daemon·firewall unit 불변. dry-activate는 sudo가 필요해 미실행.
- 11-02 10:18–10:29 Opus2 r3: browser 전용 autostart를 tmpfiles 3줄(`~browser/.config`·`autostart` 0700 browser, `L+ agent-chrome.desktop`)로 선언. 전역 xdg/autostart·HM 사용자·새 서비스 없음. Exec는 `--user-data-dir=/home/browser/.local/share/agent-chrome --remote-debugging-port=9222 --no-first-run --no-default-browser-check`(sandbox·키링 기본, CDP 결속은 Chrome 기본 루프백 — 실행 전 미확인). 평가 PASS, 9 drv/0 fetch, 빌드 exit0(7초), xrdp 생성물 r2와 동일. 타3기기 toplevel drvPath는 55a7db1과 동일(`scope-drv.log`).

# 영수증 관리

- 로컬 전용 `.agent-reports/issue-14-oracle-rdp/`에 명령·exit·시각·baseline/candidate·측정 한계를 기록한다. Git ignore 확인, 디렉터리0700/파일0600. API 원응답/계정 식별자/credential은 공개 파일에 복사하지 않는다.
- 인계에는 다른 기기에서도 읽을 수 있는 결정적 비민감 근거를 #14에 붙이고 상세 호스트 영수증은 보조로 둔다. 임시 자료는 생성자가 종료/보존/정리까지 책임진다.
