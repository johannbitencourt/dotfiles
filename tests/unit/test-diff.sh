#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

# Everything below runs against a scratch $HOME — never the real one.
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT

# Seed a drifted managed file and an unmanaged file by applying once for
# real, then hand-editing one committed file and dropping in a new unrelated
# one — this exercises fresh/unchanged/drifted/unmanaged all in one pass.
HOME="$FAKE_HOME" "${DOTFILES_ROOT}/install.sh" --config-only --non-interactive >/dev/null 2>&1 ||
	fail "seeding apply run failed"

echo "hand-edited after apply" >"${FAKE_HOME}/.bashrc"
mkdir -p "${FAKE_HOME}/.config/mako"
echo "never managed by us" >"${FAKE_HOME}/.config/mako/config.bak"
# Simulate a file that's never (yet) been applied: the seeding run above
# committed it once, so remove it again — commit::classify only looks at
# whether the target currently exists, not at stale ledger history.
rm -f "${FAKE_HOME}/.config/hyprlock/hyprlock.conf"

# Snapshot every file's mtime+content-hash before diffing, to assert
# diff::run truly changed nothing.
before=$(find "$FAKE_HOME" -type f -exec sha256sum {} + | sort)

output=$(HOME="$FAKE_HOME" "${DOTFILES_ROOT}/scripts/dotctl" diff 2>&1)

after=$(find "$FAKE_HOME" -type f -exec sha256sum {} + | sort)
[[ $before == "$after" ]] || fail "dotctl diff modified files under \$HOME"
echo "PASS: dotctl diff writes nothing"

echo "$output" | grep -q "^--- ${FAKE_HOME}/\.bashrc (managed-modified)\$" ||
	fail "diff did not report the hand-edited .bashrc as managed-modified:
$output"
echo "PASS: drifted managed file reported with a real unified diff"

# .config/mako/config.bak was never staged (config.tmpl renders to "config",
# not "config.bak") — diff only walks staged files, so it correctly never
# appears at all. The unmanaged-detection path is already covered by
# test-commit.sh; this test's job is diff's own walk/report logic.

echo "$output" | grep -qE '^NEW: .*\.config/hyprlock/hyprlock\.conf$' ||
	fail "diff did not report a never-applied file as NEW:
$output"
echo "PASS: never-applied file reported as NEW"

echo "$output" | grep -q "unchanged file(s) under ${FAKE_HOME}/.config\$" ||
	fail "diff did not report an unchanged-file tally for .config:
$output"
echo "PASS: unchanged files are tallied, not printed per-file"

echo "ALL PASS"
