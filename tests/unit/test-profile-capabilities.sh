#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/install/adapters/arch.sh"

# 1. Every dev.conf/core.conf required+optional capability resolves to a
#    real Arch package row — a stale/typo'd capability name would silently
#    make 'dotctl profile install' die at runtime instead of being caught
#    here.
for f in "${DOTFILES_ROOT}"/profiles/*.conf; do
	while IFS='=' read -r key value; do
		[[ $key == REQUIRED_CAPABILITIES || $key == OPTIONAL_CAPABILITIES ]] || continue
		[[ -z $value ]] && continue
		IFS=',' read -ra caps <<<"$value"
		for cap in "${caps[@]}"; do
			pkg=$(adapter_resolve_capability "$cap") || fail "$(basename "$f"): capability '${cap}' is unsupported by the Arch adapter"
			[[ -n $pkg && $pkg != unsupported ]] || fail "$(basename "$f"): capability '${cap}' resolved to nothing"
		done
	done <"$f"
done
echo "PASS: every profile-declared capability resolves to a real Arch package"

# 2. The regression this whole file exists to guard: none of dev.conf's
#    profile-only capabilities may ever appear in packages/capabilities.conf
#    — that file is read UNCONDITIONALLY by install.sh's core-desktop phase,
#    so a leak there would make a plain './install.sh' run install
#    profile-only tools for every user, not just 'dotctl profile install dev'.
mapfile -t core_caps < <(grep -vE '^\s*(#|$)' "${DOTFILES_ROOT}/packages/capabilities.conf")
profile_only=(neovim tmux lazygit yazi mise docker ripgrep fd fzf zoxide)
leaked=()
for cap in "${profile_only[@]}"; do
	printf '%s\n' "${core_caps[@]}" | grep -qx "$cap" && leaked+=("$cap")
done
[[ ${#leaked[@]} -eq 0 ]] || fail "profile-only capability(ies) leaked into the unconditional core set: ${leaked[*]}"
echo "PASS: dev-profile capabilities never leak into the unconditionally-resolved core capability set"

echo "ALL PASS"
