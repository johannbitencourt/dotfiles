#!/usr/bin/env bash
# waybar::validate — strips full-line // comments (the only comment style we
# generate) and checks the result is valid JSON. A real inline-comment-aware
# stripper isn't needed since we fully control this file's formatting.

waybar::validate() {
	local config="${STAGE_DIR}/config/waybar/config.jsonc"
	[[ -f $config ]] || log::die "waybar::validate: no staged config at ${config}"

	if ! grep -v '^[[:space:]]*//' "$config" | jq empty; then
		log::die "waybar::validate: config.jsonc is not valid JSON after stripping // comments"
	fi
	log::info "waybar::validate: OK"
}
