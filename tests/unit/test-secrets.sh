#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)
cd "$DOTFILES_ROOT"

fail() {
	echo "FAIL: $*"
	exit 1
}

## --cached (already tracked) + --others --exclude-standard (untracked but
## not gitignored) so this still scans everything before the first commit
## ever happens, not just what's already staged.
mapfile -t tracked < <(git ls-files --cached --others --exclude-standard)
[[ ${#tracked[@]} -gt 0 ]] || fail "git ls-files returned nothing — not run from inside the repo?"

# Patterns cheap enough to run on every commit without a dedicated secret-
# scanning tool: private key headers, common cloud key formats, and an
# assigned-looking secret/token/password value that isn't an obvious
# placeholder.
patterns=(
	'-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----'
	'AKIA[0-9A-Z]{16}'                                            # AWS access key ID
	'(secret|password|token|api[_-]?key)[[:space:]]*[:=][[:space:]]*["\x27]?[A-Za-z0-9/+_.-]{12,}'
)

hits=""
for pat in "${patterns[@]}"; do
	found=$(grep -rInE "$pat" "${tracked[@]}" 2>/dev/null || true)
	[[ -n $found ]] && hits+="${found}"$'\n'
done

# The project's own preference/config keys look like SECRET-ish names but
# hold placeholder or non-secret values (e.g. none currently exist) — if
# this ever fires on a real preference key, that's exactly the point: no
# secret-shaped value belongs in a preferences file either.
[[ -z $hits ]] || fail "possible secret found:
${hits}"

echo "PASS: no secret-shaped strings in any tracked file"
