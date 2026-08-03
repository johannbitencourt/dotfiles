#!/usr/bin/env bash
# hyprlock::reload — no-op: hyprlock is launched on demand (Super+L or
# hypridle's lock_cmd), not a persistent daemon; it reads its config fresh
# on every invocation.

hyprlock::reload() {
	log::info "hyprlock::reload: nothing to do, hyprlock reads config on next launch"
}
