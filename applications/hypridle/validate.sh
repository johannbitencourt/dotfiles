#!/usr/bin/env bash
# Running hypridle directly would fight any already-running idle daemon on
# this host's live session, so validation falls back to a brace-balance
# check instead of a real parse.

hypridle::validate() {
	local config="${STAGE_DIR}/config/hypridle/hypridle.conf"
	[[ -f $config ]] || log::die "hypridle::validate: no staged config at ${config}"
	validate::_braces "$config"
	log::info "hypridle::validate: OK (structural check only)"
}
