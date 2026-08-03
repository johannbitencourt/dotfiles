#!/usr/bin/env bash
# waybar::generate — renders this host's Waybar config into the staging dir.

waybar::generate() {
	local -A values=() # no @@KEY@@ substitution needed yet

	render_template "${DOTFILES_ROOT}/config/waybar/config.jsonc.tmpl" \
		"${STAGE_DIR}/config/waybar/config.jsonc" values "//"

	render_template "${DOTFILES_ROOT}/config/waybar/style.css.tmpl" \
		"${STAGE_DIR}/config/waybar/style.css" values

	log::info "waybar::generate: rendered config.jsonc + style.css"
}
