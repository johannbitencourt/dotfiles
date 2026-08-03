#!/usr/bin/env bash
# hypridle::reload — no known live-reload IPC; a config change needs a
# restart, handled by services.sh (Milestone 4) once the systemd unit
# exists. Exists now to satisfy the module contract.

hypridle::reload() {
	log::info "hypridle::reload: hypridle has no live-reload; restart the service instead"
}
