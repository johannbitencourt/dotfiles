#!/usr/bin/env bash
hyprlock::generate() {
	local -A values=() # no @@KEY@@ substitution needed yet
	render_template "${DOTFILES_ROOT}/config/hyprlock/hyprlock.conf.tmpl" \
		"${STAGE_DIR}/config/hyprlock/hyprlock.conf" values
	log::info "hyprlock::generate: rendered hyprlock.conf"
}
