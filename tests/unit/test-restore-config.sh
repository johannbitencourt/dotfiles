#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

# Everything below runs against a scratch $HOME — never the real one.
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
STATE_DIR="${FAKE_HOME}/.local/state/dotfiles"
mkdir -p "${STATE_DIR}/backups/20260101T000000Z-1/home/.config/app"
mkdir -p "${STATE_DIR}/backups/20260601T000000Z-2/home/.config/app"

target="${FAKE_HOME}/.config/app/f"
mkdir -p "$(dirname "$target")"

# Older transaction backed up "older-content"; newer backed up
# "newer-content". The live file right now is "current" (as if a third,
# unrelated change happened after both backups).
printf 'older-content' >"${STATE_DIR}/backups/20260101T000000Z-1/home/.config/app/f"
printf '%s\t%s\t%s\t%s\t%s\n' "$target" "${STATE_DIR}/backups/20260101T000000Z-1/home/.config/app/f" "orig1" "new1" replace-unmanaged \
	>"${STATE_DIR}/backups/20260101T000000Z-1/manifest.tsv"

printf 'newer-content' >"${STATE_DIR}/backups/20260601T000000Z-2/home/.config/app/f"
printf '%s\t%s\t%s\t%s\t%s\n' "$target" "${STATE_DIR}/backups/20260601T000000Z-2/home/.config/app/f" "orig2" "new2" replace-unmanaged \
	>"${STATE_DIR}/backups/20260601T000000Z-2/manifest.tsv"

printf 'current' >"$target"

# 1. --last must pick the lexicographically (== chronologically, given the
#    TRANSACTION_ID format) newer of the two transactions.
HOME="$FAKE_HOME" "${DOTFILES_ROOT}/scripts/dotctl" restore-config --last >/dev/null 2>&1 ||
	fail "dotctl restore-config --last failed"
[[ $(cat "$target") == "newer-content" ]] || fail "--last did not restore the newer transaction's backup"
echo "PASS: --last restores the most recent of two transactions"

# 2. --transaction <id> restores a specific (here, the older) one.
printf 'current-again' >"$target"
HOME="$FAKE_HOME" "${DOTFILES_ROOT}/scripts/dotctl" restore-config --transaction 20260101T000000Z-1 >/dev/null 2>&1 ||
	fail "dotctl restore-config --transaction failed"
[[ $(cat "$target") == "older-content" ]] || fail "--transaction did not restore the specified transaction's backup"
echo "PASS: --transaction restores the specified transaction by id"

# 3. --last and --transaction together must be rejected, not silently
#    resolved one way or the other.
if HOME="$FAKE_HOME" "${DOTFILES_ROOT}/scripts/dotctl" restore-config --last --transaction 20260101T000000Z-1 2>/dev/null; then
	fail "restore-config accepted both --last and --transaction"
fi
echo "PASS: --last and --transaction together is rejected"

# 4. Neither flag given must be rejected, not a silent no-op.
if HOME="$FAKE_HOME" "${DOTFILES_ROOT}/scripts/dotctl" restore-config 2>/dev/null; then
	fail "restore-config with no flags did not fail"
fi
echo "PASS: no flags given is rejected"

echo "ALL PASS"
