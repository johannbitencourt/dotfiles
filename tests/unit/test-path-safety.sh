#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

## Scans the project's *shipped* scripts, not tests/ itself — a test
## legitimately mentions "eval" or "rm -rf" in its own failure messages
## without that being a violation.
mapfile -t scripts < <(find "$DOTFILES_ROOT" \( -path "$DOTFILES_ROOT/.git" -o -path "$DOTFILES_ROOT/tests" \) -prune -o -type f \
	\( -name '*.sh' -o -name 'install.sh' -o -name 'hypr-session' \) -print)

# 1. `eval` is banned project-wide (HLD security requirement) — grep, don't
#    trust convention.
hits=$(grep -lE '(^|[^A-Za-z_])eval[[:space:]]' "${scripts[@]}" || true)
[[ -z $hits ]] || fail "eval found in: ${hits}"
echo "PASS: no eval anywhere in the project"

# 2. No literal `rm -rf /` (a root wipe, however unlikely to be typed for
#    real — this only needs to catch it once).
hits=$(grep -nE 'rm[[:space:]]+-[a-z]*rf?[a-z]*[[:space:]]+/[[:space:]]' "${scripts[@]}" || true)
[[ -z $hits ]] || fail "literal 'rm -rf /' found: ${hits}"
echo "PASS: no literal rm -rf / anywhere"

# 3. Every `rm -rf`/`rm -fr` target must be quoted. An unquoted variable
#    that happens to be empty/unset turns "rm -rf $DIR/*" into "rm -rf /*".
hits=$(grep -nE 'rm[[:space:]]+-[a-z]*rf?[a-z]*[[:space:]]+\$[A-Za-z_]' "${scripts[@]}" || true)
[[ -z $hits ]] || fail "unquoted variable in rm -rf: ${hits}"
echo "PASS: every rm -rf target is a quoted expansion"

echo "ALL PASS"
