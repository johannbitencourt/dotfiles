#!/usr/bin/env bash
# Hardware/distro detection. Read-only — never mutates the system.
# Populates the global DETECTED associative array (declared by install.sh).

# detect::gpu <assoc-array-name>
detect::gpu() {
	local -n out=$1
	local vendors count

	vendors=$(lspci -mm 2>/dev/null |
		grep -iE '"(VGA compatible controller|3D controller|Display controller)"' |
		grep -oiE '"(NVIDIA|Advanced Micro Devices|AMD|Intel)[^"]*"' |
		grep -oiE 'NVIDIA|Advanced Micro Devices|AMD|Intel' |
		tr '[:upper:]' '[:lower:]' |
		sed 's/advanced micro devices/amd/' |
		sort -u)
	count=$(printf '%s\n' "$vendors" | sed '/^$/d' | wc -l)

	case $count in
	0)
		log::warn "detect::gpu: no GPU vendor detected via lspci"
		out[GPU_VENDOR]=unknown
		out[GPU_MODE]=unknown
		;;
	1)
		out[GPU_VENDOR]=$vendors
		out[GPU_MODE]=single
		;;
	*)
		log::warn "detect::gpu: multiple GPU vendors detected (${vendors//$'\n'/, }); hybrid offload is not built in Phase 1 — offload vars are left unset. See the example in hosts/arch.local.conf."
		out[GPU_VENDOR]=$(printf '%s\n' "$vendors" | head -n1)
		out[GPU_MODE]=hybrid
		;;
	esac
}

# detect::distro <assoc-array-name>
detect::distro() {
	local -n out=$1
	if adapter_detect; then
		out[DISTRO_ID]=arch
	else
		log::die "detect::distro: unsupported distribution (Phase 1 supports Arch only)"
	fi
}

# detect::session — sanity-checks systemd is actually present
detect::session() {
	command -v systemctl &>/dev/null || log::die "detect::session: systemd not found"
	[[ -d /run/systemd/system ]] || log::die "detect::session: this system was not booted with systemd"
}

detect::run() {
	local -A facts=()
	local k
	detect::distro facts
	detect::gpu facts
	detect::session
	log::info "detected: distro=${facts[DISTRO_ID]} gpu_vendor=${facts[GPU_VENDOR]} gpu_mode=${facts[GPU_MODE]}"
	for k in "${!facts[@]}"; do
		DETECTED[$k]=${facts[$k]}
	done
}
