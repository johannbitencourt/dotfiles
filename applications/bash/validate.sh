#!/usr/bin/env bash
# .bashrc and .bash_profile have no .bash extension and no shebang (they're
# sourced, not executed), so the generic validate::staging heuristic misses
# them — checked explicitly here. Everything under config/bash/*.bash is
# already covered by that generic check (extension match).

bash::validate() {
	local f
	for f in "${STAGE_DIR}/home/.bashrc" "${STAGE_DIR}/home/.bash_profile"; do
		[[ -f $f ]] || continue
		bash -n "$f" || log::die "bash::validate: bash -n failed for ${f}"
	done
	log::info "bash::validate: OK"
}
