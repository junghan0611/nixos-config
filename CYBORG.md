# CYBORG — MSI Cyborg 15 AI A1VFK

납품 사양: Core Ultra 7 155H · Intel Arc + RTX 4060 Laptop · RAM 16GB · KLEVV CRAS C910 NVMe 1TB · Intel AX211 Wi-Fi. 실기기 및 Ventoy 부팅은 아직 검증 전이다.

## Ventoy로 설치

1. `cyborg-iso` 파일을 Ventoy에 넣고 UEFI로 부팅한다. Ventoy 외 외장 저장장치는 분리한다.
2. XFCE 터미널에서 `sudo cyborg-install`을 실행한다. 표시된 SSD의 모델·시리얼·용량을 확인하고 **`YES`**를 입력한다. 해당 SSD의 Windows와 모든 데이터를 지우고, 파티션 생성부터 NixOS 설치까지 오프라인으로 진행한다.
3. `junghan` 비밀번호를 설정하고 USB 없이 재부팅한다.

설치기는 KLEVV C910으로 식별되는 NVMe가 정확히 하나일 때만 진행한다. 대상 확인에 실패하면 디스크를 변경하지 않는다. `YES` 이후 오류가 나면 이미 디스크가 지워졌을 수 있으므로 바로 재실행하지 말고 오류를 확인한다.

## 첫 부팅 후

- 기본 세션은 i3, 별도 부팅 선택지는 XFCE. `teams-for-linux`가 포함된다.
- `echo cyborg > ~/.current-device`를 실행하고 이 리포를 가져온다.
- Wi-Fi·입력·오디오·절전·외부 모니터를 확인한다. NVIDIA PRIME은 `lspci -nnk`로 실측한 뒤 구성한다.
