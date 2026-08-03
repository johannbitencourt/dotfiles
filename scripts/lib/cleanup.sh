#!/usr/bin/env bash
# Shared scratch-directory cleanup. Multiple modules (stage.sh, manifest.sh)
# each mktemp their own scratch dir and need it removed on exit — a plain
# `trap ... EXIT` per module would silently clobber the others' (bash's
# `trap` replaces the handler, it doesn't chain them). Register a path here
# instead; one trap, set once, removes everything registered.

declare -ga _CLEANUP_PATHS=()

cleanup::_run() {
	local p
	for p in "${_CLEANUP_PATHS[@]}"; do
		[[ -n $p ]] && rm -rf "$p"
	done
}
trap cleanup::_run EXIT

cleanup::register() {
	_CLEANUP_PATHS+=("$1")
}
