#!/usr/bin/env bash
hypridle::generate() {
	local -A values=(
		[LOCK_TIMEOUT_SEC]="${HOST[LOCK_TIMEOUT_SEC]:-300}"
		[SCREENOFF_TIMEOUT_SEC]="${HOST[SCREENOFF_TIMEOUT_SEC]:-360}"
	)
	render_template "${DOTFILES_ROOT}/config/hypridle/hypridle.conf.tmpl" \
		"${STAGE_DIR}/config/hypridle/hypridle.conf" values
	log::info "hypridle::generate: rendered hypridle.conf"
}
