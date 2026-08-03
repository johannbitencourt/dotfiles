#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/install/rollback.sh"

fail() {
	echo "FAIL: $*"
	exit 1
}

STATE_DIR=$(mktemp -d)
trap 'rm -rf "$STATE_DIR"' EXIT

target="/home/x/.config/app/f"

# 1. A path never replaced (only ever "install"/"update") has no original
#    backup at all.
mkdir -p "${STATE_DIR}/backups/20260101T000000Z-1"
printf 'other-path\t-\t-\t-\tinstall\n' >"${STATE_DIR}/backups/20260101T000000Z-1/manifest.tsv"
if (rollback::find_original_backup "$target") 2>/dev/null; then
	fail "found a backup for a path that was never replaced"
fi
echo "PASS: no backup found for a path that was always ours"

# 2. The key regression case: an OLDER transaction backed it up as
#    replace-unmanaged (the true original); a NEWER transaction backed it
#    up again as replace-drifted (the project's own prior output, from a
#    later hand-edit). find_original_backup must return the OLDER one.
true_backup="${STATE_DIR}/backups/20260201T000000Z-2/true-original-backup"
mkdir -p "$(dirname "$true_backup")"
printf '%s\t%s\torig1\tnew1\treplace-unmanaged\n' "$target" "$true_backup" \
	>"${STATE_DIR}/backups/20260201T000000Z-2/manifest.tsv"
echo "true original content" >"$true_backup"

drifted_backup="${STATE_DIR}/backups/20260601T000000Z-3/drifted-backup"
mkdir -p "$(dirname "$drifted_backup")"
printf '%s\t%s\torig2\tnew2\treplace-drifted\n' "$target" "$drifted_backup" \
	>"${STATE_DIR}/backups/20260601T000000Z-3/manifest.tsv"
echo "drifted content, not the original" >"$drifted_backup"

result=$(rollback::find_original_backup "$target") || fail "find_original_backup returned nothing when a replace-unmanaged backup exists"
[[ $result == "$true_backup" ]] ||
	fail "expected the older replace-unmanaged backup, got: ${result}"
[[ $(cat "$result") == "true original content" ]] || fail "resolved backup path has the wrong content"
echo "PASS: returns the older replace-unmanaged backup, ignoring a newer replace-drifted one"

echo "ALL PASS"
