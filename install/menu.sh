#!/usr/bin/env bash
# The Fuzzel system menu's label -> action table (HLD 19). Flat single-level
# list, not a submenu-per-category via repeated fuzzel calls: fuzzel's own
# fuzzy filter (type "reb" -> Reboot) makes a nested nav worse, not better,
# for a keyboard picker, and HLD's tree is documentation structure, not a
# UI mandate. Category prefixes on each label keep HLD-tree fidelity
# visible in the picker itself.
#
# Style (Select theme / Select wallpaper / Toggle performance mode) is
# omitted entirely, not stubbed: no theme engine exists, wallpaper is a
# single solid hex color with no picker mechanism, and "performance mode"
# only ever existed in a chezmoi-era design this project's rewrite fully
# discarded. A menu entry that logs "not implemented yet" is a
# half-finished feature, not a smaller one.
#
# "The menu has no independent privileged logic" (HLD 19): every arm below
# is a direct passthrough to something that already exists (hyprlock,
# systemctl/hyprctl, dotctl subcommands, waybar::reload/mako::reload) — no
# sudo, no conditionals beyond what those callees already do themselves.

menu::items() {
	cat <<'EOF'
Session: Lock
Session: Suspend
Session: Logout
Session: Reboot
Session: Power off
Maintenance: Doctor
Maintenance: Update configuration
Maintenance: Update operating system
Maintenance: View logs
Maintenance: Restart Waybar
Maintenance: Restart notifications
Maintenance: Restart portals
Help: Keybindings
Help: Recovery guide
Help: Versions
EOF
}

# menu::dispatch <label> — case-keyed on the exact label text (this repo's
# own established idiom: real arrays/literal argv, never eval'd or
# string-built commands — see adapter_remove_packages). Matching on label
# text is fragile (a rename silently orphans its arm) — the *) default arm
# below turns that into a loud failure instead of a silent no-op, rather
# than adding a synthetic stable-ID layer this file doesn't need yet.
#
# Session items never open Foot (HLD's Foot rule names "package
# installation and destructive maintenance" only, and there's nothing
# worth keeping a window open for after poweroff/reboot/logout). Every
# Maintenance/Help item whose value is its output opens Foot instead —
# 'update config'/'update packages' aren't just nicer there, they're
# functionally required: both read confirmation from /dev/tty, and a
# Hyprland-keybind-launched process has no controlling terminal at all.
# No `&` backgrounding: Hyprland's own `exec` dispatcher already runs this
# whole script asynchronously from the compositor's event loop, so there's
# no need for this script to also return early — it blocking on Foot just
# means the process lingers harmlessly.
menu::dispatch() {
	local sel=$1
	case $sel in
	"Session: Lock") hyprlock ;;
	"Session: Suspend") systemctl suspend ;;
	"Session: Logout") hyprctl dispatch exit ;;
	"Session: Reboot") systemctl reboot ;;
	"Session: Power off") systemctl poweroff ;;
	"Maintenance: Doctor") foot --hold -- dotctl doctor ;;
	"Maintenance: Update configuration") foot --hold -- dotctl update config ;;
	"Maintenance: Update operating system") foot --hold -- dotctl update packages ;;
	"Maintenance: View logs")
		foot --hold -- journalctl --user -e -u waybar.service -u mako.service -u hypridle.service -u swaybg.service
		;;
	"Maintenance: Restart Waybar") waybar::reload ;;
	"Maintenance: Restart notifications") mako::reload ;;
	"Maintenance: Restart portals")
		systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service
		;;
	"Help: Keybindings") foot --hold -- less "${HOME}/.config/hypr/conf.d/50-bindings.conf" ;;
	"Help: Recovery guide") foot --hold -- dotctl recover ;;
	"Help: Versions")
		foot --hold -- pacman -Q hyprland waybar mako fuzzel foot hyprlock hypridle swaybg xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
		;;
	*) log::die "hypr-menu: unmapped selection: ${sel}" ;;
	esac
}
