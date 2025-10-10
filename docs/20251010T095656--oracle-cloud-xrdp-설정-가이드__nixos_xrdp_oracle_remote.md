---
title:      "Oracle Cloud xrdp 원격 데스크톱 설정 가이드"
date:       2025-10-10T09:56:56+09:00
tags:       ["nixos", "xrdp", "oracle", "remote-desktop", "rdp"]
identifier: "20251010T095656"
---

# Oracle Cloud xrdp 원격 데스크톱 설정 가이드

**작성일**: 2025-10-10
**목적**: Oracle Cloud VM에 GUI 접속을 위한 xrdp 설정 및 사용 방법

## 1. 개요

### VNC vs xrdp 비교
| 구분 | VNC | xrdp (RDP) |
|------|-----|------------|
| 프로토콜 | VNC | RDP (Microsoft) |
| 클라이언트 | VNC Viewer 필요 | Windows 기본 내장 |
| 성능 | 보통 | 우수 (압축/최적화) |
| 클립보드 | 제한적 | 완벽 지원 |
| 파일 전송 | 별도 설정 | 기본 지원 |
| 설정 복잡도 | 복잡 | 간단 |

### xrdp 장점
- Windows의 기본 원격 데스크톱으로 바로 접속
- 더 나은 네트워크 성능 (대역폭 효율)
- 복사/붙여넣기, 파일 전송 지원
- 필요할 때만 서비스 실행 가능

## 2. NixOS 설정 구조

### 모듈 구조
```
nixos-config/
├── users/
│   └── junghan/
│       ├── nixos.nix       # 사용자 NixOS 설정 (xrdp import)
│       └── xrdp.nix        # xrdp 서비스 모듈
├── machines/
│   └── oracle.nix          # Oracle Cloud 머신 설정
└── docs/
    └── 이 문서
```

### 구현된 기능
- ✅ 수동 시작/정지 (자동 시작 비활성화)
- ✅ 간편한 제어 명령어 (xrdp-start, xrdp-stop, xrdp-status)
- ✅ 방화벽 자동 설정
- ✅ i3/GNOME 데스크톱 지원
- ✅ 사용자별 접근 제어

## 3. Oracle Cloud 설정

### 3.1 NixOS 설정 적용
```bash
# 설정 적용 (Oracle Cloud VM에서)
cd ~/repos/gh/nixos-config
git pull  # 최신 설정 가져오기
sudo nixos-rebuild switch --flake .#oracle
```

### 3.2 Oracle Cloud Console 설정

#### Security List 설정
1. Oracle Cloud Console 로그인
2. Compute → Instances → 인스턴스 선택
3. Primary VNIC → Subnet 클릭
4. Security Lists → Default Security List 클릭
5. Add Ingress Rules:
   ```
   Source Type: CIDR
   Source CIDR: 0.0.0.0/0  (또는 특정 IP 제한)
   IP Protocol: TCP
   Source Port Range: (비움)
   Destination Port Range: 3389
   Description: RDP Access
   ```

#### Network Security Group (선택적 - 더 안전)
1. Virtual Cloud Networks → Network Security Groups
2. Create Network Security Group
3. Add Rule:
   ```
   Direction: Ingress
   Source Type: CIDR
   Source: YOUR_IP/32  (본인 IP만)
   Protocol: TCP
   Destination Port: 3389
   ```

### 3.3 방화벽 확인
```bash
# Oracle Cloud VM에서
sudo iptables -L -n | grep 3389
# 또는
sudo firewall-cmd --list-ports
```

## 4. xrdp 서비스 사용법

### 4.1 서비스 시작
```bash
# 방법 1: 별칭 사용 (권장)
xrdp-start

# 방법 2: systemctl 직접 사용
sudo systemctl start xrdp xrdp-sesman
```

### 4.2 서비스 상태 확인
```bash
# 상태 확인
xrdp-status

# 자세한 상태
sudo systemctl status xrdp
sudo systemctl status xrdp-sesman

# 포트 확인
sudo ss -tlnp | grep 3389
```

### 4.3 서비스 정지
```bash
# 사용 후 정지 (보안)
xrdp-stop

# 또는
sudo systemctl stop xrdp-sesman xrdp
```

## 5. 클라이언트 접속

### 5.1 Windows (기본 원격 데스크톱)
1. Win + R → `mstsc` 실행
2. 컴퓨터: `<Oracle-Cloud-Public-IP>:3389`
3. 사용자 이름: `junghan`
4. 암호: 시스템 암호

### 5.2 macOS (Microsoft Remote Desktop)
1. App Store에서 "Microsoft Remote Desktop" 설치
2. Add PC → PC name: Oracle Cloud Public IP
3. User account 추가
4. Connect

### 5.3 Linux (Remmina)
```bash
# 설치
sudo apt install remmina remmina-plugin-rdp  # Ubuntu/Debian
sudo dnf install remmina  # Fedora

# 실행
remmina
```
- Protocol: RDP
- Server: `<Oracle-Cloud-IP>:3389`
- Username/Password 입력

### 5.4 연결 설정 팁
- **색상 깊이**: 24비트 (True Color)
- **해상도**: 1920x1080 또는 자동
- **성능**: LAN (10 Mbps 이상)
- **클립보드**: 활성화
- **드라이브 리디렉션**: 필요시 활성화

## 6. 문제 해결

### 6.1 연결 안 됨
```bash
# 1. 서비스 확인
xrdp-status

# 2. 방화벽 확인
sudo firewall-cmd --list-all
sudo iptables -L -n | grep 3389

# 3. 포트 리스닝 확인
sudo netstat -tlnp | grep 3389
```

### 6.2 로그인 실패
```bash
# 로그 확인
sudo journalctl -u xrdp -n 50
sudo journalctl -u xrdp-sesman -n 50

# 세션 확인
ls -la /tmp/.X11-unix/
```

### 6.3 검은 화면
```bash
# startwm.sh 확인/생성
cat > ~/.xsession << 'EOF'
#!/bin/sh
exec i3
EOF
chmod +x ~/.xsession
```

### 6.4 한글 입력 문제
```bash
# 환경변수 확인
echo $GTK_IM_MODULE  # kime
echo $QT_IM_MODULE   # kime
echo $XMODIFIERS     # @im=kime
```

## 7. 보안 권장사항

### 7.1 Tailscale VPN 경유 (권장)
```bash
# Tailscale 설치 후
tailscale ip  # Tailscale IP 확인

# Oracle Cloud Security List에서
# Source CIDR을 Tailscale 네트워크로 제한
# 예: 100.64.0.0/10
```

### 7.2 특정 IP만 허용
```bash
# Oracle Cloud Security List에서
Source CIDR: YOUR_HOME_IP/32  # 집 IP만
# 또는
Source CIDR: YOUR_OFFICE_SUBNET/24  # 사무실 대역
```

### 7.3 사용 후 서비스 정지
```bash
# 사용 완료 후 항상
xrdp-stop
```

### 7.4 fail2ban 설정 (선택적)
```nix
# NixOS 설정에 추가
services.fail2ban = {
  enable = true;
  jails.xrdp = {
    enabled = true;
    filter = "xrdp";
    maxretry = 3;
  };
};
```

## 8. 성능 최적화

### 8.1 경량 데스크톱 사용
```nix
# oracle.nix에서
modules.services.xrdp.windowManager = "icewm";  # 더 가벼움
# 또는
modules.services.xrdp.windowManager = "startxfce4";  # 중간
```

### 8.2 네트워크 최적화
```bash
# RDP 클라이언트 설정
- Experience: Broadband
- Persistent bitmap caching: Enabled
- Reconnect if connection drops: Enabled
```

### 8.3 Oracle Cloud 네트워크 최적화
```bash
# MTU 조정 (필요시)
sudo ip link set dev enp0s3 mtu 1450

# TCP 최적화 (이미 설정됨)
sysctl net.ipv4.tcp_congestion_control  # bbr
```

## 9. 다른 옵션들

### 9.1 GNOME 세션 사용
```nix
# oracle.nix 수정
modules.services.xrdp.windowManager = "gnome-session";
```

### 9.2 자동 시작 활성화 (비권장)
```nix
modules.services.xrdp.autoStart = true;  # 부팅시 자동 시작
```

### 9.3 포트 변경
```nix
modules.services.xrdp.port = 13389;  # 비표준 포트 사용
# 클라이언트에서 IP:13389로 접속
```

## 10. 장단점 정리

### 장점
✅ Windows 기본 클라이언트 사용
✅ VNC보다 빠른 성능
✅ 파일 전송 지원
✅ 클립보드 완벽 지원
✅ 수동 제어로 보안 강화

### 단점
⚠️ Oracle Cloud 무료 티어 대역폭 제한
⚠️ ARM64에서 일부 앱 호환성
⚠️ 공개 인터넷 노출 시 보안 위험

### 권장 사용 시나리오
1. **긴급 GUI 작업** 필요시
2. **설정/관리 작업**용
3. **임시 데모/테스트**
4. **Tailscale VPN과 함께** 사용

### 비권장 시나리오
- 상시 GUI 작업 (로컬 VM 권장)
- 민감한 데이터 처리
- 공개 네트워크에서 VPN 없이

---

**작성자**: junghanacs / Claude
**상태**: ✅ 구현 완료
**참고**: VNC보다 간단하고 성능 좋음