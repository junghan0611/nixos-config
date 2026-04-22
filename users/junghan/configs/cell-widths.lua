-- WezTerm per-codepoint cell width override.
--
-- 왜 필요한가:
--   WezTerm 의 `unicode_version` / `treat_east_asian_ambiguous_width_as_wide`
--   는 UAX #11 분류(A/W/N)만 건드린다. 하지만 문제 글리프 다수가 "Neutral(N)"
--   로 분류돼 있어 — ☀☁☂ 같은 weather symbols — 어떤 wezterm 옵션으로도
--   2셀이 되지 않는다. Emacs `char-width-table` 은 2셀 선언, WezTerm 은 1셀
--   할당 → 3층 합의 결렬 → "Unicode Cell Drift".
--
--   `cell_widths` 는 코드포인트 범위별로 셀 폭을 명시 지정하는 테이블.
--   Emacs 쪽 선언과 정확히 같은 범위로 맞추면 드리프트가 사라진다.
--
-- 참고:
--   https://github.com/wezterm/wezterm/issues/6289
--   https://github.com/hamano/dotfiles/blob/master/.config/wezterm/eaw-console.lua
--
-- 동기화 규칙:
--   lisp/korean-input-config.el 의 char-width-table dolist 와 **동일 범위** 를
--   유지해야 한다. 한쪽만 바꾸면 드리프트 재발.
--
-- llmlog 우선순위:
--   "필수" 대역 (섹션 10/11/14) 은 이미 정합 → 이 파일에선 "허용/중요" 대역을
--   2셀로 고정해 편집 경험을 보호한다.

return {
  -- Variation Selectors (U+FE00-FE0F) — VS1..VS16, 결합문자 → width 0
  -- VS-16 (FE0F) 이모지 presentation 시 기저 글리프에 합쳐져야 함.
  {first = 0xFE00, last = 0xFE0F, width = 0},

  -- Dashes (U+2010-2015) — 하이픈·en-dash·em-dash·horizontal bar.
  -- UAX #11 상 Ambiguous(A)라 wezterm이 2셀로 올려버린다. Emacs char-width-table
  -- 은 기본 1로 두므로 cell 폭이 어긋나 "— 뒤에 공백 하나 더" 드리프트 발생.
  -- 1셀로 고정해 정합.
  {first = 0x2010, last = 0x2015, width = 1},

  -- Box Drawing (U+2500-257F) — ─ │ ┌ ┐ ┘ ┤ ┬ 등.
  -- 전 범위 Ambiguous. 모드라인/프롬프트/테이블 경계선에서 정렬 치명적.
  -- TTY 모드라인·tty-config.el vertical-border(U+2502) 와 정합을 맞추려면 1셀.
  {first = 0x2500, last = 0x257F, width = 1},

  -- Miscellaneous Technical (U+2300-23FF) — ⌚⌛⏰⏳⏱
  {first = 0x2300, last = 0x23FF, width = 2},

  -- Arrows (U+2190-21FF)
  {first = 0x2190, last = 0x21FF, width = 2},

  -- Enclosed Alphanumerics (U+2460-24FF) — ①②③ⓐⓑⓒ
  {first = 0x2460, last = 0x24FF, width = 2},

  -- Misc Symbols (U+2600-26FF) — ☀♠⚠ 혼잡지대
  {first = 0x2600, last = 0x26FF, width = 2},

  -- Dingbats (U+2700-27BF) — ✂✈✉❤
  {first = 0x2700, last = 0x27BF, width = 2},

  -- Misc Symbols and Arrows 일부 (⭐⭕)
  {first = 0x2B50, last = 0x2B55, width = 2},

  -- Mahjong / Domino / Playing Cards (U+1F000-1F0FF)
  {first = 0x1F000, last = 0x1F0FF, width = 2},

  -- Enclosed Alphanumeric Supplement (U+1F100-1F1FF) — 🄌🅰🅱 + Regional Indicators (국기)
  {first = 0x1F100, last = 0x1F1FF, width = 2},

  -- Misc Symbols and Pictographs (U+1F300-1F6FF)
  {first = 0x1F300, last = 0x1F6FF, width = 2},

  -- Alchemical / Geometric Shapes Extended (U+1F700-1F7FF)
  {first = 0x1F700, last = 0x1F7FF, width = 2},

  -- Supplemental Symbols and Pictographs (U+1F900-1F9FF)
  {first = 0x1F900, last = 0x1F9FF, width = 2},

  -- Chess / Symbols and Pictographs Extended-A (U+1FA00-1FAFF)
  {first = 0x1FA00, last = 0x1FAFF, width = 2},
}
