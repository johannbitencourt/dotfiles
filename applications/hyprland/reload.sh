#!/usr/bin/env bash
# hyprland::reload — reloads config into a running Hyprland via hyprctl.
# Not yet wired into any install phase (services land in Milestone 4); it
# exists now to satisfy the module contract and for future use once a real
# session cutover happens.

hyprland::reload() {
	if pgrep -x Hyprland &>/dev/null; then
		hyprctl reload
		log::info "hyprland::reload: hyprctl reload issued"
	else
		log::info "hyprland::reload: Hyprland is not running, nothing to reload"
	fi
}
