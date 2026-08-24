#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] && { echo "install.sh: run as your normal user, not root" >&2; exit 1; }

case "${1:-}" in
	"" | --no-packages) ;;
	*) echo "usage: install.sh [--no-packages]" >&2; exit 2 ;;
esac

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dest="${XDG_CONFIG_HOME:-$HOME/.config}"

read_manifest() {
	local line
	pkgs=()
	while IFS= read -r line || [[ -n $line ]]; do
		line="${line%%#*}"
		line="${line//[[:space:]]/}"
		[[ -n $line ]] && pkgs+=("$line")
	done < "$1"
}

enable_runit_service() {
	local service=$1
	if [[ ! -d /etc/sv/$service ]]; then
		echo "install.sh: required runit service is missing: /etc/sv/$service" >&2
		return 1
	fi
	if [[ ! -e /var/service/$service && ! -L /var/service/$service ]]; then
		sudo ln -s -- "/etc/sv/$service" "/var/service/$service"
		echo "enabled runit service: $service"
	fi
}

if [[ ${1:-} != --no-packages ]]; then
	[[ -r /etc/os-release ]] || { echo "install.sh: cannot read /etc/os-release" >&2; exit 1; }
	# shellcheck disable=SC1091
	source /etc/os-release
	distro_family="${ID:-}"
	case " ${ID_LIKE:-} " in
		*" arch "*) distro_family=arch ;;
		*" void "*) distro_family=void ;;
	esac
	case "$distro_family" in
		arch)
			read_manifest "$repo/packages/arch.txt"
			missing=()
			for pkg in "${pkgs[@]}"; do
				pacman -Q "$pkg" >/dev/null 2>&1 \
					|| pacman -Si "$pkg" >/dev/null 2>&1 \
					|| missing+=("$pkg")
			done
			if ((${#missing[@]})); then
				printf 'install.sh: required Arch packages are unavailable in the enabled repositories:\n' >&2
				printf '  %s\n' "${missing[@]}" >&2
				printf 'Refresh repository metadata or enable a repository providing them, then rerun install.sh. No packages were installed.\n' >&2
				exit 1
			fi
			sudo pacman -S --needed -- "${pkgs[@]}"

			# Root-owned copies and cp -n preserve locally maintained network files.
			sudo mkdir -p /etc/systemd/network
			sudo cp -n -- "$repo"/etc/systemd/network/*.network /etc/systemd/network/
			sudo systemctl enable --now iwd.service systemd-networkd.service \
				systemd-resolved.service bluetooth.service cups.service \
				power-profiles-daemon.service
			;;
		void)
			read_manifest "$repo/packages/void.txt"
			sudo xbps-install -S
			missing=()
			for pkg in "${pkgs[@]}"; do
				xbps-query -R "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
			done
			if ((${#missing[@]})); then
				printf 'install.sh: required Void packages are unavailable in the enabled repositories:\n' >&2
				printf '  %s\n' "${missing[@]}" >&2
				printf 'Enable a repository providing them, then rerun install.sh. No packages were installed.\n' >&2
				exit 1
			fi
			sudo xbps-install -y -- "${pkgs[@]}"

			# iwd performs DHCP and sends DNS data to openresolv on Void. Never
			# replace an existing administrator-maintained iwd configuration.
			sudo mkdir -p /etc/iwd
			if [[ ! -e /etc/iwd/main.conf ]]; then
				printf '%s\n' \
					'[General]' \
					'EnableNetworkConfiguration=true' \
					'' \
					'[Network]' \
					'NameResolvingService=resolvconf' \
					| sudo tee /etc/iwd/main.conf >/dev/null
				echo "created: /etc/iwd/main.conf"
			else
				echo "preserved existing: /etc/iwd/main.conf"
			fi

			for service in dbus iwd bluetoothd cupsd power-profiles-daemon; do
				enable_runit_service "$service"
			done
			;;
		*)
			echo "install.sh: unsupported distribution ID '${ID:-unset}' (expected arch/void or matching ID_LIKE)" >&2
			exit 1
			;;
	esac
fi

mkdir -p -- "$dest"

for src in "$repo"/config/*/; do
	name="$(basename -- "$src")"
	target="$dest/$name"
	if [[ -e $target && ! -L $target ]]; then
		mv -- "$target" "$target.bak"
		echo "moved aside: $target -> $target.bak"
	fi
	ln -sfn -- "${src%/}" "$target"
	echo "linked: $target"
done
