#!/usr/bin/env bash
# mako has no config-check flag, and running the real binary would fight the
# currently-live Omarchy mako instance over the notifications D-Bus name —
# falls back to the generic INI structure check instead.

mako::validate() {
	local config="${STAGE_DIR}/config/mako/config"
	[[ -f $config ]] || log::die "mako::validate: no staged config at ${config}"
	validate::_ini "$config"
	log::info "mako::validate: OK (structural check only)"
}
