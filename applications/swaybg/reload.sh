#!/usr/bin/env bash
# swaybg::reload — no live-reload; a color change needs a restart of the
# systemd service, handled by services.sh.

swaybg::reload() {
	log::info "swaybg::reload: swaybg has no live-reload; restart the service instead"
}
