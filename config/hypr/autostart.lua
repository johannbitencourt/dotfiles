-- Everything started with the session.

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

	-- Solid colour from the active theme, so the repo carries no binary asset.
	-- Swap -c for `-i ~/path/to.png -m fill` if you want a picture. The same
	-- command is repeated in the theme picker in bindings.lua — two short
	-- duplicates beat a module existing only to share one string.
	hl.exec_cmd("swaybg -c \"$(cat ~/.config/themes/current/background)\"")

	-- GUI authentication prompts (e.g. mounting a disk, editing a system file)
	hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")

	-- Clipboard history. Only the watcher runs; SUPER+SHIFT+V picks from it.
	hl.exec_cmd("wl-paste --watch cliphist store")
end)
