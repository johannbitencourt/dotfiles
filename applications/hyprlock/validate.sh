#!/usr/bin/env bash
# Running hyprlock directly would actually lock this host's live screen, so
# validation falls back to a brace-balance check instead of a real parse.

hyprlock::validate() {
	local config="${STAGE_DIR}/config/hyprlock/hyprlock.conf"
	[[ -f $config ]] || log::die "hyprlock::validate: no staged config at ${config}"
	validate::_braces "$config"
	log::info "hyprlock::validate: OK (structural check only)"
}
