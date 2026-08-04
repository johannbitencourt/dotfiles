#!/usr/bin/env bash
# State-aware guided recovery. Inspects current transaction/runtime state
# directly (never parses doctor's text/JSON — its check functions are
# write-only side effects, not clean return values) and offers only the fix
# that actually applies right now, per HLD: "dotctl recover offers only
# state-valid actions."

declare -g RECOVER_TXN=""
declare -ga RECOVER_DRIFTED=()
declare -g RECOVER_HYPRLAND_CONFIG_BROKEN=0
declare -ga RECOVER_MISSING_UNITS=()

# recover::_check_incomplete_transaction — sets RECOVER_TXN if an
# incomplete transaction marker exists. Same file apply::commit_config
# writes/clears and doctor's incomplete-transaction check reads.
recover::_check_incomplete_transaction() {
	RECOVER_TXN=""
	local marker="${STATE_DIR}/active-transaction"
	[[ -f $marker ]] || return 1
	RECOVER_TXN=$(cat "$marker")
	[[ -n $RECOVER_TXN ]]
}

# recover::_check_drift — sets RECOVER_DRIFTED via the shared primitive
# also used by doctor's managed-drift check.
recover::_check_drift() {
	RECOVER_DRIFTED=()
	mapfile -t RECOVER_DRIFTED < <(commit::find_drifted_paths)
	[[ ${#RECOVER_DRIFTED[@]} -gt 0 ]]
}

# recover::_check_hyprland_config — verifies the REAL, live
# ~/.config/hypr/conf.d, same approach as doctor's own check (kept as small
# duplicated logic rather than extracted — doctor's "report everything,
# never die" contract differs enough from recover's that sharing this one
# small, self-contained check isn't worth the abstraction).
recover::_check_hyprland_config() {
	RECOVER_HYPRLAND_CONFIG_BROKEN=0
	local conf_d="${HOME}/.config/hypr/conf.d"
	[[ -d $conf_d ]] || return 1
	# Not installed yet isn't "broken" — that's install's job, not recover's;
	# offering to "regenerate config" here would be a category error, same
	# reasoning as recover::_check_systemd_units's own install.json gate below.
	command -v Hyprland &>/dev/null || return 1

	local flattened
	flattened=$(mktemp)
	cleanup::register "$flattened"
	cat "${conf_d}"/*.conf >"$flattened" 2>/dev/null || true

	if ! Hyprland --config "$flattened" --verify-config >/dev/null 2>&1; then
		RECOVER_HYPRLAND_CONFIG_BROKEN=1
		return 0
	fi
	return 1
}

# recover::_check_systemd_units — sets RECOVER_MISSING_UNITS. Gated on the
# checksum ledger being non-empty (at least one file has really been
# committed): unlike doctor, which reports raw current state, recover only
# surfaces things there's something to *recover*. A never-installed host
# isn't broken, so offering a "regenerate config" fix for it would be a
# category error. install.json's mere existence isn't a reliable enough
# signal — a --dry-run apply writes it too (metadata fragments are
# unconditional) while never reaching commit::backup_and_write's real-write
# path, so it never touches this ledger.
recover::_check_systemd_units() {
	RECOVER_MISSING_UNITS=()
	[[ -s "${STATE_DIR}/managed-checksums.tsv" ]] || return 1
	local unit_dir="${HOME}/.config/systemd/user"
	local -a expected=(dotfiles-graphical-session.target waybar.service mako.service hypridle.service swaybg.service)
	local u
	for u in "${expected[@]}"; do
		[[ -f "${unit_dir}/${u}" ]] || RECOVER_MISSING_UNITS+=("$u")
	done
	[[ ${#RECOVER_MISSING_UNITS[@]} -gt 0 ]]
}

# recover::detect — runs every check, populating the globals above.
# Read-only; safe to call any time.
recover::detect() {
	apply::ensure_state_dir
	recover::_check_incomplete_transaction || true
	recover::_check_drift || true
	recover::_check_hyprland_config || true
	recover::_check_systemd_units || true
}

# recover::_confirm_or_defer <description> <equivalent-command>
# Returns 0 to proceed with the action, 1 to skip it — decline and defer are
# both "not now," never an error. A third confirm idiom, deliberately
# distinct from commit::_confirm_overwrite (dies under --non-interactive)
# and uninstall::_confirm (proceeds under --non-interactive): recover's
# framing is "diagnose AND optionally act," and the realistic
# --non-interactive caller is a health-check context, not someone who's
# decided "mutate my config now" — auto-fixing as a side effect of what
# looks like a status check would be a bad surprise.
recover::_confirm_or_defer() {
	local description=$1 equivalent_cmd=$2
	log::warn "recover: ${description}"
	if [[ $OPT_NON_INTERACTIVE -eq 1 ]]; then
		log::info "recover: not acting under --non-interactive; run: ${equivalent_cmd}"
		return 1
	fi
	local reply=""
	read -r -p "  Fix now? [y/N] " reply </dev/tty
	if [[ $reply == [yY] ]]; then
		return 0
	fi
	log::info "recover: skipped; run manually later: ${equivalent_cmd}"
	return 1
}

# recover::run — detects, then offers exactly one state-valid action.
# Coalescing: an incomplete transaction is the ONLY offered action when one
# exists (regenerating on top of a half-committed transaction is the unsafe
# case this whole check exists to prevent); otherwise drift/hyprland-config/
# missing-units collapse into a single "regenerate config" offer, since all
# three are fixed by the exact same `dotctl apply` call.
# Exit-code contract: 0 nothing found or the finding was fixed; 2 an
# actionable finding was reported but not acted on (declined/deferred);
# crashes/misuse die via log::die (exit 1), same as the rest of dotctl.
recover::run() {
	recover::detect

	if [[ -n $RECOVER_TXN ]]; then
		if recover::_confirm_or_defer \
			"an incomplete transaction (${RECOVER_TXN}) was left behind by a crashed or interrupted apply" \
			"dotctl restore-config --transaction ${RECOVER_TXN}"; then
			rollback::restore_transaction "$RECOVER_TXN"
			rm -f "${STATE_DIR}/active-transaction"
			log::info "recover: restored transaction ${RECOVER_TXN} and cleared the incomplete marker"
			return 0
		fi
		return 2
	fi

	local -a symptoms=()
	[[ ${#RECOVER_DRIFTED[@]} -gt 0 ]] && symptoms+=("drifted: ${RECOVER_DRIFTED[*]}")
	[[ $RECOVER_HYPRLAND_CONFIG_BROKEN -eq 1 ]] && symptoms+=("the live Hyprland config fails to verify")
	[[ ${#RECOVER_MISSING_UNITS[@]} -gt 0 ]] && symptoms+=("missing unit file(s): ${RECOVER_MISSING_UNITS[*]}")

	if [[ ${#symptoms[@]} -eq 0 ]]; then
		log::info "recover: no state-valid recovery action; system looks healthy"
		return 0
	fi

	local description
	description=$(printf '%s; ' "${symptoms[@]}")
	if recover::_confirm_or_defer "regenerate config — ${description}" "dotctl apply"; then
		apply::acquire_lock_and_txn
		apply::detect_and_plan_host
		apply::commit_config
		log::info "recover: config regenerated"
		return 0
	fi
	return 2
}
