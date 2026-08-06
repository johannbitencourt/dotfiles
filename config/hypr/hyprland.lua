-- Hyprland config, Lua format (hyprlang is deprecated since 0.55 and goes
-- away around 0.57). API reference: /usr/share/hypr/stubs/hl.meta.lua

-- Every output at its preferred mode. No per-host monitor config, so
-- docking/undocking never leaves a session without a usable display.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Border colours come from the active theme. dofile() rather than require()
-- because the themes live outside this directory, so they aren't on package.path.
-- pcall: a missing or broken theme file costs you themed borders, not a session.
local ok, theme = pcall(dofile, os.getenv("HOME") .. "/.config/themes/current/hyprland.lua")
if not ok then
    theme = { active_border = "rgba(7aa2f7ee)", inactive_border = "rgba(414868aa)" }
end

hl.config({
    input      = { kb_layout = "us", follow_mouse = 1, numlock_by_default = true },
    general    = {
        gaps_in = 4, gaps_out = 8, border_size = 2, layout = "dwindle",
        col = {
            active_border   = theme.active_border,
            inactive_border = theme.inactive_border,
        },
    },
    dwindle    = { preserve_split = true },
    -- Rounding and animations are cheap; blur and shadows are the expensive
    -- pair, and this is a laptop on a discrete GPU. Defaults are used for the
    -- animation curves — upstream's 17 hl.curve/hl.animation lines only
    -- restate them.
    decoration = { rounding = 8, blur = { enabled = false }, shadow = { enabled = false } },
    animations = { enabled = true },
    misc       = { disable_hyprland_logo = true, force_default_wallpaper = 0 },
})

hl.on("hyprland.start", function()
    -- WAYLAND_DISPLAY and HYPRLAND_INSTANCE_SIGNATURE don't exist until
    -- Hyprland is up, so anything activated over D-Bus (portals) needs them
    -- pushed into the activation environment from here.
    hl.exec_cmd("dbus-update-activation-environment --systemd "
        .. "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("mako")
    -- ponytail: terminals open instantly via footclient, but they all die
    -- with this one server. Drop back to plain `foot` if that ever bites.
    hl.exec_cmd("foot --server")
    hl.exec_cmd("waybar")
    hl.exec_cmd("hypridle")
    -- Solid colour rather than an image, so the repo carries no binary asset.
    -- Swap -c for `-i ~/path/to.png -m fill` if you want a picture.
    hl.exec_cmd("swaybg -c '#1a1b26'")
    -- GUI authentication prompts (e.g. mounting a disk, editing a system file)
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    -- Clipboard history. Only the watcher runs; SUPER+SHIFT+V picks from it.
    hl.exec_cmd("wl-paste --watch cliphist store")
end)

-- Both rules are upstream's, from /usr/share/hypr/hyprland.lua.
hl.window_rule({
    -- Apps asking to maximise themselves fight the tiler. Ignore them.
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- Fixes drag-and-drop breaking under XWayland.
    name  = "fix-xwayland-drags",
    match = {
        class = "^$", title = "^$", xwayland = true,
        float = true, fullscreen = false, pin = false,
    },
    no_focus = true,
})

-- Separate require() scope: an error in the binds cannot stop this file.
require("bindings")
