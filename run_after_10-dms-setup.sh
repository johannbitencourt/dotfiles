#!/usr/bin/env bash
set -euo pipefail

if ! command -v dms >/dev/null 2>&1; then
  echo "DMS is required but is not installed." >&2
  exit 1
fi

for component in colors outputs layout cursor binds windowrules; do
  target="$HOME/.config/hypr/dms/$component.lua"
  if [[ ! -s "$target" ]]; then
    dms setup "$component"
  fi
done
