#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)
cd "$DOTFILES_ROOT"

fail() {
	echo "FAIL: $*"
	exit 1
}

# 1. Entrypoints must be executable.
required=(install.sh scripts/hypr-session)
for f in "${required[@]}"; do
	[[ -x $f ]] || fail "${f} is not executable"
done
echo "PASS: entrypoints (install.sh, hypr-session) are executable"

# 2. Data/template files should never carry the executable bit — a stray
#    chmod +x on a .conf/.tmpl is almost always a mistake, not intent.
mapfile -t bad < <(git ls-files --cached --others --exclude-standard |
	grep -E '\.(conf|tmpl|ini|jsonc|json|tsv|md)$' |
	while IFS= read -r f; do [[ -x $f ]] && echo "$f"; done)
[[ ${#bad[@]} -eq 0 ]] || fail "data/template file(s) unexpectedly executable: ${bad[*]}"
echo "PASS: no data/template file carries the executable bit"

echo "ALL PASS"
