#!/usr/bin/env bash
# Read-only preview of what `dotctl apply` would change. Never calls
# commit::backup_and_write — only the existing read-only commit::classify.
# `commit::init` is still called (an idempotent ledger touch) so classify
# never hits a missing-file error on a host that's never applied before;
# it never writes to any managed target.

# diff::_walk <staged-root> <target-root>
diff::_walk() {
	local root=$1 target_root=$2
	[[ -d $root ]] || return 0

	local f rel target state unchanged=0
	while IFS= read -r -d '' f; do
		rel=${f#"$root"/}
		target="${target_root}/${rel}"
		state=$(commit::classify "$target")
		case $state in
		absent)
			printf 'NEW: %s\n' "$target"
			;;
		managed-unchanged)
			unchanged=$((unchanged + 1))
			;;
		managed-modified | unmanaged)
			printf -- '--- %s (%s)\n' "$target" "$state"
			diff -u "$target" "$f" || true
			;;
		esac
	done < <(find "$root" -type f -print0)

	[[ $unchanged -gt 0 ]] && printf '%d unchanged file(s) under %s\n' "$unchanged" "$target_root"
	return 0
}

diff::run() {
	apply::detect_and_plan_host
	apply::stage_only
	apply::ensure_state_dir
	diff::_walk "${STAGE_DIR}/config" "${HOME}/.config"
	diff::_walk "${STAGE_DIR}/home" "${HOME}"
}
