-- Borders, gaps, decoration, animations.

-- Border colours come from the active theme. dofile() rather than require()
-- because the themes live outside this directory, so they aren't on package.path.
-- pcall: a missing or broken theme file costs you themed borders, not a session.
local ok, theme = pcall(dofile, os.getenv("HOME") .. "/.config/themes/current/hyprland.lua")
if not ok then
	theme = { active_border = "rgba(7aa2f7ee)", inactive_border = "rgba(414868aa)" }
end

hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 8,
		border_size = 2,
		layout = "dwindle",
		col = {
			active_border = theme.active_border,
			inactive_border = theme.inactive_border,
		},
		-- Drag a border or a gap to resize, rather than only SUPER+right-drag.
		resize_on_border = true,
		hover_icon_on_border = true,
		-- Floating windows snap to each other and to monitor edges.
		snap = { enabled = true, window_gap = 10, monitor_gap = 10 },
	},

	decoration = {
		rounding = 8,
		-- Slight transparency on unfocused windows reads as depth without
		-- costing what blur costs.
		active_opacity = 1.0,
		inactive_opacity = 0.95,
		-- Blur and shadows are the expensive pair, and this is a laptop on a
		-- discrete GPU. Everything else here is close to free.
		blur = { enabled = false },
		shadow = { enabled = false },
	},

	dwindle = {
		preserve_split = true,
		-- Split along the longer edge, so tiles stay near-square as they nest.
		smart_split = false,
		smart_resizing = true,
		default_split_ratio = 1.0,
	},

	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		force_default_wallpaper = 0,
		-- Variable refresh rate: 1 is always, 2 only for fullscreen. 2 avoids
		-- the flicker some panels show when the desktop itself is VRR.
		vrr = 2,
		-- Don't let a background app steal focus mid-typing.
		focus_on_activate = false,
		-- Terminals hide themselves when a GUI they launched is on top.
		enable_swallow = true,
		swallow_regex = "^(foot|footclient)$",
		-- Frame cap for windows carrying the `render_unfocused` rule. Nothing
		-- sets that rule yet, so this only takes effect once something does.
		render_unfocused_fps = 10,
		-- Warn about an app that stops responding, rather than freezing with it.
		enable_anr_dialog = true,
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
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })
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
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })
