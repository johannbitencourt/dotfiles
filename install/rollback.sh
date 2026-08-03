#!/usr/bin/env bash
# Restores files from a transaction's backup manifest.tsv
# (~/.local/state/dotfiles/backups/<txn>/manifest.tsv, written by commit.sh).
# Used automatically if a mutation fails mid-transaction (see install.sh,
# which runs the commit phase in a subshell so a log::die inside it doesn't
# take down the whole script before rollback gets a chance to run), and is
# unit-tested directly against a scratch $HOME.

# rollback::_restore_path <orig-path> <backup-path>
# Copies backup-path back to orig-path, preserving symlink-ness. Returns 1
# (restoring nothing) if backup-path no longer exists. Shared by
# rollback::restore_transaction and uninstall::_classify_and_act.
rollback::_restore_path() {
	local orig_path=$1 backup_path=$2
	[[ -e $backup_path || -L $backup_path ]] || return 1

	mkdir -p "$(dirname "$orig_path")"
	if [[ -L $backup_path ]]; then
		rm -f "$orig_path"
		cp -P "$backup_path" "$orig_path"
	else
		cp -p "$backup_path" "$orig_path"
	fi
}

# rollback::restore_transaction <transaction-id>
rollback::restore_transaction() {
	local txn=$1
	local manifest="${STATE_DIR}/backups/${txn}/manifest.tsv"
	[[ -f $manifest ]] || log::die "rollback::restore_transaction: no backup manifest for transaction ${txn}"

	local orig_path backup_path orig_sum new_sum action restored=0
	while IFS=$'\t' read -r orig_path backup_path orig_sum new_sum action; do
		case $action in
		install | update) continue ;; # nothing was backed up for these
		esac
		[[ -z $backup_path || $backup_path == "-" ]] && continue

		if rollback::_restore_path "$orig_path" "$backup_path"; then
			restored=$((restored + 1))
			log::info "rollback::restore_transaction: restored ${orig_path}"
		else
			log::warn "rollback::restore_transaction: backup missing for ${orig_path}, skipping: ${backup_path}"
		fi
	done <"$manifest"

	log::info "rollback::restore_transaction: restored ${restored} file(s) from transaction ${txn}"
}

# rollback::latest_transaction — prints the most recent transaction id that
# has a backup directory (empty output if none exist). TRANSACTION_ID is
# `date -u +%Y%m%dT%H%M%SZ-$$`, so lexicographic sort is chronological sort
# — no mtime comparison needed.
rollback::latest_transaction() {
	find "${STATE_DIR}/backups" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | sort | tail -n1
}

# rollback::find_original_backup <path>
# Searches every historical transaction's manifest.tsv (oldest first) for
# the *original* pre-project backup of <path> — specifically the row with
# action=replace-unmanaged, not just any backup. A replace-drifted backup
# is of the project's own prior output, not the true original, and must be
# ignored. In practice a path can have at most one replace-unmanaged backup
# (once managed, commit::classify can never call it "unmanaged" again via
# the checksum ledger check) — except if something later replaces a managed
# file with a symlink, which classify treats as unmanaged again regardless
# of the ledger. Scanning oldest-first and taking the first match handles
# that edge case correctly too: the oldest replace-unmanaged backup is
# always the true original, even if a later one also exists.
# Prints the backup path, or nothing (exit 1) if this path was always ours.
rollback::find_original_backup() {
	local target=$1 txn manifest match
	for txn in $(find "${STATE_DIR}/backups" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | sort); do
		manifest="${STATE_DIR}/backups/${txn}/manifest.tsv"
		[[ -f $manifest ]] || continue
		match=$(awk -F'\t' -v p="$target" '$1==p && $5=="replace-unmanaged"{print $2; exit}' "$manifest")
		if [[ -n $match ]]; then
			printf '%s\n' "$match"
			return 0
		fi
	done
	return 1
}
