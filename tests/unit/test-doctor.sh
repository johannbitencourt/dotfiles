#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

status_of() {
	local json=$1 check=$2
	printf '%s' "$json" | jq -r --arg c "$check" '.[] | select(.check == $c) | .status'
}

# 1. --json is valid JSON and touches nothing under a fresh scratch $HOME.
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
before=$(find "$FAKE_HOME" -type f 2>/dev/null | sort)
json=$(HOME="$FAKE_HOME" "${DOTFILES_ROOT}/scripts/dotctl" doctor --json 2>/dev/null)
after=$(find "$FAKE_HOME" -type f 2>/dev/null | sort)
printf '%s' "$json" | jq empty || fail "doctor --json did not produce valid JSON"
# doctor is allowed to create $STATE_DIR itself (that's its own bookkeeping,
# not user config) — only assert no *managed config* appeared under $HOME.
[[ -z $(find "$FAKE_HOME/.config" -type f 2>/dev/null) ]] || fail "doctor wrote config file(s) under \$HOME/.config"
echo "PASS: doctor --json is valid JSON and writes no managed config"

# 2. On a never-applied host: managed-drift SKIP, incomplete-transaction
#    PASS, systemd-units FAIL, hyprland-config SKIP (no conf.d yet).
[[ $(status_of "$json" managed-drift) == SKIP ]] || fail "expected managed-drift=SKIP on a fresh host"
[[ $(status_of "$json" incomplete-transaction) == PASS ]] || fail "expected incomplete-transaction=PASS on a fresh host"
[[ $(status_of "$json" systemd-units) == FAIL ]] || fail "expected systemd-units=FAIL before anything is applied"
[[ $(status_of "$json" hyprland-config) == SKIP ]] || fail "expected hyprland-config=SKIP before anything is applied"
echo "PASS: fresh-host statuses (drift=SKIP, incomplete-txn=PASS, units=FAIL, hyprland-config=SKIP)"

# 3. After a real apply: systemd-units PASS, hyprland-config PASS,
#    managed-drift PASS (nothing hand-edited yet).
HOME="$FAKE_HOME" "${DOTFILES_ROOT}/install.sh" --config-only --non-interactive >/dev/null 2>&1 ||
	fail "seeding apply run failed"
json2=$(HOME="$FAKE_HOME" "${DOTFILES_ROOT}/scripts/dotctl" doctor --json 2>/dev/null)
[[ $(status_of "$json2" systemd-units) == PASS ]] || fail "expected systemd-units=PASS after apply"
[[ $(status_of "$json2" hyprland-config) == PASS ]] || fail "expected hyprland-config=PASS after apply"
[[ $(status_of "$json2" managed-drift) == PASS ]] || fail "expected managed-drift=PASS right after apply (nothing edited yet)"
echo "PASS: post-apply statuses (units=PASS, hyprland-config=PASS, drift=PASS)"

# 4. Hand-edit a managed file -> managed-drift WARN.
echo "hand-edited" >>"${FAKE_HOME}/.bashrc"
json3=$(HOME="$FAKE_HOME" "${DOTFILES_ROOT}/scripts/dotctl" doctor --json 2>/dev/null)
[[ $(status_of "$json3" managed-drift) == WARN ]] || fail "expected managed-drift=WARN after hand-editing a managed file"
echo "PASS: managed-drift=WARN after a managed file is hand-edited"

# 5. Break the (real, live) Hyprland config -> hyprland-config FAIL.
printf 'general {\n' >>"${FAKE_HOME}/.config/hypr/conf.d/40-looknfeel.conf"
json4=$(HOME="$FAKE_HOME" "${DOTFILES_ROOT}/scripts/dotctl" doctor --json 2>/dev/null)
[[ $(status_of "$json4" hyprland-config) == FAIL ]] || fail "expected hyprland-config=FAIL after corrupting the live config"
echo "PASS: hyprland-config=FAIL after the live config is corrupted"

# 6. A stale active-transaction marker (simulated crash) -> FAIL.
printf '20260101T000000Z-1\n' >"${FAKE_HOME}/.local/state/dotfiles/active-transaction"
json5=$(HOME="$FAKE_HOME" "${DOTFILES_ROOT}/scripts/dotctl" doctor --json 2>/dev/null)
[[ $(status_of "$json5" incomplete-transaction) == FAIL ]] || fail "expected incomplete-transaction=FAIL with a stale marker present"
echo "PASS: incomplete-transaction=FAIL with a stale active-transaction marker"

echo "ALL PASS"
