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

FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
STATE_DIR="${FAKE_HOME}/.local/state/dotfiles"
mkdir -p "$STATE_DIR"

# 1. No profiles.json at all: no-op, exactly today's behavior.
declare -A out=()
profile::collect_preference_defaults out
[[ ${#out[@]} -eq 0 ]] || fail "expected no-op with no profiles.json, got: ${!out[*]}"
echo "PASS: no profiles.json -> no-op (regression-safe for every host that never ran profile install)"

# 2. A scratch profiles.json naming the real "dev" profile as installed:
#    its live PREFERENCE_DEFAULTS (EDITOR=nvim) is collected. Reads
#    profiles/dev.conf itself (the real file), not a fixture copy — this
#    is exactly what "read live off disk, not the profiles.json snapshot"
#    means, and DOTFILES_ROOT here is the real repo checkout.
printf '{"profiles":{"dev":{"installed_at":"2026-01-01T00:00:00Z"}}}\n' >"${STATE_DIR}/profiles.json"
declare -A out2=()
profile::collect_preference_defaults out2
[[ ${out2[EDITOR]:-} == nvim ]] || fail "expected EDITOR=nvim collected from the installed dev profile, got: ${out2[EDITOR]:-<unset>}"
echo "PASS: an installed profile's live PREFERENCE_DEFAULTS is collected"

# 3. plan::resolve_host actually layers this in, at the documented
#    precedence point (above project defaults, below hardware/host/local/CLI).
source "${DOTFILES_ROOT}/install/detect.sh"
source "${DOTFILES_ROOT}/install/adapters/arch.sh"
source "${DOTFILES_ROOT}/install/plan.sh"
declare -gA DETECTED=()
declare -gA CLI_PREFERENCES=()
HOME="$FAKE_HOME"
plan::resolve_host arch >/dev/null 2>&1
[[ ${HOST[EDITOR]:-} == nvim ]] || fail "expected plan::resolve_host to layer in EDITOR=nvim from the installed dev profile, got: ${HOST[EDITOR]:-<unset>}"
echo "PASS: plan::resolve_host layers in installed-profile preference defaults"

# 4. Precedence: a host-file/local-override/CLI value for the same key
#    still wins over a profile default (profiles sit near the bottom of
#    the chain, per HLD 9.1).
CLI_PREFERENCES[EDITOR]=vim
plan::resolve_host arch >/dev/null 2>&1
[[ ${HOST[EDITOR]} == vim ]] || fail "expected a CLI override to still win over the profile default, got: ${HOST[EDITOR]}"
echo "PASS: a CLI/host/local override still wins over an installed profile's default"

echo "ALL PASS"
