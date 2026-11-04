# NEXT — issue-14-junghan-rdp

> 브랜치 레인. #14 RDP 작업실을 별도 계정 `browser`(uid 1990)에서 GLG 본인 계정 `junghan` 단일 세션으로 옮긴다. main에 머지하기 전에 이 파일을 지운다.

## RAIL

1. ✅ 소스 준비 (`users/junghan/xrdp.nix`, ORACLE.md §5.5, AGENTS.md 행, 클라이언트 안내·테스트)
2. ✅ eval: nuc·laptop·thinkpad drv가 main 143a80b와 같다. Oracle은 dirty 트리로 build와 dry-activate만 했다.
3. ✅ GLG가 전환을 승인했다(11-04 15:56, 코디 경유: 브랜치 commit·깨끗한 후보·switch). push·머지·tag는 승인 밖이다.
4. ⏳ **지금 여기** — 깨끗한 커밋에서 다시 build + dry-activate, 그리고 GLG 로그아웃을 기다린다.
5. GLG가 browser 세션에서 **XFCE 로그아웃**. 창만 닫으면 세션이 남는다(`KillDisconnected=false`). 로그아웃 증거가 없으면 switch하지 않는다.
6. 게이트: uid 1990 프로세스 0, `loginctl`에 browser 없음, 9222 리슨 0, system 프로필 77 그대로
7. `nixos-rebuild switch --store-path <깨끗한 toplevel> --no-reexec` → 새 세대
8. GLG가 `junghan`으로 첫 RDP 로그인 → XFCE·Agent Chrome(uid 1000, 9222)·`emacsclient -s pi -t`·PATH 관찰
9. 머지·문서 확정. GUI Emacs는 별도 단계.

## 바뀌는 것 (dry-activate 실측)

- `would remove group/user ‘browser’`. `tsusers`에 junghan이 들어간다.
- 재시작: home-manager-junghan, polkit. dbus-broker는 reload, accounts-daemon과 tmpfiles-resetup은 stop/start. **xrdp·xrdp-sesman은 재시작하지 않는다.**
- 지난 A switch에서도 polkit·dbus-broker·accounts-daemon이 같은 방식으로 움직였다.

## 지키는 것

- MaxSessions 1, CF 엔드포인트·Access·connector 3시간 운영
- SSH 암호 인증 꺼짐, sudoers, junghan 암호·home 소유와 모드(`~/.config`는 755 그대로. tmpfiles 대신 HM으로 autostart를 둔다)
- `/home/browser`와 그 프로필, `~/.config/oracle-rdp/browser.hash`는 남긴다. 퇴역은 별도 판단이다.

## 복귀

switch 뒤 문제가 생기면 `--store-path`로 77 toplevel(`yn74mfdj…`)을 다시 켠다. browser 계정은 uid 1990과 기존 해시 파일로 다시 만들어진다.

## GUI Emacs — 별도 단계, owner 판단

- 지금 Oracle Emacs는 nox다. RDP 터미널에서 `emacsclient -s pi -t`가 기존 full Doom에 붙는다.
- GUI 빌드(`emacs31-gtk3`)는 137경로, 335.8 MiB 다운로드, 1.2 GiB 풀린 크기다(dry-run). 루트 여유는 17G다.
- GTK 빌드는 "cannot recover from X disconnects"(Emacs PROBLEMS:169)다. 그래서 `pi` 데몬을 GTK로 바꾸면 RDP 로그아웃 때 데몬이 함께 죽을 수 있다. Lucid 빌드는 unstable에 attr가 없어 로컬 빌드가 필요하다.
- `server` 데몬(agenda)은 어떤 안에서도 건드리지 않는다.
- 결정 상대: doomemacs-config owner (EKG 단일 인스턴스, user/pi 역할)

영수증(비공개): `.agent-reports/issue-14-junghan-rdp/` — eval-3dev.log, candidate-dirty.toplevel, dry-activate-dirty.log
