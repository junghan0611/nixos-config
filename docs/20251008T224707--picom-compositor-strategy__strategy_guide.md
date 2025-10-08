# Picom Compositor 전략

**작성일**: 2025-10-08
**목적**: 호스트별/원격 접속별 picom 제어 방안

---

## 1. 현재 설정

**기본**: picom 항상 실행
```nix
# modules/i3.nix startup
{ command = "${pkgs.picom}/bin/picom -b"; notification = false; }
```

**토글 키바인딩**: `Mod+c`
```nix
"${mod}+c" = "exec --no-startup-id pkill picom || picom -b";
```

---

## 2. ElleNajit 전략 분석

### 환경
- **etude**: VM (Virtual Machine)
- **elle.is_vm = true**

### 전략
- **기본**: picom 비활성화
- **peek 사용 시**: 임시로 실행 후 종료

### 이유
1. VM 이중 오버헤드 방지
2. 리소스 최적화
3. 필요한 경우만 활성화

---

## 3. 호스트별 제어 방안

### 방법 1: currentSystemName으로 조건부 (추천)

**구조:**
```nix
# users/junghan/modules/i3.nix
{ config, lib, pkgs, currentSystemName, ... }:

let
  # 호스트별 picom 활성화 여부
  enablePicom =
    if currentSystemName == "nuc" then true
    else if currentSystemName == "laptop" then true
    else if currentSystemName == "storage-01" then false  # 서버
    else if currentSystemName == "gpu-01" then false      # GPU 서버
    else true;  # 기본값

  picomStartup = lib.optional enablePicom
    { command = "${pkgs.picom}/bin/picom -b"; notification = false; };
in {
  xsession.windowManager.i3.config.startup = [
    # ... 기존 startup
  ] ++ picomStartup;
}
```

**장점:**
- 명시적 호스트별 설정
- 코드로 명확히 관리

### 방법 2: 호스트 옵션 정의

**machines/nuc.nix:**
```nix
{
  junghan.i3.compositor.enable = true;
}
```

**machines/storage-01.nix:**
```nix
{
  junghan.i3.compositor.enable = false;
}
```

**modules/i3.nix:**
```nix
{ config, lib, ... }:
{
  options.junghan.i3.compositor.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable picom compositor";
  };

  config.xsession.windowManager.i3.config.startup =
    lib.optional config.junghan.i3.compositor.enable
      { command = "picom -b"; notification = false; };
}
```

**장점:**
- 재사용 가능한 옵션
- 각 호스트에서 override

---

## 4. 원격 접속 감지 방안

### SSH/VNC 감지

**방법 1: 환경 변수 체크**
```bash
 # ~/.xinitrc 또는 i3 startup script
if [ -n "$SSH_CONNECTION" ] || [ -n "$VNC_CONNECTION" ]; then
  # Remote session - disable picom
  pkill picom
else
  # Local session - enable picom
  picom -b
fi
```

**방법 2: DISPLAY 분석**
```bash
# DISPLAY=:0 → 로컬
# DISPLAY=:10.0 → SSH X forwarding
case "$DISPLAY" in
  :0|:1) picom -b ;;  # 로컬
  *)     ;;            # 원격, picom 비활성화
esac
```

**방법 3: systemd user service**
```nix
# 조건부 picom 서비스
systemd.user.services.picom = {
  Unit.Description = "Picom compositor";
  Unit.ConditionEnvironment = "!SSH_CONNECTION";  # SSH가 아닐 때만
  Service.ExecStart = "${pkgs.picom}/bin/picom";
};
```

---

## 5. 추천 적용 방안

### 단계별 접근

**Phase 1: 현재 (완료)**
- ✅ picom 기본 활성화
- ✅ `Mod+c` 토글 키바인딩

**Phase 2: 호스트별 제어 (향후)**
```nix
# machines/nuc.nix
junghan.i3.compositor.enable = true;

# machines/laptop.nix
junghan.i3.compositor.enable = true;

# machines/storage-01.nix (서버)
junghan.i3.compositor.enable = false;

# machines/gpu-01.nix (GPU 서버)
junghan.i3.compositor.enable = false;
```

**Phase 3: 원격 감지 (선택)**
```nix
# i3 startup script로 자동 감지
startup = [{
  command = pkgs.writeShellScript "picom-auto" ''
    # SSH 접속 시 picom 비활성화
    [ -n "$SSH_CONNECTION" ] && exit 0

    # 로컬 접속 시만 picom 실행
    ${pkgs.picom}/bin/picom -b
  '';
}];
```

---

## 6. 현재 사용법

**수동 제어:**
- `Mod+c`: picom 토글 (껐다 켰다)
- 터미널: `pkill picom` (종료)
- 터미널: `picom -b` (실행)

**자동 제어 (향후):**
- 호스트별 설정으로 자동
- 원격 접속 감지로 자동

---

## 7. 다음 단계

**즉시 적용 가능:**
1. ✅ 현재 상태 유지 (기본 활성화 + 토글)
2. ⚠️ 호스트별 옵션 정의 (방법 2)

**향후 고려:**
- 원격 접속 자동 감지
- 성능 모니터링 후 결정

---

**작성자**: junghanacs
**날짜**: 2025-10-08
**상태**: ✅ 전략 수립 완료
