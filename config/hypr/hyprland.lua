-- Hyprland config, Lua format. hyprlang is deprecated since 0.55 and goes away
-- around 0.57; see the README for where that actually stands. API reference is
-- /usr/share/hypr/stubs/hl.meta.lua, and upstream's annotated example config at
-- /usr/share/hypr/hyprland.lua is worth reading.
--
-- Split across files, as upstream itself recommends. Every require() below is
-- its own Lua scope, so a syntax error in one file cannot stop the others —
-- you lose that file's settings, not the session.

-- Every output at its preferred mode. No per-host monitor config, so
-- docking/undocking never leaves a session without a usable display.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

require("looknfeel")
require("input")
require("rules")
require("autostart")
require("bindings")
