#!/usr/bin/env bash
# One-time migration off the DMS/Quickshell desktop, Ghostty, and the earlier
# split Hyprland configuration.
#
# This deliberately does not live in .chezmoiremove. That file is reapplied on
# every run, which would re-delete these paths forever and permanently reserve
# the filenames -- so a later hand-written ~/.config/hypr/autostart.conf would
# be silently deleted on the next apply. Running once leaves those names free.
set -euo pipefail

config="${XDG_CONFIG_HOME:-$HOME/.config}"

legacy_files=(
  # DMS
  "$config/environment.d/90-dms.conf"
  "$config/systemd/user/hyprland-session.target.wants/dms.service"
  "$config/systemd/user/hyprland-session.target"
  # Lua entry points
  "$config/hypr/bindings.lua"
  "$config/hypr/hyprland.lua"
  # Ghostty, replaced by foot
  "$config/ghostty/config"
  "$config/ghostty/themes/dankcolors"
  # Split Hyprland config, now a single hyprland.conf
  "$config/hypr/environment.conf"
  "$config/hypr/input.conf"
  "$config/hypr/looknfeel.conf"
  "$config/hypr/autostart.conf"
  "$config/hypr/bindings.conf"
  # SwayOSD and the wallpaper daemon, replaced by osd and misc:background_color
  "$config/swayosd/config.toml"
  "$config/swayosd/style.css"
  "$HOME/.local/bin/wallpaper-daemon"
)

for file in "${legacy_files[@]}"; do
  if [[ -e "$file" || -L "$file" ]]; then
    echo "Removing legacy file: $file"
    rm -f "$file"
  fi
done

# Directories these files were the only occupants of. Anything a user put
# there themselves keeps the directory alive.
legacy_dirs=(
  "$config/systemd/user/hyprland-session.target.wants"
  "$config/ghostty/themes"
  "$config/ghostty"
  "$config/swayosd"
  "$config/environment.d"
)

for dir in "${legacy_dirs[@]}"; do
  if [[ -d "$dir" ]]; then
    rmdir --ignore-fail-on-non-empty "$dir" || true
  fi
done
