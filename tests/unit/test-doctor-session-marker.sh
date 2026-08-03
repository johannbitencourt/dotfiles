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

FAKE_RUNTIME_DIR=$(mktemp -d)
trap 'rm -rf "$FAKE_RUNTIME_DIR"' EXIT
XDG_RUNTIME_DIR=$FAKE_RUNTIME_DIR
marker="${XDG_RUNTIME_DIR}/dotfiles-hyprland-session.pid"

# 1. No marker file at all -> inactive.
if session::marker_active; then
	fail "marker reported active with no marker file present"
fi
echo "PASS: no marker file -> inactive"

# 2. Marker points at this test's own PID (a real, running process, but its
#    comm is "bash", not "Hyprland") -> inactive. This is the stale-marker
#    guard: the PID is alive, but it's not the process that wrote it.
printf '%s\n' "$$" >"$marker"
if session::marker_active; then
	fail "marker reported active for a live PID whose comm isn't Hyprland"
fi
echo "PASS: live PID with the wrong comm -> inactive (stale-marker guard)"

# 3. Marker points at a PID that doesn't exist at all -> inactive.
printf '99999999\n' >"$marker"
if session::marker_active; then
	fail "marker reported active for a nonexistent PID"
fi
echo "PASS: nonexistent PID -> inactive"

# 4. Marker with garbage (non-numeric) content -> inactive, not a crash.
printf 'not-a-pid\n' >"$marker"
if session::marker_active; then
	fail "marker reported active for non-numeric content"
fi
echo "PASS: non-numeric marker content -> inactive, no crash"

# 5. Spawn a real background process named exactly "Hyprland" (a symlink to
#    `sleep` invoked under that name) and point the marker at it -> active,
#    and SESSION_MARKER_PID is set correctly.
fake_hyprland_dir=$(mktemp -d)
trap 'rm -rf "$FAKE_RUNTIME_DIR" "$fake_hyprland_dir"' EXIT
ln -s "$(command -v sleep)" "${fake_hyprland_dir}/Hyprland"
"${fake_hyprland_dir}/Hyprland" 30 &
fake_pid=$!
printf '%s\n' "$fake_pid" >"$marker"

# There's a real (if tiny) window between fork() returning $! and execve()
# actually setting /proc/<pid>/comm to "Hyprland" — poll instead of
# asserting immediately, to avoid a race-flaky test.
for _ in 1 2 3 4 5 6 7 8 9 10; do
	[[ "$(cat "/proc/${fake_pid}/comm" 2>/dev/null)" == Hyprland ]] && break
	sleep 0.05
done

if ! session::marker_active; then
	kill "$fake_pid" 2>/dev/null || true
	fail "marker reported inactive for a live process actually named Hyprland"
fi
[[ $SESSION_MARKER_PID == "$fake_pid" ]] || {
	kill "$fake_pid" 2>/dev/null || true
	fail "SESSION_MARKER_PID was not set to the marked PID"
}
echo "PASS: live process named Hyprland -> active, SESSION_MARKER_PID set"

# 6. A session-gated check must actually transition away from PENDING once
#    the marker is active — the point of all the above, not just the
#    detection primitive in isolation. waybar.service won't be active in
#    this test environment either way, so this asserts FAIL, not PENDING.
DOCTOR_RESULTS_FILE=$(mktemp)
cleanup::register "$DOCTOR_RESULTS_FILE"
doctor::_check_waybar
result=$(jq -r '.status' "$DOCTOR_RESULTS_FILE")
[[ $result != PENDING ]] || fail "doctor::_check_waybar still reported PENDING with an active session marker"
echo "PASS: a session-gated check reports a real status once the marker is active (got: ${result})"

kill "$fake_pid" 2>/dev/null || true
wait "$fake_pid" 2>/dev/null || true

echo "ALL PASS"
