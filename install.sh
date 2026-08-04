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
# shellcheck source=scripts/lib/template.sh
source "${DOTFILES_ROOT}/scripts/lib/template.sh"
# shellcheck source=install/adapters/arch.sh
source "${DOTFILES_ROOT}/install/adapters/arch.sh"
# shellcheck source=install/detect.sh
source "${DOTFILES_ROOT}/install/detect.sh"
# shellcheck source=install/preflight.sh
source "${DOTFILES_ROOT}/install/preflight.sh"
# shellcheck source=install/plan.sh
source "${DOTFILES_ROOT}/install/plan.sh"
# shellcheck source=install/profile.sh
source "${DOTFILES_ROOT}/install/profile.sh"
# shellcheck source=install/deploy.sh
source "${DOTFILES_ROOT}/install/deploy.sh"
# shellcheck source=install/stage.sh
source "${DOTFILES_ROOT}/install/stage.sh"
# shellcheck source=install/validate.sh
source "${DOTFILES_ROOT}/install/validate.sh"
# shellcheck source=install/commit.sh
source "${DOTFILES_ROOT}/install/commit.sh"
# shellcheck source=install/services.sh
source "${DOTFILES_ROOT}/install/services.sh"
# shellcheck source=install/manifest.sh
source "${DOTFILES_ROOT}/install/manifest.sh"
# shellcheck source=install/rollback.sh
source "${DOTFILES_ROOT}/install/rollback.sh"
# shellcheck source=install/apply.sh
source "${DOTFILES_ROOT}/install/apply.sh"

declare -gA DETECTED=()
declare -gA CLI_PREFERENCES=()

OPT_HOST=$(hostname -s 2>/dev/null || printf '%s' arch)
OPT_SESSION=tty
OPT_TERMINAL=foot
OPT_DRY_RUN=0
OPT_NON_INTERACTIVE=0
OPT_CONFIG_ONLY=0
OPT_PACKAGES_ONLY=0
OPT_VERBOSE=0

usage() {
	cat <<'EOF'
Usage: ./install.sh [options]

  --host <name>            host profile to use (default: this machine's hostname)
  --session tty            session mode (Phase 1 supports only: tty)
  --terminal foot          terminal provider (Phase 1 supports only: foot)
  --preference KEY=VALUE   override a resolved value (repeatable)
  --dry-run                print the plan, mutate nothing
  --non-interactive        never prompt; fail on unresolved conflicts
  --config-only            skip package installation
  --packages-only          only install packages, skip config generation
  --verbose                more log output
  -h, --help               show this help
EOF
}

while [[ $# -gt 0 ]]; do
	case $1 in
	--host)
		OPT_HOST=$2
		shift 2
		;;
	--session)
		OPT_SESSION=$2
		[[ $OPT_SESSION == tty ]] || log::die "unsupported --session value: ${OPT_SESSION} (Phase 1 supports: tty)"
		shift 2
		;;
	--terminal)
		OPT_TERMINAL=$2
		[[ $OPT_TERMINAL == foot ]] || log::die "unsupported --terminal value: ${OPT_TERMINAL} (Phase 1 supports: foot)"
		shift 2
		;;
	--preference)
		[[ ${2:-} == *=* ]] || log::die "--preference expects KEY=VALUE, got: ${2:-}"
		CLI_PREFERENCES[${2%%=*}]=${2#*=}
		shift 2
		;;
	--dry-run)
		OPT_DRY_RUN=1
		shift
		;;
	--non-interactive)
		OPT_NON_INTERACTIVE=1
		shift
		;;
	--config-only)
		OPT_CONFIG_ONLY=1
		shift
		;;
	--packages-only)
		OPT_PACKAGES_ONLY=1
		shift
		;;
	--verbose)
		OPT_VERBOSE=1
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

[[ $EUID -ne 0 ]] || log::die "refuse to run as root; run ./install.sh as your normal user"

if [[ $OPT_CONFIG_ONLY -eq 1 && $OPT_PACKAGES_ONLY -eq 1 ]]; then
	log::die "--config-only and --packages-only are mutually exclusive"
fi

apply::acquire_lock_and_txn
apply::detect_and_plan_host
plan::resolve_capabilities
plan::build
plan::print

if [[ $OPT_CONFIG_ONLY -eq 1 ]]; then
	log::info "--config-only: skipping package installation"
else
	deploy::packages
fi

if [[ $OPT_PACKAGES_ONLY -eq 1 ]]; then
	log::info "--packages-only: skipping config generation"
	rm -f "${STATE_DIR}/active-transaction"
	exit 0
fi

# printf '%s\n' "${arr[@]}" with a genuinely EMPTY array still executes its
# format string once (printf pads a missing conversion with an empty
# string rather than running zero times), producing [""] instead of []
# once piped through jq — guard each array explicitly rather than relying
# on printf to degrade gracefully to no output.
INSTALLED_NOW_JSON='[]'
if [[ $OPT_CONFIG_ONLY -eq 0 && $OPT_DRY_RUN -eq 0 && ${#PLAN_MISSING_PACKAGES[@]} -gt 0 ]]; then
	INSTALLED_NOW_JSON=$(printf '%s\n' "${PLAN_MISSING_PACKAGES[@]}" | jq -R . | jq -sc .)
fi
REQUESTED_JSON='[]'
[[ ${#RESOLVED_PACKAGES[@]} -gt 0 ]] && REQUESTED_JSON=$(printf '%s\n' "${!RESOLVED_PACKAGES[@]}" | sort | jq -R . | jq -sc .)
PRESENT_JSON='[]'
[[ ${#PLAN_PRESENT_PACKAGES[@]} -gt 0 ]] && PRESENT_JSON=$(printf '%s\n' "${PLAN_PRESENT_PACKAGES[@]}" | jq -R . | jq -sc .)
manifest::add_fragment "$(jq -nc \
	--argjson requested "$REQUESTED_JSON" \
	--argjson present "$PRESENT_JSON" \
	--argjson installed "$INSTALLED_NOW_JSON" \
	'{capabilities: {requested: $requested, resolved: $requested},
	  packages: {already_present: $present, installed_by_project: $installed}}')"

apply::commit_config

log::info "install complete (core desktop; no first-run wizard/profiles/diagnostics yet)"
