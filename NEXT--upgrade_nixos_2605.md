# NEXT — upgrade/nixos-2605

> 브랜치 전용 핸드오프. main 병합 전 이 파일 삭제(내용은 ROADMAP.md로 승격).
> 목표: **25.11(deprecated) → 26.05** 이관 + **pnpm 단일화** + **오버레이 대청소** + **외부패키지 SSOT화**.

## NOW — 다음 세션 첫 걸음 (디스크 정리, 원래 목표)

thinkpad 디스크 **92% / 여유 38G**. Phase A(재설치)로 CLI는 복구됨. **공간 회수가 남음.**
Phase A는 끝났으니 **B → C → D 순서로 실행**:

```bash
# B) 옛 pnpm 서랍 purge (~2GB + pnpm 단일화 완결)
pnpm remove -g @openai/codex @google/gemini-cli          # bin/에 남은 stale shim 제거
rm -rf ~/.local/share/pnpm/global/5 ~/.local/share/pnpm/.tools   # 옛 pnpm10 글로벌 + self pnpm(79M)
rm -f ~/.local/share/pnpm/{acorn,anthropic-ai-sdk,ccr,claude,clawdhub,cline,codex,copilot,gccli,gdcli,gmcli,gemini,pn,pnpm,pnpx,pnx,summarize,summarizer}  # parent orphan shim (PATH 밖)
#   ↑ clawhub/summarize/pi/netlify는 bin/에 재설치됐으니 parent 것 지워도 됨. claude/codex는 ~/.local/bin(curl)이라 무관.

# C) content store prune (참조 안 되는 CAS 회수 — store 20G 중)
pnpm store prune

# D) nix GC (25.11 잔재 + 옛 세대). run.sh C) 또는 직접.
#   ⚠️ 오래된 세대 삭제 = 25.11 롤백 표면 사라짐. thinkpad는 26.05 검증·재부팅 완료라 OK 판단이면 진행.
sudo nix-collect-garbage --delete-older-than 7d && nix-store --optimise && sudo journalctl --vacuum-size=200M
```

검증: `df -h /` 여유 늘었나, `which -a pnpm` = 1개(11.9.0), `pi`/`clawhub`/`summarize`/`netlify` 실행되나.

## DONE — 이번 세션 (전부 커밋됨)

| 커밋 | 내용 | push |
|---|---|---|
| fa52acf | 26.05 이관 + 오버레이 전면 삭제 + pnpm 단일화 | ✅ |
| 938b513 | picom v13 / flameshot deprecated 정리 | ✅ |
| 291cf4c | EXTERNAL_PACKAGES SSOT 일원화 + ghostty confirm-close false | ⬜ **push 필요** |
| 7d9af7e | run.sh e)/E) 외부패키지 SSOT 배선 | ⬜ **push 필요** |

- **thinkpad 26.05 switch + 재부팅 완료.** eval/picom 경고 0. pnpm 단일 **11.9.0**.
- 오버레이 전부 삭제(`overlays=[ ]`), input=nixpkgs/disko/home-manager만. nodejs_/python312 → 그냥 이름.
- pnpm 설정: `~/.config/pnpm/rc`(manage-package-manager-versions=false + global-bin-dir), sessionPath 부모 제거.
- **EXTERNAL_PACKAGES.md = pnpm 글로벌 SSOT** (`~/update-claude.sh` 폐기).
  - pnpm 유지: netlify-cli / clawhub / @steipete/summarize / typescript(+lsp) / (pi 최초 1회)
  - curl self-updater(무조건 이 버전): claude / codex / antigravity — URL 3종 문서에 기록
  - gog = 포크 로컬빌드(`~/repos/gh/gogcli`, go.mod=upstream이라 go install 불가)
  - 제거: gemini / ccr / copilot / cline / @mariozechner gccli·gdcli·gmcli / grammy
- **Phase A 재설치 완료**: netlify 26.1.0 / clawhub 0.23.1 / summarize 0.20.1 / ts+tsls / pi 0.80.3 → v11+bin/.

## PENDING 결정 (사용자 답 필요)

1. **문서 쓰레기 정리**: `EXTERNAL_PACKAGES.md`의 **gt/bd/bv/br(gastown+beads, 2026-02)** · **CLIProxyAPI(2026-02, ToS경고)** 아직 쓰나? 안 쓰면 **doc + run.sh e)/E) 핸들러 양쪽서 제거**.
2. **Mod+m (Emacs scratchpad) 회귀**: 데몬·`emacsclient -s user`·scratchpad-toggle 스크립트 다 정상 확인됨(버전 불일치 아님, emacs 30.2). **정확한 증상 필요**(무반응? 프레임은 뜨는데 scratchpad로 안 가나? 에러?). 바인딩: `users/junghan/modules/i3.nix:488`.

## 이후 (fleet 확산)

- **laptop → nuc → oracle(최후, 봇/caddy 검증)** 순차 switch. 4개 host 모두 26.05 eval GREEN 이미 확인.
  oracle: 디스크 prune 먼저(`run.sh C)`), switch 후 OpenClaw 6봇 + caddy 6세트 검수(스킬/ORACLE.md).
- **zmx 재도입**: 이번 제외(zmx flake zig15 ↔ 26.05 zig16). zig16 빌드 확인 후 재추가. 현재 `zmx` 부재.
- **push**: 로컬 커밋 2개(291cf4c, 7d9af7e) push (GLG). 이후 agenda 스탬프.

## 이미 해결된 26.05 회귀 (참고)

ollama acceleration→package / neofetch→fastfetch / xorg·xfce→top-level / nixfmt-classic→nixfmt /
gnome·gdm 옵션 rename / neovim withRuby·withPython3·gtk4.theme legacy 고정 / picom v13 6개 / flameshot checkForUpdates / ghostty confirm-close-surface.

## 금지

- oracle 먼저 switch 금지(검증된 x86 통과 후 최후). `~/.npmrc`(auth 토큰) home-manager로 덮지 말 것.
- Phase B `rm -rf`는 되돌릴 수 없음 — global/5·.tools만, store/·bin/·global/v11 건드리지 말 것.
