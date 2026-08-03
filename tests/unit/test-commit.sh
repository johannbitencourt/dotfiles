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
STAGE_DIR=$(mktemp -d)
staged_dir=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME" "$STAGE_DIR" "$staged_dir"' EXIT
HOME=$FAKE_HOME
STATE_DIR="${HOME}/.local/state/dotfiles"
TRANSACTION_ID="test-txn"
OPT_DRY_RUN=0
OPT_NON_INTERACTIVE=1

source "${DOTFILES_ROOT}/install/manifest.sh"
source "${DOTFILES_ROOT}/install/commit.sh"
commit::init
manifest::init

echo "content-v1" >"${staged_dir}/f1"
echo "content-v2" >"${staged_dir}/f2"

target="${HOME}/.config/app/f1"

# 1. absent -> install, no prompt needed even under --non-interactive
commit::backup_and_write "${staged_dir}/f1" "$target"
[[ $(cat "$target") == content-v1 ]] || fail "absent->install did not write expected content"
echo "PASS: absent -> install"

# 2. managed-unchanged -> silent update, no backup created
before_backups=$(find "${STATE_DIR}/backups" -type f 2>/dev/null | wc -l)
commit::backup_and_write "${staged_dir}/f1" "$target"
after_backups=$(find "${STATE_DIR}/backups" -type f 2>/dev/null | wc -l)
[[ $before_backups -eq $after_backups ]] || fail "managed-unchanged unexpectedly created a backup"
echo "PASS: managed-unchanged -> update, no backup"

# 3. managed-modified (drift) -> --non-interactive must refuse
# commit::backup_and_write hard-exits (log::die) on refusal, so it's run in a
# subshell — otherwise that exit would kill this whole test script.
echo "hand-edited" >"$target"
if (commit::backup_and_write "${staged_dir}/f2" "$target") 2>/dev/null; then
	fail "drifted managed file was overwritten under --non-interactive"
fi
[[ $(cat "$target") == "hand-edited" ]] || fail "target was mutated despite refusal"
echo "PASS: managed-modified -> refused under --non-interactive"

# 4. unmanaged file -> --non-interactive must refuse, original preserved
unmanaged_target="${HOME}/.config/app/f3"
mkdir -p "$(dirname "$unmanaged_target")"
echo "pre-existing, never ours" >"$unmanaged_target"
if (commit::backup_and_write "${staged_dir}/f1" "$unmanaged_target") 2>/dev/null; then
	fail "unmanaged file was overwritten under --non-interactive"
fi
[[ $(cat "$unmanaged_target") == "pre-existing, never ours" ]] || fail "unmanaged target was mutated despite refusal"
echo "PASS: unmanaged -> refused under --non-interactive"

# 5. --dry-run never mutates, even for a fresh target
dry_target="${HOME}/.config/app/f4"
OPT_DRY_RUN=1
commit::backup_and_write "${staged_dir}/f1" "$dry_target"
[[ ! -e $dry_target ]] || fail "--dry-run wrote a file to \$HOME"
OPT_DRY_RUN=0
echo "PASS: --dry-run writes nothing"

# 6. a symlink target classifies as unmanaged (we never generate symlinks
#    ourselves), and backing it up preserves the symlink itself rather than
#    its resolved content. Tested at the classify/_backup_file level directly
#    rather than through the interactive confirm prompt, which needs a real
#    controlling TTY that a unit-test harness may not have.
link_target="${HOME}/.config/app/f5"
mkdir -p "$(dirname "$link_target")"
real_file="${HOME}/elsewhere"
echo "symlinked-content" >"$real_file"
ln -s "$real_file" "$link_target"

[[ $(commit::classify "$link_target") == unmanaged ]] || fail "symlink was not classified unmanaged"

commit::_backup_file "$link_target" "${STATE_DIR}/backups/${TRANSACTION_ID}"
[[ -L $_BACKUP_PATH ]] || fail "backup did not preserve the symlink itself"
[[ $_ORIG_SUM == "symlink:${real_file}" ]] || fail "backup did not record the symlink's original target"
echo "PASS: symlink classified unmanaged and backed up as a symlink"

echo "ALL PASS"
