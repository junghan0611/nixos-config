# CYBORG — MSI Cyborg 15 AI A1VFK

납품 사양: Core Ultra 7 155H · Intel Arc + RTX 4060 Laptop · RAM 16GB · KLEVV CRAS C910 NVMe 1TB · Intel AX211 Wi-Fi. 실기기 및 Ventoy 부팅은 아직 검증 전이다.

## ISO 원격 빌드

무거운 ISO 압축은 노트북에서 돌릴 필요가 없다. SSH로 접속 가능한 `x86_64-linux` 머신에 빌드할 소스와 `flake.lock`을 보내고, 원격 작업 디렉터리에서 아래 명령을 실행한다. Nix 원격 빌더 등록이나 대상 시스템에 `switch`할 필요는 없다.

```sh
nix build -L .#nixosConfigurations.cyborg-iso.config.system.build.isoImage
sha256sum result/iso/*.iso
```

완성된 ISO만 `scp`로 가져와 SHA-256을 대조한다. 작업 트리에 아직 커밋하지 않은 변경이 있으면 원격 사본에 명시적으로 포함한다. ISO의 NixOS 버전과 패키지는 빌드 호스트의 릴리스가 아니라 flake 설정과 잠긴 입력이 결정한다. 원격 스토어에 동일한 의존성이 있으면 재사용한다. 압축에는 GPU보다 CPU·메모리·디스크 여유가 중요하며, 3–4GB는 압축 레벨만으로 보장되지 않는다.

## Ventoy로 설치

1. `cyborg-iso` 파일을 Ventoy에 넣고 UEFI로 부팅한다. Ventoy 외 외장 저장장치는 분리한다.
2. XFCE 터미널에서 `sudo cyborg-install`을 실행한다. 표시된 SSD의 모델·시리얼·용량을 확인하고 **`YES`**를 입력한다. 해당 SSD의 Windows와 모든 데이터를 지우고, 파티션 생성부터 NixOS 설치까지 오프라인으로 진행한다.
3. `junghan` 비밀번호를 설정하고 USB 없이 재부팅한다.

기본 자동 선택은 KLEVV C910 NVMe가 정확히 하나일 때만 동작한다. SATA 테스트 머신에서는 `lsblk -o NAME,MODEL,SERIAL,SIZE,TRAN`으로 지울 디스크를 확인한 뒤 `sudo cyborg-install --disk /dev/disk/by-id/ata-…`로 직접 지정한다. 이 옵션은 모델 제한만 해제하고 전체 디스크·장치 식별·사용 중 검사와 `YES` 확인은 유지한다. 대상 확인에 실패하면 디스크를 변경하지 않는다. `YES` 이후 오류가 나면 이미 디스크가 지워졌을 수 있으므로 바로 재실행하지 말고 오류를 확인한다.

## 첫 부팅 후

- 기본 세션은 i3, 별도 부팅 선택지는 XFCE. `teams-for-linux`가 포함된다.
- `echo cyborg > ~/.current-device`를 실행하고 이 리포를 가져온다.
- Wi-Fi·입력·오디오·절전·외부 모니터를 확인한다. NVIDIA PRIME은 `lspci -nnk`로 실측한 뒤 구성한다.
