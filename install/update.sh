#!/usr/bin/env bash
# Packages-domain update: get the plan, confirm, upgrade, record, diagnose.
#
# Deliberately outside apply::acquire_lock_and_txn's config-transaction
# machinery — no TRANSACTION_ID, no active-transaction marker, no manifest
# fragments, no touching install.json's packages.already_present/
# installed_by_project (those track capability packages install.sh's
# package phase requested; a native distro upgrade of already-installed
# packages is an orthogonal axis). Per HLD 15.4 the native package domain is
# a separate, NOT-automatically-reversible transaction domain from
# configuration — wiring it into rollback.sh would falsely imply it shares
# config's rollback guarantee.
#
# Snapshot integration (HLD 17.2's "optionally creates a supported
# snapshot") is HLD's own Phase 6 and this host has no backend — skipped
# entirely, not stubbed.

# update::_confirm_upgrade — dies under --non-interactive or on decline.
# Reuses commit::_confirm_overwrite's die-under-non-interactive/prompt/
# die-on-decline *shape* (a fourth generic confirm helper would be one too
# many), but stays its own function with its own message: a full-system
# pacman upgrade isn't "an overwrite conflict." Deliberately NOT
# uninstall::_confirm's proceed-under-non-interactive idiom either:
# uninstall's scope is fully known in advance (project-owned files/services
# only) and config-restorable; a system upgrade's package set is only known
# at runtime and is NOT automatically reversible. HLD 17.2 says "only after
# approval" — under no controlling TTY, "refuse rather than guess" is the
# safe read of that line.
update::_confirm_upgrade() {
	if [[ $OPT_NON_INTERACTIVE -eq 1 ]]; then
		log::die "update packages: refusing to upgrade without confirmation (--non-interactive)"
	fi
	log::warn "update packages: the plan above is about to be applied"
	local reply=""
	read -r -p "  Proceed with the upgrade? [y/N] " reply </dev/tty
	[[ $reply == [yY] ]] || log::die "update packages: aborted by user"
}

# update::_write_report <outcome> <plan-output> <upgrade-output>
update::_write_report() {
	local outcome=$1 plan_output=$2 upgrade_output=$3
	local report_dir="${HOME}/.local/share/dotfiles"
	mkdir -p "$report_dir"
	local report_path="${report_dir}/update-packages-report-$(date -u +%Y%m%dT%H%M%SZ).json"
	jq -n --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		--arg outcome "$outcome" --arg plan_output "$plan_output" \
		--arg upgrade_output "$upgrade_output" \
		'{schema_version: 1, generated_at: $generated_at, outcome: $outcome,
		  plan_output: $plan_output, upgrade_output: $upgrade_output}' \
		>"$report_path"
	log::info "update packages: report written to ${report_path}"
}

# update::packages_run — plan, confirm, upgrade, record, diagnose.
update::packages_run() {
	apply::ensure_state_dir

	log::info "update packages: asking the adapter for the upgrade plan..."
	local plan_output rc=0
	plan_output=$(adapter_upgrade_plan 2>&1) || rc=$?
	printf '%s\n' "$plan_output"
	((rc == 0)) || log::die "update packages: failed to compute the upgrade plan (exit ${rc})"

	if [[ $plan_output == *"there is nothing to do"* ]]; then
		log::info "update packages: already up to date"
		update::_write_report up-to-date "$plan_output" ""
		return 0
	fi

	if [[ $OPT_DRY_RUN -eq 1 ]]; then
		log::info "update packages: --dry-run, not upgrading"
		return 0
	fi

	update::_confirm_upgrade

	log::info "update packages: upgrading..."
	local upgrade_output rc2=0
	upgrade_output=$(adapter_upgrade_system 2>&1) || rc2=$?
	printf '%s\n' "$upgrade_output"
	update::_write_report "$([[ $rc2 -eq 0 ]] && printf applied || printf failed)" "$plan_output" "$upgrade_output"

	log::info "update packages: running diagnostics..."
	doctor::run 0

	((rc2 == 0)) || log::die "update packages: pacman upgrade failed (exit ${rc2}) — packages are not automatically reversible; see the report above"
	log::info "update packages: complete"
}
