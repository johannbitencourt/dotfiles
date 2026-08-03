#!/usr/bin/env bash
foot::generate() {
	local -A values=(
		[TERMINAL_FONT]="${HOST[TERMINAL_FONT]:-JetBrainsMono Nerd Font}"
		[TERMINAL_FONT_SIZE]="${HOST[TERMINAL_FONT_SIZE]:-12}"
		[TERMINAL_PADDING]="${HOST[TERMINAL_PADDING]:-8}"
	)
	render_template "${DOTFILES_ROOT}/config/foot/foot.ini.tmpl" \
		"${STAGE_DIR}/config/foot/foot.ini" values
	log::info "foot::generate: rendered foot.ini"
}
