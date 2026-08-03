#!/usr/bin/env bash
# Pre-flight checks. Read-only — never mutates the system.

preflight::run() {
	local bash_major=${BASH_VERSINFO[0]}
	((bash_major >= 5)) || log::die "preflight: bash 5+ required, found ${BASH_VERSION}"

	local -a required_cmds=(pacman sudo systemctl jq git sed awk grep lspci sha256sum flock)
	local cmd
	for cmd in "${required_cmds[@]}"; do
		command -v "$cmd" &>/dev/null || log::die "preflight: required command not found: ${cmd}"
	done

	log::info "preflight: all checks passed"
}
