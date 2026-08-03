#!/usr/bin/env bash
fuzzel::generate() {
	local -A values=(
		[TERMINAL_FONT]="${HOST[TERMINAL_FONT]:-JetBrainsMono Nerd Font}"
		[TERMINAL_FONT_SIZE]="${HOST[TERMINAL_FONT_SIZE]:-12}"
	)
	render_template "${DOTFILES_ROOT}/config/fuzzel/fuzzel.ini.tmpl" \
		"${STAGE_DIR}/config/fuzzel/fuzzel.ini" values
	log::info "fuzzel::generate: rendered fuzzel.ini"
}
