#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
readonly DOTFILES_ROOT

# shellcheck source=scripts/lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=scripts/lib/cleanup.sh
source "${DOTFILES_ROOT}/scripts/lib/cleanup.sh"
# shellcheck source=scripts/lib/kv-parser.sh
source "${DOTFILES_ROOT}/scripts/lib/kv-parser.sh"
# shellcheck source=install/adapters/arch.sh
source "${DOTFILES_ROOT}/install/adapters/arch.sh"
# shellcheck source=install/commit.sh
source "${DOTFILES_ROOT}/install/commit.sh"
# shellcheck source=install/rollback.sh
source "${DOTFILES_ROOT}/install/rollback.sh"
# shellcheck source=install/session.sh
source "${DOTFILES_ROOT}/install/session.sh"
# shellcheck source=install/apply.sh
source "${DOTFILES_ROOT}/install/apply.sh"
# shellcheck source=install/uninstall.sh
source "${DOTFILES_ROOT}/install/uninstall.sh"
# Note: no detect/preflight/plan/stage/validate/services/manifest/deploy —
# uninstall never generates, validates, or installs anything.

OPT_REMOVE_PACKAGES=0
OPT_REMOVE_STATE=0
OPT_KEEP_CONFIG=0
OPT_DRY_RUN=0
OPT_NON_INTERACTIVE=0

usage() {
	cat <<'EOF'
Usage: ./uninstall.sh [options]

  --remove-packages   also remove packages this project installed (best-effort; see below)
  --remove-state      also delete ~/.local/state/dotfiles (install.json + all backup history)
  --keep-config       leave generated config files in place; only stop services (and
                       remove packages/state if those flags are also given)
  --dry-run           show what would happen, change nothing
  --non-interactive   never prompt; proceed without asking for confirmation
  --verbose           more log output
  -h, --help          show this help

Restores every managed file to its pre-project original when a backup of it
exists, otherwise removes it. Native packages and project state are
retained unless their flags are given. Writes a report to
~/.local/share/dotfiles/uninstall-report-<timestamp>.json.
EOF
}

while [[ $# -gt 0 ]]; do
	case $1 in
	--remove-packages)
		OPT_REMOVE_PACKAGES=1
		shift
		;;
	--remove-state)
		OPT_REMOVE_STATE=1
		shift
		;;
	--keep-config)
		OPT_KEEP_CONFIG=1
		shift
		;;
	--dry-run)
		OPT_DRY_RUN=1
		shift
		;;
	--non-interactive)
		OPT_NON_INTERACTIVE=1
		shift
		;;
	--verbose)
		set -x
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		log::die "unknown option: $1 (see --help)"
		;;
	esac
done

[[ $EUID -ne 0 ]] || log::die "refuse to run as root; run ./uninstall.sh as your normal user"

apply::ensure_state_dir
LOCK_FILE="${STATE_DIR}/lock"
exec 200>"$LOCK_FILE"
flock -n 200 || log::die "another install/update is already running (lock: ${LOCK_FILE})"

uninstall::run "$OPT_REMOVE_PACKAGES" "$OPT_REMOVE_STATE" "$OPT_KEEP_CONFIG" "$OPT_DRY_RUN"
