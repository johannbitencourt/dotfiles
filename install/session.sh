#!/usr/bin/env bash
# Session-liveness detection. Shared by doctor's session-gated checks and
# uninstall's "is this project's session currently running?" warning —
# extracted here (rather than living in doctor.sh) so uninstall.sh doesn't
# have to pull in all of doctor.sh's unrelated dependencies just for this.
# scripts/hypr-session writes the marker this reads.

declare -g SESSION_MARKER_PID=""

# session::marker_active — true if this project's own Hyprland session is
# running right now. Reads the PID hypr-session writes just before exec'ing
# into Hyprland, then cross-checks /proc/<pid>/comm since that PID could
# have been reused by an unrelated process since. Deliberately not "is a
# Hyprland-family process running" — that would misfire against another
# project's Hyprland session on the same machine (see e.g. this dev host's
# live Omarchy session).
session::marker_active() {
	SESSION_MARKER_PID=""
	local marker="${XDG_RUNTIME_DIR:-}/dotfiles-hyprland-session.pid"
	[[ -n ${XDG_RUNTIME_DIR:-} && -f $marker ]] || return 1
	local pid
	pid=$(cat "$marker" 2>/dev/null) || return 1
	[[ $pid =~ ^[0-9]+$ ]] || return 1
	kill -0 "$pid" 2>/dev/null || return 1
	[[ "$(cat "/proc/${pid}/comm" 2>/dev/null)" == Hyprland ]] || return 1
	SESSION_MARKER_PID=$pid
}
