---
title: "Oracle VM 스토리지 확장 및 백업 전략"
date: 2025-10-08T12:50:47+09:00
tags: ["oracle", "storage", "backup", "nixos"]
identifier: "20251008T125047"
---

# Oracle VM 스토리지 확장 및 백업 전략

**English**: Oracle VM Storage Expansion and Backup Strategy

## 📊 현재 상태(Current_State)

- **Boot Volume**: 46.6GB → **100GB** (확장 완료 ✅)
- **무료 티어 한도(Free_Tier_Limit)**: 200GB (Boot + Block Volume 합계)
- **사용 가능 공간**: **73GB** (i3wm 설치 충분)

### 시스템 정보

**확장 전**:
```bash
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0 46.6G  0 disk
├─sda1   8:1    0  512M  0 part /boot
└─sda2   8:2    0 46.1G  0 part /nix/store, /

/dev/sda2        46G   21G   23G   48% /
```

**확장 후**:
```bash
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0  100G  0 disk
├─sda1   8:1    0  512M  0 part /boot
└─sda2   8:2    0 99.5G  0 part /nix/store, /

/dev/sda2        98G   21G   73G   22% /
```

## 🎯 스토리지 확장 전략(Storage_Expansion_Strategy)

### 방안 1: Boot Volume 확장 ⭐ (권장 - 완료)

**장점**: 간단, 기존 데이터 유지, 재부팅만 필요

#### 1단계: OCI 콘솔 작업

1. **OCI 웹 콘솔 접속**
   - https://cloud.oracle.com
   - Compute → Instances → 해당 인스턴스 선택

2. **Boot Volume 확장**
   - Resources → Boot Volume 클릭
   - Boot Volume 링크 클릭 (파란색)
   - 우측 상단 "Edit" 버튼
   - Volume Size: 46GB → **100GB** 입력
   - "Save Changes" 클릭

3. **인스턴스 재부팅**
   - Instances 페이지로 돌아가기
   - More Actions → Reboot
   - 확인

#### 2단계: NixOS에서 확장 적용

재부팅 후 SSH 접속하여 실행:

```bash
# 1. 디스크 크기 인식 확인
lsblk
# sda: 100G 확인 (파티션 sda2는 아직 46.1G)

# 2. 파티션 정보 확인
sudo fdisk -l /dev/sda
# 시작 섹터 확인: 1050624

# 3. fdisk로 파티션 확장
sudo fdisk /dev/sda << 'EOF'
d
2
n
2
1050624

w
EOF
# 파티션 2 삭제 후 동일 시작점으로 재생성

# 4. 파티션 테이블 리로드 (자동 인식됨)
lsblk
# sda2: 99.5G 확인

# 5. 파일시스템 확장
sudo resize2fs /dev/sda2

# 6. 확인
df -h /
# /dev/sda2  98G  21G  73G  22% /
```

#### 대안: 재부팅 없이 디스크 리스캔 (선택)

OCI에서 Boot Volume 크기 변경 후 재부팅 대신:

```bash
# OCI 디스크 리스캔 (재부팅 없이 크기 변경 인식)
sudo dd iflag=direct if=/dev/oracleoci/oraclevda of=/dev/null count=1
echo "1" | sudo tee /sys/class/block/`readlink /dev/oracleoci/oraclevda | cut -d'/' -f 2`/device/rescan

# 리스캔 후 위의 2-6단계 동일하게 진행
```

### 방안 2: Block Volume 추가

**용도별 구성**:
- Boot Volume (100GB): 시스템
- Block Volume (~100GB): `/backup`, `/data`

#### OCI 콘솔 작업

```bash
# 1. Block Volume 생성
# OCI Console → Block Storage → Block Volumes → Create Block Volume
# - Name: oracle-backup-volume
# - Size: 100GB
# - Availability Domain: 인스턴스와 동일

# 2. 인스턴스에 연결
# Block Volumes → Attach to Instance
# - Attachment Type: Paravirtualized
# - Device Path: /dev/sdb (자동 할당)
```

#### NixOS configuration.nix 설정

```nix
# /etc/nixos/configuration.nix

{ config, pkgs, ... }:

{
  # 핵심 시스템 도구 (스토리지 관리)
  environment.systemPackages = with pkgs; [
    # 파티션 관리
    cloud-utils      # growpart
    parted          # 파티션 편집
    gptfdisk        # GPT 파티션 도구

    # 파일시스템
    e2fsprogs       # resize2fs (ext4)
    xfsprogs        # xfs 관리
    btrfs-progs     # btrfs 관리

    # 디스크 모니터링
    smartmontools   # smartctl
    iotop           # I/O 모니터
    ncdu            # 디스크 사용량 분석
  ];

  # Block Volume 자동 마운트
  fileSystems."/backup" = {
    device = "/dev/sdb";
    fsType = "ext4";
    autoFormat = true;  # 초기 포맷 (주의!)
  };

  # 스토리지 최적화
  services.fstrim.enable = true;  # SSD TRIM

  # 디스크 모니터링
  services.smartd = {
    enable = true;
    notifications.wall.enable = true;
  };
}
```

적용:
```bash
sudo nixos-rebuild switch
```

## 🛡️ 백업 및 스냅샷 전략(Backup_Strategy)

### 1. OCI 자동 백업 정책 ⚠️ (비용 주의!)

#### 백업 정책 비교

**Bronze Policy**:
- 월별 증분 백업: 매월 1일 자정 → 12개월 보관
- 연별 증분 백업: 1월 초 → 5년 보관
- **1년 후 백업 개수**: 13개 (월 12 + 연 1)

**Silver Policy**:
- 주별 증분 백업: 일요일 → 4주 보관
- 월별 증분 백업: 매월 1일 → 12개월 보관
- 연별 증분 백업: 1월 초 → 5년 보관
- **백업 개수**: 21개 (주 4 + 월 12 + 연 5)

**Gold Policy**:
- 일별 증분 백업: 매일 → 7일 보관
- 주별 증분 백업: 일요일 → 4주 보관
- 월별 증분 백업: 매월 1일 → 12개월 보관
- **백업 개수**: 23개 (일 7 + 주 4 + 월 12)

#### ⚠️ 무료 티어 한도 및 비용

```
무료 Volume Backup 한도: 최대 5개
- Boot Volume + Block Volume 백업 합계
- 5개 초과 시 Object Storage 요금으로 과금

Bronze 정책 1년 후 예상 비용:
- 백업 개수: 13개
- 초과분: 8개 (13 - 5)
- 백업당 크기: ~20GB (증분 압축)
- 초과 스토리지: 160GB
- 월 비용: 160GB × $0.0255/GB = ~$4.08/월 💸
```

#### ❌ 권장: 자동 백업 정책 비활성화

**대신 사용할 무료 백업 방법**:

**Option 1: 수동 OCI 백업** (5개 이하 유지)
```bash
# OCI 콘솔 → Boot Volume → Create Manual Backup

백업 시나리오:
1. 주요 시스템 업데이트 전: 1개
2. 월별 정기 백업: 3개 (순환)
3. 긴급 복구용: 1개

관리:
- 오래된 백업 수동 삭제
- 5개 한도 엄수
→ 완전 무료 ✅
```

**Option 2: Restic 로컬 백업** (권장) ⭐
- Boot Volume 내에서 백업
- 추가 스토리지 비용 없음
- 자동화 가능
- 증분 백업으로 공간 효율

**Option 3: Syncthing 오프사이트 복제**
- 노트북/NUC로 자동 동기화
- 3-2-1 백업 규칙 준수
- 완전 무료

### 2. Cross-Region Replication ⚠️ (비용 주의!)

#### 비용 구성

```bash
1. 복제본 스토리지 (유료)
   - Destination 리전에 동일 크기 볼륨 생성
   - 100GB 복제 → 100GB 추가 스토리지 비용
   - Seoul → Tokyo: $0.0425/GB/월
   - 월 비용: 100GB × $0.0425 = $4.25/월 💸

2. Outbound Data Transfer
   - 첫 10TB/월 무료 ✅
   - 100GB 초기 복제 + 증분 변경분 → 무료 범위

3. Replication 기능 자체
   - 무료 ✅

총 비용: ~$4.25/월 (스토리지만)
```

#### ❌ 무료 티어에서 사용 불가 권장

**이유**:
```
Free Tier: 200GB 총 스토리지
- Boot Volume (Seoul): 100GB
- Replica (Tokyo): 100GB
총: 200GB ✅ (한도 내)

문제: Tokyo 리전은 무료 티어 대상 아님!
→ Tokyo 스토리지는 유료 과금 💸
```

**무료 대안**: Syncthing으로 노트북/NUC 동기화

### 3. Restic 백업(Application_Data_Backup) ⭐

#### NixOS configuration.nix

```nix
{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ restic ];

  # Restic 자동 백업
  services.restic.backups = {
    daily = {
      repository = "/backup/restic";
      passwordFile = "/etc/nixos/restic-password";

      paths = [
        "/home"
        "/etc/nixos"
        "/var/lib"
      ];

      exclude = [
        "/home/*/.cache"
        "/home/*/Downloads"
        "*.tmp"
      ];

      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };

      pruneOpts = [
        "--keep-daily 3"
        "--keep-weekly 2"
        "--keep-monthly 2"
      ];
    };
  };
}
```

#### 초기 설정

```bash
# 1. 백업 디렉토리 생성
sudo mkdir -p /backup/restic

# 2. 비밀번호 파일 생성
echo "your-strong-password" | sudo tee /etc/nixos/restic-password
sudo chmod 600 /etc/nixos/restic-password

# 3. 리포지토리 초기화
sudo restic -r /backup/restic init --password-file /etc/nixos/restic-password

# 4. 설정 적용
sudo nixos-rebuild switch

# 5. 수동 백업 테스트
sudo systemctl start restic-backups-daily

# 6. 백업 상태 확인
sudo restic -r /backup/restic snapshots --password-file /etc/nixos/restic-password
```

#### 복구 방법

```bash
# 스냅샷 목록 확인
sudo restic -r /backup/restic snapshots --password-file /etc/nixos/restic-password

# 특정 파일 복구
sudo restic -r /backup/restic restore latest \
  --target /tmp/restore \
  --path /home/junghan/important-file \
  --password-file /etc/nixos/restic-password

# 전체 복구
sudo restic -r /backup/restic restore latest \
  --target /tmp/restore \
  --password-file /etc/nixos/restic-password
```

### 4. 스냅샷 전략(Snapshot_Strategy)

#### 3-2-1 백업 규칙

- **3**개 백업 복사본
- **2**가지 다른 매체 (Local + Remote)
- **1**개 오프사이트 백업

#### 구현 방법

**1단계: 로컬 백업** (Boot Volume 내)
```nix
services.restic.backups.daily = {
  repository = "/backup/restic";
  # 위의 Restic 설정 참조
};
```

**2단계: 오프사이트 복제** (Syncthing)
```nix
{
  services.syncthing = {
    enable = true;
    user = "junghan";
    dataDir = "/home/junghan";

    settings.folders.backup = {
      path = "/backup/critical";
      devices = [ "laptop" "nuc" ];
      versioning = {
        type = "staggered";
        params = {
          cleanInterval = "3600";
          maxAge = "15768000";  # 6개월
        };
      };
    };
  };
}
```

**3단계: 수동 OCI 백업** (중요 마일스톤)
- OCI 콘솔에서 수동 생성
- 5개 이하 유지
- 주요 업데이트 전에만 생성

## 📋 실행 계획(Action_Plan)

### ✅ 단계 1: Boot Volume 확장 (완료)

```bash
# 1. OCI 콘솔에서 Boot Volume 46GB → 100GB로 확장 ✅
# 2. 인스턴스 재부팅 ✅
# 3. SSH 접속 후 파티션 확장 ✅

sudo fdisk /dev/sda  # 파티션 재생성
sudo resize2fs /dev/sda2  # 파일시스템 확장
df -h /  # 98G 확인 ✅
```

### 단계 2: 핵심 시스템 도구 설치

```nix
# configuration.nix에 추가
environment.systemPackages = with pkgs; [
  # 파티션 관리
  cloud-utils parted gptfdisk

  # 파일시스템
  e2fsprogs xfsprogs btrfs-progs

  # 모니터링
  smartmontools iotop ncdu
];
```

### 단계 3: 백업 설정 (권장)

```bash
# 1. Restic 초기화
sudo mkdir -p /backup/restic
echo "password" | sudo tee /etc/nixos/restic-password
sudo chmod 600 /etc/nixos/restic-password
sudo restic -r /backup/restic init --password-file /etc/nixos/restic-password

# 2. configuration.nix에 Restic 설정 추가
# 3. Syncthing 설정 (선택)
# 4. nixos-rebuild switch

sudo nixos-rebuild switch
```

### 단계 4: OCI 백업 정책 (비활성화 권장)

```bash
# ❌ Bronze/Silver/Gold 정책 활성화 안 함
# → 1년 후 $4+/월 비용 발생

# ✅ 수동 백업만 사용
# OCI 콘솔 → Boot Volume → Create Manual Backup
# 5개 이하 유지 → 무료
```

## 💾 예상 용량 배분(Capacity_Allocation)

### Boot Volume 100GB 구성 (현재)

```
Boot Volume (100GB):
├─ / (루트 시스템): 30GB
├─ /nix/store: 40GB
├─ /backup/restic: 20GB  # Restic 백업
└─ 여유 공간: 10GB
```

### Block Volume 100GB 구성 (선택)

```
Block Volume (100GB - /backup):
├─ Restic 리포지토리: 60GB
├─ 수동 백업: 20GB
├─ Syncthing 동기화: 10GB
└─ 임시 저장소: 10GB

총 사용: 200GB (무료 티어 최대 활용)
```

## 🔍 모니터링 및 유지보수

### 디스크 사용량 모니터링

```bash
# 전체 디스크 확인
df -h

# Nix store 크기 확인
du -sh /nix/store

# 가장 큰 패키지 확인
nix path-info -Sh /run/current-system | sort -rhk2 | head -20

# 백업 용량 확인
du -sh /backup/restic
sudo restic -r /backup/restic stats --password-file /etc/nixos/restic-password
```

### 정기 정리 작업

```nix
{
  # Nix 자동 가비지 컬렉션
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Nix store 자동 최적화
  nix.settings.auto-optimise-store = true;
}
```

수동 정리:
```bash
# 오래된 generation 삭제
sudo nix-env --delete-generations +3  # 최근 3개만 유지

# 가비지 컬렉션
sudo nix-collect-garbage -d

# Store 최적화 (하드링크로 중복 제거)
sudo nix-store --optimise

# 오래된 백업 정리
sudo restic -r /backup/restic forget \
  --keep-daily 3 \
  --keep-weekly 2 \
  --keep-monthly 2 \
  --prune \
  --password-file /etc/nixos/restic-password
```

## 📝 참고사항

### Oracle Free Tier 스토리지 한도

- **Total Block Volume**: 200GB (Boot + Block Volume 합계)
- **Volume Backups**: 최대 5개 무료
  - 5개 초과 시 Object Storage 요금 ($0.0255/GB/월)
- **Cross-Region Replication**: 유료 (권장 안 함)

### 주의사항

1. **자동 백업 정책 비활성화 권장**
   - Bronze/Silver/Gold 모두 1년 후 비용 발생
   - 수동 백업 5개 이하 유지 → 무료

2. **Cross-Region Replication 비활성화**
   - 월 $4+ 스토리지 비용
   - Syncthing 무료 대안 사용

3. **파티션 작업 주의**
   - `autoFormat = true` 옵션은 기존 데이터 삭제
   - 파티션 재생성 시 시작 섹터 확인 필수

4. **Restic 비밀번호 관리**
   - `.gitignore`에 추가
   - 안전한 장소에 백업 보관

### 유용한 명령어

```bash
# Block Volume 연결 확인
lsblk

# 파티션 정보
sudo fdisk -l /dev/sda

# 파일시스템 마운트 확인
mount | grep /backup

# OCI 디스크 리스캔 (재부팅 없이)
sudo dd iflag=direct if=/dev/oracleoci/oraclevda of=/dev/null count=1
echo "1" | sudo tee /sys/class/block/`readlink /dev/oracleoci/oraclevda | cut -d'/' -f 2`/device/rescan

# Restic 백업 통계
sudo restic -r /backup/restic stats --password-file /etc/nixos/restic-password

# OCI CLI로 Boot Volume 확인 (설치 후)
oci compute boot-volume get --boot-volume-id <boot-volume-id>
```

## 📚 추가 자료

- [Oracle Cloud Free Tier 문서](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- [OCI Block Storage Backup Policy 비용](https://support.oracle.com/knowledge/Oracle%20Cloud/2827638_1.html)
- [Restic 공식 문서](https://restic.readthedocs.io/)
- [NixOS File Systems 설정](https://nixos.org/manual/nixos/stable/options.html#opt-fileSystems)
- [OCI Block Volume 관리](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/overview.htm)

---

**작성일**: 2025-10-08
**최종 업데이트**: 2025-10-08
**환경**: Oracle Cloud VM, NixOS 25.05, ARM64
**확장 완료**: Boot Volume 100GB ✅
