#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

caps_file="${DOTFILES_ROOT}/packages/capabilities.conf"
mapping_file="${DOTFILES_ROOT}/packages/mappings/arch.conf"

mapfile -t capabilities < <(grep -vE '^\s*(#|$)' "$caps_file")

# 1. No duplicate capability names.
dupes=$(printf '%s\n' "${capabilities[@]}" | sort | uniq -d)
[[ -z $dupes ]] || fail "duplicate capability name(s) in capabilities.conf: ${dupes}"
echo "PASS: no duplicate capability names"

# 2. Every capability has exactly one row in the Arch mapping.
missing=()
for cap in "${capabilities[@]}"; do
	count=$(awk -F'\t' -v c="$cap" '!/^#/ && $1 == c' "$mapping_file" | wc -l)
	[[ $count -eq 0 ]] && missing+=("$cap")
	[[ $count -gt 1 ]] && fail "capability '${cap}' has ${count} rows in mappings/arch.conf (expected 1)"
done
[[ ${#missing[@]} -eq 0 ]] || fail "capabilities with no arch.conf mapping: ${missing[*]}"
echo "PASS: every capability has exactly one Arch package mapping"

# 3. Every mapping row's capability actually exists in capabilities.conf
#    (catches a mapping for a capability that was renamed/removed).
mapfile -t mapped_caps < <(awk -F'\t' '!/^#/ && NF {print $1}' "$mapping_file")
stray=()
for cap in "${mapped_caps[@]}"; do
	printf '%s\n' "${capabilities[@]}" | grep -qx "$cap" || stray+=("$cap")
done
[[ ${#stray[@]} -eq 0 ]] || fail "mappings/arch.conf has row(s) for undeclared capabilities: ${stray[*]}"
echo "PASS: no stray mapping rows for undeclared capabilities"

# 4. Every applications/*/packages.conf entry references a real capability
#    (catches a typo'd or stale per-module package reference).
bad_refs=()
for pkgfile in "${DOTFILES_ROOT}"/applications/*/packages.conf; do
	[[ -f $pkgfile ]] || continue
	while IFS= read -r cap; do
		[[ -z $cap || $cap == \#* ]] && continue
		printf '%s\n' "${capabilities[@]}" | grep -qx "$cap" || bad_refs+=("${pkgfile}:${cap}")
	done <"$pkgfile"
done
[[ ${#bad_refs[@]} -eq 0 ]] || fail "applications/*/packages.conf reference(s) to undeclared capabilities: ${bad_refs[*]}"
echo "PASS: every application module references only declared capabilities"

echo "ALL PASS"
