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

---

## 설치

### 요구사항

- NixOS 25.05+
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

### AI 시대의 시스템 관리

**투명성**
- 선언적 설정은 AI 에이전트가 이해하기 쉬움
- 숨겨진 상태나 매직 없음
- 전체 시스템을 코드로 추적 가능

**재현성**
- nix-shell은 AI 에이전트에게 명확한 개발 환경 제공
- "내 컴퓨터에서는 되는데"가 없음
- 협업의 신뢰성 향상

**효율성**
- 설정 공유와 재사용
- 여러 머신 관리 오버헤드 최소화
- 롤백으로 실험 부담 감소

**크로스 플랫폼**
- home-manager는 macOS, WSL에서도 사용 가능
- 일관된 홈 환경

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

**최종 업데이트**: 2025-10-08
