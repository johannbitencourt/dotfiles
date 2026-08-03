#!/usr/bin/env bash
# foot::reload — no-op: each foot window reads its config at launch; there's
# no persistent daemon to signal (foot's optional server mode is not used in
# Phase 1).

foot::reload() {
	log::info "foot::reload: nothing to do, foot reads config on next launch"
}
