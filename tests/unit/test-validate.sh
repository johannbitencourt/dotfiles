#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

# 1. A real validate run against this actual repo must succeed and touch
#    nothing under $HOME.
FAKE_HOME=$(mktemp -d)
before=$(find "$FAKE_HOME" -type f 2>/dev/null | wc -l)
HOME="$FAKE_HOME" "${DOTFILES_ROOT}/scripts/dotctl" validate >/dev/null 2>&1 ||
	fail "dotctl validate failed against the real, uncorrupted repo"
after=$(find "$FAKE_HOME" -type f 2>/dev/null | wc -l)
[[ $before -eq $after ]] || fail "dotctl validate wrote file(s) under \$HOME"
rm -rf "$FAKE_HOME"
echo "PASS: validate succeeds on the real repo and writes nothing under \$HOME"

# 2. A scratch checkout with one corrupted app-module input must fail
#    loudly, and still write nothing under $HOME.
scratch_repo=$(mktemp -d)
cp -r "${DOTFILES_ROOT}/." "$scratch_repo/"
rm -rf "${scratch_repo}/.git"
# An unclosed brace is a real Hyprland parse error, not just a missing
# option name — a stronger corruption than a typo'd key.
printf 'general {\n' >>"${scratch_repo}/config/hypr/conf.d/40-looknfeel.conf.tmpl"

FAKE_HOME2=$(mktemp -d)
before2=$(find "$FAKE_HOME2" -type f 2>/dev/null | wc -l)
if HOME="$FAKE_HOME2" "${scratch_repo}/scripts/dotctl" validate >/tmp/validate-corrupt.log 2>&1; then
	fail "dotctl validate did not fail against a corrupted config template"
fi
after2=$(find "$FAKE_HOME2" -type f 2>/dev/null | wc -l)
[[ $before2 -eq $after2 ]] || fail "dotctl validate wrote file(s) under \$HOME despite failing"
grep -qi "verif" /tmp/validate-corrupt.log || fail "failure output didn't mention config verification:
$(cat /tmp/validate-corrupt.log)"

rm -rf "$scratch_repo" "$FAKE_HOME2"
echo "PASS: validate fails loudly on a corrupted app-module input, writes nothing under \$HOME"

echo "ALL PASS"
