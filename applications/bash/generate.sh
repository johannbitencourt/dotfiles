#!/usr/bin/env bash
bash::generate() {
	local -A values=() # no @@KEY@@ substitution needed yet

	render_template "${DOTFILES_ROOT}/config/bash/bashrc.tmpl" \
		"${STAGE_DIR}/home/.bashrc" values
	render_template "${DOTFILES_ROOT}/config/bash/profile.tmpl" \
		"${STAGE_DIR}/home/.bash_profile" values
	render_template "${DOTFILES_ROOT}/config/bash/inputrc.tmpl" \
		"${STAGE_DIR}/home/.inputrc" values

	local mod
	for mod in "${DOTFILES_ROOT}"/config/bash/modules/*.bash.tmpl; do
		render_template "$mod" \
			"${STAGE_DIR}/config/bash/$(basename "${mod%.tmpl}")" values
	done

	log::info "bash::generate: rendered .bashrc, .bash_profile, .inputrc + modules"
}
