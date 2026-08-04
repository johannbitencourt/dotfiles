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

# 2. Installing "core" (zero required capabilities): confirm is skipped
#    entirely (nothing to confirm), adapter_install_packages is never
#    called, and an entry is still recorded — this is the one full
#    success path reachable without a real tty.
profile::install core </dev/null
[[ $captured_install == "<not called>" ]] || fail "adapter_install_packages was called for a zero-capability profile: ${captured_install}"
json=$(reports)
[[ -n $json ]] || fail "no profiles.json was written for core"
echo "$json" | jq -e '.profiles.core' >/dev/null || fail "profiles.json has no 'core' entry: ${json}"
[[ $(echo "$json" | jq -r '.profiles.core.packages.installed_by_profile | length') -eq 0 ]] ||
	fail "expected zero installed_by_profile packages for core, got: ${json}"
echo "PASS: installing a zero-capability profile skips confirm entirely and still records an entry"

# 3. Installing an already-installed profile refuses rather than
#    re-installing or double-recording.
output=$(profile::install core </dev/null 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "installing an already-installed profile unexpectedly succeeded"
echo "$output" | grep -qi "already installed" || fail "unexpected failure message: ${output}"
echo "PASS: installing an already-installed profile refuses"
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
echo "$output" | grep -qi "refusing to proceed without confirmation" || fail "unexpected failure message: ${output}"
[[ -z $(reports) ]] || fail "a profiles.json entry was written despite refusing to install"
echo "PASS: --non-interactive refuses to install rather than guessing when confirmation is needed"
OPT_NON_INTERACTIVE=0

# 6. Conflict gating: profile::install dies on a declared conflict with a
#    currently-installed profile unless --force. Reachable end to end
#    without a tty, since the conflict check runs before any confirm.
#    profile::_load is shadowed to give "core" (0 required capabilities,
#    so a forced install needs no confirm either) a synthetic
#    CONFLICTING_PROFILES, without touching the real profiles/core.conf.
rm -rf "${FAKE_HOME}/.local/state/dotfiles"
mkdir -p "${FAKE_HOME}/.local/state/dotfiles"
printf '{"profiles":{"beta":{}}}\n' >"${FAKE_HOME}/.local/state/dotfiles/profiles.json"
profile::_load() {
	local id=$1
	local -n _fixture_ref=$2
	[[ $id == core ]] || fail "unexpected profile::_load call in conflict-gating test: ${id}"
	_fixture_ref[PROFILE_ID]=core
	_fixture_ref[CONFLICTING_PROFILES]=beta
}
output=$(profile::install core 0 </dev/null 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "profile install with an unforced declared conflict unexpectedly succeeded"
echo "$output" | grep -qi "declared conflict" || fail "expected a conflict failure message, got: ${output}"
echo "$(reports)" | jq -e '.profiles.core' >/dev/null 2>&1 && fail "a 'core' profiles.json entry was written despite the unforced conflict"
echo "PASS: profile install dies on a declared conflict with a currently-installed profile unless --force"

profile::install core 1 </dev/null
json=$(reports)
echo "$json" | jq -e '.profiles.core' >/dev/null || fail "expected --force to let a conflicting zero-capability profile install, got: ${json}"
echo "PASS: --force proceeds past a declared conflict"
unset -f profile::_load
rm -rf "${FAKE_HOME}/.local/state/dotfiles"

# 7. Hardware-constraint gating: profile::install always dies on an unmet
#    hardware constraint, no override flag — checked against this real
#    host's actual detected GPU vendor (read-only detection, safe to run
#    for real; this machine is confirmed nvidia earlier this session, so
#    "amd" is unmet by construction).
profile::_load() {
	local id=$1
	local -n _fixture_ref=$2
	[[ $id == core ]] || fail "unexpected profile::_load call in hardware-constraint-gating test: ${id}"
	_fixture_ref[PROFILE_ID]=core
	_fixture_ref[HARDWARE_CONSTRAINTS]=GPU_VENDOR=amd
}
output=$(profile::install core </dev/null 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "profile install with an unmet hardware constraint unexpectedly succeeded"
echo "$output" | grep -qi "unmet hardware constraint" || fail "expected an unmet-hardware-constraint failure message, got: ${output}"
[[ -z $(reports) ]] || fail "a profiles.json entry was written despite the unmet hardware constraint"
echo "PASS: profile install always dies on an unmet hardware constraint, no override"
unset -f profile::_load

echo "ALL PASS"
