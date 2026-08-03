#!/usr/bin/env bash
# Restores files from a transaction's backup manifest.tsv
# (~/.local/state/dotfiles/backups/<txn>/manifest.tsv, written by commit.sh).
# Used automatically if a mutation fails mid-transaction (see install.sh,
# which runs the commit phase in a subshell so a log::die inside it doesn't
# take down the whole script before rollback gets a chance to run), and is
# unit-tested directly against a scratch $HOME.

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

		if [[ ! -e $backup_path && ! -L $backup_path ]]; then
			log::warn "rollback::restore_transaction: backup missing for ${orig_path}, skipping: ${backup_path}"
			continue
		fi

		mkdir -p "$(dirname "$orig_path")"
		if [[ -L $backup_path ]]; then
			rm -f "$orig_path"
			cp -P "$backup_path" "$orig_path"
		else
			cp -p "$backup_path" "$orig_path"
		fi
		restored=$((restored + 1))
		log::info "rollback::restore_transaction: restored ${orig_path}"
	done <"$manifest"

	log::info "rollback::restore_transaction: restored ${restored} file(s) from transaction ${txn}"
}
