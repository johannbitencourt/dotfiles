-- Keyboard, pointer, touchpad, gestures.

hl.config({
	input = {
		kb_layout = "us",
		numlock_by_default = true,
		-- 1 = focus follows the mouse across windows.
		follow_mouse = 1,
		-- Scrolling over an unfocused window scrolls it without focusing it.
		mouse_refocus = false,
		-- Faster than the 25/600 default; the stock delay feels sticky when
		-- holding a direction key to move through a buffer.
		repeat_rate = 40,
		repeat_delay = 400,
		-- "flat" is 1:1 pointer movement. The default adaptive profile is
		-- fine for a mouse and awful for precise work on a trackpad.
		accel_profile = "flat",

		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
			-- Tap then hold to drag, no physical click needed.
			tap_and_drag = true,
			-- Two-finger tap is right-click, three-finger is middle.
			tap_button_map = "lrm",
			-- Stops the cursor jumping when a palm brushes the pad mid-sentence.
			disable_while_typing = true,
			-- The default of 1.0 is slow on a high-resolution pad.
			scroll_factor = 0.6,
		},
	},

	binds = {
		-- Pressing the current workspace's key again returns to the previous one.
		workspace_back_and_forth = true,
		-- Leaving a workspace hides the scratchpad with it.
		hide_special_on_workspace_change = true,
		-- Focus moves to the next monitor when it runs out of windows this way.
		window_direction_monitor_fallback = true,
	},

	cursor = {
		-- Hide the pointer while typing; any movement brings it back.
		hide_on_key_press = true,
		-- Omarchy's value: the pointer follows you to the new workspace, so the
		-- next click lands where you're looking.
		warp_on_change_workspace = 1,
		-- Keeps the cursor from breaking VRR on the fullscreen path.
		no_break_fs_vrr = true,
	},
})

-- Three-finger horizontal swipe moves between workspaces. `hl.gesture` replaced
-- the old gestures:workspace_swipe options — this form is from upstream's own
-- example config at /usr/share/hypr/hyprland.lua:236.
hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

hl.config({
	gestures = {
		-- Don't create a new workspace by swiping past the last one; it's too
		-- easy to do by accident and then wonder where a window went.
		workspace_swipe_create_new = false,
		-- Once a swipe commits to an axis it stays on it.
		workspace_swipe_direction_lock = true,
	},
})
