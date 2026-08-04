#!/usr/bin/env bash
# Shared logging helpers. Sourced by install.sh and install/*.sh.

log::_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

log::info() { printf '[%s] INFO  %s\n' "$(log::_ts)" "$*" >&2; }
log::warn() { printf '[%s] WARN  %s\n' "$(log::_ts)" "$*" >&2; }
log::error() { printf '[%s] ERROR %s\n' "$(log::_ts)" "$*" >&2; }
log::die() {
	log::error "$*"
	exit 1
}

# cli::confirm_or_die <label> <what> <question>
# Shared "refuse under --non-interactive, prompt on a real TTY, die on
# decline" shape — used by every mutating command whose scope is only
# known after runtime resolution (an ambiguous overwrite conflict, a
# package upgrade, a profile install/remove). Lives here rather than its
# own file: every caller already sources log.sh, and a dedicated file
# would need the same new source line added to a dozen call sites for one
# small function. Deliberately NOT uninstall::_confirm's shape (proceeds
# under --non-interactive) — that one's scope is fully known just from
# having invoked the command; this one's isn't.
cli::confirm_or_die() {
	local label=$1 what=$2 question=$3
	if [[ $OPT_NON_INTERACTIVE -eq 1 ]]; then
		log::die "${label}: refusing without confirmation (--non-interactive): ${what}"
	fi
	log::warn "${label}: ${what}"
	local reply=""
	read -r -p "  ${question} [y/N] " reply </dev/tty
	[[ $reply == [yY] ]] || log::die "${label}: aborted by user"
}
