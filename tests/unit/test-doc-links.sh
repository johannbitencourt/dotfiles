#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)
cd "$DOTFILES_ROOT"

fail() {
	echo "FAIL: $*"
	exit 1
}

mapfile -t md_files < <(git ls-files --cached --others --exclude-standard -- '*.md')
if [[ ${#md_files[@]} -eq 0 ]]; then
	echo "PASS: no markdown files to check"
	exit 0
fi

broken=()
for md in "${md_files[@]}"; do
	dir=$(dirname "$md")
	# Extract markdown link targets: [text](target). Skip URLs and anchors —
	# only local file paths need to resolve on disk.
	while IFS= read -r target; do
		[[ -z $target ]] && continue
		[[ $target =~ ^(https?:)?// ]] && continue
		[[ $target == \#* ]] && continue
		target=${target%%#*} # drop a trailing #anchor
		[[ -e "${dir}/${target}" ]] || broken+=("${md} -> ${target}")
	done < <(grep -oE '\]\([^)]+\)' "$md" | sed -E 's/^\]\((.*)\)$/\1/')
done

[[ ${#broken[@]} -eq 0 ]] || fail "broken local doc link(s):
$(printf '  %s\n' "${broken[@]}")"

echo "PASS: every local markdown link resolves to a real file"
