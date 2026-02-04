-- WezTerm configuration for NixOS
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Window appearance
config.window_background_opacity = 0.85
config.text_background_opacity = 0.85
config.window_decorations = "RESIZE"

-- Tab bar
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true

-- Font (D2Coding for consistency with ghostty/i3)
config.font = wezterm.font("D2Coding ligature", { weight = "Regular", italic = false })
config.font_size = 14.0

-- Window size
config.initial_cols = 120
config.initial_rows = 35

-- Color scheme
config.color_scheme = "Dracula (Official)"
config.audible_bell = "Disabled"

-- Scrollback settings (optimized for Claude Code)
config.scrollback_lines = 10000  -- Limit to prevent memory bloat
config.enable_scroll_bar = true
config.scroll_to_bottom_on_input = true

-- Key bindings
config.keys = {
    -- Disable ALT-Return (conflicts with Claude Code multiline input)
    {
        key = "Return",
        mods = "ALT",
        action = wezterm.action.DisableDefaultAssignment,
    },
}

return config
