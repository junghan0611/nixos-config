-- WezTerm configuration for NixOS
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Window appearance
config.window_background_opacity = 0.85
config.text_background_opacity = 0.85
config.window_decorations = "TITLE | RESIZE"

-- Tab bar
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false

-- Font
-- Fallback 순서: GLG(기본) → Noto 심볼 시리즈(좁은 범위부터) → Noto Emoji(최종).
-- assume_emoji_presentation=true 가 이모지 코드포인트를 Noto Emoji 에서 끝내 주므로
-- 번들된 Noto Color Emoji 까지 내려가지 않는다.
-- scale=0.9 는 이모지 글리프가 셀을 넘어 인접 컬럼을 먹는 것을 막는 용도.
-- Symbola 제거 — Noto Sans Symbols 1/2 + Math 가 커버리지 대체, 유지보수도 살아있음.
config.font = wezterm.font_with_fallback({
    "GLG Nerd Font Mono",
    "Noto Sans Symbols",
    "Noto Sans Symbols 2",
    "Noto Sans Math",
    "Noto Music",
    "Noto Znamenny Musical Notation",
    { family = "Noto Emoji", assume_emoji_presentation = true, scale = 0.9 },
})
config.font_size = 15.1

-- 유니코드 셀 폭 합의 —
-- cell_widths: per-codepoint 명시 테이블. UAX #11 의 A/W/N 분류가 Emacs 와
-- 맞지 않는 대역(☀☁☂ 같은 Neutral 포함)을 강제로 2셀로 고정한다.
-- 같은 범위가 korean-input-config.el 의 char-width-table 에도 설정돼 있다.
-- ref: https://github.com/wezterm/wezterm/issues/6289
--
-- unicode_version 은 기본값(9) 유지. v14 는 VS-16 등 presentation selector 를
-- "존중" 해 폭을 추가로 승격시키는데, cell_widths 가 이미 명시했으면 오히려
-- 경쟁(base=2 cell_widths + VS-16 승격)으로 드리프트 유발.
-- 어차피 Noto Emoji (mono) 로 고정돼 있어 VS-16 의 컬러 이모지 요청 효과 불필요.
config.unicode_version = 16
config.cell_widths = require 'cell-widths'

-- Prevent wide glyphs (emoji/CJK/box-drawing) from overflowing their cell
-- and visually eating adjacent columns. Default "WhenFollowedBySpace" allows
-- overflow when the next cell is blank, which is exactly the "잡아먹는" case.
config.allow_square_glyphs_to_overflow_width = "Never"

-- Window size
config.initial_cols = 120
config.initial_rows = 35

-- Color scheme
config.color_scheme = 'Modus Vivendi Tinted (Gogh)'

-- Cursor color (match kitty: cursor #ff4769, pink — visible on both day/night themes)
-- color_scheme이 깔린 뒤 cursor 관련 키만 덮어쓴다.
config.colors = {
    cursor_bg = '#ff4769',
    cursor_border = '#ff4769',
    -- kitty의 'cursor_text_color background'에 대응:
    -- Modus Vivendi Tinted 배경색을 박아서 커서 위 글자가 배경으로 사라지게.
    cursor_fg = '#0d0e1c',
}

config.window_close_confirmation = "AlwaysPrompt"
config.audible_bell = "Disabled"

-- Kitty graphics protocol (for kitty-graphics.el in terminal Emacs)
config.enable_kitty_graphics = true

-- Scrollback
config.scrollback_lines = 1000
config.enable_scroll_bar = false

-- Key bindings
config.keys = {
    -- Disable ALT-Return (conflicts with Claude Code multiline input)
    {key = "Return", mods = "ALT", action = wezterm.action.DisableDefaultAssignment},
    -- term-keys: Right Alt → Emacs <Hangul>
    {key = "RightAlt", mods = "", action = wezterm.action{SendString="\x1b\x1f\x50\x60\x1f"}},
    -- term-keys: Shift+Space → Emacs S-SPC
    {key = "Space", mods = "SHIFT", action = wezterm.action{SendString="\x1b\x1f\x50\x21\x1f"}},
    -- term-keys: F1~F12
    {key = "F1",  mods = "", action = wezterm.action{SendString="\x1b\x1f\x60\x1f"}},
    {key = "F2",  mods = "", action = wezterm.action{SendString="\x1b\x1f\x21\x40\x1f"}},
    {key = "F3",  mods = "", action = wezterm.action{SendString="\x1b\x1f\x22\x20\x1f"}},
    {key = "F4",  mods = "", action = wezterm.action{SendString="\x1b\x1f\x22\x60\x1f"}},
    {key = "F5",  mods = "", action = wezterm.action{SendString="\x1b\x1f\x23\x40\x1f"}},
    {key = "F6",  mods = "", action = wezterm.action{SendString="\x1b\x1f\x24\x20\x1f"}},
    {key = "F7",  mods = "", action = wezterm.action{SendString="\x1b\x1f\x24\x60\x1f"}},
    {key = "F8",  mods = "", action = wezterm.action{SendString="\x1b\x1f\x25\x40\x1f"}},
    {key = "F9",  mods = "", action = wezterm.action{SendString="\x1b\x1f\x26\x20\x1f"}},
    {key = "F10", mods = "", action = wezterm.action{SendString="\x1b\x1f\x26\x60\x1f"}},
    {key = "F11", mods = "", action = wezterm.action{SendString="\x1b\x1f\x27\x40\x1f"}},
    {key = "F12", mods = "", action = wezterm.action{SendString="\x1b\x1f\x28\x20\x1f"}},

    -- Tab switching (ghostty와 동일: Alt+1..9 로 N번째 탭 이동, Alt+0 = 마지막 탭)
    {key = "1", mods = "ALT", action = wezterm.action.ActivateTab(0)},
    {key = "2", mods = "ALT", action = wezterm.action.ActivateTab(1)},
    {key = "3", mods = "ALT", action = wezterm.action.ActivateTab(2)},
    {key = "4", mods = "ALT", action = wezterm.action.ActivateTab(3)},
    {key = "5", mods = "ALT", action = wezterm.action.ActivateTab(4)},
    {key = "6", mods = "ALT", action = wezterm.action.ActivateTab(5)},
    {key = "7", mods = "ALT", action = wezterm.action.ActivateTab(6)},
    {key = "8", mods = "ALT", action = wezterm.action.ActivateTab(7)},
    {key = "9", mods = "ALT", action = wezterm.action.ActivateTab(-1)}, -- 마지막 탭
}

return config
