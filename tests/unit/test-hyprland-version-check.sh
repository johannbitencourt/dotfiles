#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/scripts/lib/kv-parser.sh"
source "${DOTFILES_ROOT}/install/adapters/arch.sh"

# adapter_candidate_version is shadowed throughout — real behavior runs a
# real `pacman -Si`, which is fine to run for real (read-only), but these
# cases need a controlled, deterministic candidate version to exercise
# every branch of the sort -V comparison.

# 1. Candidate strictly newer than min: passes.
ADAPTER_MIN_VERSION=0.56.0
adapter_candidate_version() { printf '0.56.1-1\n'; }
adapter_check_hyprland_version && rc=0 || rc=$?
[[ $rc -eq 0 ]] || fail "expected pass for a newer candidate, got rc=${rc}"
echo "PASS: a candidate newer than the minimum passes"

# 2. Candidate exactly equal to min: passes (not an off-by-one exclusion).
adapter_candidate_version() { printf '0.56.0-2\n'; }
adapter_check_hyprland_version && rc=0 || rc=$?
[[ $rc -eq 0 ]] || fail "expected pass for a candidate exactly at the minimum, got rc=${rc}"
echo "PASS: a candidate exactly at the minimum passes"

# 3. Candidate older than min: fails (rc=1), not a crash.
adapter_candidate_version() { printf '0.41.0-1\n'; }
adapter_check_hyprland_version && rc=0 || rc=$?
[[ $rc -eq 1 ]] || fail "expected rc=1 for an older candidate, got rc=${rc}"
echo "PASS: a candidate older than the minimum fails with rc=1, not a crash"

# 4. Candidate unresolvable (e.g. pacman unreachable): rc=2, distinct from
#    "too old".
adapter_candidate_version() { printf ''; }
adapter_check_hyprland_version && rc=0 || rc=$?
[[ $rc -eq 2 ]] || fail "expected rc=2 for an unresolvable candidate, got rc=${rc}"
echo "PASS: an unresolvable candidate returns rc=2, distinct from 'too old'"

# 5. adapter_validate_version dies with a clear message in both failure
#    modes, rather than a bare nonzero exit.
adapter_candidate_version() { printf '0.41.0-1\n'; }
output=$(adapter_validate_version 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "adapter_validate_version unexpectedly succeeded with an old candidate"
echo "$output" | grep -qi "older than required minimum" || fail "unexpected failure message: ${output}"
echo "PASS: adapter_validate_version dies with a clear message when the candidate is too old"

adapter_candidate_version() { printf ''; }
output=$(adapter_validate_version 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "adapter_validate_version unexpectedly succeeded with no resolvable candidate"
echo "$output" | grep -qi "could not query" || fail "unexpected failure message: ${output}"
echo "PASS: adapter_validate_version dies with a clear message when the candidate can't be resolved"

# 6. The real, current compat.conf/adapter combination, run for real
#    against this actual host (read-only pacman query, safe): the real
#    installed Hyprland candidate must satisfy the real declared minimum —
#    this is the concrete "is this project actually compatible with the
#    Hyprland on this machine" check.
# Re-source to restore the REAL adapter_candidate_version — unset -f would
# just delete the function entirely, not "revert" to arch.sh's original
# definition (bash keeps no redefinition history).
source "${DOTFILES_ROOT}/install/adapters/arch.sh"
declare -A compat=()
kv_parse_file "${DOTFILES_ROOT}/compat/compat.conf" compat
ADAPTER_MIN_VERSION=${compat[HYPRLAND_MIN_VERSION]}
adapter_check_hyprland_version && rc=0 || rc=$?
[[ $rc -eq 0 ]] || fail "the real installed Hyprland candidate (${ADAPTER_CANDIDATE_VERSION:-unknown}) does not satisfy compat.conf's real HYPRLAND_MIN_VERSION=${ADAPTER_MIN_VERSION} (rc=${rc})"
echo "PASS: the real installed Hyprland candidate (${ADAPTER_CANDIDATE_VERSION}) satisfies compat.conf's real HYPRLAND_MIN_VERSION=${ADAPTER_MIN_VERSION}"

echo "ALL PASS"
