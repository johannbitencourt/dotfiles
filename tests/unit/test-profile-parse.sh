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

# 3. profiles/core.conf's empty list fields parse without error (the
#    zero-capability edge dev.conf never exercises).
declare -A core=()
kv_parse_file "${DOTFILES_ROOT}/profiles/core.conf" core
[[ ${core[PROFILE_ID]} == core ]] || fail "PROFILE_ID not parsed for core.conf: ${core[PROFILE_ID]:-<unset>}"
mapfile -t core_caps < <(profile::_split_list "${core[REQUIRED_CAPABILITIES]}")
[[ ${#core_caps[@]} -eq 0 ]] || fail "expected zero required capabilities for core.conf, got: ${core_caps[*]}"
declare -A core_prefs=()
profile::_split_preference_defaults "${core[PREFERENCE_DEFAULTS]}" core_prefs
[[ ${#core_prefs[@]} -eq 0 ]] || fail "expected zero preference defaults for core.conf, got: ${!core_prefs[*]}"
echo "PASS: profiles/core.conf's empty list fields parse cleanly (zero-capability edge)"

echo "ALL PASS"
