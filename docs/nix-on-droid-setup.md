# Nix-on-Droid 설정 가이드

Android 환경에서 Nix 패키지 매니저를 사용하기 위한 설정 가이드입니다.

## 목차

1. [F-Droid에서 설치 후 초기 설정](#1-f-droid에서-설치-후-초기-설정)
2. [기본 패키지 설치](#2-기본-패키지-설치)
3. [Git 및 SSH 설정](#3-git-및-ssh-설정)
4. [Flake 기반 설정으로 전환](#4-flake-기반-설정으로-전환)
5. [이 저장소와 통합](#5-이-저장소와-통합)
6. [문제 해결](#6-문제-해결)

---

## 1. F-Droid에서 설치 후 초기 설정

### 1.1 앱 권한 설정

F-Droid에서 Nix-on-Droid 설치 후:

1. **저장소 접근 권한** 부여 (Android 설정 → 앱 → Nix-on-Droid → 권한)
2. 앱 실행 후 **OK** 누르면 수백 MB 다운로드 시작
3. 다운로드 완료까지 대기 (Wi-Fi 권장)

### 1.2 기본 설정 파일 생성

첫 번째 bash 프롬프트에서:

```bash
# 기본 설정 파일 생성
mkdir -p ~/.config/nixpkgs

cat > ~/.config/nixpkgs/nix-on-droid.nix << 'EOF'
{ pkgs, ... }:

{
  # 기본 패키지 설치
  environment.packages = with pkgs; [
    # 필수 도구
    git
    vim
    openssh
    curl
    wget

    # 개발 도구
    ripgrep
    fd
    jq
    tree
    htop

    # Nix 개발
    nil  # Nix LSP
    nixfmt-classic
  ];

  # 환경 변수
  environment.sessionVariables = {
    EDITOR = "vim";
    LANG = "en_US.UTF-8";
  };

  # 타임존 설정
  time.timeZone = "Asia/Seoul";

  # MOTD (Message of the Day)
  environment.motd = ''
    Welcome to Nix-on-Droid!
    Run 'nix-on-droid help' for available commands.
  '';

  # 시스템 버전 (변경하지 않음)
  system.stateVersion = "24.05";
}
EOF
```

### 1.3 설정 적용

```bash
# 설정 적용 (첫 실행 시 시간이 걸림)
nix-on-droid switch

# 도움말 확인
nix-on-droid help
```

---

## 2. 기본 패키지 설치

### 2.1 nix-on-droid 명령어

| 명령어 | 설명 |
|--------|------|
| `nix-on-droid switch` | 설정 파일 적용 |
| `nix-on-droid rollback` | 이전 설정으로 되돌리기 |
| `nix-on-droid generations` | 세대 목록 확인 |
| `nix-on-droid help` | 도움말 |

### 2.2 임시 패키지 사용

설정 파일 수정 없이 임시로 패키지 사용:

```bash
# 일회성 셸
nix-shell -p python3 nodejs

# Flakes로 패키지 실행
nix run nixpkgs#cowsay -- "Hello from Android!"
```

---

## 3. Git 및 SSH 설정

### 3.1 Git 설정

```bash
# Git 사용자 정보 설정
git config --global user.name "Junghan Kim"
git config --global user.email "your-email@example.com"
git config --global init.defaultBranch main
```

### 3.2 SSH 키 생성 및 설정

```bash
# SSH 디렉토리 생성
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# SSH 키 생성 (GitHub용)
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/id_ed25519

# 공개 키 확인 (GitHub에 등록)
cat ~/.ssh/id_ed25519.pub

# SSH 설정 파일
cat > ~/.ssh/config << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config
```

### 3.3 SSH 서버 설정 (PC에서 폰 접속용)

`~/.config/nixpkgs/nix-on-droid.nix`에 추가:

```nix
{ pkgs, lib, ... }:

{
  # ... 기존 설정 ...

  # SSH 서버 활성화 스크립트
  build.activation.sshd = lib.hm.dag.entryAfter ["installPackages"] ''
    $DRY_RUN_CMD mkdir -p ~/.ssh

    # 호스트 키 생성 (없는 경우에만)
    if [ ! -f ~/.ssh/ssh_host_rsa_key ]; then
      $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f ~/.ssh/ssh_host_rsa_key -N ""
    fi

    # sshd 설정 파일
    $DRY_RUN_CMD cat > ~/.ssh/sshd_config << SSHD_EOF
Port 8022
HostKey $HOME/.ssh/ssh_host_rsa_key
AuthorizedKeysFile $HOME/.ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
PrintMotd yes
AcceptEnv LANG LC_*
SSHD_EOF

    # sshd 시작 스크립트
    $DRY_RUN_CMD cat > $HOME/.local/bin/sshd-start << 'SCRIPT_EOF'
#!/bin/sh
echo "Starting sshd on port 8022..."
exec ${pkgs.openssh}/bin/sshd -f ~/.ssh/sshd_config -D
SCRIPT_EOF
    $DRY_RUN_CMD chmod +x $HOME/.local/bin/sshd-start
    $DRY_RUN_CMD mkdir -p $HOME/.local/bin
  '';
}
```

PC에서 접속:

```bash
# PC의 공개 키를 폰에 등록
# 폰에서:
echo "ssh-ed25519 AAAA... your-pc-key" >> ~/.ssh/authorized_keys

# PC에서 접속:
ssh -p 8022 nix-on-droid@<폰-IP-주소>
```

---

## 4. Flake 기반 설정으로 전환

### 4.1 Flake 활성화

```bash
# nix.conf 설정 (이미 활성화되어 있을 수 있음)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### 4.2 Flake 프로젝트 생성

```bash
# 설정 디렉토리
mkdir -p ~/nix-config
cd ~/nix-config

# flake.nix 생성
cat > flake.nix << 'EOF'
{
  description = "Nix-on-Droid configuration for Android";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-on-droid, home-manager }:
  let
    system = "aarch64-linux";
  in {
    nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      modules = [
        ./nix-on-droid.nix

        # Home Manager 통합
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            config = ./home.nix;
          };
        }
      ];
    };
  };
}
EOF
```

### 4.3 모듈 파일 생성

```bash
# nix-on-droid.nix
cat > nix-on-droid.nix << 'EOF'
{ pkgs, ... }:

{
  environment.packages = with pkgs; [
    git
    vim
    openssh
    curl
    wget
    ripgrep
    fd
    jq
    tree
    htop
    nil
    nixfmt-classic
  ];

  environment.sessionVariables = {
    EDITOR = "vim";
    LANG = "en_US.UTF-8";
  };

  time.timeZone = "Asia/Seoul";
  system.stateVersion = "24.05";
}
EOF

# home.nix (Home Manager 설정)
cat > home.nix << 'EOF'
{ pkgs, ... }:

{
  home.stateVersion = "24.05";

  programs.git = {
    enable = true;
    userName = "Junghan Kim";
    userEmail = "your-email@example.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -la";
      nod = "nix-on-droid";
      nod-switch = "nix-on-droid switch --flake ~/nix-config";
    };
  };

  programs.vim = {
    enable = true;
    defaultEditor = true;
    extraConfig = ''
      set number
      set relativenumber
      syntax on
    '';
  };
}
EOF
```

### 4.4 Flake 적용

```bash
cd ~/nix-config

# Git 초기화 (flake은 git repo가 필요)
git init
git add .

# Flake으로 적용 (--impure 플래그 필요)
nix-on-droid switch --flake .#default --impure
```

---

## 5. 이 저장소와 통합

이 nixos-config 저장소를 Nix-on-Droid에서도 사용하려면:

### 5.1 저장소 클론

```bash
# SSH 키 설정 완료 후
cd ~
git clone git@github.com:junghanacs/nixos-config.git
# 또는
git clone https://github.com/junghanacs/nixos-config.git
```

### 5.2 flake.nix에 Nix-on-Droid 설정 추가

`flake.nix`에 다음 input 추가:

```nix
inputs = {
  # ... 기존 inputs ...

  # Nix-on-Droid
  nix-on-droid = {
    url = "github:nix-community/nix-on-droid/release-24.05";
    inputs.nixpkgs.follows = "nixpkgs";  # 주의: 버전 호환성 확인 필요
  };
};
```

outputs에 추가:

```nix
outputs = { self, nixpkgs, nix-on-droid, ... }@inputs: {
  # ... 기존 nixosConfigurations ...

  # Nix-on-Droid 설정
  nixOnDroidConfigurations.phone = nix-on-droid.lib.nixOnDroidConfiguration {
    pkgs = import inputs.nixpkgs {
      system = "aarch64-linux";
      config.allowUnfree = true;
    };
    modules = [ ./machines/phone.nix ];
  };
};
```

### 5.3 machines/phone.nix 생성

```nix
{ pkgs, ... }:

{
  environment.packages = with pkgs; [
    git
    vim
    openssh
    curl
    wget
    ripgrep
    fd
    jq
    tree
    htop
  ];

  environment.sessionVariables = {
    EDITOR = "vim";
    LANG = "en_US.UTF-8";
  };

  time.timeZone = "Asia/Seoul";
  system.stateVersion = "24.05";

  # Home Manager 통합 (선택)
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    config = { pkgs, ... }: {
      home.stateVersion = "24.05";
      programs.git.enable = true;
    };
  };
}
```

### 5.4 폰에서 적용

```bash
cd ~/nixos-config
nix-on-droid switch --flake .#phone --impure
```

---

## 6. 문제 해결

### 터미널이 멈출 때

- 알림 바에서 **"Acquire wakelock"** 버튼 클릭
- 배터리 최적화에서 Nix-on-Droid 제외

### 저장소 접근 오류

```bash
# Android 설정에서 저장소 권한 확인
# 앱 → Nix-on-Droid → 권한 → 파일 및 미디어
```

### Flake 빌드 실패

```bash
# --impure 플래그 필수
nix-on-droid switch --flake .#default --impure

# Git tracked 파일 확인
git status
git add <새로운-파일>
```

### SSH 연결 실패

```bash
# 폰의 IP 주소 확인
ip addr show wlan0 | grep inet

# sshd 실행 확인
sshd-start  # 포그라운드에서 실행

# 포트 확인
netstat -tlnp | grep 8022
```

---

## 참고 자료

- [Nix-on-Droid 공식 매뉴얼](https://nix-community.github.io/nix-on-droid/)
- [Nix-on-Droid GitHub](https://github.com/nix-community/nix-on-droid)
- [Nix-on-Droid 설정 옵션](https://nix-community.github.io/nix-on-droid/nix-on-droid-options.html)
- [SSH 접속 위키](https://github.com/nix-community/nix-on-droid/wiki/SSH-access)
- [F-Droid 앱 페이지](https://f-droid.org/en/packages/com.termux.nix/)
