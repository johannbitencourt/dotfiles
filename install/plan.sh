#!/usr/bin/env bash
# Resolves the host profile and capability->package mapping, then builds the
# package plan. No mutation here — deploy.sh does the actual installing.

declare -gA HOST=()
declare -gA RESOLVED_PACKAGES=() # capability -> package name
declare -ga PLAN_MISSING_PACKAGES=()
declare -ga PLAN_PRESENT_PACKAGES=()
declare -g PLAN_HOST_NAME=""

# plan::resolve_host <host-name>
# Precedence (lowest to highest): project preference defaults < detected
# hardware facts < committed host profile < local untracked host override
# < --preference CLI flags. (2 layers, not the full HLD 7-layer chain — see
# the Phase-1 simplification table in the project plan.)
plan::resolve_host() {
	PLAN_HOST_NAME=$1
	local host_file="${DOTFILES_ROOT}/hosts/${PLAN_HOST_NAME}.conf"
	[[ -f $host_file ]] || log::die "plan::resolve_host: no such host profile: ${host_file}"

	local k
	local -A defaults=()
	kv_parse_file "${DOTFILES_ROOT}/preferences/defaults.conf" defaults
	for k in "${!defaults[@]}"; do HOST[$k]=${defaults[$k]}; done

	for k in "${!DETECTED[@]}"; do HOST[$k]=${DETECTED[$k]}; done

	local -A committed=()
	kv_parse_file "$host_file" committed
	for k in "${!committed[@]}"; do HOST[$k]=${committed[$k]}; done

	local local_override="${HOME}/.config/dotfiles/hosts/${PLAN_HOST_NAME}.local.conf"
	if [[ -f $local_override ]]; then
		local -A local_kv=()
		kv_parse_file "$local_override" local_kv
		for k in "${!local_kv[@]}"; do HOST[$k]=${local_kv[$k]}; done
	fi

	for k in "${!CLI_PREFERENCES[@]}"; do HOST[$k]=${CLI_PREFERENCES[$k]}; done

	log::info "plan::resolve_host: host=${PLAN_HOST_NAME} type=${HOST[HOST_TYPE]:-unknown} gpu=${HOST[GPU_VENDOR]:-unknown}/${HOST[GPU_MODE]:-unknown}"
}

plan::resolve_capabilities() {
	local caps_file="${DOTFILES_ROOT}/packages/capabilities.conf"
	local cap pkg
	while IFS= read -r cap; do
		[[ -z $cap || $cap == \#* ]] && continue
		pkg=$(adapter_resolve_capability "$cap") || log::die "plan::resolve_capabilities: capability unsupported by this adapter: ${cap}"
		RESOLVED_PACKAGES[$cap]=$pkg
	done <"$caps_file"
	log::info "plan::resolve_capabilities: resolved ${#RESOLVED_PACKAGES[@]} capabilities"
}

plan::build() {
	local cap pkg
	for cap in "${!RESOLVED_PACKAGES[@]}"; do
		pkg=${RESOLVED_PACKAGES[$cap]}
		if adapter_package_installed "$pkg"; then
			PLAN_PRESENT_PACKAGES+=("$pkg")
		else
			PLAN_MISSING_PACKAGES+=("$pkg")
		fi
	done
	log::info "plan::build: ${#PLAN_PRESENT_PACKAGES[@]} package(s) already present, ${#PLAN_MISSING_PACKAGES[@]} to install"
}

plan::print() {
	local p
	printf '\nInstall plan\n'
	printf '  host profile     : %s\n' "$PLAN_HOST_NAME"
	printf '  distro           : %s\n' "${HOST[DISTRO_ID]:-unknown}"
	printf '  gpu              : %s (%s)\n' "${HOST[GPU_VENDOR]:-unknown}" "${HOST[GPU_MODE]:-unknown}"
	printf '  packages present : %d\n' "${#PLAN_PRESENT_PACKAGES[@]}"
	printf '  packages to install (%d):\n' "${#PLAN_MISSING_PACKAGES[@]}"
	for p in "${PLAN_MISSING_PACKAGES[@]}"; do printf '    - %s\n' "$p"; done
	printf '\n'
}
