# NixOS vLLM GPU Stack 전략 (RTX 5080 클러스터)

**작성일**: 2025-11-19  
**맥락**: 회사 클러스터(`~/repos/work/hej-nixos-cluster/`)에서 RTX 5080 3대 + 스토리지 서버 구성, 현재 Ollama 기반 GPU LLM 서빙. vLLM 0.11.0이 `nixpkgs-unstable`에 들어온 시점에서, 어느 레이어까지 unstable을 도입해야 하는지 전략 정리.

---

## 1. 목표와 전제

- **목표**
  - 기존 Ollama 스택은 유지하면서, **vLLM 0.11.x + PyTorch + CUDA** 스택을 도입해 확장성 높은 LLM 서빙(vLLM) 레이어 추가.
  - NixOS 특성상 **가능한 한 좁은 범위로 unstable** 을 사용해 재현성과 안정성을 지키기.

- **전제**
  - 클러스터는 별도 리포 `~/repos/work/hej-nixos-cluster/` 에 flake 기반으로 관리된다고 가정.
  - 현재 Python은 **3.12** 기준으로 사용 중.
  - GPU 노드는 **RTX 5080 (Blackwell 세대)** 로, 최신 CUDA / NVIDIA driver 스택이 필요.
  - 이 퍼블릭 리포 (`~/sync/emacs/nixos-config`) 에서는 **전략 문서만 작성**하고, 실제 설정 변경은 work 리포에서 수행.

---

## 2. nixpkgs-unstable 의 vLLM 0.11.0 구조 요약

`nixpkgs-unstable` 의 `pkgs/development/python-modules/vllm/default.nix` 기준 요약:

- **버전**: `vllm 0.11.0`
- **Python 빌드 베이스**: `buildPythonPackage` + `torch.stdenv`
- **핵심 의존성** (발췌):
  - Python 레벨: `torch`, `torchaudio`, `torchvision`, `transformers`, `xformers`, `bitsandbytes`, `flashinfer` 등
  - GPU 레벨: `cudaPackages.cuda_nvcc`, `cuda_cudart`, `libcublas`, `libcusparse`, `libcusolver`, `cudnn`, `libcufile`, `nccl` 등
  - CPU 백엔드: `oneDNN`, `numactl` (리눅스)
- **CUDA/ROCm 토글**:
  - `cudaSupport ? torch.cudaSupport`
  - `rocmSupport ? torch.rocmSupport`
  - `gpuTargets ? [ ]` 로 SM 아키텍처 지정 가능
- **GPU 아키텍처 지원**
  - `supportedTorchCudaCapabilities` 에서 SM 3.5 ~ 12.x 대까지 다수의 compute capability 를 지원.
  - Blackwell 세대(예: SM 10.x / 12.x 계열)에 대한 플래그를 포함하고 있으며, `gpuTargets` 또는 `cudaPackages.flags.cudaCapabilities` 를 통해 설정.

**핵심 포인트**

- vLLM 패키지는 **자신이 속한 nixpkgs 채널의 PyTorch / CUDA 스택과 강하게 결합**되어 있다.
- 따라서 `nixpkgs-unstable.python3_12Packages.vllm` 을 쓰면, **그와 동일 채널의 `torch`/`cudaPackages` 를 같이 따라오게 됨**.
- 하지만 **커널 / NVIDIA driver 는 시스템 레벨**이므로, 여기서 말하는 unstable 스택은 **user-space CUDA + PyTorch 레이어**에 한정된다.

---

## 3. "어디까지 unstable 인가"를 레이어로 나누어 보기

### 3.1 Python 레이어: vLLM 전용 Python 3.12 환경 (필수 unstable)

- **전략**: GPU 노드에 `nixpkgs-unstable` 기반 **전용 Python 3.12 환경**을 하나 두고, vLLM, PyTorch, CUDA user-space libs 를 모두 그 안에서 해결.
- 예시 (개념적 flake 코드, work 리포에서 사용):

```nix
# hej-nixos-cluster/flake.nix (개념)
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";  # 시스템 기본
  nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
};

outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs:
let
  system = "x86_64-linux";
  pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
  pkgsUnstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };

  vllmPythonEnv = pkgsUnstable.python3_12.withPackages (ps: [
    ps.vllm
    ps.torch
    ps.torchaudio
    ps.torchvision
    # 필요 시: ps.bitsandbytes ps.flashinfer 등
  ]);
in {
  # GPU 노드용 NixOS 설정에서 이 env 를 systemd 서비스 등에 사용
}
```

- 이렇게 하면:
  - **system 전체는 여전히 25.05 stable** 을 사용.
  - vLLM 관련 Python 패키지와 CUDA user-space libs 는 **모두 unstable 쪽 Python env 안에 캡슐화**.
  - Ollama, 기타 기존 Python 앱은 기존 stable Python 그대로 유지 가능.

**결론 (Python 레이어)**

- vLLM 0.11.0을 제대로 쓰려면, **vLLM + PyTorch + 관련 Python 패키지는 `nixpkgs-unstable` 쪽을 통째로 쓰는 것이 안전**하다.
- 즉, "vLLM만 unstable" 이라기보다 **"vLLM이 속한 Python 3.12 패키지 세트 전체"**가 사실상 unstable 이 된다.

---

### 3.2 NVIDIA Driver / CUDA 레이어: 가능한 한 시스템 채널과 일치 유지

- NixOS에서 **커널 + NVIDIA driver** 는 `boot.kernelPackages` 에 묶여 있으며, 보통은 **주 채널(nixpkgs)의 버전과 동기화** 되어 있다.
- vLLM 패키지는 user-space CUDA 라이브러리( `cuda_cudart`, `libcublas`, `nccl`, `cudnn`, `libcufile` 등 )를 `cudaPackages` 를 통해 가져온다.

#### 3.2.1 안전한 기본 전략

1. **GPU 노드의 커널/드라이버는 그대로 유지 (25.05)**
   - 이미 RTX 5080 + Ollama가 동작 중이라면, 현재 driver 버전이 해당 GPU 세대와 어느 정도 호환되는 상태라고 가정.
   - 먼저 **기존 driver 그대로** vLLM env 를 붙여 보고, 
     - `CUDA driver version is insufficient for CUDA runtime version` 류 에러가 나오는지 확인.

2. **문제가 없다면**
   - 커널/driver 는 계속 stable 25.05 의 `linuxPackages.nvidiaPackages.*` 사용.
   - vLLM 쪽은 user-space CUDA 만 unstable 에서 가져와 사용.

3. **문제가 생긴다면 (driver too old)**
   - 옵션 A: GPU 노드만 `nixpkgs-unstable` 에 맞춰 **전체 시스템을 올리기**
     - `inputs.nixpkgs` 를 GPU 노드용 flake에서는 `nixpkgs-unstable` 로 지정.
     - 커널 + NVIDIA driver + CUDA + PyTorch + vLLM 이 모두 동일 채널에서 나오는 구조.
   - 옵션 B(비추천): stable 커널에 unstable driver 를 억지로 섞는 방식은 NixOS 에서 관리/디버깅 난이도가 크므로 피하는 것이 좋다.

**결론 (NVIDIA 레이어)**

- 1단계에서는 **driver 레이어는 그대로 두고, user-space CUDA(vLLM env)만 unstable** 로 가져오는 경로를 먼저 시도.
- RTX 5080 + vLLM 0.11.0 에서 driver 호환성 문제를 경험한다면, 
  - GPU 노드만 별도 flake input (nixpkgs-unstable) 으로 올리는 것을 **두 번째 단계**로 고려.

---

### 3.3 Ollama 공존 전략

- 현재 Ollama는
  - 별도 바이너리 (`pkgs.ollama`) + 자기가 관리하는 모델 캐시/런타임 구조.
  - PyTorch / vLLM Python 스택과는 **직접적인 Python dependency 충돌이 없다**.

**전략**

- Ollama는 **기존 stable 채널 그대로 유지**.
- vLLM는 **별도의 Python env + systemd 서비스** 로 운영.
- 둘 다 같은 GPU 를 공유하지만, 서로 다른 user-space 스택을 사용.

예시 (개념적 NixOS 서비스 스니펫):

```nix
# hej-nixos-cluster/machines/gpu-node-01.nix (개념)
{ config, lib, pkgs, pkgsUnstable, ... }:

let
  vllmPythonEnv = pkgsUnstable.python3_12.withPackages (ps: [ ps.vllm ]);
in {
  systemd.services.vllm-api = {
    description = "vLLM API server";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = ''
        ${vllmPythonEnv}/bin/python -m vllm.entrypoints.openai.api_server \
          --host 0.0.0.0 --port 8000 \
          --model /path/to/model
      '';
      Restart = "always";
      Environment = [
        # 필요 시 명시적인 GPU 타겟 설정
        # "VLLM_TARGET_DEVICE=cuda"
      ];
    };
  };
}
```

- Ollama 서비스는 기존 설정을 그대로 유지하고, GPU 스케줄링/리소스 관리는 k8s 또는 외부 오케스트레이터에서 담당 (이 문서 범위 밖).

---

## 4. Python 3.12 관점에서의 정리

- vLLM derivation 은 `python` 인자를 받아 내부에서:
  - `pythonRelaxDeps = true;`
  - `CMakeLists.txt` 에서 Python minor 버전을 **동적으로 감지**하도록 패치되어 있음.
- 따라서 unstable 의 vLLM 0.11.0 은 **Python 3.12 환경에서 정상 동작하도록 이미 조정**되어 있다.
- 이 리포와 work 리포 모두에서 **Python 3.12** 를 기본으로 가져가는 것은 vLLM 측에서 문제가 되지 않는다.

**주의할 점**

- 같은 프로세스 안에서 **stable Python 패키지 세트와 unstable Python 패키지 세트를 섞어 쓰지 않는다.**
  - 예: 한 `python3_12` env 에 stable `torch` 와 unstable `vllm` 을 동시에 끼워 맞추는 시도 → 의도치 않은 ABI/의존성 충돌 위험.
- 대신, 
  - vLLM 용 env = `pkgsUnstable.python3_12.withPackages` 로 독립 구성.
  - 기타 앱 용 env = stable 쪽 Python3.12 로 별도로 유지.

---

## 5. 클러스터 리포(hej-nixos-cluster)에서의 적용 단계

### 5.1 준비: flake 입력 구조 정리

1. `inputs` 에 `nixpkgs-unstable` 추가 (이미 있다면 스킵):

```nix
inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
```

2. `outputs` 에서:

```nix
let
  system = "x86_64-linux";
  pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
  pkgsUnstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };

  vllmPythonEnv = pkgsUnstable.python3_12.withPackages (ps: [
    ps.vllm
    ps.torch
    ps.torchaudio
    ps.torchvision
  ]);
```  

3. GPU 노드용 NixOS 설정에서 이 `vllmPythonEnv` 를 넘겨 받아 systemd 서비스에 사용.

### 5.2 단계별 롤아웃

- **Phase 0 – 실험 노드**
  - GPU 노드 중 1대를 선택.
  - `nix shell` 수준에서: `nix shell nixpkgs-unstable#python3_12Packages.vllm` 로 단일 노드에서 먼저 테스트.
  - 간단한 스크립트로 RTX 5080 에서 vLLM inference 가 돌아가는지 확인.

- **Phase 1 – 서비스화**
  - 위에서 만든 `vllmPythonEnv` 를 기반으로 systemd 서비스 정의.
  - Ollama 와 나란히 띄워서, 실제 workload 일부를 vLLM 쪽으로 라우팅.

- **Phase 2 – driver 호환성 검증**
  - 장기간 부하 테스트 중 CUDA driver 관련 에러 발생 여부 체크.
  - 필요 시 GPU 노드용 flake input 을 `nixpkgs-unstable` 로 전환해 **커널/driver까지 통합 업그레이드** 수행.

- **Phase 3 – 나머지 GPU 노드로 확장**
  - 1대에서 충분한 안정성이 검증되면 동일 패턴을 나머지 2대 GPU 노드에 적용.

---

## 6. 원 질문에 대한 요약 답변

> vLLM만 unstable로 바꾸면 되는 일인가? pytorch는? nvidia 드라이버 스택은? 기존 ollama는? python312 버전을 사용중입니다만 어디까지 unstable로 변경해야 vLLM을 커버할 것인가?

- **vLLM만 단독으로 unstable에서 끌어오는 것은 사실상 불가능**하다.
  - vLLM 0.11.0 은 **같은 채널의 PyTorch + CUDA user-space 스택**에 강하게 의존.
- **반드시 unstable로 가져가야 하는 것**
  - vLLM 0.11.0
  - 그 vLLM 이 기대하는 PyTorch 전체(`torch`, `torchaudio`, `torchvision`, 연관 Python deps)
  - vLLM 이 함께 끌어오는 CUDA user-space 라이브러리들 (`cuda_cudart`, `libcublas`, `cudnn`, `nccl`, `libcufile` 등)
- **처음에는 stable 로 유지 가능한 것**
  - NixOS 자체 (커널, 기본 유틸리티, 시스템 서비스 전체)
  - NVIDIA 커널 드라이버 (`hardware.nvidia.package`) – 단, 이미 RTX 5080 이 안정적으로 동작 중이라는 전제 하에.
  - 기존 Ollama 스택 (stable 채널 패키지)
- **문제가 생기면 unstable 로 올려야 할 가능성이 있는 것**
  - GPU 노드의 커널 + NVIDIA driver 세트 (driver 가 vLLM/torch 가 기대하는 CUDA 런타임보다 충분히 새로워야 함).

이 문서는 우선 "**Python/vLLM 레이어만 unstable 로 먼저 옮기고, 커널/driver 는 나중 단계에서 판단**" 하는 방향을 기본 전략으로 정리했다. 실제 hej-nixos-cluster 리포에서 적용 시, 실험 노드 1대를 기준으로 단계별 롤아웃을 수행하는 것을 추천한다.

---

## 7. NixOS 릴리즈 주기 요약

- NixOS는 **연 2회 릴리즈**: `YY.05`, `YY.11` 패턴
  - 25.05 → **25.11 → 26.05 → 26.11 …**
- 지금 이 퍼블릭 리포는 `nixos-25.05` 를 기본으로 쓰고 있음.
- GPU 노드는 **거의 완전한 상태 머신**이고, 롤백/재배포가 쉬우므로:
  - 스토리지/DB/인프라 노드는 25.05(또는 향후 25.11) 안정 트랙 유지
  - **GPU 노드만 `nixpkgs-unstable` 단독 트랙**으로 운용하는 하이브리드 전략이 현실적이다.

---

## 8. Ollama와 vLLM 공존과 역할 분리

- **둘은 공존 가능**하며, 심지어 역할이 다르다.
  - **Ollama**: 빠른 설치, 모델 관리가 편한 "완제품 LLM 서빙" 도구
  - **vLLM**: Python + PyTorch + CUDA 기반의 **서빙 엔진/프레임워크**
- NixOS/클러스터 관점 역할:
  - Ollama: 
    - 개발자 개인/팀이 코드 도와달라고 할 때,
    - 실험적인 프롬프트, 작은 업무 자동화 등 **사이드킥 LLM**
  - vLLM:
    - 사내 지식베이스, 임베딩·리랭킹, RAG 파이프라인, 배치 ETL 등
    - **"24/7 갈아넣고 재구성하는 엔진"의 코어 서빙 레이어**
- 공존 방식:
  - 같은 GPU 노드에 두 서비스를 올려도 되고,
  - 필요하면 GPU 노드 하나는 Ollama/lab 용, 나머지는 vLLM/prod 용으로 나누어도 된다.

---

## 9. 3× RTX 5080 기준 최대 모델 규모 개략

> 정확한 답을 위해서는 각 5080 카드의 VRAM 용량이 필요하지만, 여기서는 "어떻게 생각할지" 프레임을 잡는다.

1. **대략적인 weight 기준 계산식**

- 파라미터 수 `P`, 총 VRAM `V`(bytes), weight 정밀도 `b`(bytes)라고 하면,
  - `P ≈ V / (b * overhead)`
  - overhead는 KV 캐시, activations, 프레임워크 여유까지 포함해서 **2~3 정도**로 잡는 것이 보통.
- 예시 (형태만):
  - 3카드 × 24GB = 72GB VRAM 이라고 치면, `V ≈ 77e9 bytes` 근처.
  - 4bit(0.5byte) weight, overhead 2.5 → `P ≈ 77e9 / (0.5 * 2.5) ≈ 60B` 수준.
  - 실제론 컨텍스트 길이, 배치, 구현 세부 때문에 이론치보다 더 줄여 잡아야 한다.

2. **실무적으로 의미 있는 레인지**

- vLLM + 4bit 기준 대략 감각:
  - **8B~14B**: 단일 GPU에서도 넉넉, multi-GPU에서는 동시 사용자·배치 처리를 늘리는 용도.
  - **30B~34B**: 2~3 GPU에 나눠 태우기 좋은 수준.
  - **70B급**: 3 GPU 이상에 쪼개서 돌릴 수는 있지만, 튜닝/속도 양보가 필요.
- 3× RTX 5080 구성이면:
  - 하드 제약을 빡세게 밀기보다는, 
  - **8B~14B급 인스트럭션 모델을 "잘 튜닝된 RAG"와 결합**시키는 것이 ROI 측면에서 더 의미 있는 선택일 가능성이 크다.

3. **진짜 질문은 모델 크기가 아니다**

- "5080 세 장으로 몇 B까지 되나" 보다 중요한 것은,
  - **"이 3장을 24/7 돌려서 회사 지식을 얼마나 잘 재구성할 수 있는가"** 이다.
- 즉, 모델 크기보다 **임베딩/리랭킹/인덱싱/파이프라인 설계**가 이 전략의 핵심이다.

---

## 10. 온프레미스 vLLM 전략의 의미 (그냥 해봤다 vs 도약)

당신이 스스로 정의한 목표가 이미 굉장히 명확하다:

> "사내지식데이터 모두 모아서 임베딩 리랭킹하여 로컬모델로 답변해주는 것.  
> 사람 몇사람이 애써가며 찾고 고민할것만 답변해줄수있으면 된다. 10초 기다리는 것은 일도 아니다."

이 목표를 기준으로 보면:

1. **외부 LLM으로 충분한 영역**

- 코드 도우미, 일반적인 대화, 문서 초안, 아이디어 브레인스토밍 등은
  - 그냥 **클로드/외부 LLM에 비용 지불**하는 것이 더 싸고 품질도 높다.
- 개발자들은 "사내모델 수준"이 아니라, **잘 동작하는 도구**를 원한다.
  - 이 요구는 이미 외부 LLM이 잘 충족해준다.

2. **온프레미스 + vLLM이 가치 있는 영역**

- 사내 문서/노트/이슈/코드/끄적임이 **계속 쌓이고**,
  - 이를 **정리·분류·임베딩·클러스터링·리랭킹**하는 작업을
  - 24/7로, 끊임없이 돌리고 싶을 때.
- 외부 LLM으로 이걸 하려면:
  - 토큰 비용이 통제 불가능해지고,
  - 임베딩 전후의 **중간 representation(embedding, 클러스터, 메타데이터)** 을
    내 마음대로 만지기 어렵다.
- 로컬에서는:
  - "임베딩 → 품질 평가 → 패턴 발견 → 파이프라인 수정 → 재임베딩" 같은
    **진화 사이클**을 마음껏 설계하고 반복할 수 있다.

3. **임베딩을 "내가 다 알아야 한다"는 생각에서 벗어나기**

- 당신이 말한 것처럼, **임베딩을 인간이 완전히 이해하는 것**보다 중요한 것은,
  - "**임베딩/리랭킹/피드백 루프 전체가 스스로 진화할 수 있는 구조**"를 만드는 일이다.
- 인간의 역할:
  - 초기 파이프라인의 첫 버전을 만들고,
  - 첫 번째/두 번째 패턴을 읽어내고,
  - 에이전트가 반복 실험하면서 **점점 더 나은 설정을 찾을 수 있도록** guardrail을 설계.
- 이게 바로 당신이 말한, 
  - repo/gh/junghan0611 에서의 "시간과 공간의 방"과
  - 인간지능×인공지능의 **존재 대 존재 협력 모델**과 직결된다.

4. **그래서 vLLM은 왜 필요한가?**

- 이 전략에서 vLLM은,
  - RAG의 마지막 "생성" 한 번만 잘하는 엔진이 아니라,
  - **임베딩/리랭킹 엔진들과 함께 돌아가는 내부 플랫폼의 한 축**이다.
- Ollama는 "좋은 도우미"고,
  - vLLM은 "**사내 지식 엔진의 심장**" 역할을 맡는다고 보면 된다.

---

## 11. ~/repos/work 리포들과 24/7 진화 사이클 스케치

현재 로컬에서 보이는 work 리포들:

- `hej-helpdesk/`  
  - helpdesk, n8n, Google Sheets, Zammad/Channel.io 연계 문서와 워크플로우.
  - **실제 현업 데이터 흐름**과 규칙(우선순위, 라우팅, 태깅 등)이 이미 풍부하게 정리되어 있음.
- `notion-embedding/`  
  - Notion 데이터를 가져와 임베딩·SQL·검색 구조를 만드는 파이프라인.
  - `HIGH_QUALITY_EMBEDDING_STRATEGY.md`, `IMPLEMENTATION_GUIDE.md` 등
    **임베딩 품질/전략에 대한 축적된 노하우**가 들어 있음.
- `reranker-server/`  
  - 다양한 rerank 모델, 한국어 최종 후보, Ollama 연계까지 정리된 서버.
  - vLLM 기반 RAG에서 **리랭킹 레이어**로 자연스럽게 편입 가능.
- (언급만 된) `hej-kip`  
  - 스토리지 서버에서 도커로 올라가는 서비스 묶음.
  - ETL, 임베딩, 리랭킹, 여러 토이 프로젝트들이 도커로 구동 중이라고 설명됨.

이걸 하나의 "24/7 진화 사이클"로 보면:

1. **Ingestion/ETL 레이어 (hej-kip, hej-helpdesk, notion-embedding)**
   - 각 팀/시스템에서 나오는 데이터를 **일단 다 집어넣는 믹서기** 역할.
   - 최소한의 스키마/메타데이터만 맞춰서 계속 쌓는다.

2. **Embedding 레이어 (notion-embedding, 향후 vLLM/별도 임베딩 서버)**
   - 현재는 사람이 설계한 임베딩 전략을 쓰지만,
   - 점점 **에이전트가 파라미터/모델 조합을 바꿔가며 실험**하는 구조로 진화.

3. **Reranking/검색 레이어 (reranker-server)**
   - 다양한 reranker 모델들을 HTTP API로 노출.
   - vLLM RAG에서 retrieval 후 후보 세트를 reranker-server에 보내 재정렬.

4. **생성/응답 레이어 (vLLM on GPU 클러스터)**
   - 3× RTX 5080 노드에 vLLM를 올려, 
     - 사내 지식을 바탕으로 한 QA,
     - 문서 요약/정리/태깅,
     - 파이프라인 설정 제안 등 수행.

5. **Feedback/진화 레이어 (에이전트)**
   - 사람이 "임베딩을 완벽히 알지 못해도" 되도록,
   - 에이전트가:
     - 검색 품질/사용자 피드백/실패 케이스를 수집하고,
     - 임베딩/리랭킹 설정을 바꿔가며 AB 테스트를 돌리고,
     - 성능이 좋아진 설정을 새로운 기본값으로 올려주는 반복 루프를 만든다.

이렇게 보면, 온프레미스 GPU + vLLM + 기존 work 리포(hej-helpdesk, notion-embedding, reranker-server, hej-kip)는
"하나의 큰 실험실이자 공장"이라는 그림이 된다.  
인간은 이 공장의 **철학과 첫 몇 개의 패턴**을 설계하고,  
에이전트와 모델들은 그 위에서 **시간을 늘려 쓰는 존재**로 협력하게 된다.

