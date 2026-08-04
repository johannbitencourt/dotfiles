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

# Capabilities declared by any profile's REQUIRED_CAPABILITIES (comma-
# joined single value — profiles/*.conf's own format, see profiles/dev.conf).
# Profile-only capabilities (e.g. neovim, tmux) have real mapping rows in
# arch.conf but are deliberately absent from capabilities.conf itself
# (install.sh's unconditional core-desktop phase must never resolve them)
# — check 3 below needs this union so those rows aren't flagged as stray.
mapfile -t profile_caps < <(
	for f in "${DOTFILES_ROOT}"/profiles/*.conf; do
		[[ -f $f ]] || continue
		grep -E '^REQUIRED_CAPABILITIES=' "$f" | cut -d= -f2- | tr ',' '\n'
	done | grep -v '^$' | sort -u
)

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

# 3. Every mapping row's capability actually exists in capabilities.conf or
#    a profile's declared capabilities (catches a mapping for a capability
#    that was renamed/removed from both).
mapfile -t mapped_caps < <(awk -F'\t' '!/^#/ && NF {print $1}' "$mapping_file")
stray=()
for cap in "${mapped_caps[@]}"; do
	{ printf '%s\n' "${capabilities[@]}"; printf '%s\n' "${profile_caps[@]}"; } | grep -qx "$cap" || stray+=("$cap")
done
[[ ${#stray[@]} -eq 0 ]] || fail "mappings/arch.conf has row(s) for undeclared capabilities: ${stray[*]}"
echo "PASS: no stray mapping rows for undeclared capabilities"

# 4. Profile-declared capabilities must not silently duplicate into the
#    core, unconditionally-resolved capabilities.conf — that's exactly the
#    trap that would make a plain './install.sh' run install profile-only
#    tools for everyone. The only legitimate overlap is 'jq': profiles/dev.conf
#    intentionally reuses the existing core "jq" capability rather than
#    inventing a separate one.
allowed_overlap=(jq)
overlap=()
for cap in "${profile_caps[@]}"; do
	if printf '%s\n' "${capabilities[@]}" | grep -qx "$cap"; then
		printf '%s\n' "${allowed_overlap[@]}" | grep -qx "$cap" || overlap+=("$cap")
	fi
done
[[ ${#overlap[@]} -eq 0 ]] || fail "profile-declared capability(ies) unexpectedly duplicated into capabilities.conf: ${overlap[*]}"
echo "PASS: profile-declared capabilities don't leak into the unconditional core capability set (except the intentional jq reuse)"

echo "ALL PASS"
