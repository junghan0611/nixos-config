# NEXT — upgrade/nixos-2605

> 브랜치 전용 핸드오프. main 병합 전 이 파일 삭제(내용은 ROADMAP.md로 승격).
> 목표: **25.11(deprecated) → 26.05** 릴리즈 이관 + **pnpm 단일화** + **오버레이 대청소**.

## 왜 이 브랜치

- 25.11은 deprecated. pnpm_11은 25.11 채널엔 있으나 우리 lock(5/5 rev)엔 없어 `pnpm_11` 참조가 깨졌다.
- rev 추가/25.11 내부 bump는 곧 버려질 작업 → **26.05 직행**으로 확 잡는다.
- 철학: `_xx` 버전 핀 지양(그냥 `nodejs`/`python3`/`pnpm`), 26.05 미지원/미사용은 아예 제외,
  버전 변동 큰 툴(codex/claude-code 등)은 nix에 안 넣고 pnpm global로.

## 완료 (config, eval GREEN)

- `flake.nix`: nixpkgs `nixos-26.05`, home-manager `release-26.05`. **오버레이 전부 삭제 → `overlays = [ ]`**.
  input은 `nixpkgs`/`disko`/`home-manager`만. (unstable·pinned·claude-desktop·zmx 입력 삭제)
  - 26.05 네이티브가 종전 오버레이 이상 커버: ghostty 1.3.1 · chrome 148 · bun 1.3.13 · scrcpy 4.0 ·
    edge 145.0.3800.70(URL 수정됨) · tdlib 1.8.65 · pnpm 11.9.0.
- fallout 수리: `services.ollama.acceleration` → `package = pkgs.ollama-vulkan` (thinkpad.nix);
  `neofetch` → `fastfetch`; `nodePackages.asar`는 claude-desktop 삭제로 해소;
  `xfce.thunar-volman` → `pkgs.thunar-volman` (top-level 이동).
- 버전 언핀: `nodejs_24`/`nodejs_22` → `nodejs`(7파일), `python312*` → `python3*`(6파일).
- pnpm 단일화(nix 쪽): `shell.nix` sessionPath에서 부모 `$PNPM_HOME` 제거(‘/bin’만),
  `.bashrc`의 부모 PATH 주입 블록 제거, **`~/.config/pnpm/rc`** home-manager 관리로 신설
  (`manage-package-manager-versions=false` + `global-bin-dir=$PNPM_HOME/bin`).
  ※ npm auth 토큰이 든 `~/.npmrc`는 건드리지 않음(pnpm 전용 rc로 분리).
- `nixos-rebuild dry-build .#thinkpad` **exit 0**. 규모: 614 로컬 빌드 + 3399 fetch(10.1 GiB↓/31.4 GiB).

## 다음 (실행 순서 — 단계적, oracle 최후)

1. **thinkpad 실빌드**: `nixos-rebuild build --flake .#thinkpad` (switch 아님) — build-time 실패 surface + 캐시 prime.
2. **thinkpad switch → 검증**: 재부팅/재로그인 후 `which -a pnpm`이 **1개**(nix, 11.9.0)인지,
   GUI(chrome/edge/ghostty/scrcpy), telega(tdlib), ollama-vulkan 동작.
3. **entwurf 런타임 청소(thinkpad, nix로 안 지워짐)**: switch 뒤 entwurf 담당이 수행 —
   `~/.local/share/pnpm/.tools`(self 11.5.0)·self-shim(pnpm/pnpx/pn/pnx)·`global/5` 서랍 삭제,
   글로벌 재설치(pnpm add -g …)를 `$PNPM_HOME/bin`으로 수렴. `pnpm setup`/`self-update` 금지.
4. **laptop → nuc** 순차 switch + 검증.
5. **oracle 최후**: 디스크 여유 먼저(`run.sh C)` prune) → switch →
   **OpenClaw 6봇 모델 prefix + caddy 6세트 전수 검증**(nixos-config 스킬/ORACLE.md 규약).

## 후속/미결 (별도)

- **zmx 재도입**: 이번에 제외(zmx flake의 zig15 ↔ 26.05 zig16 충돌 우려). 26.05 zig16으로 빌드되는지
  별도 확인 후 재추가. 그때까지 `zmx` CLI 부재.
- **eval 경고(비차단, stateVersion<26.05라 legacy 유지)**: `neovim.withRuby`/`withPython3` 기본 true→false,
  `gtk.gtk4.theme` 기본 변경. silence하려면 명시값 설정 — 지금은 legacy 유지로 무해.
- Edge 관련 `flake.nix` 상단 "nixpkgs-pinned" 주석은 이미 입력과 함께 삭제됨(확인용).

## 검증 기준

- `which -a pnpm` = 1줄, `pnpm --version` = 11.9.0.
- `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` 각 host GREEN.
- oracle: 봇 6대 GREEN + caddy 6세트 정상.

## 금지

- oracle를 먼저 switch하지 말 것(검증된 x86 기기 통과 후 최후).
- `~/.npmrc`(auth 토큰)를 home-manager로 덮지 말 것.
- 커밋/푸시는 GLG. push 전 git-hooks 통과 확인.
