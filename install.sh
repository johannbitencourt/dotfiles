#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] && { echo "install.sh: run as your normal user, not root" >&2; exit 1; }

case "${1:-}" in
	"" | --no-packages) ;;
	*) echo "usage: install.sh [--no-packages]" >&2; exit 2 ;;
esac

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dest="${XDG_CONFIG_HOME:-$HOME/.config}"

if [[ ${1:-} != --no-packages ]]; then
	mapfile -t pkgs < <(grep -vE '^[[:space:]]*(#|$)' -- "$repo/packages.txt")
	# Every name in packages.txt is in Arch's official repos, so pacman alone
	# does the whole list — no AUR helper to install or keep working. The few
	# AUR extras this setup can use are listed in the README and left to you.
	sudo pacman -S --needed -- "${pkgs[@]}"
	# iwd only brings up the wifi *link*; addresses and DNS come from
	# systemd-networkd/resolved, which need a .network match to do anything —
	# systemd ships only inert .example files. Copied, not symlinked: root
	# should not read config out of a user-writable directory. Never
	# overwrites, so a hand-tuned /etc survives a re-run.
	sudo mkdir -p /etc/systemd/network
	sudo cp -n -- "$repo"/etc/systemd/network/*.network /etc/systemd/network/

	# Installed-but-not-enabled is the classic way to end up with no wifi.
	sudo systemctl enable --now iwd.service systemd-networkd.service \
		systemd-resolved.service bluetooth.service cups.service
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
