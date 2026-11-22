# CYBORG — MSI Cyborg 15 AI A1VFK

납품 사양: Core Ultra 7 155H · Intel Arc + RTX 4060 Laptop · RAM 16GB · KLEVV CRAS C910 NVMe 1TB · Intel AX211 Wi-Fi. 이 회사 실기기는 아직 설치·부팅 전이다.

## ISO 원격 빌드

무거운 ISO 압축은 노트북에서 돌릴 필요가 없다. SSH로 접속 가능한 `x86_64-linux` 머신에 빌드할 소스와 `flake.lock`을 보내고, 원격 작업 디렉터리에서 아래 명령을 실행한다. Nix 원격 빌더 등록이나 대상 시스템에 `switch`할 필요는 없다.

```sh
nix build -L .#nixosConfigurations.cyborg-iso.config.system.build.isoImage
sha256sum result/iso/*.iso
```

완성된 ISO만 `scp`로 가져와 SHA-256을 대조한다. 작업 트리에 아직 커밋하지 않은 변경이 있으면 원격 사본에 명시적으로 포함한다. ISO의 NixOS 버전과 패키지는 빌드 호스트의 릴리스가 아니라 flake 설정과 잠긴 입력이 결정한다. 원격 스토어에 동일한 의존성이 있으면 재사용한다. 압축에는 GPU보다 CPU·메모리·디스크 여유가 중요하며, 3–4GB는 압축 레벨만으로 보장되지 않는다.

## 현장 검수 — 별도 데스크톱

GLG 현장 보고: RX 470 데스크톱에서 Ventoy가 처음 보이지 않았으나 USB 2.0 포트로 바꾼 뒤 UEFI 부팅했다. SATA `/dev/sda`에 `sudo cyborg-install --disk /dev/sda` 첫 시도는 실패했고 정확한 오류는 수집하지 못했다. 마운트 문제는 아니었으며 같은 명령의 두 번째 시도에서 설치가 진행됐다. 원인은 미상이며 자동 재시도나 재포맷의 근거가 아니다.

설치 중 라이브 XFCE가 자동 잠금됐고 텍스트 콘솔로 전환되지 않았다. `Switch User` → `nixos`로 돌아가 진행 화면을 다시 볼 수 있었다. 설치 후 담당자의 읽기 전용 SSH 확인: hostname `cyborg`, NixOS 26.05, UEFI, `/dev/sda2` ext4 루트·`/dev/sda1` vfat `/boot`, sshd·display-manager 활성, i3 실행, 실패 유닛 0, RX 470 amdgpu, Teams 바이너리 존재. Teams 실행과 오프라인 설치 여부는 확인하지 않았다. 이 관측은 회사 실기기 검증이 아니다.

라이브 XFCE 자동 잠금 방지 선언은 다음 ISO 빌드에만 반영된다. **현재 사용하는 ISO는 다시 굽지 않는다.** 설치된 시스템의 잠금 정책은 바꾸지 않았다. 새 선언의 라이브 작동은 아직 검증 전이다.

## Ventoy로 설치 — 회사 실기기

1. 준비된 `cyborg-iso`를 Ventoy에서 UEFI로 부팅한다. 보이지 않으면 USB 2.0 포트도 확인한다(별도 데스크톱 선례, 실기기 성공 보장 아님). Ventoy 외 외장 저장장치는 분리한다.
2. XFCE 터미널에서 `sudo cyborg-install`을 실행한다. 표시된 SSD의 모델·시리얼·용량을 확인하고 **`YES`**를 입력한다. 해당 SSD의 Windows와 모든 데이터를 지운다. 파티션 생성부터 NixOS 설치까지 오프라인으로 진행하도록 설계했으나 실제 오프라인 검증은 아직 못 했다.
3. `junghan` 비밀번호를 설정하고 USB 없이 재부팅한다. 현재 ISO에서 라이브 화면이 잠기고 콘솔 전환도 안 되면 `Switch User` → `nixos`로 복귀하는 우회책이 있다.

기본 자동 선택은 KLEVV C910 NVMe가 정확히 하나일 때만 동작한다. SATA 테스트 머신에서는 `lsblk -o NAME,MODEL,SERIAL,SIZE,TRAN`으로 지울 디스크를 확인한 뒤 `sudo cyborg-install --disk /dev/disk/by-id/ata-…`로 직접 지정한다. 이 옵션은 모델 제한만 해제하고 전체 디스크·장치 식별·사용 중 검사와 `YES` 확인은 유지한다. 대상 확인에 실패하면 디스크를 변경하지 않는다. `YES` 이후 오류가 나면 이미 디스크가 지워졌을 수 있으므로 바로 재실행하지 말고 오류를 확인한다.

## 첫 부팅 후

- 기본 세션은 i3, 별도 부팅 선택지는 XFCE. `teams-for-linux`가 포함된다.
- `echo cyborg > ~/.current-device`를 실행하고 이 리포를 가져온다. 설치 ISO와 현재 리포 변경분은 다를 수 있다.
- `lspci -nnk`, `lsusb`, `lsblk -f`로 실측하고 Wi-Fi·입력·오디오·절전·외부 모니터를 확인한다. NVIDIA PRIME 구성은 별도 판단이다.
- 리포를 가져온 뒤 `#cyborg` switch가 필요한지 GLG가 판단한다. switch는 별도 실행이며 현재 검증이나 설치의 일부가 아니다.
