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
config.hide_tab_bar_if_only_one_tab = true

-- Font
config.font = wezterm.font_with_fallback({
    "GLG Nerd Font Mono",
    "Noto Emoji",          -- monochrome emoji (no color)
})
config.font_size = 15.1

-- Window size
config.initial_cols = 120
config.initial_rows = 35

-- Color scheme
config.color_scheme = "Modus Vivendi"
config.window_close_confirmation = "AlwaysPrompt"
config.audible_bell = "Disabled"

-- Scrollback (Emacs TUI가 화면 제어하므로 최소화)
config.scrollback_lines = 1000
config.enable_scroll_bar = false

-- Key bindings
config.keys = {
    -- Disable ALT-Return (conflicts with Claude Code multiline input)
    {
        key = "Return",
        mods = "ALT",
        action = wezterm.action.DisableDefaultAssignment,
    },
    -- term-keys: Right Alt → Emacs <Hangul> (fcitx5 기본그룹에서 Alt_R로 통과)
    {key = "RightAlt", mods = "", action = wezterm.action{SendString="\x1b\x1f\x50\x60\x1f"}},
    -- term-keys: Shift+Space → Emacs S-SPC
    {key = "Space", mods = "SHIFT", action = wezterm.action{SendString="\x1b\x1f\x50\x21\x1f"}},
    -- M-u, M-v → Emacs로 통과 (wezterm이 가로채지 않음)
}

return config
