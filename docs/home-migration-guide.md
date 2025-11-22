# /home 디렉토리 마이그레이션 가이드 (Oracle Cloud)

## 배경
- 기존: sda2 (98GB)에 / 와 /home 모두 포함 → 95% 사용
- 목표: 새 볼륨 sdb (100GB)로 /home 분리

## ✅ 올바른 전체 순서

### 1단계: 새 볼륨 준비 및 데이터 복사

```bash
# ext4 포맷
sudo mkfs.ext4 -L home /dev/sdb

# UUID 확인 (나중에 사용)
sudo blkid /dev/sdb
# 예: UUID="751eac87-35bf-4da0-8dd1-361763ec0c24"

# 임시 마운트
sudo mkdir -p /mnt/newhome
sudo mount /dev/sdb /mnt/newhome

# syncthing 중지 (선택사항, 안정성 향상)
sudo systemctl stop syncthing@junghan

# 데이터 복사 (30G 정도 소요 시간 있음)
sudo rsync -aAXv --info=progress2 /home/ /mnt/newhome/

# 복사 검증
du -sh /mnt/newhome/junghan
ls -la /mnt/newhome/junghan/
```

### 2단계: NixOS 설정 업데이트

```bash
cd ~/nixos-config

# hosts/oracle/hardware-configuration.nix 편집
# 다음 내용 추가 (26번째 줄 이후):
```

```nix
fileSystems."/home" =
  { device = "/dev/disk/by-uuid/751eac87-35bf-4da0-8dd1-361763ec0c24";
    fsType = "ext4";
  };
```

### 3단계: NixOS 설정 적용 (boot 옵션 사용)

```bash
# ⚠️ 'switch'가 아닌 'boot' 사용 (다음 부팅 시에만 적용)
sudo nixos-rebuild boot --flake .#oracle

# 이 시점에서는 아직 sdb가 /home에 마운트되지 않음
```

### 4단계: 재부팅

```bash
sudo reboot
```

**재부팅 후 상태:**
- sdb가 자동으로 /home에 마운트됨
- sda2의 기존 /home은 sdb에 "가려져서" 보이지 않음

### 5단계: 기존 /home을 /home.old로 변경 (정리 작업)

```bash
# 현재 /home 마운트 확인
df -h /home
# /dev/sdb         98G   39G   55G  42% /home

# sdb를 임시로 언마운트 (기존 /home이 보이도록)
sudo umount /home

# 이제 sda2의 기존 /home이 보임
ls -la /home/

# 기존 /home을 /home.old로 변경
sudo mv /home /home.old

# 새 /home 디렉토리 생성
sudo mkdir /home

# sdb를 다시 /home에 마운트
sudo mount /dev/sdb /home

# 확인
df -h /home
ls -la ~/
```

### 6단계: 검증 및 최종 정리

```bash
# syncthing 재시작
sudo systemctl start syncthing@junghan

# 모든 서비스 정상 동작 확인
systemctl status syncthing@junghan

# 며칠 후 문제 없으면 /home.old 삭제
# sudo umount /home
# sudo rm -rf /home.old
# sudo mount /dev/sdb /home
```

## ⚠️ 잘못된 방법 (실패 사례)

```bash
# ❌ 이렇게 하면 안 됩니다!
sudo mv /home /home.old         # ← 현재 세션이 즉시 먹통됨
sudo mkdir /home                # ← 이미 로그인 세션이 깨진 상태
# ... 복구 필요
```

**왜 실패하나:**
- 현재 로그인 세션이 /home/junghan을 사용 중
- /home을 옮기면 모든 경로가 깨짐 (bashrc, ssh keys, 등)
- NixOS 설정도 ~/nixos-config를 못 찾음

## 핵심 포인트

1. **순서가 생명**:
   - 데이터 복사 → NixOS 설정 → 재부팅 → 정리
   - 재부팅 전에는 기존 /home을 절대 건드리지 않음

2. **boot vs switch**:
   - `boot`: 다음 부팅 시에만 적용 (현재 세션 안전)
   - `switch`: 즉시 적용 (위험, /home이 바로 바뀔 수 있음)

3. **UUID 사용**:
   - `/dev/sdb`는 부팅 순서에 따라 변경 가능
   - UUID는 항상 동일

4. **/home.old 정리**:
   - 바로 삭제하지 말고 며칠 대기
   - sdb 언마운트 후에만 접근 가능

## 복구 방법 (문제 발생 시)

### Case 1: /home을 잘못 옮긴 경우
```bash
# 다른 SSH 세션이나 콘솔에서
sudo mv /home.old /home
```

### Case 2: 재부팅 후 /home이 마운트 안 되는 경우
```bash
# Single User Mode로 부팅
# GRUB에서 'e' → kernel line에 'single' 추가

# 수동 마운트
mount -o remount,rw /
mount /dev/sdb /home
```

### Case 3: UUID를 잘못 입력한 경우
```bash
# 올바른 UUID 확인
sudo blkid /dev/sdb

# hardware-configuration.nix 수정
cd ~/nixos-config
# UUID 수정 후
sudo nixos-rebuild boot --flake .#oracle
sudo reboot
```

## 최종 결과

**Before:**
```
sda1: /boot (512MB)
sda2: / 및 /home (98GB, 95% 사용)
```

**After:**
```
sda1: /boot (512MB)
sda2: / only (98GB, 85% 사용)
sdb:  /home only (98GB, 42% 사용)
```

**Benefits:**
- nix 빌드 작업 가능 (15GB 여유 공간)
- /home 독립 관리 (백업, 스냅샷 용이)
- 디스크 공간 부족 문제 해결

## 참고사항

- Oracle Cloud는 root 계정 기본 잠김 → Emergency mode 접근 어려움
- 문제 시 Boot Volume을 다른 인스턴스에 attach하여 복구
- syncthing 등 서비스는 /home 마운트 후 자동 시작됨
