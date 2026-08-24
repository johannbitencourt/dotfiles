-- Everything started with the session.

hl.on("hyprland.start", function()
	-- WAYLAND_DISPLAY and HYPRLAND_INSTANCE_SIGNATURE don't exist until
	-- Hyprland is up, so anything activated over D-Bus (the portals) needs
	-- them pushed into the activation environment from here.
	--
	-- Programs started below inherit Hyprland's own environment directly, so
	-- they don't need this. A portal does, and it's activated on demand and
	-- then lives for the session — so one that comes up before the import
	-- lands stays broken until you log out. The polkit agent shares this
	-- shell to guarantee it starts after the import, not alongside it.
	hl.exec_cmd("dbus-update-activation-environment "
		.. "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE; "
		.. "if command -v systemctl >/dev/null 2>&1; then "
		.. "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP "
		.. "XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE 2>/dev/null ||:; fi; "
		-- GUI authentication prompts (mounting a disk, editing a system file).
		-- Prefer the systemd user unit where available, then binaries shipped by
		-- Arch's hyprpolkitagent or Void's polkit-gnome package.
		.. "if command -v systemctl >/dev/null 2>&1 "
		.. "&& systemctl --user start hyprpolkitagent.service 2>/dev/null; then :; "
		.. "elif command -v hyprpolkitagent >/dev/null 2>&1; then exec hyprpolkitagent; "
		.. "elif [ -x /usr/lib/hyprpolkitagent/hyprpolkitagent ]; then "
		.. "exec /usr/lib/hyprpolkitagent/hyprpolkitagent; "
		.. "else exec /usr/libexec/polkit-gnome-authentication-agent-1; fi")

	-- Arch starts these through systemd user units. Void has no user manager,
	-- so start the same session daemons directly when they are not already up.
	for _, daemon in ipairs({ "pipewire", "pipewire-pulse", "wireplumber" }) do
		hl.exec_cmd("if [ ! -d /run/systemd/system ] && ! pgrep -x " .. daemon
			.. " >/dev/null 2>&1; then exec " .. daemon .. "; fi")
	end

	hl.exec_cmd("mako")
	-- ponytail: terminals open instantly via footclient, but they all die
	-- with this one server. Drop back to plain `foot` if that ever bites.
	hl.exec_cmd("foot --server")
	-- A standalone Quickshell config is optional; Waybar remains the fallback.
	hl.exec_cmd("if [ -f \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml\" ]; "
		.. "then qs -d -n; else exec waybar; fi")
	hl.exec_cmd("hypridle")

	-- Solid colour from the active theme, so the repo carries no binary asset.
	-- Swap -c for `-i ~/path/to.png -m fill` if you want a picture. The same
	-- command is repeated in the theme picker in bindings.lua — two short
	-- duplicates beat a module existing only to share one string.
	-- The default matters: swaybg rejects an empty -c and exits, so a missing
	-- or empty theme file would otherwise leave no background at all.
	hl.exec_cmd("c=$(cat ~/.config/themes/current/background 2>/dev/null); "
		.. "swaybg -c \"${c:-#1a1b26}\"")

	-- Clipboard history. Only the watcher runs; SUPER+SHIFT+V picks from it.
	hl.exec_cmd("wl-paste --watch cliphist store")
end)
