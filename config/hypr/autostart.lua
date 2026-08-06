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
	hl.exec_cmd("dbus-update-activation-environment --systemd "
		.. "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE; "
		-- GUI authentication prompts (mounting a disk, editing a system file).
		-- The package ships a user unit in some builds and only a binary in
		-- others, so try the unit and fall back to the path.
		.. "systemctl --user start hyprpolkitagent.service 2>/dev/null "
		.. "|| exec /usr/lib/hyprpolkitagent/hyprpolkitagent")

	hl.exec_cmd("mako")
	-- ponytail: terminals open instantly via footclient, but they all die
	-- with this one server. Drop back to plain `foot` if that ever bites.
	hl.exec_cmd("foot --server")
	hl.exec_cmd("waybar")
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
