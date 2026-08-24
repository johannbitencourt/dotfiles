local mod = "SUPER"

hl.bind(mod .. " + Return",    hl.dsp.exec_cmd("footclient"))
hl.bind(mod .. " + Space",     hl.dsp.exec_cmd("fuzzel"))
hl.bind(mod .. " + L",         hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + W",         hl.dsp.window.close())
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
-- Power menu. elogind's loginctl provides the same interface on Void; zzz is a
-- final Void fallback for suspend if elogind is not running.
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exec_cmd(
	"a=$(printf 'suspend\\nreboot\\npoweroff' | fuzzel --dmenu) || exit; "
	.. "[ -n \"$a\" ] || exit; "
	.. "if [ -d /run/systemd/system ]; then systemctl \"$a\"; "
	.. "elif command -v loginctl >/dev/null 2>&1; then loginctl \"$a\"; "
	.. "elif [ \"$a\" = suspend ] && command -v zzz >/dev/null 2>&1; then zzz; "
	.. "else notify-send 'Power action unavailable' \"Cannot run $a on this system\"; fi"))

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

-- Screenshot: region to clipboard, whole screen to a file.
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
hl.bind("Print", hl.dsp.exec_cmd(
	"mkdir -p ~/Pictures && grim ~/Pictures/$(date +%Y%m%d-%H%M%S).png"))

-- Scratchpad: a window parked off-layout that toggles back into view.
hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + M", hl.dsp.window.move({ workspace = "special:magic" }))

-- Clipboard history through the launcher we already have.
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd(
	"cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"))

-- Theme picker. Flips themes/current, then nudges everything that can reload in
-- place: mako, Quickshell (or Waybar fallback), and Hyprland itself (which
-- re-reads the theme's border
-- colours through hyprland.lua's dofile). foot, fuzzel, hyprlock and nvim read
-- the theme on next launch.
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd(
	-- -type d excludes `current` itself, which is a symlink.
	"cd ~/.config/themes && t=$(find . -maxdepth 1 -type d ! -name . -printf '%f\\n' "
	.. "| sort | fuzzel --dmenu) && ln -sfn \"$t\" current "
	.. "&& makoctl reload; "
	.. "if [ -f \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml\" ]; then "
	.. "qs ipc call dotbar reloadTheme >/dev/null 2>&1 "
	.. "|| { qs kill >/dev/null 2>&1 ||:; qs -d -n; }; "
	.. "else pkill -SIGUSR2 waybar 2>/dev/null ||:; fi; hyprctl reload; "
	-- swaybg has no reload, so it gets replaced. Orphaning it is fine — init
	-- adopts it and it outlives the shell this bind runs in.
	.. "pkill -x swaybg; c=$(cat ~/.config/themes/current/background 2>/dev/null); "
	.. "swaybg -c \"${c:-#1a1b26}\" &"))

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
