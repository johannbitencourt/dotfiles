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
    general    = {
        gaps_in = 4, gaps_out = 8, border_size = 2, layout = "dwindle",
        col = {
            -- Tokyo Night, same palette as waybar/foot/fuzzel/mako.
            active_border   = { colors = { "rgba(7aa2f7ee)", "rgba(bb9af7ee)" }, angle = 45 },
            inactive_border = "rgba(414868aa)",
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

local mod = "SUPER"

hl.bind(mod .. " + Return",    hl.dsp.exec_cmd("foot"))
hl.bind(mod .. " + Space",     hl.dsp.exec_cmd("fuzzel"))
hl.bind(mod .. " + L",         hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + W",         hl.dsp.window.close())
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
-- Power menu. Escaping fuzzel leaves no argument at all (unquoted expansion),
-- so systemctl just lists units instead of doing anything.
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exec_cmd(
    "systemctl $(printf 'suspend\\nreboot\\npoweroff' | fuzzel --dmenu)"))

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

-- Screenshot: region to clipboard.
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))

-- Clipboard history through the launcher we already have.
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd(
    "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"))

-- Night light toggle. hyprsunset 0.4.0 has no config file and no schedule,
-- so pkill-or-start is the whole state machine.
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("pkill hyprsunset || hyprsunset -t 4000"))

-- Laptop function keys. `locked` lets them work while hyprlock is up.
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),                                 { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),                             { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true })

-- On-demand status, so the bar isn't the only way to check the battery.
-- exec_cmd runs through a shell, so $(...) works. BAT* rather than BAT0:
-- this machine's battery is BAT1 and the numbering isn't portable.
hl.bind(mod .. " + B", hl.dsp.exec_cmd(
    [[notify-send "$(date '+%H:%M  %a %d %b')" ]]
    .. [["Battery $(cat /sys/class/power_supply/BAT*/capacity)% ]]
    .. [[($(cat /sys/class/power_supply/BAT*/status)) - ]]
    .. [[network $(ip -4 route show default | grep -q . && echo up || echo down)"]]))
