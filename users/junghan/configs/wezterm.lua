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
config.font = wezterm.font_with_fallback({
    "GLG Nerd Font Mono",
    "Noto Emoji",          -- monochrome emoji (no color)
})
config.font_size = 15.1

-- Window size
config.initial_cols = 120
config.initial_rows = 35

-- Color scheme
config.color_scheme = 'Modus Vivendi Tinted (Gogh)'
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
}

return config
