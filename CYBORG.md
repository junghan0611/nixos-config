# CYBORG — MSI Cyborg 15 AI A1VFK

납품 사양: Core Ultra 7 155H · Intel Arc + RTX 4060 Laptop · RAM 16GB · KLEVV CRAS C910 NVMe 1TB · Intel AX211 Wi-Fi. 회사 실기기는 설치 후 부팅 경로를 수선했고, 현재 내장 NVMe에서 정상 부팅한다. 이는 ISO 설치 절차 자체의 성공 검증과는 별개다.

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

## 실기기 검수 — PRIME과 로컬 임베딩

4세대 부팅에서 `cyborg-root` 검사와 `/`, `CYBORG-BOOT`의 `/boot` 마운트 및 LightDM을 확인했다. i3/X11의 기본 OpenGL 렌더러는 Intel Arc, `nvidia-offload` 실행은 RTX 4060 Laptop GPU(595.71.05)였다. `gerbv --version`은 2.10.0. Intel 쪽 HDMI의 QHD 2560×1440 @ 59.95Hz 확장 출력은 X11에서 확인했다. 회사에서는 FHD 모니터를 HDMI에 연결했다. `cyborg-office-fhd`는 `HDMI-1` 1920×1080 @ 60Hz를 위에, 내장 `eDP-1`을 기본 화면으로 아래에 둔다. 현장 로컬 프로필의 자동 적용을 확인했고, 같은 배치를 Cyborg 전용 Home Manager 프로필로 선언했다. 기존 수동 저장본(`~/.config/autorandr/cyborg-office-fhd`)이 있는 기기는 첫 Home Manager 적용 전에 다른 위치로 백업한다.

2026-11-25: 기본 `ollama` 0.32.3 서비스는 8B 스모크에서 100% CPU였다. 아래는 별도로 빌드한 **CUDA Ollama 0.32.3**을 임시 루프백 포트 `11435`에서 실행한 실측이다. 동일한 18토큰 한국어 입력, `/api/embed`, 컨텍스트 2048, 모델 한 개씩 실행했다. 두 모델 모두 `ollama ps`에서 100% GPU였다.

| 모델 (로컬 ID) | 모델 파일 | 차원 | 첫 요청 | 동일 입력 반복 3회 | GPU 사용 / 여유 |
|---|---:|---:|---:|---:|---:|
| `qwen3-embedding:8b` (`64b933495768`) | 4.7 GB | 4096 | 5.07초 | 134.5–137.3 ms | 6137 / 1672 MiB |
| `qwen3-embedding:4b` (`df5bd2e3c74c`) | 2.5 GB | 2560 | 5.04초 | 117.3–128.0 ms | 4013 / 3796 MiB |

두 모델 파일은 기존 모델 저장소에 준비됐다. 첫 요청은 모델 로딩을 포함하며 반복 입력에는 캐시 재사용이 있어 실제 검색 지연이나 대량 처리량을 대표하지 않는다. 임시 CUDA 서버는 종료했고 기본 서비스 선언과 Andenken 설정·코퍼스·인덱스는 변경하지 않았다. 재현용 빌드: `NIXPKGS_ALLOW_UNFREE=1 nix build --impure --out-link /tmp/cyborg-ollama-cuda 'nixpkgs#ollama-cuda'` (당시 소스 빌드 33분 14초, 레지스트리 입력은 비고정).

Andenken의 기존 8B/4096차원 인덱스에는 로컬 8B를 읽기 전용 비교 후보로 본다. 차원이 같아도 양자화·입력 처리 차이가 있으므로 다양한 쿼리로 OpenRouter 대비 지연과 상위 검색 결과를 검증하기 전에는 혼용하지 않는다. 4B는 VRAM 여유가 약 2.1 GiB 더 많지만 2560차원 별도 인덱스가 필요하다.

### 일상 사용: 부팅 시 CUDA Ollama

Cyborg의 `ollama.service`는 부팅 때 자동 시작하고 `http://127.0.0.1:11435`에만 바인딩한다. 쿼리 모델은 `bge-m3:latest`(1024차원), `/v1/embeddings`를 사용한다. 서버 부팅은 모델 선적재와 다르다: 첫 요청에서 적재하고 마지막 사용 후 최대 8시간 유지한다. 모델 저장소는 기존 `/var/lib/ollama/models`를 재사용하며, 모델 파일이 없는 신규 설치에서는 `OLLAMA_HOST=127.0.0.1:11435 ollama pull bge-m3:latest`가 한 번 필요하다. 서버 상태는 `systemctl status ollama`와 `curl -fsS http://127.0.0.1:11435/api/version`으로 확인한다.

사이보그 실측: BGE-M3 파일 1.2GB, ctx 2048, 100% GPU, 서로 다른 warm 단건 0.16–0.18초, GPU 전체 사용/여유 761/7048 MiB. 아래의 8B 임시 런처는 과거 벤치 재현용이며 상시 서비스와 같은 포트를 쓰므로 병행 실행하지 않는다.

### 8B: OpenRouter 비교와 15분 지속 부하

동일 합성 입력 6회씩 비교: 첫 단건 로컬 5.33초 / OpenRouter 1.34초(원격 모델 적재 상태 비관측), 이후 단건 0.17–0.18초 / 3.32–3.48초, 배치 4개(625 입력 토큰) 0.66–0.77초 / 2.76–3.91초. OpenRouter는 6회 성공·429 없음; 장시간 원격 레이트 제한은 측정하지 않았다. 로컬 지속 900.7초 동안 5,316청크, 5.90청크/초, 실패 0, 배치 p50 0.678초/p95 0.689초, VRAM 사용/여유 6143/1666 MiB, 관측 최고 63°C. 합성 문형 반복이 있어 실제 코퍼스나 검색 품질을 대표하지 않는다.

1. 위 CUDA 빌드를 준비한다(다른 경로는 `OLLAMA_CUDA_BIN`으로 지정). 대상 기기에서 기존 `ollama.service`가 실행 중이고, `ollama list`에 `qwen3-embedding:8b`가 있어야 한다. 없으면 `sudo systemctl start ollama` 및 `ollama pull qwen3-embedding:8b`로 별도 준비한다.
2. `bash scripts/cyborg-embedding-runtime.sh start`로 임시 서버를 올린다. 접속 계약: **base `http://127.0.0.1:11435`** (`/v1` 미포함), `POST /v1/embeddings`, 모델 `qwen3-embedding:8b`, 배열 `input`, `data[].index`, 유한 벡터 4096차원. 검증된 설정은 컨텍스트 2048, 배치 4, 요청 타임아웃 30초다. 운영 서비스(`11434`)와 설정은 바꾸지 않으며 임시 서버 수명은 최대 20분이다.
3. `python3 scripts/cyborg-embedding-bench.py`는 로컬 스모크, `--seconds 900`은 15분 지속 부하. **유료 비교를 명시적으로 원할 때만** `--openrouter`를 추가한다(환경의 `ANDENKEN_SESSION_API_KEY` 또는 `OPENROUTER_API_KEY`, 합성 6회 이하, 자동 재시도 없음). 이 벤치는 기존 코퍼스와 인덱스를 읽거나 수정하지 않는다.
4. 사용자가 `bash scripts/cyborg-embedding-runtime.sh stop`으로 임시 서버를 종료한다. 장애는 `journalctl -u cyborg-embedding-cuda.service`에서 확인한다. Andenken 후보 시험에서는 이 엔드포인트를 명시적으로 사용하고 운영 인덱스 쓰기나 교체는 별도 결정으로 둔다.
