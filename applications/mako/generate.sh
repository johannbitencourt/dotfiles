#!/usr/bin/env bash
mako::generate() {
	local -A values=() # no @@KEY@@ substitution needed yet
	render_template "${DOTFILES_ROOT}/config/mako/config.tmpl" \
		"${STAGE_DIR}/config/mako/config" values
	log::info "mako::generate: rendered config"
}
