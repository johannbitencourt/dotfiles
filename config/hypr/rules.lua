-- Window and layer rules.

-- Both of these are upstream's, from /usr/share/hypr/hyprland.lua.
hl.window_rule({
	-- Apps asking to maximise themselves fight the tiler. Ignore them.
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	-- Fixes drag-and-drop breaking under XWayland.
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

-- Portal file pickers and auth prompts are transient dialogs, not windows to
-- tile. Sized rather than left to the app, which usually picks something tiny.
hl.window_rule({
	name = "float-dialogs",
	match = { class = "^(xdg-desktop-portal-gtk|hyprpolkitagent|org.gnome.Nautilus)$" },
	float = true,
	size = "800 600",
	center = true,
})

-- Small single-purpose GUIs from packages.txt. Same reasoning.
hl.window_rule({
	name = "float-utilities",
	match = { class = "^(pavucontrol|system-config-printer|imv|virt-viewer|\\.blueman-manager-wrapped)$" },
	float = true,
	center = true,
})

-- Video popped out of a browser: keep it floating, on top, and out of the way.
hl.window_rule({
	name = "picture-in-picture",
	match = { title = "^(Picture-in-Picture)$" },
	float = true,
	pin = true,
	size = "480 270",
	move = "100%-500 100%-300",
})

-- Password and payment prompts shouldn't land in a screen recording.
hl.window_rule({
	name = "hide-from-screenshare",
	match = { class = "^(hyprpolkitagent)$" },
	no_screen_share = true,
})

-- Blur is off globally, so layers get the cheap treatment instead: the bar and
-- the launcher skip the fade so they feel instant.
hl.layer_rule({
	name = "instant-launcher",
	match = { namespace = "^(launcher|fuzzel)$" },
	no_anim = true,
})
