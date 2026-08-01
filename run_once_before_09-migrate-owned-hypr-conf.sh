#!/usr/bin/env bash
set -euo pipefail

legacy="$HOME/.config/hypr/hyprland.conf"
marker="# DMS generates and updates these files. Keep personal overrides below them."

# Only migrate the deprecated config created by an earlier revision of this repo.
if [[ -f "$legacy" ]] && grep -Fqx "$marker" "$legacy"; then
  backup="$HOME/.config/hypr/legacy-conf-backup"
  mkdir -p "$backup"
  for name in hyprland envs monitors input looknfeel autostart bindings; do
    file="$HOME/.config/hypr/$name.conf"
    if [[ -f "$file" ]]; then
      cp -a "$file" "$backup/$name.conf"
      rm "$file"
    fi
  done
fi
