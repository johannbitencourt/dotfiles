#!/usr/bin/env bash
# fuzzel isn't installed on this host yet (no real binary to check config
# syntax against directly) — falls back to a generic INI structure check.
# Revisit with `fuzzel --check-config` (if such a flag exists) once installed.

fuzzel::validate() {
	local config="${STAGE_DIR}/config/fuzzel/fuzzel.ini"
	[[ -f $config ]] || log::die "fuzzel::validate: no staged config at ${config}"
	validate::_ini "$config"
	log::info "fuzzel::validate: OK (structural check only)"
}
