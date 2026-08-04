#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/scripts/lib/cleanup.sh"
source "${DOTFILES_ROOT}/install/adapters/arch.sh"
source "${DOTFILES_ROOT}/install/commit.sh"
source "${DOTFILES_ROOT}/install/rollback.sh"
source "${DOTFILES_ROOT}/install/session.sh"
source "${DOTFILES_ROOT}/install/apply.sh"
source "${DOTFILES_ROOT}/install/recover.sh"

# 1. A completely fresh scratch $HOME: nothing to detect.
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME=$FAKE_HOME
recover::detect
[[ -z $RECOVER_TXN ]] || fail "fresh host reported an incomplete transaction"
[[ ${#RECOVER_DRIFTED[@]} -eq 0 ]] || fail "fresh host reported drift"
[[ $RECOVER_HYPRLAND_CONFIG_BROKEN -eq 0 ]] || fail "fresh host reported a broken Hyprland config"
[[ ${#RECOVER_MISSING_UNITS[@]} -eq 0 ]] || fail "fresh host reported missing units (none expected — none checked for, since nothing applied)"
echo "PASS: fresh host detects nothing"

# 1b. A --dry-run apply leaves behind an install.json (metadata fragments
# are unconditional) without ever touching the checksum ledger. That alone
# must not make recover treat this host as "already applied."
mkdir -p "${FAKE_HOME}/.local/state/dotfiles"
printf '{"managed_files": []}\n' >"${FAKE_HOME}/.local/state/dotfiles/install.json"
recover::detect
[[ ${#RECOVER_MISSING_UNITS[@]} -eq 0 ]] || fail "a dry-run-only install.json incorrectly made units look missing"
echo "PASS: a dry-run-only install.json does not trigger a missing-units finding"
rm -f "${FAKE_HOME}/.local/state/dotfiles/install.json"

# 2. A stale active-transaction marker is detected.
printf '20260101T000000Z-1\n' >"${FAKE_HOME}/.local/state/dotfiles/active-transaction"
recover::detect
[[ $RECOVER_TXN == "20260101T000000Z-1" ]] || fail "incomplete transaction not detected: RECOVER_TXN=${RECOVER_TXN}"
echo "PASS: an incomplete transaction is detected"
rm -f "${FAKE_HOME}/.local/state/dotfiles/active-transaction"

# 3. Seed via a real apply, then hand-edit a managed file: drift detected.
HOME="$FAKE_HOME" "${DOTFILES_ROOT}/install.sh" --config-only --non-interactive >/dev/null 2>&1 ||
	fail "seeding apply run failed"
echo "hand-edited" >>"${FAKE_HOME}/.bashrc"
recover::detect
[[ ${#RECOVER_DRIFTED[@]} -gt 0 ]] || fail "drift was not detected after hand-editing a managed file"
[[ " ${RECOVER_DRIFTED[*]} " == *" ${FAKE_HOME}/.bashrc "* ]] || fail "drifted list did not include the hand-edited file: ${RECOVER_DRIFTED[*]}"
echo "PASS: drift in a managed file is detected"

# 4. Right after that same apply: units present, Hyprland config valid.
[[ $RECOVER_HYPRLAND_CONFIG_BROKEN -eq 0 ]] || fail "hyprland config incorrectly reported broken right after a clean apply"
[[ ${#RECOVER_MISSING_UNITS[@]} -eq 0 ]] || fail "units incorrectly reported missing right after a clean apply"
echo "PASS: hyprland-config/units both clean right after a real apply"

# 5. Corrupt the live Hyprland config: detected as broken.
printf 'general {\n' >>"${FAKE_HOME}/.config/hypr/conf.d/40-looknfeel.conf"
recover::detect
[[ $RECOVER_HYPRLAND_CONFIG_BROKEN -eq 1 ]] || fail "corrupted hyprland config was not detected"
echo "PASS: a corrupted live Hyprland config is detected"

# 6. Remove a unit file: detected as missing.
rm -f "${FAKE_HOME}/.config/systemd/user/waybar.service"
recover::detect
[[ " ${RECOVER_MISSING_UNITS[*]} " == *" waybar.service "* ]] || fail "removed unit file was not detected as missing: ${RECOVER_MISSING_UNITS[*]}"
echo "PASS: a removed systemd unit file is detected as missing"

# --- Action layer (M4): drive the real `dotctl recover` end to end. ---
# The interactive [y/N] confirm path reads from /dev/tty by design (same as
# commit::_confirm_overwrite / uninstall::_confirm) and isn't automated
# anywhere else in this suite either — only --non-interactive is exercised
# here. The underlying mutations it would trigger (rollback::restore_transaction,
# apply::commit_config) are already covered by test-restore-config.sh and
# test-doctor.sh/test-apply-parity.sh, so this only needs to prove recover's
# own logic: coalescing, deferring, and exit codes.

ACTION_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME" "$ACTION_HOME"' EXIT

# 7. A healthy, never-applied host: exit 0, no mutation.
output=$(HOME="$ACTION_HOME" "${DOTFILES_ROOT}/scripts/dotctl" recover --non-interactive 2>&1) && rc=0 || rc=$?
[[ $rc -eq 0 ]] || fail "expected exit 0 on a healthy host, got ${rc}: ${output}"
echo "$output" | grep -qi "healthy" || fail "expected a 'healthy' message, got: ${output}"
echo "PASS: a healthy host exits 0 with no action offered"

# 8. Seed an incomplete transaction: --non-interactive defers, never restores,
#    exits 2, and names the exact manual command.
mkdir -p "${ACTION_HOME}/.local/state/dotfiles"
printf '20260101T000000Z-1\n' >"${ACTION_HOME}/.local/state/dotfiles/active-transaction"
output=$(HOME="$ACTION_HOME" "${DOTFILES_ROOT}/scripts/dotctl" recover --non-interactive 2>&1) && rc=0 || rc=$?
[[ $rc -eq 2 ]] || fail "expected exit 2 with an incomplete transaction deferred, got ${rc}: ${output}"
echo "$output" | grep -q "dotctl restore-config --transaction 20260101T000000Z-1" || fail "expected the exact manual restore command, got: ${output}"
[[ -f "${ACTION_HOME}/.local/state/dotfiles/active-transaction" ]] || fail "--non-interactive must never act: the marker was removed"
echo "PASS: an incomplete transaction defers under --non-interactive, exit 2, marker untouched"
rm -f "${ACTION_HOME}/.local/state/dotfiles/active-transaction"

# 9. Seed drift: --non-interactive defers, never regenerates, exits 2, and
#    names `dotctl apply` as the fix.
HOME="$ACTION_HOME" "${DOTFILES_ROOT}/install.sh" --config-only --non-interactive >/dev/null 2>&1 ||
	fail "seeding apply run failed"
echo "hand-edited" >>"${ACTION_HOME}/.bashrc"
before_sum=$(sha256sum "${ACTION_HOME}/.bashrc" | awk '{print $1}')
output=$(HOME="$ACTION_HOME" "${DOTFILES_ROOT}/scripts/dotctl" recover --non-interactive 2>&1) && rc=0 || rc=$?
[[ $rc -eq 2 ]] || fail "expected exit 2 with drift deferred, got ${rc}: ${output}"
echo "$output" | grep -q "dotctl apply" || fail "expected 'dotctl apply' named as the fix, got: ${output}"
after_sum=$(sha256sum "${ACTION_HOME}/.bashrc" | awk '{print $1}')
[[ $before_sum == "$after_sum" ]] || fail "--non-interactive must never act: the drifted file was regenerated anyway"
echo "PASS: drift defers under --non-interactive, exit 2, file left untouched"

echo "ALL PASS"
