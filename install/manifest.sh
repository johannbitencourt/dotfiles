#!/usr/bin/env bash
# Assembles ~/.local/state/dotfiles/install.json from small JSON fragments
# dropped during each phase, combined via `jq -s add` rather than one large
# `jq -n` call. managed_files accumulates separately (JSONL, one object per
# committed file) since it's built incrementally, not as a single fragment.

declare -g MANIFEST_FRAGMENTS_DIR=""
declare -g MANIFEST_FILES_JSONL=""

manifest::init() {
	# Its own scratch dir, not a subdirectory of $STAGE_DIR: callers need to
	# add fragments (e.g. the package plan) before stage::init has run, so
	# this can't depend on $STAGE_DIR existing yet. Cleaned up by its own
	# trap rather than riding along with stage::init's.
	MANIFEST_FRAGMENTS_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-manifest.XXXXXX")
	cleanup::register "$MANIFEST_FRAGMENTS_DIR"
	MANIFEST_FILES_JSONL="${MANIFEST_FRAGMENTS_DIR}/managed_files.jsonl"
	: >"$MANIFEST_FILES_JSONL"
}

# manifest::add_fragment <json-object>
# Fragments must set disjoint top-level keys — they're merged with `add`.
manifest::add_fragment() {
	local json=$1
	local n
	n=$(find "$MANIFEST_FRAGMENTS_DIR" -maxdepth 1 -name '*.fragment.json' 2>/dev/null | wc -l)
	printf '%s' "$json" >"${MANIFEST_FRAGMENTS_DIR}/$(printf '%02d' "$n").fragment.json"
}

# manifest::add_managed_file <path> <sha256> <action>
manifest::add_managed_file() {
	local path=$1 sum=$2 action=$3
	jq -nc --arg path "$path" --arg checksum "$sum" --arg action "$action" \
		'{path: $path, checksum: ("sha256:" + $checksum), action: $action}' >>"$MANIFEST_FILES_JSONL"
}

manifest::write() {
	local out="${STATE_DIR}/install.json"
	mkdir -p "$(dirname "$out")"

	# An unmatched glob expands to its own literal pattern (nullglob is not
	# set), which would make jq try to open a file that doesn't exist — check
	# for a real match first instead of relying on a suppressed jq error.
	local -a fragment_files=("${MANIFEST_FRAGMENTS_DIR}"/*.fragment.json)
	local combined='{}'
	[[ -e ${fragment_files[0]} ]] && combined=$(jq -sc 'add // {}' "${fragment_files[@]}")

	local managed_files
	managed_files=$(jq -sc '.' "$MANIFEST_FILES_JSONL" 2>/dev/null)
	[[ -z $managed_files ]] && managed_files='[]'

	jq -n --argjson base "$combined" --argjson managed_files "$managed_files" \
		'$base + {managed_files: $managed_files}' >"$out"

	log::info "manifest::write: wrote ${out}"
}
