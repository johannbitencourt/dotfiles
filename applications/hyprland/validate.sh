#!/usr/bin/env bash
# hyprland::validate — flattens this host's staged conf.d/*.conf fragments
# (the same files `source = ~/.config/hypr/conf.d/*.conf` pulls in at
# runtime) and runs them through `Hyprland --verify-config`. The staged
# hyprland.conf itself only contains that one source line — pointed at the
# real $HOME, not the staging dir — so there's nothing else to check there
# without touching the live session.

hyprland::validate() {
	local conf_d="${STAGE_DIR}/config/hypr/conf.d"
	[[ -d $conf_d ]] || log::die "hyprland::validate: no conf.d staged at ${conf_d}"

	local flattened
	flattened=$(mktemp)
	cat "${conf_d}"/*.conf >"$flattened" 2>/dev/null

	local output
	if ! output=$(Hyprland --config "$flattened" --verify-config 2>&1); then
		rm -f "$flattened"
		log::die "hyprland::validate: config verification failed:
${output}"
	fi
	rm -f "$flattened"
	log::info "hyprland::validate: OK"
}
