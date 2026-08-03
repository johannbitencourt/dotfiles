#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

# install.sh --config-only and dotctl apply both call the same
# apply::commit_config — this asserts they actually commit identical files
# to two fresh scratch $HOMEs, not just that both happen to exit 0.
HOME_A=$(mktemp -d)
HOME_B=$(mktemp -d)
trap 'rm -rf "$HOME_A" "$HOME_B"' EXIT

HOME="$HOME_A" "${DOTFILES_ROOT}/install.sh" --config-only --non-interactive >/dev/null 2>&1 ||
	fail "install.sh --config-only failed against a fresh scratch \$HOME"
HOME="$HOME_B" "${DOTFILES_ROOT}/scripts/dotctl" apply --non-interactive >/dev/null 2>&1 ||
	fail "dotctl apply failed against a fresh scratch \$HOME"

# install.json's transaction_id/project_commit can legitimately differ run
# to run (timestamp-based, PID-suffixed) — strip it from both before diffing.
rm -f "${HOME_A}/.local/state/dotfiles/install.json" "${HOME_B}/.local/state/dotfiles/install.json"
rm -f "${HOME_A}/.local/state/dotfiles/lock" "${HOME_B}/.local/state/dotfiles/lock"
rm -rf "${HOME_A}/.local/state/dotfiles/backups" "${HOME_B}/.local/state/dotfiles/backups"

# managed-checksums.tsv holds the same {path, checksum} rows either way, but
# (a) row order follows `find`'s filesystem traversal order, not guaranteed
# to match between two independent runs, and (b) rows record absolute paths,
# which necessarily embed each run's distinct $HOME — normalize both before
# comparing, so this actually checks the checksums, not the tmpdir names.
ledger_a="${HOME_A}/.local/state/dotfiles/managed-checksums.tsv"
ledger_b="${HOME_B}/.local/state/dotfiles/managed-checksums.tsv"
if ! diff -q \
	<(sed "s|^${HOME_A}|~|" "$ledger_a" | sort) \
	<(sed "s|^${HOME_B}|~|" "$ledger_b" | sort) >/dev/null 2>&1; then
	fail "managed-checksums.tsv content differs (order/\$HOME-independent):
$(diff <(sed "s|^${HOME_A}|~|" "$ledger_a" | sort) <(sed "s|^${HOME_B}|~|" "$ledger_b" | sort))"
fi
rm -f "$ledger_a" "$ledger_b"

if ! diff -rq "$HOME_A" "$HOME_B" >/tmp/apply-parity.diff 2>&1; then
	fail "install.sh --config-only and dotctl apply produced different trees:
$(cat /tmp/apply-parity.diff)"
fi

echo "PASS: install.sh --config-only and dotctl apply commit identical files"
echo "ALL PASS"
