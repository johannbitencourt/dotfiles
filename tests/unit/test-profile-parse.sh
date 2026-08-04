#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/scripts/lib/kv-parser.sh"
source "${DOTFILES_ROOT}/install/profile.sh"

# 1. profiles/dev.conf parses via kv_parse_file (unchanged contract — no
#    new list-support added to the parser) and splits its 11 required
#    capabilities correctly.
declare -A dev=()
kv_parse_file "${DOTFILES_ROOT}/profiles/dev.conf" dev
[[ ${dev[PROFILE_ID]} == dev ]] || fail "PROFILE_ID not parsed: ${dev[PROFILE_ID]:-<unset>}"

mapfile -t caps < <(profile::_split_list "${dev[REQUIRED_CAPABILITIES]}")
[[ ${#caps[@]} -eq 11 ]] || fail "expected 11 required capabilities, got ${#caps[@]}: ${caps[*]}"
[[ " ${caps[*]} " == *" jq "* ]] || fail "expected jq among required capabilities: ${caps[*]}"
[[ " ${caps[*]} " == *" neovim "* ]] || fail "expected neovim among required capabilities: ${caps[*]}"
echo "PASS: profiles/dev.conf parses and splits its 11 required capabilities"

# 2. PREFERENCE_DEFAULTS splits into a single KEY=VALUE pair.
declare -A prefs=()
profile::_split_preference_defaults "${dev[PREFERENCE_DEFAULTS]}" prefs
[[ ${prefs[EDITOR]} == nvim ]] || fail "expected EDITOR=nvim, got: ${prefs[EDITOR]:-<unset>}"
echo "PASS: PREFERENCE_DEFAULTS=EDITOR=nvim splits to prefs[EDITOR]=nvim"

# 3. Empty list fields parse without error (the zero-capability edge
#    dev.conf never exercises) — an inline fixture, not a whole shipped
#    profile file just to prove kv_parse_file/profile::_split_* handle "".
declare -A empty=([PROFILE_ID]=empty [REQUIRED_CAPABILITIES]= [PREFERENCE_DEFAULTS]=)
mapfile -t empty_caps < <(profile::_split_list "${empty[REQUIRED_CAPABILITIES]}")
[[ ${#empty_caps[@]} -eq 0 ]] || fail "expected zero required capabilities for an empty field, got: ${empty_caps[*]}"
declare -A empty_prefs=()
profile::_split_preference_defaults "${empty[PREFERENCE_DEFAULTS]}" empty_prefs
[[ ${#empty_prefs[@]} -eq 0 ]] || fail "expected zero preference defaults for an empty field, got: ${!empty_prefs[*]}"
echo "PASS: empty list fields parse cleanly (zero-capability edge)"

echo "ALL PASS"
