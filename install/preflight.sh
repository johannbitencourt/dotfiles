#!/usr/bin/env bash
# Pre-flight checks. Read-only — never mutates the system.

# Shared with doctor's required-commands check (install/doctor.sh), which
# reports missing commands instead of dying on the first one.
readonly -a PREFLIGHT_REQUIRED_COMMANDS=(pacman sudo systemctl jq git sed awk grep lspci sha256sum flock)

preflight::run() {
	local bash_major=${BASH_VERSINFO[0]}
	((bash_major >= 5)) || log::die "preflight: bash 5+ required, found ${BASH_VERSION}"

	local cmd
	for cmd in "${PREFLIGHT_REQUIRED_COMMANDS[@]}"; do
		command -v "$cmd" &>/dev/null || log::die "preflight: required command not found: ${cmd}"
	done

	log::info "preflight: all checks passed"
}
