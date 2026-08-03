#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

# 1. Run directly from the repo checkout: dotctl must detect
#    ../install/apply.sh next to it and resolve DOTFILES_ROOT from its own
#    path, not from the (still-unrendered) @@DOTFILES_ROOT_ABS@@ literal.
"${DOTFILES_ROOT}/scripts/dotctl" --help >/dev/null || fail "dotctl --help failed when run from the repo checkout"
echo "PASS: repo-checkout context resolves DOTFILES_ROOT from its own path"

# 2. Once rendered (as it would be by stage::generate_scripts) and copied
#    somewhere with no install/apply.sh nearby, it must fall back to the
#    baked-in absolute path and still work.
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/scripts/lib/cleanup.sh"
source "${DOTFILES_ROOT}/scripts/lib/kv-parser.sh"
source "${DOTFILES_ROOT}/scripts/lib/template.sh"

rendered_dir=$(mktemp -d)
cleanup::register "$rendered_dir"
deployed_dir=$(mktemp -d)
cleanup::register "$deployed_dir"

declare -A values=([DOTFILES_ROOT_ABS]="$DOTFILES_ROOT")
render_template "${DOTFILES_ROOT}/scripts/dotctl" "${rendered_dir}/dotctl" values

grep -q "DOTFILES_ROOT=\"${DOTFILES_ROOT}\"" "${rendered_dir}/dotctl" ||
	fail "rendered dotctl does not have the real DOTFILES_ROOT baked in"
echo "PASS: render_template bakes in the real DOTFILES_ROOT_ABS"

cp "${rendered_dir}/dotctl" "${deployed_dir}/dotctl"
chmod +x "${deployed_dir}/dotctl"
[[ ! -f "${deployed_dir}/../install/apply.sh" ]] || fail "test setup invalid: an install/apply.sh exists near the deployed copy"
"${deployed_dir}/dotctl" --help >/dev/null || fail "deployed standalone copy failed to run via its baked-in DOTFILES_ROOT"
echo "PASS: deployed standalone copy falls back to the baked-in path and runs"

echo "ALL PASS"
