#!/usr/bin/env bash
# mako::reload — mako supports live config reload via `makoctl reload`.

mako::reload() {
	if pgrep -x mako &>/dev/null && command -v makoctl &>/dev/null; then
		makoctl reload
		log::info "mako::reload: makoctl reload issued"
	else
		log::info "mako::reload: mako is not running or makoctl unavailable, nothing to reload"
	fi
}
