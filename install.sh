#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] && { echo "install.sh: run as your normal user, not root" >&2; exit 1; }

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dest="${XDG_CONFIG_HOME:-$HOME/.config}"
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
