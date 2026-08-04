-- Hyprland config, Lua format (hyprlang is deprecated since 0.55 and goes
-- away around 0.57). API reference: /usr/share/hypr/stubs/hl.meta.lua

-- Every output at its preferred mode. No per-host monitor config, so
-- docking/undocking never leaves a session without a usable display.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    input      = { kb_layout = "us", follow_mouse = 1, numlock_by_default = true },
    general    = { gaps_in = 4, gaps_out = 8, border_size = 2, layout = "dwindle" },
    dwindle    = { preserve_split = true },
    -- Deliberately low-overhead: no blur, no shadows, no animations.
    decoration = { blur = { enabled = false }, shadow = { enabled = false } },
    animations = { enabled = false },
    misc       = { disable_hyprland_logo = true, force_default_wallpaper = 0 },
})

hl.on("hyprland.start", function()
    -- WAYLAND_DISPLAY and HYPRLAND_INSTANCE_SIGNATURE don't exist until
    -- Hyprland is up, so anything activated over D-Bus (portals) needs them
    -- pushed into the activation environment from here.
    hl.exec_cmd("dbus-update-activation-environment --systemd "
        .. "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("mako")
end)

local mod = "SUPER"

hl.bind(mod .. " + Return",    hl.dsp.exec_cmd("foot"))
hl.bind(mod .. " + Space",     hl.dsp.exec_cmd("fuzzel"))
hl.bind(mod .. " + L",         hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + W",         hl.dsp.window.close())
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())

for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. dir,         hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end

for i = 1, 5 do
    hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
