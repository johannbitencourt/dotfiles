#!/usr/bin/env bash
# Arch (pacman) distribution adapter.
#
# Only the functions Phase 1 actually calls are implemented. This file is
# sourced directly by install.sh — there is no adapter interface/loader file
# yet; add one when a second adapter (Fedora/openSUSE/Debian) exists to
# enforce a contract against.
#
# Contract implemented here (subset of the full HLD adapter contract):
#   adapter_detect
#   adapter_validate_version
#   adapter_resolve_capability <capability> -> prints package name, or "unsupported"
#   adapter_package_installed <package>
#   adapter_install_packages <package>...
#   adapter_candidate_version <package>
#   adapter_enable_system_service <unit>
#   adapter_disable_system_service <unit>

adapter_detect() {
	[[ -r /etc/os-release ]] || return 1
	grep -qx 'ID=arch' /etc/os-release
}

# adapter_resolve_capability <capability>
# Prints the resolved package name on stdout, or "unsupported". Always
# "native" in Phase 1 (see packages/mappings/arch.conf header comment).
adapter_resolve_capability() {
	local capability=$1
	local mapping="${DOTFILES_ROOT}/packages/mappings/arch.conf"
	local pkg
	pkg=$(awk -F'\t' -v cap="$capability" '!/^#/ && $1 == cap { print $2; exit }' "$mapping")
	if [[ -z $pkg ]]; then
		printf '%s\n' "unsupported"
		return 1
	fi
	printf '%s\n' "$pkg"
}

adapter_package_installed() {
	local pkg=$1
	pacman -Q "$pkg" &>/dev/null
}

# adapter_install_packages <package>...
adapter_install_packages() {
	local -a pkgs=("$@")
	[[ ${#pkgs[@]} -eq 0 ]] && return 0
	sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

# adapter_candidate_version <package>
adapter_candidate_version() {
	local pkg=$1
	pacman -Si "$pkg" 2>/dev/null | awk -F': ' '/^Version/ { print $2; exit }'
}

adapter_validate_version() {
	local -A compat
	kv_parse_file "${DOTFILES_ROOT}/compat/compat.conf" compat
	local min_version=${compat[HYPRLAND_MIN_VERSION]}
	local candidate candidate_ver
	candidate=$(adapter_candidate_version hyprland)
	[[ -n $candidate ]] || log::die "adapter_validate_version: could not query candidate hyprland version"
	# pacman versions are pkgver-pkgrel (and, rarely, epoch:pkgver-pkgrel); strip
	# the pkgrel suffix so sort -V compares plain pkgver against pkgver. Epochs
	# aren't handled — no Phase-1 capability uses one.
	candidate_ver=${candidate%-*}

	if [[ "$(printf '%s\n%s\n' "$min_version" "$candidate_ver" | sort -V | head -n1)" != "$min_version" ]]; then
		log::die "hyprland candidate ${candidate} is older than required minimum ${min_version}"
	fi
	log::info "hyprland candidate ${candidate} satisfies minimum ${min_version}"
}

adapter_enable_system_service() {
	local unit=$1
	systemctl --user enable --now "$unit"
}

adapter_disable_system_service() {
	local unit=$1
	systemctl --user disable --now "$unit" 2>/dev/null || true
}
