#!/usr/bin/env bash
# Backs up and commits staged files into $HOME.
#
# Conflict classification (flat 4-state, per HLD 10.3 — the fuller 7-state
# adoption classifier from HLD 9.6 is Phase-2 scope):
#   absent            : target doesn't exist                     -> install
#   managed-unchanged  : we wrote it before, untouched since       -> update
#   managed-modified   : we wrote it before, user has since edited -> back up, ask (or fail --non-interactive)
#   unmanaged          : exists and we never wrote it (incl. symlinks) -> back up, ask (or fail --non-interactive)
#
# "Managed" is tracked via a checksum ledger at
# ~/.local/state/dotfiles/managed-checksums.tsv (path<TAB>sha256), updated
# after every successful write. This is Milestone 2's minimal precursor to
# the fuller install.json manifest built in Milestone 5.

declare -g _BACKUP_PATH=""
declare -g _ORIG_SUM=""

commit::init() {
	local ledger="${STATE_DIR}/managed-checksums.tsv"
	mkdir -p "$(dirname "$ledger")"
	touch "$ledger"
}

commit::classify() {
	local target=$1

	if [[ -L $target ]]; then
		printf '%s\n' unmanaged # we never generate symlinks ourselves
		return 0
	fi
	if [[ ! -e $target ]]; then
		printf '%s\n' absent
		return 0
	fi

	local ledger="${STATE_DIR}/managed-checksums.tsv"
	local recorded
	recorded=$(awk -F'\t' -v p="$target" '$1==p{print $2; exit}' "$ledger")
	if [[ -z $recorded ]]; then
		printf '%s\n' unmanaged
		return 0
	fi

	local current
	current=$(sha256sum "$target" | awk '{print $1}')
	if [[ $current == "$recorded" ]]; then
		printf '%s\n' managed-unchanged
	else
		printf '%s\n' managed-modified
	fi
}

# commit::find_drifted_paths — prints one path per line for every managed
# path whose live content no longer matches what this project last wrote
# (commit::classify == managed-modified). Empty output if the ledger is
# absent or empty. Shared by doctor's managed-drift check and
# dotctl recover's detection — a real second caller wanting the exact same
# list, not a speculative extraction.
commit::find_drifted_paths() {
	local ledger="${STATE_DIR}/managed-checksums.tsv"
	[[ -s $ledger ]] || return 0

	local path _sum
	while IFS=$'\t' read -r path _sum; do
		[[ -z $path ]] && continue
		[[ $(commit::classify "$path") == managed-modified ]] && printf '%s\n' "$path"
	done <"$ledger"
}

# commit::_confirm_overwrite <target> <reason>
# Fails hard under --non-interactive; otherwise prompts on the real TTY.
commit::_confirm_overwrite() {
	local target=$1 reason=$2
	cli::confirm_or_die commit "${target}: ${reason}" "Back up and replace ${target}?"
}

# commit::_backup_file <target> <backup-dir>
# Sets globals _BACKUP_PATH / _ORIG_SUM. A symlink is preserved as-is; its
# resolved target is recorded (prefixed "symlink:") instead of a checksum.
commit::_backup_file() {
	local target=$1 backup_dir=$2
	local rel=${target#"$HOME"/}
	_BACKUP_PATH="${backup_dir}/home/${rel}"
	mkdir -p "$(dirname "$_BACKUP_PATH")"

	if [[ -L $target ]]; then
		cp -P "$target" "$_BACKUP_PATH"
		_ORIG_SUM="symlink:$(readlink "$target")"
	else
		cp -p "$target" "$_BACKUP_PATH"
		_ORIG_SUM=$(sha256sum "$target" | awk '{print $1}')
	fi
}

commit::_record_checksum() {
	local path=$1 sum=$2
	local ledger="${STATE_DIR}/managed-checksums.tsv"
	local tmp
	tmp=$(mktemp)
	awk -F'\t' -v p="$path" '$1 != p' "$ledger" >"$tmp"
	mv "$tmp" "$ledger"
	printf '%s\t%s\n' "$path" "$sum" >>"$ledger"
}

# commit::backup_and_write <staged-file> <target-path>
commit::backup_and_write() {
	local staged=$1 target=$2
	local state
	state=$(commit::classify "$target")

	if [[ $OPT_DRY_RUN -eq 1 ]]; then
		log::info "commit: [dry-run] ${target}: ${state}"
		return 0
	fi

	local backup_dir="${STATE_DIR}/backups/${TRANSACTION_ID}"
	local manifest="${backup_dir}/manifest.tsv"
	local orig_sum="-" backup_path="-" action="install"

	case $state in
	absent)
		action=install
		;;
	managed-unchanged)
		action=update
		;;
	managed-modified)
		commit::_confirm_overwrite "$target" "has local modifications (drift)"
		commit::_backup_file "$target" "$backup_dir"
		backup_path=$_BACKUP_PATH
		orig_sum=$_ORIG_SUM
		action=replace-drifted
		;;
	unmanaged)
		commit::_confirm_overwrite "$target" "exists and is not managed by dotfiles-hyprland"
		commit::_backup_file "$target" "$backup_dir"
		backup_path=$_BACKUP_PATH
		orig_sum=$_ORIG_SUM
		action=replace-unmanaged
		;;
	esac

	mkdir -p "$(dirname "$target")"
	cp "$staged" "$target"
	local new_sum
	new_sum=$(sha256sum "$target" | awk '{print $1}')

	mkdir -p "$backup_dir"
	printf '%s\t%s\t%s\t%s\t%s\n' "$target" "$backup_path" "$orig_sum" "$new_sum" "$action" >>"$manifest"
	commit::_record_checksum "$target" "$new_sum"
	manifest::add_managed_file "$target" "$new_sum" "$action"
	log::info "commit: ${target}: ${action}"
}

# commit::commit_staged_tree <staged-root> <target-root>
commit::commit_staged_tree() {
	local root=$1 target_root=$2
	[[ -d $root ]] || return 0
	local f rel target
	while IFS= read -r -d '' f; do
		rel=${f#"$root"/}
		target="${target_root}/${rel}"
		commit::backup_and_write "$f" "$target"
	done < <(find "$root" -type f -print0)
}
