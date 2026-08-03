#!/usr/bin/env bash
# Shared logging helpers. Sourced by install.sh and install/*.sh.

log::_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

log::info() { printf '[%s] INFO  %s\n' "$(log::_ts)" "$*" >&2; }
log::warn() { printf '[%s] WARN  %s\n' "$(log::_ts)" "$*" >&2; }
log::error() { printf '[%s] ERROR %s\n' "$(log::_ts)" "$*" >&2; }
log::die() {
	log::error "$*"
	exit 1
}
