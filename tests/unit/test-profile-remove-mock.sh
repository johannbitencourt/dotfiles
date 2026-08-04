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
source "${DOTFILES_ROOT}/install/apply.sh"
source "${DOTFILES_ROOT}/install/profile.sh"

doctor::run() { :; }

FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME=$FAKE_HOME
OPT_DRY_RUN=0
OPT_NON_INTERACTIVE=0

captured_remove="<not called>"
adapter_remove_packages() { captured_remove="$*"; }
adapter_install_packages() { fail "adapter_install_packages must never be called by profile remove"; }

# 1. The orphan check itself, tested directly (reaching it through
#    profile::remove when there's something to actually remove requires
#    confirming at the interactive [y/N] prompt, which reads from /dev/tty
#    by design — untested for the same reason as every other confirm gate
#    in this suite). Two synthetic profiles, never the real profiles/
#    directory: "alpha" (installed, needs neovim+tmux) and "beta"
#    (installed, needs neovim+fd) — removing "beta" must keep "neovim"
#    (alpha still needs it) but flag "fd" for removal (nothing else needs
#    it). DOTFILES_ROOT itself stays real (so adapter_resolve_capability
#    resolves against the real, already-tested arch.conf mapping) — only
#    profile::_load is shadowed, to serve the two synthetic profiles
#    without ever touching the real profiles/ directory.
apply::ensure_state_dir
profile::_load() {
	local id=$1
	local -n _fixture_ref=$2
	case $id in
	alpha) _fixture_ref[REQUIRED_CAPABILITIES]=neovim,tmux ;;
	beta) _fixture_ref[REQUIRED_CAPABILITIES]=neovim,fd ;;
	*) fail "unexpected profile::_load call in orphan-check test: ${id}" ;;
	esac
}
printf '{"schema_version":1,"profiles":{"alpha":{"packages":{"installed_by_profile":["neovim","tmux"]}},"beta":{"packages":{"installed_by_profile":["neovim","fd"]}}}}\n' \
	>"${STATE_DIR}/profiles.json"

keep=() to_remove=()
profile::_compute_orphans beta keep to_remove
[[ " ${keep[*]} " == *" neovim "* ]] || fail "expected neovim to be kept (alpha still needs it), got keep=${keep[*]}"
[[ " ${to_remove[*]} " == *" fd "* ]] || fail "expected fd to be flagged for removal, got to_remove=${to_remove[*]}"
[[ " ${to_remove[*]} " != *" neovim "* ]] || fail "neovim was incorrectly flagged for removal: ${to_remove[*]}"
echo "PASS: profile::_compute_orphans keeps a package still needed by another installed profile, flags the exclusive one"

# 2. Removing "alpha" itself, with "beta" still (fictionally) installed:
#    neovim stays kept (beta still needs it), but tmux — needed by nothing
#    else, not core either — is flagged for removal. Symmetric proof to
#    case 1, from the other profile's side of the same fixture.
keep2=() to_remove2=()
profile::_compute_orphans alpha keep2 to_remove2
[[ " ${keep2[*]} " == *" neovim "* ]] || fail "expected neovim to be kept (beta still needs it), got keep=${keep2[*]}"
[[ " ${to_remove2[*]} " == *" tmux "* ]] || fail "expected tmux flagged for removal, got to_remove=${to_remove2[*]}"
[[ " ${to_remove2[*]} " != *" neovim "* ]] || fail "neovim was incorrectly flagged for removal: ${to_remove2[*]}"
echo "PASS: a package needed by nothing else (no other profile, not core) is flagged for removal"
unset -f profile::_load
rm -f "${STATE_DIR}/profiles.json"

# 3. Removing a profile that isn't currently installed dies.
output=$(profile::remove dev 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "removing a not-installed profile unexpectedly succeeded"
echo "$output" | grep -qi "not currently installed" || fail "unexpected failure message: ${output}"
echo "PASS: removing a not-installed profile dies rather than silently succeeding"

# 4. --dry-run: seed a real "dev" install record (tmux installed_by_profile),
#    confirm is never reached, nothing removed, entry untouched.
printf '{"schema_version":1,"profiles":{"dev":{"packages":{"installed_by_profile":["tmux"],"already_present":[]}}}}\n' \
	>"${STATE_DIR}/profiles.json"
OPT_DRY_RUN=1
profile::remove dev </dev/null
[[ $captured_remove == "<not called>" ]] || fail "adapter_remove_packages was called under --dry-run: ${captured_remove}"
jq -e '.profiles.dev' "${STATE_DIR}/profiles.json" >/dev/null || fail "the dev entry was deleted under --dry-run"
echo "PASS: --dry-run removes nothing and leaves the profiles.json entry intact"
OPT_DRY_RUN=0

# 5. --non-interactive refuses rather than guessing when there IS something
#    to actually remove (tmux isn't needed by anything else here).
OPT_NON_INTERACTIVE=1
output=$(profile::remove dev </dev/null 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "profile remove under --non-interactive with removable packages unexpectedly succeeded"
echo "$output" | grep -qi "refusing without confirmation" || fail "unexpected failure message: ${output}"
jq -e '.profiles.dev' "${STATE_DIR}/profiles.json" >/dev/null || fail "the dev entry was deleted despite refusing to remove"
[[ $captured_remove == "<not called>" ]] || fail "adapter_remove_packages was called under --non-interactive: ${captured_remove}"
echo "PASS: --non-interactive refuses to remove rather than guessing when confirmation is needed"

echo "ALL PASS"
