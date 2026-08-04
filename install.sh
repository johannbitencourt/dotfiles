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
	sudo pacman -S --needed -- "${pkgs[@]}"
	# Installed-but-not-enabled is the classic way to end up with no wifi.
	sudo systemctl enable --now NetworkManager.service bluetooth.service
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
