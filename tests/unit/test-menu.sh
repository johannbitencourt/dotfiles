#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/scripts/lib/cleanup.sh"
source "${DOTFILES_ROOT}/scripts/lib/kv-parser.sh"
source "${DOTFILES_ROOT}/scripts/lib/template.sh"
source "${DOTFILES_ROOT}/applications/waybar/reload.sh"
source "${DOTFILES_ROOT}/applications/mako/reload.sh"
source "${DOTFILES_ROOT}/install/menu.sh"

# Every downstream command any dispatch arm could reach is shadowed BEFORE
# any dispatch call. This is not optional caution: this session's own shell
# already has hyprctl/systemctl live-connected to this actual real machine
# (confirmed: $HYPRLAND_INSTANCE_SIGNATURE is set) — nothing here may ever
# reach them unshadowed.
captured="<not called>"
hyprlock() { captured="hyprlock $*"; }
systemctl() { captured="systemctl $*"; }
hyprctl() { captured="hyprctl $*"; }
foot() { captured="foot $*"; }
pgrep() { return 1; }
pkill() { captured="pkill $*"; }
makoctl() { captured="makoctl $*"; }

# 1. Every item menu::items lists has a real, non-default dispatch arm —
#    catches an orphaned label (typo'd rename) as a loud test failure
#    instead of a silent no-op menu selection.
while IFS= read -r label; do
	output=$(menu::dispatch "$label" 2>&1) && rc=0 || rc=$?
	[[ $rc -eq 0 ]] || fail "menu::dispatch \"${label}\" hit the unmapped-selection default arm: ${output}"
done < <(menu::items)
echo "PASS: every menu::items label has a mapped dispatch arm"

# 2. Each Session item invokes its exact command directly, no Foot wrapper.
menu::dispatch "Session: Lock"
[[ $captured == "hyprlock " ]] || fail "Lock: unexpected invocation: ${captured}"
menu::dispatch "Session: Suspend"
[[ $captured == "systemctl suspend" ]] || fail "Suspend: unexpected invocation: ${captured}"
menu::dispatch "Session: Logout"
[[ $captured == "hyprctl dispatch exit" ]] || fail "Logout: unexpected invocation: ${captured}"
menu::dispatch "Session: Reboot"
[[ $captured == "systemctl reboot" ]] || fail "Reboot: unexpected invocation: ${captured}"
menu::dispatch "Session: Power off"
[[ $captured == "systemctl poweroff" ]] || fail "Power off: unexpected invocation: ${captured}"
echo "PASS: every Session item invokes its exact command directly, no Foot wrapper"

# 3. Foot-routed Maintenance/Help items pass the exact intended inner
#    command through to the shadowed foot.
menu::dispatch "Maintenance: Doctor"
[[ $captured == "foot --hold -- dotctl doctor" ]] || fail "Doctor: unexpected invocation: ${captured}"
menu::dispatch "Maintenance: Update configuration"
[[ $captured == "foot --hold -- dotctl update config" ]] || fail "Update configuration: unexpected invocation: ${captured}"
menu::dispatch "Maintenance: Update operating system"
[[ $captured == "foot --hold -- dotctl update packages" ]] || fail "Update operating system: unexpected invocation: ${captured}"
menu::dispatch "Maintenance: View logs"
[[ $captured == "foot --hold -- journalctl --user -e -u waybar.service -u mako.service -u hypridle.service -u swaybg.service" ]] ||
	fail "View logs: unexpected invocation: ${captured}"
menu::dispatch "Help: Keybindings"
[[ $captured == "foot --hold -- less ${HOME}/.config/hypr/conf.d/50-bindings.conf" ]] || fail "Keybindings: unexpected invocation: ${captured}"
menu::dispatch "Help: Recovery guide"
[[ $captured == "foot --hold -- dotctl recover" ]] || fail "Recovery guide: unexpected invocation: ${captured}"
menu::dispatch "Help: Versions"
[[ $captured == "foot --hold -- pacman -Q hyprland waybar mako fuzzel foot hyprlock hypridle swaybg xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk" ]] ||
	fail "Versions: unexpected invocation: ${captured}"
echo "PASS: Foot-routed items pass the exact intended command through to foot"

# 4. Restart Waybar/notifications route through the real reload functions
#    without ever reaching a real process (pgrep shadowed "not running").
captured="<not called>"
menu::dispatch "Maintenance: Restart Waybar"
[[ $captured == "<not called>" ]] || fail "Restart Waybar reached pkill even though waybar isn't running: ${captured}"
menu::dispatch "Maintenance: Restart notifications"
[[ $captured == "<not called>" ]] || fail "Restart notifications reached makoctl even though mako isn't running: ${captured}"
echo "PASS: Restart Waybar/notifications route through waybar::reload/mako::reload without touching a real process"

# 5. Restart portals issues the exact systemctl --user restart, no Foot
#    wrapper.
menu::dispatch "Maintenance: Restart portals"
[[ $captured == "systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service" ]] ||
	fail "Restart portals: unexpected invocation: ${captured}"
echo "PASS: Restart portals runs the exact systemctl --user restart, no Foot wrapper"

# 6. An unmapped selection dies loudly instead of silently doing nothing.
output=$(menu::dispatch "Session: Nonexistent" 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "an unmapped selection unexpectedly succeeded"
echo "$output" | grep -qi "unmapped selection" || fail "unexpected failure message: ${output}"
echo "PASS: an unmapped selection dies loudly, not silently"

# 7. Bonus: waybar::reload/mako::reload themselves, previously untested
#    anywhere in this repo — both branches, still never touching a real
#    process.
pgrep() { return 0; } # "waybar/mako is running"
waybar::reload
[[ $captured == "pkill -SIGUSR2 -x waybar" ]] || fail "waybar::reload (running) unexpected invocation: ${captured}"
mako::reload
[[ $captured == "makoctl reload" ]] || fail "mako::reload (running) unexpected invocation: ${captured}"
pgrep() { return 1; } # "not running"
captured="<not called>"
waybar::reload
[[ $captured == "<not called>" ]] || fail "waybar::reload called pkill even though waybar isn't running: ${captured}"
mako::reload
[[ $captured == "<not called>" ]] || fail "mako::reload called makoctl even though mako isn't running: ${captured}"
echo "PASS: waybar::reload/mako::reload correctly gate on the process actually running"

# 8. The one safe real-subprocess check: render hypr-menu for real (baking
#    in DOTFILES_ROOT like dotctl), then run the rendered copy with ONLY
#    --help — the sole invocation that's provably safe, since it returns
#    before the script ever sources install/menu.sh or calls fuzzel. No
#    other invocation shape of this script is ever executed as a real
#    subprocess anywhere in this suite.
rendered_dir=$(mktemp -d)
cleanup::register "$rendered_dir"
declare -A root_values=([DOTFILES_ROOT_ABS]="$DOTFILES_ROOT")
render_template "${DOTFILES_ROOT}/scripts/hypr-menu" "${rendered_dir}/hypr-menu" root_values
grep -q "DOTFILES_ROOT=\"${DOTFILES_ROOT}\"" "${rendered_dir}/hypr-menu" ||
	fail "rendered hypr-menu does not have the real DOTFILES_ROOT baked in"
chmod +x "${rendered_dir}/hypr-menu"
"${rendered_dir}/hypr-menu" --help >/dev/null || fail "hypr-menu --help failed"
echo "PASS: hypr-menu renders with DOTFILES_ROOT baked in and --help runs safely as a real subprocess"

echo "ALL PASS"
