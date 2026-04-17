# nixos-config MEMORY.md

리포 특화 디버깅 노트. Claude Code, pi, 다른 에이전트 모두 참조.
일반 개발 메모리는 `~/.claude/projects/-home-junghan-repos-gh-nixos-config/memory/MEMORY.md`에.

---

## 폰트 3층 레이어 (2026-04-17)

이모지/폰트가 앱에서 "왜 이렇게 뜨지?"일 때, **한 곳 고쳐서 안 풀리면 다른 층도 의심**.

### 레이어 A — 시스템 fontconfig

- 진단: `fc-match emoji`, `fc-list | grep -i <패턴>`
- 기본값 설정처: `machines/shared.nix` → `fonts.fontconfig.defaultFonts.{serif,sansSerif,monospace,emoji}`
- **함정**: `fonts.enableDefaultPackages = true`가 자동으로 6개 폰트 추가. 여기에 `noto-fonts-color-emoji` 포함. `packages` 리스트에서 빼도 이게 `true`면 다시 들어옴.
- **해결**: `enableDefaultPackages = false`로 끄고, 원하는 기본 폰트만 명시 — `dejavu_fonts, freefont_ttf, gyre-fonts, liberation_ttf, unifont`.
- 추적 도구: `nix why-depends /run/current-system /nix/store/...-noto-fonts-color-emoji-...`

### 레이어 B — 앱 자체 내장 폰트 (WezTerm)

- WezTerm은 바이너리에 `JetBrainsMono`, `Noto Color Emoji`, `Nerd Font Symbols`를 **내장**. `font_dirs`로 끌 수 없음.
- `font_with_fallback` 리스트 뒤에 **내장이 자동 append**됨 — 글리프가 없으면 내려감.
- **해결**: fallback 항목에 `{ family = "Noto Emoji", assume_emoji_presentation = true }` 명시. WezTerm이 이모지 글리프 해결을 거기서 종료 → 내장까지 내려가지 않음.
- 검증: `wezterm ls-fonts` 출력에서 `BuiltIn` 항목이 사라져야 완료.

### 레이어 C — Emacs/데몬 캐시

- Emacs daemon은 시작 시 폰트셋을 캐싱. 시스템 바꿔도 재시작 전까진 옛 폰트 참조.
- **해결**: `pkill -USR2 emacs` 또는 수동 재시작. telega/describe-char로 확인.

### "완전 제거" 플로우

```
1. machines/shared.nix:
   - fonts.enableDefaultPackages = false
   - packages에서 noto-fonts-color-emoji, noto-fonts-emoji-blob-bin 제거
   - defaultFonts.emoji = [ "Noto Emoji" "Symbola" ]
2. wezterm.lua:
   - { family = "Noto Emoji", assume_emoji_presentation = true }
3. sudo nixos-rebuild switch --flake .#<profile>
4. WezTerm 재시작 (pkill -f wezterm-gui)
5. Emacs daemon 재시작
6. fc-match emoji  → Noto Emoji
7. fc-list | grep -i 'color.?emoji'  → 빈 출력
8. wezterm ls-fonts  → BuiltIn 없음
```

---

## 리빌드 날짜의 착각

`readlink /run/current-system` 결과의 날짜(예: `nixos-system-thinkpad-25.11.20260415.1766437`)는
**nixpkgs flake.lock의 `lastModified` 기준**이지 리빌드 시각이 아님.

리빌드가 실제로 됐는지는 **store path 해시**(예: `872yd9...`)가 바뀌었는지로 판단.
`sudo nix-env --list-generations --profile /nix/var/nix/profiles/system`의 생성 시간이 실제 리빌드 시각.

---

## shared.nix 변경의 영향 범위

`machines/shared.nix`는 **thinkpad/nuc/laptop/oracle 모두 공통** import.
한 번의 수정이 4개 머신 전부에 영향. 각 머신별로 별도 `nixos-rebuild switch` 필요.

Oracle은 OpenClaw 운영 중 → 롤아웃 타이밍 조심. `~/AGENTS.md`의 `OpenClaw operational context` 참조.
