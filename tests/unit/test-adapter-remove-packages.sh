#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/install/adapters/arch.sh"

fail() {
	echo "FAIL: $*"
	exit 1
}

# 1. No packages -> no-op, sudo/pacman never invoked at all.
sudo() {
	echo "FAIL: sudo was called with no packages to remove" >&2
	exit 1
}
adapter_remove_packages || fail "adapter_remove_packages with no args returned nonzero"
unset -f sudo
echo "PASS: no packages -> no-op, sudo never invoked"

# 2. With packages -> a real array passed to `sudo pacman -R --noconfirm`,
#    not eval'd or string-built. `sudo` is shadowed here so no real pacman
#    command ever runs.
captured=""
sudo() { captured="$*"; }
adapter_remove_packages foo bar-baz
unset -f sudo
[[ $captured == "pacman -R --noconfirm foo bar-baz" ]] || fail "unexpected sudo invocation: ${captured}"
echo "PASS: packages passed through as a real array, not a string-built command"

echo "ALL PASS"
