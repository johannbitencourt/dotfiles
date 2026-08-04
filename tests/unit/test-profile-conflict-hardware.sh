#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/install/profile.sh"

# Neither dev.conf nor core.conf declares a conflict/recommendation/
# hardware-constraint (no sibling profile exists yet to conflict with, and
# this host's own hardware is whatever it happens to be) — this is
# mechanism-with-no-live-trigger by design. Prove it with synthetic
# fixture field arrays directly, without touching HOST or the real
# profiles/ directory at all.

# 1. profile::_check_conflicts: a declared conflict that IS currently
#    installed is detected and warned about.
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
STATE_DIR="${FAKE_HOME}/.local/state/dotfiles"
mkdir -p "$STATE_DIR"
printf '{"profiles":{"beta":{}}}\n' >"${STATE_DIR}/profiles.json"

declare -A fields_conflict=([CONFLICTING_PROFILES]=beta,gamma)
output=$(profile::_check_conflicts alpha fields_conflict 2>&1) && rc=0 || rc=$?
[[ $rc -eq 0 ]] || fail "expected profile::_check_conflicts to return 0 (conflict found), got ${rc}"
echo "$output" | grep -qi "declared conflict 'beta' is currently installed" || fail "expected a warning naming 'beta', got: ${output}"
echo "PASS: a declared conflict that is currently installed is detected and warned about"

# 2. A declared conflict that is NOT currently installed: no warning,
#    returns 1 (bash-false).
printf '{"profiles":{}}\n' >"${STATE_DIR}/profiles.json"
output=$(profile::_check_conflicts alpha fields_conflict 2>&1) && rc=0 || rc=$?
[[ $rc -eq 1 ]] || fail "expected profile::_check_conflicts to return 1 (no conflict), got ${rc}"
[[ -z $output ]] || fail "expected no warning when the conflicting profile isn't installed, got: ${output}"
echo "PASS: no warning when the declared conflict isn't currently installed"

# 3. No CONFLICTING_PROFILES declared at all: returns 1, no warning (the
#    real dev.conf/core.conf case).
declare -A fields_none=([CONFLICTING_PROFILES]=)
output=$(profile::_check_conflicts alpha fields_none 2>&1) && rc=0 || rc=$?
[[ $rc -eq 1 ]] || fail "expected profile::_check_conflicts to return 1 with no declared conflicts, got ${rc}"
echo "PASS: no declared conflicts -> no warning, returns false"

# 4. profile::_check_hardware_constraints: an unmet constraint is detected
#    and warned about.
declare -gA HOST=([GPU_VENDOR]=amd)
declare -A fields_hw=([HARDWARE_CONSTRAINTS]=GPU_VENDOR=nvidia)
output=$(profile::_check_hardware_constraints alpha fields_hw 2>&1) && rc=0 || rc=$?
[[ $rc -eq 0 ]] || fail "expected profile::_check_hardware_constraints to return 0 (unmet), got ${rc}"
echo "$output" | grep -qi "hardware constraint unmet: GPU_VENDOR=nvidia" || fail "expected an unmet-constraint warning, got: ${output}"
echo "PASS: an unmet hardware constraint is detected and warned about"

# 5. A satisfied hardware constraint: no warning, returns 1.
HOST[GPU_VENDOR]=nvidia
output=$(profile::_check_hardware_constraints alpha fields_hw 2>&1) && rc=0 || rc=$?
[[ $rc -eq 1 ]] || fail "expected profile::_check_hardware_constraints to return 1 (satisfied), got ${rc}"
[[ -z $output ]] || fail "expected no warning when the constraint is satisfied, got: ${output}"
echo "PASS: a satisfied hardware constraint produces no warning"

echo "ALL PASS"
