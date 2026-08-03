#!/usr/bin/env bash
# Strict KEY=VALUE parser. Never sources, never evals the target file.
#
# Format: KEY=VALUE, one per line. KEY must match ^[A-Z][A-Z0-9_]*$.
# `#` starts a comment (to end of line) unless it appears inside VALUE —
# inline `#` in a value is not supported by design; keep values comment-free.
# Blank lines and comment-only lines are skipped. Any other line is a hard error.

# kv_parse_file <path> <assoc-array-name>
# Populates the caller's associative array (declared with `declare -A`).
kv_parse_file() {
	local file=$1
	local -n kv_out=$2
	local line_no=0
	local line

	[[ -f $file ]] || log::die "kv_parse_file: not a file: ${file}"

	while IFS= read -r line || [[ -n $line ]]; do
		line_no=$((line_no + 1))
		line=${line%%#*}
		# trim leading/trailing whitespace
		line=${line#"${line%%[![:space:]]*}"}
		line=${line%"${line##*[![:space:]]}"}
		[[ -z $line ]] && continue

		if [[ $line =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
			kv_out[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
		else
			log::die "kv_parse_file: ${file}:${line_no}: invalid line, expected KEY=VALUE: ${line}"
		fi
	done <"$file"
}
