#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/applications/hyprland/validate.sh"

STAGE_DIR=$(mktemp -d)
trap 'rm -rf "$STAGE_DIR"' EXIT
mkdir -p "${STAGE_DIR}/config/hypr/conf.d"
printf 'general {\n    gaps_in = 4\n}\n' >"${STAGE_DIR}/config/hypr/conf.d/40-looknfeel.conf"

# 1. Regression: on a fresh machine (or --dry-run/--config-only before
#    packages are installed), the Hyprland binary doesn't exist yet.
#    Calling it directly used to fail with bash's own "command not found"
#    (exit 127), which hyprland::validate's own `if ! output=$(Hyprland
#    ...)` treated as "config verification failed" — log::die, crashing
#    the whole install right at that step. Simulated here with a minimal
#    PATH containing only the real mktemp/cat, no Hyprland — command -v
#    can't be faked by shadowing a function (it would just find the
#    function instead), so this is done via a real, narrowed PATH.
REAL_MKTEMP=$(command -v mktemp)
REAL_CAT=$(command -v cat)
FAKE_BIN=$(mktemp -d)
trap 'rm -rf "$STAGE_DIR" "$FAKE_BIN"' EXIT
ln -s "$REAL_MKTEMP" "${FAKE_BIN}/mktemp"
ln -s "$REAL_CAT" "${FAKE_BIN}/cat"

output=$(PATH="$FAKE_BIN" hyprland::validate 2>&1) && rc=0 || rc=$?
[[ $rc -eq 0 ]] || fail "hyprland::validate died when Hyprland isn't installed yet (rc=${rc}): ${output}"
echo "$output" | grep -qi "SKIP" || fail "expected a SKIP message when Hyprland isn't installed, got: ${output}"
echo "PASS: hyprland::validate skips gracefully when Hyprland isn't installed yet, instead of dying"

# 2. The real Hyprland on this host: a valid staged config still verifies
#    for real (read-only, safe).
hyprland::validate >/dev/null 2>&1 || fail "hyprland::validate failed against a valid config with the real Hyprland present"
echo "PASS: a valid config still verifies for real once Hyprland is present"

# 3. The real Hyprland on this host: an invalid staged config is still
#    caught (the guard doesn't accidentally swallow real failures).
printf 'this is not valid hyprland syntax {{{\n' >"${STAGE_DIR}/config/hypr/conf.d/40-looknfeel.conf"
output=$(hyprland::validate 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "hyprland::validate unexpectedly succeeded on an invalid config"
echo "$output" | grep -qi "config verification failed" || fail "unexpected failure message: ${output}"
echo "PASS: a genuinely invalid config still fails validation when Hyprland is present"

echo "ALL PASS"
