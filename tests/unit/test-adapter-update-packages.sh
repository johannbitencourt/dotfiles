#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/install/adapters/arch.sh"

fail() {
	echo "FAIL: $*"
	exit 1
}

# 1. adapter_upgrade_plan -> exactly `sudo pacman -Syu --print --noconfirm`,
#    real pacman never invoked.
captured=""
sudo() { captured="$*"; }
adapter_upgrade_plan
unset -f sudo
[[ $captured == "pacman -Syu --print --noconfirm" ]] || fail "unexpected sudo invocation: ${captured}"
echo "PASS: adapter_upgrade_plan invokes exactly 'pacman -Syu --print --noconfirm'"

# 2. adapter_upgrade_system -> exactly `sudo pacman -Syu --noconfirm`, real
#    pacman never invoked.
captured=""
sudo() { captured="$*"; }
adapter_upgrade_system
unset -f sudo
[[ $captured == "pacman -Syu --noconfirm" ]] || fail "unexpected sudo invocation: ${captured}"
echo "PASS: adapter_upgrade_system invokes exactly 'pacman -Syu --noconfirm'"

echo "ALL PASS"
