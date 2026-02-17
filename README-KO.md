# nixos-config

**재현 가능한 컴퓨팅 환경을 위한 NixOS 설정**

[English](./README.md)

---

## 개요

이 저장소는 **어디서나 동일한 컴퓨팅 환경**을 구축하기 위한 NixOS 및 home-manager 설정입니다.

### 핵심 목표

**재현 가능성 (Reproducibility)**
- 선언적 설정으로 전체 시스템을 코드로 관리
- 인간과 AI 에이전트가 동일한 투명한 시스템 공유
- 삽질 없이 전체 시스템 통제 가능

**확장성 (Scalability)**
- Oracle Cloud Free Tier VM 최적화 (높은 가성비)
- 로컬 머신(NUC, Laptop)에서 원격 서버까지 통합 관리
- NixOS 패키지 생태계 활용

**일관성 (Consistency)**
- Regolith Linux의 i3wm 워크플로우 유지
- [dotdoom-starter](https://github.com/junghan0611/dotdoom-starter)와 긴밀한 통합
- 터미널/Emacs 중심의 엄선된 도구들

---

## 주요 기능

### 🖥️ 윈도우 매니저

**i3wm (기본)**
- Regolith 3 스타일 gaps, borders, colors
- py3status + Emacs org-clock 통합
- 선언적 설정 (home-manager)
- picom compositor (Regolith 설정)

**GNOME (specialisation)**
- 선택 가능한 대체 데스크탑
- 부팅 메뉴에서 전환

### 📝 Emacs 통합

**Doom Emacs**
- [dotdoom-starter](https://github.com/junghan0611/dotdoom-starter) 연동
- mu4e 이메일
- org-mode + denote
- py3status로 현재 작업 표시

**도구:**
- edit-input: 웹 양식을 Emacs로 편집
- rofi-pass: 패스워드 관리
- Desktop 항목: Sync/Doctor/Upgrade Doom

### 🛠️ 개발 환경

**언어별 모듈**
- Python (jupyter, pandas, black, ruff)
- Nix (nixd, nil, nixfmt)
- C/C++ (lldb, clang-tools)
- LaTeX (texlive)
- Shell (shellcheck, shfmt)

**공통 도구**
- gh, lazygit, aider-chat
- direnv, nix-direnv

### 📦 home-manager 모듈 구조

```
users/junghan/modules/
├── default.nix           # Imports 통합
├── shell.nix             # git, bash, tmux, gpg
├── i3.nix                # i3 선언적 설정
├── dunst.nix             # 알림 시스템
├── picom.nix             # compositor
├── emacs.nix             # Doom Emacs
├── email.nix             # mu4e + mbsync
├── fonts.nix             # 커스텀 폰트
└── development/          # 언어별 환경
```

**리팩토링 결과:**
- Before: `home-manager.nix` 341줄
- After: 118줄 (-65%, 모듈화)

### 🐳 Docker 서비스 (Oracle VM)

Oracle Cloud ARM VM에서 셀프호스팅 서비스 운영:

| 서비스 | 포트 | 설명 |
|--------|------|------|
| [Remark42](https://remark42.com) | 80/443 | 셀프호스팅 댓글 시스템 (Let's Encrypt SSL) |
| [OpenClaw](https://openclaw.ai) | 18789 | AI 어시스턴트 게이트웨이 (Telegram + Claude) |

- Remark42: `comments.junghanacs.com` — GitHub/Google/Telegram/Anonymous 인증
- OpenClaw: Telegram 봇으로 모바일 상시 AI 접근 — SSH 터널로 Web UI

[`docker/`](./docker/) 디렉토리에 compose 파일 및 설정 가이드.

---

## 설치

### 디바이스 프로파일

| 프로파일 | 디바이스 | CPU | 용도 |
|---------|--------|-----|------|
| `thinkpad` | ThinkPad P16s Gen 2 | AMD Ryzen | 회사 노트북 |
| `laptop` | Samsung NT930SBE | Intel i7 | 개인 노트북 |
| `nuc` | Intel NUC | Intel i7 4-Core | 홈 서버 |
| `oracle` | Oracle Cloud VM | ARM (Ampere) | 원격 서버 (Free Tier) + Docker 서비스 |

### 요구사항

- NixOS 25.11+
- Flakes 활성화

### NUC / Laptop

```bash
# Clone
git clone https://github.com/junghan0611/nixos-config.git
cd nixos-config

# 호스트 설정 편집
vim hosts/nuc/configuration.nix
vim hosts/nuc/vars.nix

# 빌드 및 적용
sudo nixos-rebuild switch --flake .#nuc
```

### Oracle Cloud VM

Oracle Free Tier VM 설치는 `templates/nixos-oracle-vm/` 참조

**기반:** [mtlynch.io Oracle Cloud NixOS Guide](https://mtlynch.io/notes/nix-oracle-cloud/) (일부 수정)

---

## 사용법

### 시스템 관리

```bash
# 재빌드
sudo nixos-rebuild switch --flake .#nuc

# Flake 업데이트
nix flake update

# 설정 확인
nix flake check
```

### i3 키바인딩

| 키 | 기능 |
|----|------|
| `Mod+d` | rofi (combi) |
| `Mod+p` | rofi-pass |
| `Mod+i` | edit-input (Emacs) |
| `Mod+c` | picom 토글 |
| `Mod+n` | 알림 닫기 |
| `Mod+grave` | 알림 히스토리 |

### 이메일

```bash
# 동기화
mbsync -a

# Emacs mu4e
SPC o m
```

---

## 철학

### 재현성: 대장장이의 대장간

> "컴퓨터는 블랙박스가 아니라 **대장장이의 대장간**이다.
> 마스터(인간)가 도구를 통제하고, 조수(에이전트)는 돕지만, 도구 선택은 마스터의 권한 아래 있다."

**핵심 통찰**: 재현 가능한 컴퓨팅 환경은 인간-AI 협업의 필수 조건입니다.

**주요 원칙**:

**1. 재현성 = 신뢰**
```
전통적 OS:
  - "뭐가 설치되어 있지?" → 알 수 없음
  - "버전이 뭐지?" → 불명확
  - 에이전트: 추측, 시행착오

NixOS:
  - configuration.nix = 단일 진실의 원천
  - 에이전트: 정확하고 재현 가능한 작업
```

**2. 마스터의 통제권**
```
대장장이 (인간):
  - 도구 선택 (nixos-config)
  - 환경 통제
  - 최종 판단

도구 (컴퓨터):
  - 키보드, 에디터, 프로그래밍 언어
  - 확장된 신체

조수 (AI 에이전트):
  - 도와주지만, 도구는 선택하지 않음
  - 도구 선택 = 마스터의 영역
```

**3. 스케일: 데스크톱 → 데이터센터**
```
동일한 문법, 무한한 확장:
  - 데스크톱: configuration.nix
  - 서버: configuration.nix (동일 패턴)
  - 클러스터: flake.nix (동일 철학)

→ 한 번 배우면 모든 곳에 적용
```

**4. 에이전트를 위한 투명성**
```yaml
에이전트가 알아야 하는 것:
  - 당신의 도구는? (environment.systemPackages)
  - 당신의 에디터는? (programs.emacs)
  - 당신의 언어는? (pkgs.python311)

nixos-config가 제공:
  - 완전한 환경 명세
  - 정확한 버전 (flake.lock)
  - 완전한 투명성

→ 에이전트가 정확하고 작동하는 코드 생성
```

**더 읽기**: [NixOS: 재현성과 대장장이의 도구 철학](./docs/20251018T184200--nixos-재현성과-대장장이의-도구철학__nixos_philosophy_reproducibility_master.md)

---

## 참고 자료

### 영감을 받은 프로젝트

**NixOS 설정:**
- [hlissner/dotfiles](https://github.com/hlissner/dotfiles) - Doom Emacs maintainer
- [ElleNajt/nixos-config](https://github.com/ElleNajt/nixos-config) - home-manager 패턴

**가이드:**
- [mtlynch.io Oracle Cloud NixOS](https://mtlynch.io/notes/nix-oracle-cloud/)

**관련 프로젝트:**
- [dotdoom-starter](https://github.com/junghan0611/dotdoom-starter) - Doom Emacs 설정

---

## 문서

### 설정 가이드

- [CHANGELOG.md](./CHANGELOG.md) - 버전 히스토리 및 패키지 추적
- [패키지 설치 가이드](./docs/PACKAGE_GUIDE.md) - 패키지 추가 방법 (AI 에이전트 및 사용자용)
- [외부 패키지](./docs/EXTERNAL_PACKAGES.md) - NixOS 외부 패키지 (uv, pnpm, Docker)
- [키바인딩 참조](./docs/KEYBINDINGS.md) - i3 키바인딩

### Docker 서비스 가이드

- [Remark42 설정](./docker/remark42/SETUP.org) - 댓글 시스템 배포
- [OpenClaw 설정](./docker/openclaw/SETUP.org) - AI 게이트웨이 배포 (Telegram + Claude)

### 분석 및 전략

`docs/` 디렉토리 참조:
- 분석 문서 (denote 형식)
- 통합 계획
- 전략 가이드

---

## 라이선스

MIT License

---

## 저자

**Jung Han (junghanacs)**
- 블로그: [힣's 디지털가든](https://notes.junghanacs.com)
- GitHub: [@junghan0611](https://github.com/junghan0611)
- Email: junghanacs@gmail.com

---

**최종 업데이트**: 2026-02-17
