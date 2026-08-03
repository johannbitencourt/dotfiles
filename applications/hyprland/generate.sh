#!/usr/bin/env bash
# hyprland::generate — renders this host's Hyprland config into the staging
# dir. Called by stage::generate_applications, which sources this file and
# invokes hyprland::generate.

hyprland::generate() {
	local -A values=(
		[PRIMARY_OUTPUT]="${HOST[PRIMARY_OUTPUT]:-eDP-1}"
		[KEYBOARD_LAYOUT]="${HOST[KEYBOARD_LAYOUT]:-us}"
		[HYPR_GAPS_IN]="${HOST[HYPR_GAPS_IN]:-4}"
		[HYPR_GAPS_OUT]="${HOST[HYPR_GAPS_OUT]:-8}"
		[HYPR_BORDER_SIZE]="${HOST[HYPR_BORDER_SIZE]:-2}"
		[HYPR_ANIMATIONS]="${HOST[HYPR_ANIMATIONS]:-0}"
		[HYPR_BLUR]="${HOST[HYPR_BLUR]:-0}"
	)

	render_template "${DOTFILES_ROOT}/config/hypr/hyprland.conf.tmpl" \
		"${STAGE_DIR}/config/hypr/hyprland.conf" values

	local frag
	for frag in "${DOTFILES_ROOT}"/config/hypr/conf.d/*.conf.tmpl; do
		render_template "$frag" \
			"${STAGE_DIR}/config/hypr/conf.d/$(basename "${frag%.tmpl}")" values
	done

	log::info "hyprland::generate: rendered hyprland.conf + conf.d fragments"
}
