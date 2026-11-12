# CYBORG — MSI Cyborg 15 AI A1VFK

실물 인수 전 준비 상태다. 기기 실측이나 부팅 성공 기록이 아니다.

## 확인된 납품 사양

- Core Ultra 7 155H, Intel Arc 내장 GPU + RTX 4060 Laptop (8GB)
- DDR5-5600 16GB (8GB × 2), KLEVV CRAS C910 NVMe 1TB
- 15.6인치 1920×1080 144Hz, Intel AX211 Wi-Fi 6E, Realtek 기가비트 LAN
- BIOS E15K2IMS.10B (2024-09-30); Windows 11 Home 설치 상태

## 출근 전 준비

- NixOS 26.05 x86_64 설치 USB를 UEFI로 부팅할 수 있게 준비한다. 네트워크와 전원 어댑터도 준비한다.
- 이 리포의 **cyborg 변경분을 포함한** 사본을 설치 환경에서 접근할 수 있게 준비한다. Git에 반영되지 않은 파일은 원격 clone에 나타나지 않는다. 필요하면 USB에 작업 트리 사본을 별도로 둔다.
- ThinkPad의 미푸시 커밋·org 및 개인 데이터·SSH/GPG 키·인증기·비밀번호 관리자·브라우저·API 환경변수·외부 패키지 목록을 조사하고 안전한 매체로 이전한다. 회사 데이터와 자격증명은 반출 정책을 따른다. 선언 설정만으로 홈 디렉터리와 로그인 상태는 복구되지 않는다.
- 회사의 Linux 사용, 디스크 암호화 및 보안 도구 요구사항을 확인한다. 아래 기본 예시는 암호화되지 않는다. 암호화가 필요하면 이 절차로 포맷하지 말고 암호화 설계를 먼저 적용한다.
- 설치 시간을 줄이려면 동일 flake lock의 `cyborg` 시스템을 미리 빌드해 캐시 또는 별도 저장 매체로 전달하는 방안을 검증한다. 네트워크 속도, 다운로드량, 로컬 빌드와 홈 데이터 크기에 따라 1시간은 보장되지 않는다.

## 설치 당일 — Windows 전체 삭제

**아래 파티션 생성과 포맷은 선택한 디스크 전체를 지운다.** 인수한 기기에서만 진행하고 다른 저장 장치는 분리한다. UEFI 부팅 확인: `test -d /sys/firmware/efi/efivars`. 설치 USB에서 네트워크를 연결한 뒤 `lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,FSTYPE,MOUNTPOINTS`로 KLEVV 1TB 내장 디스크를 확인한다. USB와 혼동하지 말 것. 장치명이 확인되기 전에는 어떤 삭제 명령도 실행하지 않는다.

기본 디스크 구성은 GPT + 1GiB EFI + 나머지 ext4다. swap·암호화·hibernate는 아직 구성되지 않았다. ISO에 `parted`, `mkfs.fat`, `mkfs.ext4`가 있는지 확인하고 없다면 먼저 도구를 준비한다. 아래 `DISK`는 예시가 아니라 **실측한 전체 디스크 경로로 직접 지정**한다. NVMe 파티션 표기는 `p1`, `p2`다.

```sh
# 예: DISK=/dev/nvme0n1 — lsblk로 식별한 경우에만 입력
DISK=/dev/확인한_내장_NVMe
sudo parted -s "$DISK" -- mklabel gpt
sudo parted -s "$DISK" -- mkpart ESP fat32 1MiB 1025MiB
sudo parted -s "$DISK" -- set 1 esp on
sudo parted -s "$DISK" -- mkpart root ext4 1025MiB 100%
sudo partprobe "$DISK"
lsblk -f "$DISK"
# 아래 경로는 NVMe일 때만 적용. 반드시 위 lsblk와 대조.
sudo mkfs.fat -F 32 -n CYBORG-BOOT "${DISK}p1"
sudo mkfs.ext4 -L cyborg-root "${DISK}p2"
sudo mount /dev/disk/by-label/cyborg-root /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/CYBORG-BOOT /mnt/boot
```

설치 환경에서 리포의 준비된 사본으로 이동한다. `nix flake`는 Git 작업 트리의 미추적 파일을 무시하므로 사본의 파일 포함 상태를 확인한다. 먼저 평가한 다음 설치한다:

```sh
nix --extra-experimental-features 'nix-command flakes' eval .#nixosConfigurations.cyborg.config.system.build.toplevel.drvPath --raw
sudo nixos-install --flake .#cyborg
```

`nixos-install`의 root 비밀번호 설정을 마친 후 재부팅한다. 기존 선언은 junghan 초기 비밀번호를 `password`로 설정하고 wheel 무비밀번호 sudo를 허용한다. **첫 로그인 즉시 `passwd`로 junghan 비밀번호를 바꾼다.** 공유 네트워크에 연결된 회사 기기에서 이 sudo 정책이 허용되는지도 확인한다. 홈에서 `echo cyborg > ~/.current-device`를 실행하고 리포 및 개인 데이터를 복원한다.

현재 하드웨어 파일은 라벨 기반의 사전 가정이다. 실기기에서 `sudo nixos-generate-config --show-hardware-config` 결과와 `lsblk -f`, `lspci -nnk`, `lsusb`를 대조해 필요한 모듈과 파일시스템을 확인하고 리포에 반영한다. 생성 파일을 무검토로 덮어쓰면 라벨 마운트나 다른 설정이 달라질 수 있다.

## 첫 부팅 검증

- GUI/i3, 키보드·한글 입력·터치패드, Wi-Fi/Bluetooth, 소리·마이크·카메라, 밝기.
- 내장 패널과 HDMI/USB-C 외부 모니터, 도크 연결 및 분리. `autorandr` 프로필은 실측 후 생성.
- AC/배터리, suspend/resume 및 덮개, 팬 소음. GPU 구성은 실측 전 기본 상태다.
- `lspci -nnk`로 Intel/NVIDIA PCI 주소와 드라이버 확인 후 NVIDIA PRIME·외부 출력·전력·Ollama 가속을 별도로 구성하고 시험한다. 현재 Ollama는 수동 시작이며 GPU 가속은 보장하지 않는다.
- `./run.sh`, 에이전트 도구, 복원한 SSH 키·계정, org와 필요한 리포 접근을 확인한다. 2층 패키지는 `run.sh E)` 목록을 보고 복원한다.
