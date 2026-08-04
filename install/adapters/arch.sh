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
#   adapter_remove_packages <package>...
#   adapter_candidate_version <package>
#   adapter_upgrade_plan
#   adapter_upgrade_system
#   adapter_enable_system_service <unit>
#   adapter_disable_system_service <unit>

# Accepts ID=arch, or any Arch derivative that sets ID_LIKE=arch per the
# os-release(5) spec (CachyOS, EndeavourOS, Manjaro, etc. all do this) —
# matches HLD 6.2's own Arch-family tier table, which lists CachyOS and
# EndeavourOS alongside Arch Linux itself, not just a literal ID=arch.
# Support is meant to come from a real compatibility manifest (HLD 6.3),
# not just /etc/os-release — that manifest (tiers, --experimental,
# known-issues) is unbuilt Phase 3 scope; this is the minimal fix for the
# concrete bug (CachyOS rejected outright) without building it early.
adapter_detect() {
	local os_release=${1:-/etc/os-release}
	[[ -r $os_release ]] || return 1
	grep -qx 'ID=arch' "$os_release" && return 0
	grep -qE '^ID_LIKE=.*\barch\b' "$os_release"
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

# adapter_remove_packages <package>...
# Plain -R, not -Rs: pacman itself refuses to remove a package something
# else still depends on, matching "shared dependencies are never
# automatically removed" without any extra logic here.
adapter_remove_packages() {
	local -a pkgs=("$@")
	[[ ${#pkgs[@]} -eq 0 ]] && return 0
	sudo pacman -R --noconfirm "${pkgs[@]}"
}

# adapter_candidate_version <package>
adapter_candidate_version() {
	local pkg=$1
	pacman -Si "$pkg" 2>/dev/null | awk -F': ' '/^Version/ { print $2; exit }'
}

# adapter_check_hyprland_version — non-dying core shared by
# adapter_validate_version (dies on failure, used by apply) and doctor's
# distro check (reports and keeps going). Sets ADAPTER_CANDIDATE_VERSION /
# ADAPTER_MIN_VERSION as a side effect. Returns: 0 candidate>=min, 1
# candidate<min, 2 candidate unknown (e.g. pacman unreachable).
adapter_check_hyprland_version() {
	local -A compat
	kv_parse_file "${DOTFILES_ROOT}/compat/compat.conf" compat
	ADAPTER_MIN_VERSION=${compat[HYPRLAND_MIN_VERSION]}
	ADAPTER_CANDIDATE_VERSION=$(adapter_candidate_version hyprland)
	[[ -n $ADAPTER_CANDIDATE_VERSION ]] || return 2

	# pacman versions are pkgver-pkgrel (and, rarely, epoch:pkgver-pkgrel);
	# strip the pkgrel suffix so sort -V compares plain pkgver against
	# pkgver. Epochs aren't handled — no Phase-1/2 capability uses one.
	local candidate_ver=${ADAPTER_CANDIDATE_VERSION%-*}
	[[ "$(printf '%s\n%s\n' "$ADAPTER_MIN_VERSION" "$candidate_ver" | sort -V | head -n1)" == "$ADAPTER_MIN_VERSION" ]]
}

adapter_validate_version() {
	local rc
	adapter_check_hyprland_version && rc=0 || rc=$?
	case $rc in
	0) log::info "hyprland candidate ${ADAPTER_CANDIDATE_VERSION} satisfies minimum ${ADAPTER_MIN_VERSION}" ;;
	2) log::die "adapter_validate_version: could not query candidate hyprland version" ;;
	*) log::die "hyprland candidate ${ADAPTER_CANDIDATE_VERSION} is older than required minimum ${ADAPTER_MIN_VERSION}" ;;
	esac
}

# adapter_upgrade_plan
# Refreshes package metadata and prints the pending upgrade. pacman has no
# side-effect-free preview: --print still requires root and still writes
# the local sync-db cache (confirmed empirically: `pacman -Syu --print` as
# non-root refuses with "you cannot perform this operation unless you are
# root"). Deliberately not split into a separate refresh + `pacman -Qu` —
# that reintroduces the exact stale-db/partial-upgrade risk -Syu together
# avoids.
adapter_upgrade_plan() {
	sudo pacman -Syu --print --noconfirm
}

# adapter_upgrade_system — the real system-wide upgrade.
adapter_upgrade_system() {
	sudo pacman -Syu --noconfirm
}

adapter_enable_system_service() {
	local unit=$1
	systemctl --user enable --now "$unit"
}

adapter_disable_system_service() {
	local unit=$1
	systemctl --user disable --now "$unit" 2>/dev/null || true
}
