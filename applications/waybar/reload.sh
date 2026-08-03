#!/usr/bin/env bash
# waybar::reload — not yet wired into any install phase (services land in
# Milestone 4); exists now to satisfy the module contract.

waybar::reload() {
	if pgrep -x waybar &>/dev/null; then
		pkill -SIGUSR2 -x waybar
		log::info "waybar::reload: sent SIGUSR2 to waybar"
	else
		log::info "waybar::reload: waybar is not running, nothing to reload"
	fi
}
