#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
readonly DOTFILES_ROOT

# shellcheck source=scripts/lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
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

STATE_DIR="${HOME}/.local/state/dotfiles"
mkdir -p "$STATE_DIR"
LOCK_FILE="${STATE_DIR}/lock"
exec 200>"$LOCK_FILE"
flock -n 200 || log::die "another install/update is already running (lock: ${LOCK_FILE})"

TRANSACTION_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
readonly TRANSACTION_ID
log::info "starting transaction ${TRANSACTION_ID} (host=${OPT_HOST} dry_run=${OPT_DRY_RUN})"

preflight::run
detect::run
adapter_validate_version
plan::resolve_host "$OPT_HOST"
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
	exit 0
fi

commit::init
stage::init
manifest::init
stage::generate_environment
stage::generate_applications
stage::generate_scripts
stage::generate_systemd_units
validate::staging "${STAGE_DIR}/config"
validate::staging "${STAGE_DIR}/home"
validate::applications
services::validate_units

PROJECT_COMMIT=$(git -C "$DOTFILES_ROOT" rev-parse --short HEAD 2>/dev/null || printf '%s' unknown)
manifest::add_fragment "$(jq -nc \
	--arg txn "$TRANSACTION_ID" \
	--arg commit "$PROJECT_COMMIT" \
	--arg distro_id "${HOST[DISTRO_ID]:-unknown}" \
	--arg host_profile "$PLAN_HOST_NAME" \
	--arg session_mode "$OPT_SESSION" \
	--arg gpu_vendor "${HOST[GPU_VENDOR]:-unknown}" \
	--arg gpu_mode "${HOST[GPU_MODE]:-unknown}" \
	'{schema_version: 1, transaction_id: $txn, project_commit: $commit,
	  distro: {id: $distro_id}, host_profile: $host_profile, session_mode: $session_mode,
	  hardware: {gpu_vendor: $gpu_vendor, gpu_mode: $gpu_mode},
	  pending_validations: ["PENDING_LOGIN_VALIDATION"]}')"

INSTALLED_NOW_JSON='[]'
if [[ $OPT_CONFIG_ONLY -eq 0 && $OPT_DRY_RUN -eq 0 ]]; then
	INSTALLED_NOW_JSON=$(printf '%s\n' "${PLAN_MISSING_PACKAGES[@]}" | jq -R . | jq -sc .)
fi
manifest::add_fragment "$(jq -nc \
	--argjson requested "$(printf '%s\n' "${!RESOLVED_PACKAGES[@]}" | sort | jq -R . | jq -sc .)" \
	--argjson present "$(printf '%s\n' "${PLAN_PRESENT_PACKAGES[@]}" | jq -R . | jq -sc .)" \
	--argjson installed "$INSTALLED_NOW_JSON" \
	'{capabilities: {requested: $requested, resolved: $requested},
	  packages: {already_present: $present, installed_by_project: $installed}}')"

manifest::add_fragment '{"services_enabled":["dotfiles-graphical-session.target","waybar.service","mako.service","hypridle.service","swaybg.service"]}'

# Run the commit phase in a subshell: a log::die inside it (e.g. a refused
# conflict) calls exit, which an ERR trap does NOT catch when it fires from a
# nested function (verified empirically) — an exit always terminates the
# whole process outright. Isolating it in a subshell means only the subshell
# dies, so the parent can detect the failure and roll back the files that
# *did* get committed before it died (their rows are already flushed to
# manifest.tsv on disk, subshell or not).
if ! (
	commit::commit_staged_tree "${STAGE_DIR}/config" "${HOME}/.config"
	commit::commit_staged_tree "${STAGE_DIR}/home" "${HOME}"
); then
	log::error "install: a mutation failed mid-transaction; rolling back committed files for ${TRANSACTION_ID}"
	rollback::restore_transaction "$TRANSACTION_ID"
	log::die "install: transaction ${TRANSACTION_ID} rolled back after failure"
fi

services::reload_units
manifest::write

log::info "install complete (Phase 1: core desktop, no dotctl/profiles/wizard yet)"
