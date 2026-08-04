#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

# IMPORTANT: this host's live Omarchy session has real systemd --user units
# literally named waybar.service/mako.service/hypridle.service (confirmed
# via `systemctl --user list-unit-files`) — calling the real
# adapter_disable_system_service here could disable Omarchy's actual
# running services. adapter_disable_system_service is shadowed below
# (same technique as test-adapter-remove-packages.sh's `sudo` shadow) so
# this test never touches the real systemctl --user at all.

# seed_fixture <state-dir> — a managed_files set with one restorable file
# (has a replace-unmanaged backup) and one fresh-install file (no backup).
seed_fixture() {
	local state_dir=$1 fake_home=$2
	mkdir -p "$state_dir"

	local restorable="${fake_home}/.config/app/restorable"
	local fresh="${fake_home}/.config/app/fresh"
	mkdir -p "$(dirname "$restorable")"
	printf 'current project content' >"$restorable"
	printf 'fresh project content' >"$fresh"

	jq -n --arg r "$restorable" --arg f "$fresh" \
		'{managed_files: [{path:$r, checksum:"sha256:x", action:"update"},
		                  {path:$f, checksum:"sha256:y", action:"install"}],
		  services_enabled: ["waybar.service","mako.service"],
		  packages: {already_present: [], installed_by_project: []}}' \
		>"${state_dir}/install.json"

	local backup_dir="${state_dir}/backups/20260101T000000Z-1"
	local backup_file="${backup_dir}/home/.config/app/restorable"
	mkdir -p "$(dirname "$backup_file")"
	printf 'true original content' >"$backup_file"
	printf '%s\t%s\torig\tnew\treplace-unmanaged\n' "$restorable" "$backup_file" >"${backup_dir}/manifest.tsv"
}

run_uninstall() {
	# shadow adapter_disable_system_service so nothing ever touches the
	# real systemctl --user (see the safety note above)
	adapter_disable_system_service() {
		DISABLED_UNITS+=("$1")
	}
	uninstall::run "$@"
}

source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/scripts/lib/cleanup.sh"
source "${DOTFILES_ROOT}/scripts/lib/kv-parser.sh"
source "${DOTFILES_ROOT}/install/adapters/arch.sh"
source "${DOTFILES_ROOT}/install/commit.sh"
source "${DOTFILES_ROOT}/install/rollback.sh"
source "${DOTFILES_ROOT}/install/session.sh"
source "${DOTFILES_ROOT}/install/apply.sh"
source "${DOTFILES_ROOT}/install/uninstall.sh"

# 1. --dry-run changes nothing at all.
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME=$FAKE_HOME
seed_fixture "${HOME}/.local/state/dotfiles" "$HOME"
# Scoped to .config, not all of $HOME: apply::ensure_state_dir legitimately
# touches the checksum ledger under $STATE_DIR even during --dry-run (its
# own bookkeeping, not managed config) — matches test-doctor.sh's precedent.
before=$(find "${HOME}/.config" -type f -exec sha256sum {} + | sort)
OPT_NON_INTERACTIVE=0
DISABLED_UNITS=()
run_uninstall 0 0 0 1 >/dev/null 2>&1
after=$(find "${HOME}/.config" -type f -exec sha256sum {} + | sort)
[[ $before == "$after" ]] || fail "--dry-run modified files"
[[ ${#DISABLED_UNITS[@]} -eq 0 ]] || fail "--dry-run stopped services"
echo "PASS: --dry-run changes nothing"

# 2. Real run (--non-interactive, proceeds without prompting): restorable
#    file goes back to its true original; fresh file (no backup) is
#    removed; services get "disabled" (captured, not real).
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME=$FAKE_HOME
seed_fixture "${HOME}/.local/state/dotfiles" "$HOME"
OPT_NON_INTERACTIVE=1
DISABLED_UNITS=()
run_uninstall 0 0 0 0 >/dev/null 2>&1
[[ $(cat "${HOME}/.config/app/restorable") == "true original content" ]] ||
	fail "restorable file was not restored to its true original"
[[ ! -e "${HOME}/.config/app/fresh" ]] || fail "fresh-install file (no backup) was not removed"
[[ " ${DISABLED_UNITS[*]} " == *" waybar.service "* && " ${DISABLED_UNITS[*]} " == *" mako.service "* ]] ||
	fail "expected services were not stopped: ${DISABLED_UNITS[*]}"
echo "PASS: restore-if-backup-exists, else remove; services stopped (captured, not real)"

# 3. --keep-config: files untouched, but services still stop.
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME=$FAKE_HOME
seed_fixture "${HOME}/.local/state/dotfiles" "$HOME"
OPT_NON_INTERACTIVE=1
DISABLED_UNITS=()
run_uninstall 0 0 1 0 >/dev/null 2>&1
[[ $(cat "${HOME}/.config/app/restorable") == "current project content" ]] || fail "--keep-config touched the restorable file"
[[ -e "${HOME}/.config/app/fresh" ]] || fail "--keep-config removed the fresh file"
[[ ${#DISABLED_UNITS[@]} -eq 2 ]] || fail "--keep-config should still stop services"
echo "PASS: --keep-config leaves files alone, still stops services"

# 4. --remove-packages with no installed_by_project data warns, doesn't crash.
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME=$FAKE_HOME
seed_fixture "${HOME}/.local/state/dotfiles" "$HOME"
OPT_NON_INTERACTIVE=1
DISABLED_UNITS=()
output=$(run_uninstall 1 0 0 0 2>&1)
echo "$output" | grep -qi "installed_by_project" || fail "no warning shown for empty installed_by_project on --remove-packages"
echo "PASS: --remove-packages with no package data warns instead of crashing"

# 5. Report survives --remove-state (written outside \$STATE_DIR).
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME=$FAKE_HOME
seed_fixture "${HOME}/.local/state/dotfiles" "$HOME"
OPT_NON_INTERACTIVE=1
DISABLED_UNITS=()
run_uninstall 0 1 0 0 >/dev/null 2>&1
[[ ! -d "${HOME}/.local/state/dotfiles" ]] || fail "--remove-state did not remove \$STATE_DIR"
report_count=$(find "${HOME}/.local/share/dotfiles" -name 'uninstall-report-*.json' 2>/dev/null | wc -l)
[[ $report_count -eq 1 ]] || fail "expected exactly one uninstall report, found ${report_count}"
report_path=$(find "${HOME}/.local/share/dotfiles" -name 'uninstall-report-*.json')
jq empty "$report_path" || fail "uninstall report is not valid JSON"
[[ $(jq -r '.flags.remove_state' "$report_path") == true ]] || fail "report does not reflect remove_state=true"
echo "PASS: report survives --remove-state, lives under .local/share, is valid JSON"

# 6. A still-installed tool profile (profiles.json, entirely separate from
#    install.json) is warned about, since this uninstall never touches it.
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME=$FAKE_HOME
seed_fixture "${HOME}/.local/state/dotfiles" "$HOME"
printf '{"profiles":{"dev":{}}}\n' >"${HOME}/.local/state/dotfiles/profiles.json"
OPT_NON_INTERACTIVE=1
DISABLED_UNITS=()
output=$(run_uninstall 0 0 0 0 2>&1)
echo "$output" | grep -qi "tool profile(s) still installed" || fail "no warning shown for a still-installed tool profile: ${output}"
echo "$output" | grep -q "dev" || fail "warning did not name the still-installed profile: ${output}"
echo "PASS: a still-installed tool profile is warned about, not silently left untouched"

# 7. No profiles.json at all: no warning (today's common case).
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME=$FAKE_HOME
seed_fixture "${HOME}/.local/state/dotfiles" "$HOME"
OPT_NON_INTERACTIVE=1
DISABLED_UNITS=()
output=$(run_uninstall 0 0 0 0 2>&1)
echo "$output" | grep -qi "tool profile(s) still installed" && fail "unexpected profile warning with no profiles.json at all: ${output}"
echo "PASS: no profiles.json -> no warning"

echo "ALL PASS"
