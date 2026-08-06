-- Borders, gaps, decoration, animations.

-- Border colours come from the active theme. dofile() rather than require()
-- because the themes live outside this directory, so they aren't on package.path.
-- pcall: a missing or broken theme file costs you themed borders, not a session.
local ok, theme = pcall(dofile, os.getenv("HOME") .. "/.config/themes/current/hyprland.lua")
if not ok then
	theme = { active_border = "rgba(7aa2f7ee)", inactive_border = "rgba(414868aa)" }
end

-- Geometry and decoration follow Omarchy's defaults, which is the look this
-- machine actually runs. That means blur and shadows ON and rounding 0 — the
-- opposite of a performance-first setup, and a deliberate trade.
hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 10,
		border_size = 2,
		layout = "dwindle",
		col = {
			active_border = theme.active_border,
			inactive_border = theme.inactive_border,
		},
		resize_on_border = false,
		allow_tearing = false,
		-- Floating windows snap to each other and to monitor edges.
		snap = { enabled = true, window_gap = 10, monitor_gap = 10 },
	},

	decoration = {
		rounding = 0,
		shadow = {
			enabled = true,
			range = 2,
			render_power = 3,
			color = "rgba(1a1a1aee)",
		},
		blur = {
			enabled = true,
			size = 2,
			passes = 2,
			special = true,
			brightness = 0.60,
			contrast = 0.75,
		},
	},

	dwindle = {
		preserve_split = true,
		-- 2 = always split to the right/below, so new windows land predictably
		-- rather than following the cursor's half of the tile.
		force_split = 2,
	},

	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		disable_scale_notification = true,
		force_default_wallpaper = 0,
		-- Variable refresh rate: 1 is always, 2 only for fullscreen. 2 avoids
		-- the flicker some panels show when the desktop itself is VRR.
		vrr = 2,
		-- Omarchy's value: let an app raise itself when it asks to.
		focus_on_activate = true,
		-- Clicking a window under a fullscreen one un-fullscreens rather than
		-- leaving you clicking at something you can't see.
		on_focus_under_fullscreen = 1,
		-- Terminals hide themselves when a GUI they launched is on top.
		enable_swallow = true,
		swallow_regex = "^(foot|footclient)$",
		-- Frame cap for windows carrying the `render_unfocused` rule. Nothing
		-- sets that rule yet, so this only takes effect once something does.
		render_unfocused_fps = 10,
		-- Warn about an app that stops responding, rather than freezing with it.
		enable_anr_dialog = true,
		anr_missed_pings = 3,
	},

	ecosystem = {
		no_update_news = true,
		no_donation_nag = true,
	},

	xwayland = {
		-- X11 apps render at scale 1 and get upscaled, which is blurry. Forcing
		-- zero scaling makes them crisp; they handle their own scaling instead.
		force_zero_scaling = true,
	},
})

-- Upstream's default curves and animations, from /usr/share/hypr/hyprland.lua.
-- Listed rather than left implicit so the speeds are visible and tunable.
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.config({ animations = { enabled = true } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
-- Omarchy uses the easeOutQuint bezier here rather than upstream's spring; the
-- `easy` spring above is left defined in case you want to switch back.
hl.animation({ leaf = "windows", enabled = true, speed = 3.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
-- Workspace switching is instant in Omarchy's config, and switching is the
-- thing you do most — the animation is pure latency.
hl.animation({ leaf = "workspaces", enabled = false })
hl.animation({ leaf = "workspacesIn", enabled = false })
hl.animation({ leaf = "workspacesOut", enabled = false })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })
