#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/scripts/lib/cleanup.sh"
source "${DOTFILES_ROOT}/install/session.sh"
source "${DOTFILES_ROOT}/install/doctor.sh"

fail() {
	echo "FAIL: $*"
	exit 1
}

status_of() { jq -r '.status' "$DOCTOR_RESULTS_FILE"; }
detail_of() { jq -r '.detail' "$DOCTOR_RESULTS_FILE"; }
# doctor::_record appends — reset before each call so status_of/detail_of
# read this call's result, not every prior one accumulated in the file.
check_monitors() {
	: >"$DOCTOR_RESULTS_FILE"
	doctor::_check_monitors
}

FAKE_RUNTIME_DIR=$(mktemp -d)
trap 'rm -rf "$FAKE_RUNTIME_DIR"' EXIT
XDG_RUNTIME_DIR=$FAKE_RUNTIME_DIR
marker="${XDG_RUNTIME_DIR}/dotfiles-hyprland-session.pid"
DOCTOR_RESULTS_FILE=$(mktemp)
cleanup::register "$DOCTOR_RESULTS_FILE"

# 1. No session marker at all -> PENDING, no crash.
check_monitors
[[ $(status_of) == PENDING ]] || fail "expected PENDING with no session marker, got: $(status_of)"
echo "PASS: no session marker -> PENDING"

# Spawn a real background process named exactly "Hyprland" (same technique
# as test-doctor-session-marker.sh) so session::marker_active reports true
# for the rest of this file.
fake_hyprland_dir=$(mktemp -d)
trap 'rm -rf "$FAKE_RUNTIME_DIR" "$fake_hyprland_dir"' EXIT
ln -s "$(command -v sleep)" "${fake_hyprland_dir}/Hyprland"
"${fake_hyprland_dir}/Hyprland" 30 &
fake_pid=$!
printf '%s\n' "$fake_pid" >"$marker"
for _ in 1 2 3 4 5 6 7 8 9 10; do
	[[ "$(cat "/proc/${fake_pid}/comm" 2>/dev/null)" == Hyprland ]] && break
	sleep 0.05
done
session::marker_active || {
	kill "$fake_pid" 2>/dev/null || true
	fail "test setup failed: session marker did not become active"
}
cleanup_fake_hyprland() { kill "$fake_pid" 2>/dev/null || true; wait "$fake_pid" 2>/dev/null || true; }
trap 'cleanup_fake_hyprland; rm -rf "$FAKE_RUNTIME_DIR" "$fake_hyprland_dir"' EXIT

# 2. Session active, but no $XDG_RUNTIME_DIR/hypr/ at all -> WARN, no crash.
check_monitors
[[ $(status_of) == WARN ]] || fail "expected WARN with no hypr/ socket dir, got: $(status_of)"
echo "$(detail_of)" | grep -qi "no Hyprland IPC socket found" || fail "unexpected detail: $(detail_of)"
echo "PASS: session active but no IPC socket directory -> WARN"

# 3. Exactly one signature dir; hyprctl reports 2 monitors -> PASS.
mkdir -p "${XDG_RUNTIME_DIR}/hypr/onlysig"
hyprctl() { printf 'Monitor DP-1\nMonitor HDMI-A-1\n'; }
check_monitors
[[ $(status_of) == PASS ]] || fail "expected PASS with monitors reporting, got: $(status_of) / $(detail_of)"
echo "$(detail_of)" | grep -q "^2 " || fail "expected the count 2 in the detail: $(detail_of)"
echo "PASS: exactly one IPC socket + monitors reporting -> PASS"

# 4. Same single signature, hyprctl reports zero monitors -> WARN.
hyprctl() { printf ''; }
check_monitors
[[ $(status_of) == WARN ]] || fail "expected WARN with zero monitors reported, got: $(status_of)"
echo "$(detail_of)" | grep -qi "zero monitors" || fail "unexpected detail: $(detail_of)"
echo "PASS: hyprctl reachable but zero monitors -> WARN"

# 5. hyprctl itself fails (can't reach the socket) -> WARN, not a crash.
hyprctl() { return 1; }
check_monitors
[[ $(status_of) == WARN ]] || fail "expected WARN when hyprctl fails, got: $(status_of)"
echo "$(detail_of)" | grep -qi "hyprctl monitors failed" || fail "unexpected detail: $(detail_of)"
echo "PASS: hyprctl failing outright -> WARN, not a crash"
unset -f hyprctl

# 6. Two signature dirs -> WARN, correctly refuses to guess which is ours.
mkdir -p "${XDG_RUNTIME_DIR}/hypr/othersig"
check_monitors
[[ $(status_of) == WARN ]] || fail "expected WARN with two IPC socket dirs, got: $(status_of)"
echo "$(detail_of)" | grep -qi "multiple Hyprland instances" || fail "unexpected detail: $(detail_of)"
echo "PASS: multiple IPC socket directories -> WARN, doesn't guess"

cleanup_fake_hyprland

# 7. The real check on this actual host — read-only, safe to run for real.
#    This project's own session has never been started for real here, so
#    this must report PENDING, not crash or false-positive.
XDG_RUNTIME_DIR=$(printenv XDG_RUNTIME_DIR || printf '/run/user/%s' "$(id -u)")
rm -f "$marker"
check_monitors
[[ $(status_of) == PENDING ]] || fail "expected PENDING for real on this host (session never started), got: $(status_of)"
echo "PASS: the real check on this host reports PENDING, matching that no session has been started here"

echo "ALL PASS"
