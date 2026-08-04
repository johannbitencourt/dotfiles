#!/usr/bin/env bash
# Shared core for `./uninstall.sh` and `dotctl uninstall`. Neither wraps the
# other — both call these same functions, same pattern as install.sh/
# `dotctl apply` and install/apply.sh.
#
# Requires OPT_NON_INTERACTIVE to already be set by the caller's own option
# parsing (plain global assignment, no `local`, is enough).

declare -g UNINSTALL_FILES_JSONL=""

uninstall::_init_report() {
	UNINSTALL_FILES_JSONL=$(mktemp)
	cleanup::register "$UNINSTALL_FILES_JSONL"
}

# uninstall::_record_file <path> <action> [restored-from]
uninstall::_record_file() {
	local path=$1 action=$2 restored_from=${3:-}
	if [[ -n $restored_from ]]; then
		jq -nc --arg path "$path" --arg action "$action" --arg from "$restored_from" \
			'{path: $path, action: $action, restored_from: $from}' >>"$UNINSTALL_FILES_JSONL"
	else
		jq -nc --arg path "$path" --arg action "$action" \
			'{path: $path, action: $action}' >>"$UNINSTALL_FILES_JSONL"
	fi
}

uninstall::_managed_paths() {
	local manifest="${STATE_DIR}/install.json"
	[[ -f $manifest ]] || return 0
	jq -r '.managed_files[]?.path' "$manifest"
}

uninstall::_enabled_services() {
	local manifest="${STATE_DIR}/install.json"
	[[ -f $manifest ]] || return 0
	jq -r '.services_enabled[]?' "$manifest"
}

# uninstall::_confirm <prompt>
# Prompts on a real TTY; under --non-interactive, proceeds without asking
# rather than dying. This is deliberately NOT commit::_confirm_overwrite's
# idiom: that gate exists because a conflict's resolution is genuinely
# ambiguous (overwrite or not?), so --non-interactive's "refuse rather than
# guess" is the safe default. Uninstall's confirm isn't resolving an
# ambiguity — running `dotctl uninstall`/`--remove-state`/etc. at all is
# already the unambiguous expression of intent. Dying here would make
# --non-interactive permanently unusable for uninstall (it could never pass
# its own gate), which isn't a safety feature, just a broken flag.
uninstall::_confirm() {
	local prompt=$1
	if [[ $OPT_NON_INTERACTIVE -eq 1 ]]; then
		log::info "uninstall: --non-interactive, proceeding without asking: ${prompt}"
		return 0
	fi
	local reply=""
	read -r -p "${prompt} [y/N] " reply </dev/tty
	[[ $reply == [yY] ]] || log::die "uninstall: aborted by user"
}

# uninstall::_write_report <remove_packages> <remove_state> <keep_config> <packages-removed-array-name> <packages-note>
# Written under ~/.local/share/dotfiles, deliberately NOT $STATE_DIR: that's
# exactly what --remove-state means to delete, so the report can't live
# there. .local/share (XDG data, persistent) is the natural sibling to
# .local/state for an artifact meant to survive it.
uninstall::_write_report() {
	local remove_packages=$1 remove_state=$2 keep_config=$3
	local -n _pkgs_removed=$4
	local pkgs_note=$5

	local report_dir="${HOME}/.local/share/dotfiles"
	mkdir -p "$report_dir"
	local report_path="${report_dir}/uninstall-report-$(date -u +%Y%m%dT%H%M%SZ).json"
	local project_commit
	project_commit=$(git -C "$DOTFILES_ROOT" rev-parse --short HEAD 2>/dev/null || printf '%s' unknown)

	local files_json
	files_json=$(jq -sc '.' "$UNINSTALL_FILES_JSONL" 2>/dev/null)
	[[ -z $files_json ]] && files_json='[]'

	local pkgs_removed_json='[]'
	[[ ${#_pkgs_removed[@]} -gt 0 ]] && pkgs_removed_json=$(printf '%s\n' "${_pkgs_removed[@]}" | jq -R . | jq -sc .)

	jq -n \
		--arg uninstalled_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		--arg commit "$project_commit" \
		--argjson remove_packages "$([[ $remove_packages -eq 1 ]] && printf true || printf false)" \
		--argjson remove_state "$([[ $remove_state -eq 1 ]] && printf true || printf false)" \
		--argjson keep_config "$([[ $keep_config -eq 1 ]] && printf true || printf false)" \
		--argjson files "$files_json" \
		--argjson packages_removed "$pkgs_removed_json" \
		--arg packages_note "$pkgs_note" \
		'{schema_version: 1, uninstalled_at: $uninstalled_at, project_commit: $commit,
		  flags: {remove_packages: $remove_packages, remove_state: $remove_state, keep_config: $keep_config},
		  files: $files,
		  packages: {removed: $packages_removed, note: $packages_note}}' \
		>"$report_path"

	log::info "uninstall: report written to ${report_path}"
}

# uninstall::run <remove_packages:0|1> <remove_state:0|1> <keep_config:0|1> <dry_run:0|1>
uninstall::run() {
	local remove_packages=$1 remove_state=$2 keep_config=$3 dry_run=$4

	apply::ensure_state_dir
	uninstall::_init_report

	local -a files services
	mapfile -t files < <(uninstall::_managed_paths)
	mapfile -t services < <(uninstall::_enabled_services)

	log::info "uninstall: ${#files[@]} managed file(s), ${#services[@]} service(s) on record"
	local f u
	for f in "${files[@]}"; do log::info "  file: ${f}"; done
	for u in "${services[@]}"; do log::info "  service: ${u}"; done

	if session::marker_active; then
		log::warn "uninstall: this project's own Hyprland session appears to be running right now"
	fi

	if [[ $dry_run -eq 1 ]]; then
		log::info "uninstall: --dry-run, no changes made"
		return 0
	fi

	local action_desc="restore/remove"
	[[ $keep_config -eq 1 ]] && action_desc="leave"
	uninstall::_confirm "Stop project services and ${action_desc} managed config files?"

	for u in "${services[@]}"; do
		adapter_disable_system_service "$u"
	done

	if [[ $keep_config -eq 1 ]]; then
		for f in "${files[@]}"; do
			uninstall::_record_file "$f" kept
		done
	else
		local backup
		for f in "${files[@]}"; do
			if [[ ! -e $f && ! -L $f ]]; then
				uninstall::_record_file "$f" already_missing
				continue
			fi
			if backup=$(rollback::find_original_backup "$f"); then
				rollback::_restore_path "$f" "$backup"
				uninstall::_record_file "$f" restored "$backup"
				log::info "uninstall: restored ${f}"
			else
				rm -f "$f"
				uninstall::_record_file "$f" removed
				log::info "uninstall: removed ${f}"
			fi
		done
	fi

	local -a pkgs_removed=()
	local pkgs_note=""
	if [[ $remove_packages -eq 1 ]]; then
		local -a pkgs
		mapfile -t pkgs < <(jq -r '.packages.installed_by_project[]?' "${STATE_DIR}/install.json" 2>/dev/null)
		if [[ ${#pkgs[@]} -eq 0 ]]; then
			pkgs_note="no packages recorded as installed_by_project — either none were installed by this project, or install.json here was only ever written by 'dotctl apply' (which never records package data; only ./install.sh's package phase does). Nothing was removed."
			log::warn "uninstall: ${pkgs_note}"
		else
			uninstall::_confirm "Remove ${#pkgs[@]} package(s): ${pkgs[*]}?"
			adapter_remove_packages "${pkgs[@]}"
			pkgs_removed=("${pkgs[@]}")
		fi
	fi

	uninstall::_write_report "$remove_packages" "$remove_state" "$keep_config" pkgs_removed "$pkgs_note"

	# Tool/workflow profiles (dotctl profile install <id>) track their own
	# packages in profiles.json, entirely separate from install.json's
	# installed_by_project — this uninstall never touches them. Cheap,
	# real-surprise-avoiding warning rather than silent cleanup: full
	# profile-aware uninstall is a real small feature, not a one-liner (see
	# install/profile.sh's header for why removal needs the orphan check).
	local -a still_installed_profiles
	mapfile -t still_installed_profiles < <(jq -r '.profiles // {} | keys[]' "${STATE_DIR}/profiles.json" 2>/dev/null)
	if [[ ${#still_installed_profiles[@]} -gt 0 ]]; then
		log::warn "uninstall: tool profile(s) still installed and NOT touched by this uninstall: ${still_installed_profiles[*]} — run 'dotctl profile remove <id>' first if you want their packages removed too"
	fi

	if [[ $remove_state -eq 1 ]]; then
		uninstall::_confirm "Permanently delete ${STATE_DIR} (install.json and every historical backup — dotctl restore-config will have nothing left afterward)?"
		rm -rf "$STATE_DIR"
		log::info "uninstall: removed ${STATE_DIR}"
	fi

	log::info "uninstall: complete"
}
