---
name: oracle-reboot
description: "Oracle 분기 유지보수·계획 재부팅 — 명시 승인, 범위별 정리, 명령별 sudo 권한, 유효기간 있는 실제 OpenClaw 유휴 게이트, 재접속 후 수동 복구·공개면 확인을 단계별로 수행한다. 자동 재부팅기/업데이트기가 아니다. 트리거: oracle reboot, 오라클 재부팅, 분기 정리, 정리하고 재부팅, 재접속 점검, 부팅됐어."
user_invocable: true
---

# oracle-reboot — 정리 → 한 번 재부팅 → 복구 확인

이 리포 전용 운영 절차의 **정본**이다. GLG가 약3개월마다 수동 작업 시간을 잡을 때 사용한다. 달력·uptime 자체는 실행 승인이 아니다. 보안 패치/장애를 분기까지 미뤄도 된다는 뜻도 아니다.

## 0. 경계와 정본

- **Oracle만.** `~/.current-device`의 첫 하이픈 앞 토큰이 `oracle`인지 확인하고 KST 시각을 기록한다.
- **이번 범위를 먼저 말한다:** 상태 조회 / 정확한 삭제 대상 / 재부팅 / 필요한 수동 서비스 복구. 조회 승인을 삭제·재부팅 승인으로 확대하지 않는다. commit/push도 별도다.
- **비목표:** flake update, 새 Nix 구성 적용, 외부 패키지/이미지 갱신, OpenClaw 버전업·DB 이관, auth/scope 변경, 재임베딩, 모델 smoke/prewarm. 필요하면 별도로 판단한다.
- cron·watcher·숨은 helper agent·자동 재시도·자동 롤백을 설치하지 않는다. 긴 작업은 사용자 기본소켓의 보이는 tmux, stdout도 화면에 남긴다.
- 상태 수집 = `../../../scripts/oracle-maintenance-preflight.sh`(`run.sh d`, Oracle 분기). 정리 로직 = `../../../scripts/diskclean.sh`. 복제 관리기를 새로 만들지 않는다.
- 런타임의 버전별 사실과 API = [openclaw](../openclaw/SKILL.md), suspend/RPC deadline = [openclaw-update](../openclaw-update/SKILL.md), 서빙 URL 기대값 = [nixos-config](../nixos-config/SKILL.md) §5. 소유자 정본을 임의 수정하지 않는다.

## 1. 상태 수집 — 아직 아무것도 지우지 않는다

리포 루트에서:

```bash
bash scripts/oracle-maintenance-preflight.sh
# 목표 구성을 실제로 비교해야 할 때만:
bash scripts/oracle-maintenance-preflight.sh --nix-plan
```

- 실행별 영수증은 `.agent-reports/oracle-maintenance/<KST>.<고유접미사>/`에 영속 보존한다. 디렉터리700·파일600. `/tmp`만이 정본/유일 영수증이 되게 하지 않는다.
- 로그와 정본 소스 사본·해시를 함께 보존한다. 토큰·env 전체·세션 원문·auth/config 덤프는 수집하지 않는다. CLI는 기존 인증을 내부에서 사용하게 한다.
- `COLLECTION_COMPLETE`는 **수집 명령 완료일 뿐 서비스 정상/삭제 허가가 아니다.** 실패 unit의 행, 실제 probe, Docker 상태를 읽는다. `ESTIMATE_UNAUDITED`는 정리 dry-run이 일부 du/find 오류를 숨긴다는 뜻이다.
- 기본 수집은 Nix 평가/다운로드를 하지 않는다. `--nix-plan`은 `--offline --no-update-lock-file`이어도 소스 store 복사·평가 캐시 쓰기가 가능하다. store쓰기0/네트워크0을 보장하지 않는다.
- root(Docker/Nix)와 home(봇 상태/사용자 데이터)을 따로 본다. 이미지 논리 크기, narSize, du 합계, reclaimable은 실제 회수량이 아니다.
- Git branch·변경·upstream을 확인한다. main 복귀/pull이 필요하면 변경 보존부터 결정하며 reset/discard하지 않는다. 현재 `system`과 목표가 같으면 재switch를 의식처럼 반복하지 않는다.

## 2. 범위 승인 → 개별 정리 → 실제 전후 비교

삭제 후보는 **정확한 경로/링크 대상·소유자·참조 관계·재생성 방법**으로 제시하고 승인받는다. 어제의 측정/승인 범위가 오늘도 같은지 실행 직전 확인한다.

### Nix

- 현재 system, booted system, 현행 Home Manager, 별도 사용자 profile/crypto, 최소1개 사용 가능한 복귀 세대를 확인·보존한다. 오래된 standalone HM과 현행 NixOS 모듈 HM을 이름만으로 혼동하지 않는다.
- 승인된 root 은퇴 전 링크 대상/보호 대상을 **텍스트/메타데이터로** 기록한다. 링크 복원은 GC 전에는 가능하지만, GC 후 삭제된 store 경로를 링크만 되살려 복구할 수 있다고 말하지 않는다.
- 범위가 root 은퇴라면 **나이/세대 삭제 없는 `nix-store --gc`**를 선택할 수 있다. 명령 exit·실제 `df` 증감·보호 대상 생존을 확인한다.
- `--delete-older-than 14d/30d`는 복귀 세대1개 보존을 보장하지 않는다. 기존 `nix-gc.timer` 다음 시각·규칙도 확인한다. 보호 root/정책 변경이 필요하면 GLG와 결정하며 몰래 timer를 바꾸지 않는다.

### 일괄 정리 도구의 한계

- `diskclean.sh safe/deep`는 **전체 묶음**이다. 부분 승인에는 실행하지 말고 승인된 개별 명령을 쓴다. `--yes`는 승인이 아니다.
- 알려진 Emacs prefix를 제외해도 일반적인 `/tmp` 활성 사용 감지는 아니다. 크기0 init-directory, socket, borrower, 영수증도 보호 대상이다. 오래됐다는 이유로 전체 삭제하지 않는다.
- pnpm store는 라이브 Node/Pi/봇의 마운트된 의존성과 얽힌다. 다른 에이전트가 닫혔어도 우리 세션은 살아 있다. 실행 중 prune하지 않는다.
- Docker는 현재/승인된 복귀 이미지 보존. `prune -a` 기본 금지, dangling도 실행 직전 정확한 집합을 재확인한다. Oracle journal은 선언된1GiB 진단 보존을 유지하며 추가 vacuum하지 않는다.
- 각 명령의 실패를 확인하고 멈춘다. 스크립트 마지막 exit0만으로 중간 실패를 덮지 않는다.

## 3. 재부팅 전 준비 — 유휴 게이트보다 먼저

1. **부트:** current/booted/기본 선택, 실제 kernel/initrd/init 파일과 복귀 엔트리를 확인한다. 같은 kernel 체인과 구성 전체 동일은 다른 주장이다.
2. **접근:** SSH/tailnet·필요시 클라우드 콘솔, GLG의 재접속 방법을 준비한다.
3. **권한은 실제 명령별로:**
   ```bash
   sudo -n -l /run/current-system/sw/bin/systemctl reboot
   sudo -n -ll
   ```
   `sudo -n true` 실패로 reboot까지 불가능하다고 단정하지 않는다. 해당 명령의 `!authenticate`/NOPASSWD를 확인한다. 인증이 필요하면 **같은 보이는 터미널**에서 먼저 로컬 인증한다. 비밀번호를 채팅/스크립트로 받지 않는다.
4. **복구 주체·방법:** 아래 표를 라이브 상태와 소유자 정본으로 확인한다. 프로세스 수명이 길거나 PPID1이라는 이유로 수동/자동을 추측하지 않는다. system unit의 실행 파일도 살아 있는지 본다.
5. **NEXT:** 마지막 완료 단계, 다음 복구 검사, 절대 영수증 경로, 실행 승인/미승인 경계를 남긴다. 새 실행의700 영수증 디렉터리 `$R`에 `(umask 077; set -C; printf '%s\n' "$(</proc/sys/kernel/random/boot_id)" > "$R/boot-id.before")`로 이전 boot ID를600으로 한 번만 기록한다(기존 파일 덮어쓰기 금지). 재접속 시 이 파일을 먼저 비교하고 덮어쓰지 않는다. 이 모델이 자동 재개된다고 가정하지 않는다. 기록/DM/인증을 게이트 취득 뒤에 길게 하지 않는다.

| 대상 | 확인과 복구 |
|---|---|
| agenda용 Emacs `server` | 현행은 의도적 수동 기동. geworfen/GLG 정본 `~/repos/gh/geworfen/ops/tmux/agent-emacs.sh start`. 정상 데몬을 중복 기동/임의 수선하지 않는다. unit 자동화로 설계를 바꾸지 않는다. |
| Pi용 Emacs/TTY | 필요할 때 GLG/하네스 기존 절차. 모델 자동 재개를 가정하지 않는다. |
| translation-server `:1969` | `systemctl show translation-server.service`로 실제 loaded/enabled/active와 실행 파일을 확인한다. 현행 자동 기동 여부는 실측하며 npm 명령을 발명하지 않는다. |
| Docker·네트워크 | docker enabled·컨테이너 restart policy, tailscaled 등의 실제 상태를 기록한다. restart와 recreate를 섞지 않는다. |

## 4. 최종 유휴 게이트와 재부팅 — 끊지 않고 같은 셸에서

**“봇이 방금 턴을 끝냈다”는 타이밍 정보이지 실제 유휴 게이트의 대체가 아니다.** 라이브 버전 문서/CLI와 `openclaw-update` 절차를 따른다.

- `gateway.suspend.prepare` 응답을 처음부터600 파일로 저장한다. requestId·suspensionId·expiresAtMs를 버리지 않는다.
- 다음 모두를 확인해야 한다: `status=ready`, 정수 `activeCount=0`, `blockers=[]`, 비어 있지 않은 suspensionId, **현재 시각보다 충분히 남은 만료 시각**.
- **TTL을 고정값으로 외우지 않는다.** 실제 응답의 expiresAtMs에서 현재 시각을 뺀 **남은 시간이 셧다운 예산 이상**이어야 한다. 예제 최소 예산은60초이며, 측정한 정지 지연/서비스 timeout이 더 길면 먼저 예산을 늘린다. TTL이 그 예산을 충족하지 못하면 멈추고 별도로 판단한다. 준비/설명/도구 왕복 뒤 오래된 ready를 재사용하지 않는다. 검증→재부팅 요청을 같은 셸에서 바로 수행한다.
- busy/unknown/파싱 실패/짧은 만료면 **재부팅하지 않는다.** 응답을 확인하고 취득한 suspensionId로 `openclaw gateway resume <suspensionId>`하여 풀거나 상태를 판독한다. 강제 턴 중단·맹목 재prepare/reboot 루프는 없다.

아래는 **이미 승인·권한·접속·복구/NEXT 준비가 끝난 때만** 쓰는 마지막 동작 예다. `$R`은 이번700 영수증 디렉터리의 절대경로다. 그 전에 boot ID와 승인 범위를 기록해 둔다. 인증이 필요한 규칙이면 prepare 전에 같은 TTY에서 `sudo -v`로 갱신하고, NOPASSWD인 규칙에는 일반 `sudo -v`를 불필요하게 요구하지 않는다. 권한 목록 조회와 실제 인증 가능성은 다르다. 예제는 서브셸로 격리되어 셸 옵션/umask가 SSH 로그인 셸에 남지 않는다.

```bash
(
set -euo pipefail
set -C  # 요청 ID/응답/실행 결과를 덮어쓰지 않는다.
trap 'printf "STOP at line %s; no automatic retry. Inspect receipt and own hold.\n" "$LINENO" >&2' ERR
umask 077
: "${R:?이번 영수증 절대경로를 먼저 지정}"
[[ "$R" == /* && -d "$R" ]]
[[ "$(</proc/sys/kernel/random/boot_id)" == "$(<"$R/boot-id.before")" ]]
[[ ! -e "$R/reboot-attempt.flag" && ! -e "$R/reboot-requested.flag" ]]
[[ ! -e "$R/suspend-prepare.final.json" ]]
[[ ! -e "$R/sudo-check.final.txt" && ! -e "$R/suspend-request-id.final" ]]
# §3에서 실제 규칙/인증을 끝낸 상태. prepare 전에 권한 목록도 다시 기록한다.
sudo -n -l /run/current-system/sw/bin/systemctl reboot > "$R/sudo-check.final.txt"
shutdown_budget_ms=60000  # 최소 예산; 더 긴 정지 지연은 이 값을 늘려 사전 판단한다.
show_resume() {
    python3 -I - "$R/suspend-prepare.final.json" <<'PY_RESUME'
import json, shlex, sys
try:
    x = json.load(open(sys.argv[1]))
except (OSError, ValueError):
    raise SystemExit('No readable suspensionId: inspect live state; do not guess/retry.')
sid = x.get('suspensionId') if isinstance(x, dict) else None
if not isinstance(sid, str) or not sid:
    raise SystemExit('No suspensionId: inspect live state; do not guess/retry.')
print('If reboot was NOT initiated, release this own hold after checking state:')
print(shlex.join(['docker', 'exec', 'openclaw-gateway', 'openclaw', 'gateway', 'resume', sid]))
PY_RESUME
}
request="oracle-reboot-$(date +%s)"
printf '%s\n' "$request" > "$R/suspend-request-id.final"
if docker exec openclaw-gateway openclaw gateway call gateway.suspend.prepare --json \
  --params "{\"requestId\":\"$request\",\"terminalPolicy\":\"preserve\"}" > "$R/suspend-prepare.final.json"; then
    :
else
    rc=$?
    show_resume || true  # CLI 실패여도 서버가 hold를 취득했을 수 있다.
    exit "$rc"
fi
if python3 -I - "$R/suspend-prepare.final.json" "$shutdown_budget_ms" <<'PY_GATE'
import json, sys, time
x = json.load(open(sys.argv[1]))
budget = int(sys.argv[2])
if not (budget >= 60000 and isinstance(x, dict) and x.get('status') == 'ready'
        and type(x.get('activeCount')) is int and x['activeCount'] == 0
        and x.get('blockers') == []
        and isinstance(x.get('suspensionId'), str) and bool(x['suspensionId'])
        and type(x.get('expiresAtMs')) is int
        and x['expiresAtMs'] > time.time() * 1000 + budget):
    raise SystemExit('STOP: gate not ready/valid or below shutdown budget. No reboot.')
PY_GATE
then
    :
else
    rc=$?
    show_resume || true
    exit "$rc"
fi
# 검증 뒤 다른 모델 턴/긴 작업을 끼우지 않는다. attempt는 요청/수락 증거가 아니다.
TZ=Asia/Seoul date --iso-8601=seconds > "$R/reboot-attempt.flag"
if sudo -n /run/current-system/sw/bin/systemctl reboot; then rc=0; else rc=$?; fi
printf '%s\n' "$rc" > "$R/reboot-command.exit"
if [[ "$rc" -ne 0 ]]; then show_resume || true; fi
exit "$rc"
)
```

이 예가 중간에 멈췄으면 저장한 응답/실행 결과를 판독하고 **resume 필요 여부부터** 처리한다. 출력된 resume은 자동 실행이 아니다. `reboot-attempt.flag`는 시도 전, `reboot-command.exit`는 반환 후 기록이며, 후자가 없으면 성공/실패를 추정하지 않는다. 명령 exit0도 요청 수락일 뿐 실제 재부팅 증거가 아니다. transport 단절·결과 불명에서는 부팅/서비스 상태부터 확인하며 자동 재시도하지 않는다. STOP 뒤에는 이전 hold를 판독/해제하고, 재시도가 승인된 경우에만 **새 `$R` + 새 boot-id.before**로 시작한다. 기존 영수증/flag를 지워 강제로 재실행하지 않는다.

## 5. 재접속 — 이전 단계 재실행 말고 먼저 실측

1. 이전 boot ID와 `/proc/sys/kernel/random/boot_id`를 비교한다. 새 부팅인지, current/booted·kernel·기본 엔트리가 계획과 맞는지 확인한다. 오래된 background 완료 통지는 이미 끝낸 GC/reboot를 반복할 이유가 아니다.
2. system/user failed unit, Docker 기동/health, Gateway 이미지·RestartCount·인증된 RPC health를 확인한다. `/health`200이나 배지만으로 정상 판정하지 않는다. CLI/RPC는 모델 호출이 아니다. **자신이 취득한 suspension이 남지 않았는지도** 라이브 버전의 문서화된 상태 조회로 확인한다. health.ok만으로 hold가 없다고 추정하지 말고, 잔존 시 저장한 ID/만료/현재 상태를 판독해 필요한 resume을 수행한다.
3. Emacs `server` absent가 예상이면 승인된 소유자 정본으로 기동한 뒤:
   ```bash
   timeout 8 emacsclient -s server --alternate-editor=false --eval '(+ 1 1)'
   ```
   자동 daemon 기동 없는 probe다. 무응답/새 설정 문제가 있으면 geworfen 담당과 조율하며 여기서 daemon/config를 임의 수선하지 않는다.
4. 그 다음 [nixos-config §5](../nixos-config/SKILL.md)의 공개 URL 전체·comments ping. claw/map302와 comments루트404는 정상 기대값이다. agenda 검사만 먼저 해서 Emacs 수동 기동을 새 장애로 오판하지 않는다.
5. translation-server 등 자동 서비스 복귀, `scripts/turnwatch.sh 24`의 실제 오류·대기/미완료 턴을 확인한다. 과거 실패 행을 새 부팅 장애와 구분하고 private 원문을 덤프하거나 DB를 수선하지 않는다.
6. root/home 여유와 재시작 수를 다시 기록한다. startup ELOOP 등 오류가 있었으면 영향·복구·현재 안정성·미해결 원인을 분리해 적는다. restart수가 계속 늘거나 RPC deadline을 넘으면 멈추고 판단하며 무조건 recreate/rollback하지 않는다.

**종료 조건:** 계획한 부팅 확인 + 필수 서비스 복구 + 전체 공개면 기대 상태 + Gateway RPC/재시작 안정 + 영수증/NEXT 갱신. 실제 봇 동작은 다음 자연 대화/자동화로 관찰한다. 임의 smoke/prewarm 모델 턴은 만들지 않는다. 오래 걸려 GLG가 자리를 비웠다면 완료/판단 필요 사건당 DM1회, 보고 있는 동안은 채팅으로 답한다.

## 6. 갈무리와 다음 단계

- 완료한 GC/재부팅을 반복하지 않도록 NEXT 현재 좌표를 닫는다. 남은 home 공간, 복귀 보존 정책, 미관찰 자연 동작은 별도 상자에 둔다.
- OpenClaw 다음 릴리즈는 **별도 읽기 전용 검토부터** 시작한다. 호스트 재부팅 승인이 이미지 pull/스키마 이관/인덱스 초기화 승인은 아니다.
- 사전 수집 코드가 바뀌면 `python3 -B scripts/test-oracle-maintenance-preflight.py`와 `bash -n`을 먼저 수행한다. 합성 fixture 통과를 실서비스 정상 증거로 확대하지 않는다.
