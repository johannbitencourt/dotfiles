#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

source "${DOTFILES_ROOT}/install/adapters/arch.sh"

FIXTURE=$(mktemp)
trap 'rm -f "$FIXTURE"' EXIT

# 1. Plain Arch Linux: ID=arch.
printf 'NAME="Arch Linux"\nID=arch\n' >"$FIXTURE"
adapter_detect "$FIXTURE" || fail "ID=arch was not detected"
echo "PASS: ID=arch is detected"

# 2. CachyOS-shaped: ID=cachyos, ID_LIKE=arch (quoted, the real-world
#    shape) — HLD 6.2 explicitly lists CachyOS as Tier 1 under the Arch
#    family, but a bare ID=arch check rejects it outright (the actual bug
#    this test guards against).
printf 'NAME="CachyOS Linux"\nID=cachyos\nID_LIKE="arch"\n' >"$FIXTURE"
adapter_detect "$FIXTURE" || fail "ID_LIKE=\"arch\" (CachyOS-shaped) was not detected"
echo "PASS: an Arch derivative declaring ID_LIKE=arch is detected"

# 3. EndeavourOS-shaped: ID_LIKE=arch, unquoted.
printf 'NAME="EndeavourOS"\nID=endeavouros\nID_LIKE=arch\n' >"$FIXTURE"
adapter_detect "$FIXTURE" || fail "unquoted ID_LIKE=arch (EndeavourOS-shaped) was not detected"
echo "PASS: an unquoted ID_LIKE=arch is also detected"

# 4. An unrelated distro: neither ID=arch nor ID_LIKE containing arch.
printf 'NAME="Fedora Linux"\nID=fedora\nID_LIKE=fedora\n' >"$FIXTURE"
if adapter_detect "$FIXTURE"; then
	fail "a non-Arch distro was incorrectly detected as Arch"
fi
echo "PASS: an unrelated distro is correctly rejected"

# 5. Missing/unreadable file.
if adapter_detect "${FIXTURE}.does-not-exist"; then
	fail "a missing os-release file was incorrectly detected as Arch"
fi
echo "PASS: a missing os-release file is rejected, not a crash"

# 6. The real /etc/os-release on this actual host — read-only, safe to
#    run for real, confirms the real call site (no argument, defaults to
#    /etc/os-release) still works after adding the optional parameter.
adapter_detect || fail "the real /etc/os-release on this host was not detected as Arch-family"
echo "PASS: the real /etc/os-release on this host is detected"

echo "ALL PASS"
