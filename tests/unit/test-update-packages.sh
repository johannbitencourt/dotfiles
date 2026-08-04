#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/scripts/lib/cleanup.sh"
source "${DOTFILES_ROOT}/install/commit.sh"
source "${DOTFILES_ROOT}/install/apply.sh"
source "${DOTFILES_ROOT}/install/update.sh"

# update::packages_run's diagnostics step is a real call to doctor::run,
# already covered end to end by test-doctor.sh; stub it here so this test
# stays scoped to update.sh's own orchestration (plan -> confirm -> upgrade
# -> report), not doctor's real system checks.
doctor::run() { :; }

FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME=$FAKE_HOME
OPT_DRY_RUN=0
OPT_NON_INTERACTIVE=0

reports() { find "${HOME}/.local/share/dotfiles" -maxdepth 1 -name 'update-packages-report-*.json' 2>/dev/null; }

# 1. Already up to date: no confirm, no upgrade, report outcome=up-to-date.
adapter_upgrade_plan() { printf ':: Starting full system upgrade...\nthere is nothing to do\n'; }
adapter_upgrade_system() { fail "adapter_upgrade_system must not be called when up to date"; }
update::packages_run
report=$(reports)
[[ -n $report ]] || fail "no report written when up to date"
[[ $(jq -r .outcome "$report") == up-to-date ]] || fail "expected outcome=up-to-date, got: $(cat "$report")"
echo "PASS: already up to date -> report outcome=up-to-date, upgrade never attempted"
rm -f "$report"

# 2. Pending upgrade + --dry-run: no confirm, no upgrade, no report at all.
adapter_upgrade_plan() { printf 'Packages (1) foo-1.0-1 -> foo-1.1-1\n'; }
adapter_upgrade_system() { fail "adapter_upgrade_system must not be called under --dry-run"; }
OPT_DRY_RUN=1
update::packages_run
[[ -z $(reports) ]] || fail "a report was written under --dry-run"
echo "PASS: --dry-run shows the plan, upgrades nothing, writes no report"
OPT_DRY_RUN=0

# 3. Pending upgrade + --non-interactive: refuses rather than guesses (HLD
#    "only after approval" — under no controlling TTY that means refuse),
#    no upgrade, no report.
adapter_upgrade_system() { fail "adapter_upgrade_system must not be called under --non-interactive"; }
OPT_NON_INTERACTIVE=1
output=$(update::packages_run 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "update::packages_run under --non-interactive with a pending upgrade unexpectedly succeeded"
echo "$output" | grep -qi "refusing to upgrade without confirmation" || fail "unexpected failure message: ${output}"
[[ -z $(reports) ]] || fail "a report was written despite refusing to upgrade"
echo "PASS: --non-interactive refuses to upgrade rather than guessing, no report"
OPT_NON_INTERACTIVE=0

# 4. update::_write_report's failure-path shape, tested directly: reaching
#    it through update::packages_run requires actually confirming at the
#    interactive [y/N] prompt, which reads from /dev/tty by design — same as
#    commit::_confirm_overwrite/uninstall::_confirm/recover::_confirm_or_defer,
#    none of which are exercised through that branch anywhere in this suite
#    either. This environment has no controlling tty at all (`tty` reports
#    "not a tty"), so that branch stays untested here too, on purpose.
update::_write_report failed "Packages (1) foo-1.0-1 -> foo-1.1-1" "error: some failure"
report=$(reports)
[[ -n $report ]] || fail "update::_write_report wrote nothing"
[[ $(jq -r .outcome "$report") == failed ]] || fail "expected outcome=failed, got: $(cat "$report")"
[[ $(jq -r .upgrade_output "$report") == "error: some failure" ]] || fail "upgrade_output not recorded verbatim"
echo "PASS: update::_write_report records a failed outcome with the real upgrade output"
rm -f "$report"

# 5. Domain separation: a run never touches install.json, active-transaction,
#    the checksum ledger, or backups — those belong to the config domain.
mkdir -p "${HOME}/.local/state/dotfiles"
printf '{"managed_files": []}\n' >"${HOME}/.local/state/dotfiles/install.json"
before=$(sha256sum "${HOME}/.local/state/dotfiles/install.json" | awk '{print $1}')
adapter_upgrade_plan() { printf 'there is nothing to do\n'; }
update::packages_run
after=$(sha256sum "${HOME}/.local/state/dotfiles/install.json" | awk '{print $1}')
[[ $before == "$after" ]] || fail "update packages touched install.json — that's the config domain's file"
[[ ! -f "${HOME}/.local/state/dotfiles/active-transaction" ]] || fail "update packages left an active-transaction marker — it has no transaction"
[[ ! -d "${HOME}/.local/state/dotfiles/backups" ]] || fail "update packages created a backups dir — packages aren't backed up like config"
echo "PASS: packages domain never touches the config domain's transaction/manifest/backup state"
rm -f "$(reports)"

echo "ALL PASS"
