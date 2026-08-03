#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)
source "${DOTFILES_ROOT}/scripts/lib/log.sh"

fail() {
	echo "FAIL: $*"
	exit 1
}

# Everything below runs against a scratch $HOME — never the real one.
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME=$FAKE_HOME
STATE_DIR="${HOME}/.local/state/dotfiles"
TRANSACTION_ID="test-txn"

source "${DOTFILES_ROOT}/install/commit.sh"
source "${DOTFILES_ROOT}/install/rollback.sh"
commit::init

backup_dir="${STATE_DIR}/backups/${TRANSACTION_ID}"
manifest="${backup_dir}/manifest.tsv"
mkdir -p "$backup_dir"

# 1. A file that was successfully replaced (with a backup) must be restored
#    to its original content.
target_a="${HOME}/.config/app/a"
mkdir -p "$(dirname "$target_a")"
printf 'original-A' >"$target_a"
commit::_backup_file "$target_a" "$backup_dir" # sets _BACKUP_PATH/_ORIG_SUM, no confirm needed
printf 'new-A' >"$target_a"
new_sum_a=$(sha256sum "$target_a" | awk '{print $1}')
printf '%s\t%s\t%s\t%s\t%s\n' "$target_a" "$_BACKUP_PATH" "$_ORIG_SUM" "$new_sum_a" "replace-unmanaged" >>"$manifest"

# 2. A freshly-installed file (no prior conflict, no backup) must be left
#    alone by rollback — there's nothing to "restore" it to.
target_b="${HOME}/.config/app/b"
mkdir -p "$(dirname "$target_b")"
printf 'freshly-installed-B' >"$target_b"
printf '%s\t%s\t%s\t%s\t%s\n' "$target_b" "-" "-" "$(sha256sum "$target_b" | awk '{print $1}')" "install" >>"$manifest"

# 3. A symlink that was backed up must come back as a symlink, not a
#    dereferenced copy of its target's content.
target_c="${HOME}/.config/app/c"
mkdir -p "$(dirname "$target_c")"
real_file="${HOME}/elsewhere-c"
printf 'symlinked-content' >"$real_file"
ln -s "$real_file" "$target_c"
commit::_backup_file "$target_c" "$backup_dir"
rm -f "$target_c"
printf 'replaced-C' >"$target_c"
new_sum_c=$(sha256sum "$target_c" | awk '{print $1}')
printf '%s\t%s\t%s\t%s\t%s\n' "$target_c" "$_BACKUP_PATH" "$_ORIG_SUM" "$new_sum_c" "replace-unmanaged" >>"$manifest"

rollback::restore_transaction "$TRANSACTION_ID"

[[ $(cat "$target_a") == "original-A" ]] || fail "target_a was not restored to its original content"
echo "PASS: replaced file restored to original content"

[[ $(cat "$target_b") == "freshly-installed-B" ]] || fail "target_b (install action, no backup) was altered by rollback"
echo "PASS: freshly-installed file left alone by rollback"

[[ -L $target_c ]] || fail "target_c was not restored as a symlink"
[[ $(readlink "$target_c") == "$real_file" ]] || fail "target_c symlink points at the wrong target after restore"
echo "PASS: symlink restored as a symlink, not dereferenced"

# 4. Restoring a transaction with no manifest at all must fail loudly, not
#    silently no-op — run in a subshell since log::die exits the process.
if (rollback::restore_transaction "no-such-transaction") 2>/dev/null; then
	fail "restoring a nonexistent transaction did not fail"
fi
echo "PASS: nonexistent transaction restore fails loudly"

echo "ALL PASS"
