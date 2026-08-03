#!/usr/bin/env bash
# bash::reload — no-op: an already-running interactive shell can't be
# reloaded externally; the user re-sources ~/.bashrc or opens a new shell.

bash::reload() {
	log::info "bash::reload: nothing to do, open a new shell (or 'source ~/.bashrc') to pick up changes"
}
