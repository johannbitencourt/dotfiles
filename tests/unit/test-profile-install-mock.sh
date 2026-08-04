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
source "${DOTFILES_ROOT}/install/adapters/arch.sh"
source "${DOTFILES_ROOT}/install/commit.sh"
source "${DOTFILES_ROOT}/install/rollback.sh"
source "${DOTFILES_ROOT}/install/session.sh"
source "${DOTFILES_ROOT}/install/detect.sh"
source "${DOTFILES_ROOT}/install/preflight.sh"
source "${DOTFILES_ROOT}/install/plan.sh"
source "${DOTFILES_ROOT}/install/apply.sh"
source "${DOTFILES_ROOT}/install/profile.sh"

# doctor::run is real system-reading logic already covered by
# test-doctor.sh; stub it here (no need to even source install/doctor.sh)
# so this test stays scoped to profile install's own orchestration.
doctor::run() { :; }

FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME=$FAKE_HOME
declare -gA DETECTED=()
declare -gA CLI_PREFERENCES=()
OPT_HOST=arch
OPT_DRY_RUN=0
OPT_NON_INTERACTIVE=0

# Every adapter call that would otherwise touch real pacman is shadowed —
# this session's own shell already showed sudo/pacman calls are real and
# reachable, so nothing here may execute unshadowed (same posture as
# test-adapter-remove-packages.sh / test-adapter-update-packages.sh).
captured_install="<not called>"
adapter_install_packages() { captured_install="$*"; }
adapter_remove_packages() { fail "adapter_remove_packages must never be called by profile install"; }

reports() { cat "${FAKE_HOME}/.local/state/dotfiles/profiles.json" 2>/dev/null; }

# 1. profile::_record_install's actual attribution logic, tested directly —
#    reaching this through profile::install with missing packages requires
#    actually confirming at the interactive [y/N] prompt, which reads from
#    /dev/tty by design, same as commit::_confirm_overwrite/
#    update::_confirm_upgrade/recover::_confirm_or_defer, none of which are
#    exercised through that branch anywhere in this suite either — this
#    environment has no controlling tty at all (`tty` reports "not a tty").
apply::ensure_state_dir
required=(neovim tmux jq)
present=(neovim jq)
installed=(tmux)
declare -A prefs=([EDITOR]=nvim)
profile::_record_install dev required present installed prefs
json=$(reports)
[[ -n $json ]] || fail "profile::_record_install wrote nothing"
[[ $(echo "$json" | jq -r '.profiles.dev.packages.already_present | length') -eq 2 ]] ||
	fail "expected 2 already_present packages, got: ${json}"
[[ $(echo "$json" | jq -r '.profiles.dev.packages.installed_by_profile[0]') == tmux ]] ||
	fail "expected installed_by_profile=[tmux], got: ${json}"
[[ $(echo "$json" | jq -r '.profiles.dev.preference_defaults_applied.EDITOR') == nvim ]] ||
	fail "expected preference_defaults_applied.EDITOR=nvim, got: ${json}"
echo "PASS: profile::_record_install records the present/installed package attribution and preference defaults"
rm -rf "${FAKE_HOME}/.local/state/dotfiles"

# 2. Installing a zero-required-capability profile: confirm is skipped
#    entirely (nothing to confirm), adapter_install_packages is never
#    called, and an entry is still recorded — this is the one full
#    success path reachable without a real tty. profile::_load is shadowed
#    for a synthetic "empty" id rather than shipping a whole zero-
#    capability profile file just to exercise this edge.
profile::_load() {
	local id=$1
	local -n _fixture_ref=$2
	[[ $id == empty ]] || fail "unexpected profile::_load call in zero-capability test: ${id}"
	_fixture_ref[PROFILE_ID]=empty
	_fixture_ref[REQUIRED_CAPABILITIES]=
}
profile::install empty </dev/null
[[ $captured_install == "<not called>" ]] || fail "adapter_install_packages was called for a zero-capability profile: ${captured_install}"
json=$(reports)
[[ -n $json ]] || fail "no profiles.json was written for a zero-capability profile"
echo "$json" | jq -e '.profiles.empty' >/dev/null || fail "profiles.json has no 'empty' entry: ${json}"
[[ $(echo "$json" | jq -r '.profiles.empty.packages.installed_by_profile | length') -eq 0 ]] ||
	fail "expected zero installed_by_profile packages, got: ${json}"
echo "PASS: installing a zero-capability profile skips confirm entirely and still records an entry"

# 3. Installing an already-installed profile refuses rather than
#    re-installing or double-recording.
output=$(profile::install empty </dev/null 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "installing an already-installed profile unexpectedly succeeded"
echo "$output" | grep -qi "already installed" || fail "unexpected failure message: ${output}"
echo "PASS: installing an already-installed profile refuses"
# Re-source to restore the REAL profile::_load — unset -f would just
# delete the function entirely, not "revert" to profile.sh's original
# definition (bash keeps no redefinition history).
source "${DOTFILES_ROOT}/install/profile.sh"
rm -rf "${FAKE_HOME}/.local/state/dotfiles"

# 4. --dry-run (profile "dev", which has real missing packages on this
#    host — tmux) never calls adapter_install_packages and writes no entry.
OPT_DRY_RUN=1
profile::install dev </dev/null
[[ $captured_install == "<not called>" ]] || fail "adapter_install_packages was called under --dry-run: ${captured_install}"
[[ -z $(reports) ]] || fail "a profiles.json entry was written under --dry-run"
echo "PASS: --dry-run installs nothing and writes no profiles.json entry"
OPT_DRY_RUN=0

# 5. --non-interactive refuses rather than guessing when there ARE missing
#    packages to confirm (no controlling tty either way in this environment).
OPT_NON_INTERACTIVE=1
output=$(profile::install dev </dev/null 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "profile install under --non-interactive with missing packages unexpectedly succeeded"
echo "$output" | grep -qi "refusing without confirmation" || fail "unexpected failure message: ${output}"
[[ -z $(reports) ]] || fail "a profiles.json entry was written despite refusing to install"
echo "PASS: --non-interactive refuses to install rather than guessing when confirmation is needed"
OPT_NON_INTERACTIVE=0

echo "ALL PASS"
