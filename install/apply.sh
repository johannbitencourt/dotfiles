#!/usr/bin/env bash
# The shared core between install.sh's config phase and `dotctl apply`.
# Neither wraps the other — both call these same functions. Requires
# OPT_HOST/OPT_DRY_RUN/OPT_NON_INTERACTIVE to already be set by the caller's
# own option parsing (plain global assignment, no `local`, is enough — see
# each caller).

# apply::ensure_state_dir — just $STATE_DIR + the commit checksum ledger.
# Read-only callers (diff, doctor, restore-config) need this without taking
# the project lock or minting a transaction — they aren't starting a
# mutation, so they shouldn't contend with one that's in progress.
apply::ensure_state_dir() {
	STATE_DIR="${HOME}/.local/state/dotfiles"
	mkdir -p "$STATE_DIR"
	commit::init
}

# apply::acquire_lock_and_txn — takes the project lock, mints a transaction
# id, and writes the minimal "a transaction is in progress" marker doctor's
# incomplete-transaction check reads. Also brings up the manifest fragment
# store, since callers need to add fragments (e.g. install.sh's package-plan
# fragment) before staging runs.
apply::acquire_lock_and_txn() {
	apply::ensure_state_dir
	LOCK_FILE="${STATE_DIR}/lock"
	exec 200>"$LOCK_FILE"
	flock -n 200 || log::die "another install/update is already running (lock: ${LOCK_FILE})"

	TRANSACTION_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
	readonly TRANSACTION_ID
	printf '%s\n' "$TRANSACTION_ID" >"${STATE_DIR}/active-transaction"
	log::info "starting transaction ${TRANSACTION_ID} (host=${OPT_HOST:-} dry_run=${OPT_DRY_RUN:-0})"

	manifest::init
}

# apply::detect_and_plan_host — read-only detection plus host-profile
# resolution. Shared by install.sh, dotctl apply, dotctl diff, dotctl validate.
apply::detect_and_plan_host() {
	preflight::run
	detect::run
	adapter_validate_version
	plan::resolve_host "$OPT_HOST"
}

# apply::stage_only — renders every managed file into $STAGE_DIR, without
# validating or touching $HOME. Shared by apply::stage_and_validate and
# `dotctl diff`, which stages but deliberately skips validation (diff shows
# drift, not correctness).
apply::stage_only() {
	stage::init
	stage::generate_environment
	stage::generate_applications
	stage::generate_scripts
	stage::generate_systemd_units
}

# apply::stage_and_validate — stages, then validates, without touching
# $HOME. The read-only half of apply; reused as-is by `dotctl validate`.
apply::stage_and_validate() {
	apply::stage_only
	validate::staging "${STAGE_DIR}/config"
	validate::staging "${STAGE_DIR}/home"
	validate::applications
	services::validate_units
}

# apply::commit_config — stage+validate, then commit into $HOME (subshell-
# isolated so a refused conflict's log::die can't take the whole process
# down before rollback gets a chance — see the comment at the call site
# below), reload services, and finalize the manifest. This is the entire
# "config-only" apply: install.sh calls it after its own package-plan phase;
# dotctl apply calls it directly, skipping the package plan entirely.
apply::commit_config() {
	apply::stage_and_validate

	local project_commit
	project_commit=$(git -C "$DOTFILES_ROOT" rev-parse --short HEAD 2>/dev/null || printf '%s' unknown)
	manifest::add_fragment "$(jq -nc \
		--arg txn "$TRANSACTION_ID" \
		--arg commit "$project_commit" \
		--arg distro_id "${HOST[DISTRO_ID]:-unknown}" \
		--arg host_profile "$PLAN_HOST_NAME" \
		--arg session_mode "${OPT_SESSION:-tty}" \
		--arg gpu_vendor "${HOST[GPU_VENDOR]:-unknown}" \
		--arg gpu_mode "${HOST[GPU_MODE]:-unknown}" \
		'{schema_version: 1, transaction_id: $txn, project_commit: $commit,
		  distro: {id: $distro_id}, host_profile: $host_profile, session_mode: $session_mode,
		  hardware: {gpu_vendor: $gpu_vendor, gpu_mode: $gpu_mode},
		  pending_validations: ["PENDING_LOGIN_VALIDATION"]}')"

	manifest::add_fragment '{"services_enabled":["dotfiles-graphical-session.target","waybar.service","mako.service","hypridle.service","swaybg.service"]}'

	# Run in a subshell: a log::die inside it (e.g. a refused conflict) calls
	# exit, which an ERR trap does NOT catch when it fires from a nested
	# function (verified empirically in Phase 1) — exit always terminates the
	# whole process outright. Isolating it here means only the subshell dies,
	# so the parent can detect the failure and roll back the files that *did*
	# get committed before it died (their rows are already flushed to
	# manifest.tsv on disk, subshell or not).
	if ! (
		commit::commit_staged_tree "${STAGE_DIR}/config" "${HOME}/.config"
		commit::commit_staged_tree "${STAGE_DIR}/home" "${HOME}"
	); then
		log::error "a mutation failed mid-transaction; rolling back committed files for ${TRANSACTION_ID}"
		rollback::restore_transaction "$TRANSACTION_ID"
		rm -f "${STATE_DIR}/active-transaction"
		log::die "transaction ${TRANSACTION_ID} rolled back after failure"
	fi

	services::reload_units
	manifest::write
	rm -f "${STATE_DIR}/active-transaction"
}
