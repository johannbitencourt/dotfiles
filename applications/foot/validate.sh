#!/usr/bin/env bash
# foot isn't installed on this host yet (no real binary to check config
# syntax against directly) — falls back to a generic INI structure check.

foot::validate() {
	local config="${STAGE_DIR}/config/foot/foot.ini"
	[[ -f $config ]] || log::die "foot::validate: no staged config at ${config}"
	validate::_ini "$config"
	log::info "foot::validate: OK (structural check only)"
}
