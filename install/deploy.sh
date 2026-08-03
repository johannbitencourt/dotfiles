#!/usr/bin/env bash
# Package-installation phase. The only mutating phase implemented in
# Milestone 1 — config staging/commit/services land in later milestones.

deploy::packages() {
	if [[ ${#PLAN_MISSING_PACKAGES[@]} -eq 0 ]]; then
		log::info "deploy::packages: nothing to install"
		return 0
	fi

	if [[ $OPT_DRY_RUN -eq 1 ]]; then
		log::info "deploy::packages: --dry-run, would install: ${PLAN_MISSING_PACKAGES[*]}"
		return 0
	fi

	log::info "deploy::packages: installing ${#PLAN_MISSING_PACKAGES[@]} package(s)"
	adapter_install_packages "${PLAN_MISSING_PACKAGES[@]}"
}
