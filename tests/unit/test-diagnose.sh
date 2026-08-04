#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

# diagnose::run derives its host name via `hostname -s`, which isn't
# affected by overriding $HOME — the local override path must match this
# real machine's actual hostname for the seeded fixture to be picked up.
HOST_NAME=$(hostname -s 2>/dev/null || printf '%s' arch)

FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT

# Seed the one local/untracked file diagnose redacts: one secret-shaped
# line, one ordinary preference line.
mkdir -p "${FAKE_HOME}/.config/dotfiles/hosts"
cat >"${FAKE_HOME}/.config/dotfiles/hosts/${HOST_NAME}.local.conf" <<'EOF'
API_KEY=abcdefghijklmnop123456
HYPR_GAPS_IN=8
EOF

# Seed a fake backup transaction whose *body* (not its id) contains a
# planted secret-shaped string — diagnose must list the transaction id in
# transactions.txt but never touch the backup file's content at all.
mkdir -p "${FAKE_HOME}/.local/state/dotfiles/backups/20260101T000000Z-1/home/.config/app"
printf 'PLANTED-BACKUP-BODY-SECRET-XYZ' >"${FAKE_HOME}/.local/state/dotfiles/backups/20260101T000000Z-1/home/.config/app/f"
printf 'x\ty\torig\tnew\treplace-unmanaged\n' >"${FAKE_HOME}/.local/state/dotfiles/backups/20260101T000000Z-1/manifest.tsv"

HOME="$FAKE_HOME" "${DOTFILES_ROOT}/scripts/dotctl" diagnose >/dev/null 2>&1 ||
	fail "dotctl diagnose failed"

bundle=$(find "${FAKE_HOME}/.local/share/dotfiles/diagnostics" -name '*.tar.gz')
[[ -n $bundle ]] || fail "no bundle was written"
[[ $(printf '%s\n' "$bundle" | wc -l) -eq 1 ]] || fail "expected exactly one bundle, found: ${bundle}"
echo "PASS: diagnose writes exactly one tar.gz bundle"

extracted=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME" "$extracted"' EXIT
tar -xzf "$bundle" -C "$extracted"

jq empty "${extracted}/doctor.json" || fail "doctor.json in the bundle is not valid JSON"
echo "PASS: bundle's doctor.json is valid JSON"

redacted="${extracted}/hosts/${HOST_NAME}.local.conf.redacted"
[[ -f $redacted ]] || fail "redacted local override file is missing from the bundle"
grep -qx "HYPR_GAPS_IN=8" "$redacted" || fail "ordinary preference line was altered by redaction: $(cat "$redacted")"
grep -q "^API_KEY=<redacted>$" "$redacted" || fail "secret-shaped line was not redacted: $(cat "$redacted")"
echo "PASS: ordinary line kept verbatim, secret-shaped line redacted"

# The real secret value must never appear ANYWHERE in the extracted tree,
# not just be absent from the one file we expect to redact it.
if grep -rq "abcdefghijklmnop123456" "$extracted"; then
	fail "the planted secret value leaked into the bundle somewhere"
fi
echo "PASS: the planted secret value appears nowhere in the extracted bundle"

# Backup file *bodies* must never be included — only transaction ids.
if grep -rq "PLANTED-BACKUP-BODY-SECRET-XYZ" "$extracted"; then
	fail "a backup file's body leaked into the bundle"
fi
grep -qx "20260101T000000Z-1" "${extracted}/transactions.txt" || fail "transaction id missing from transactions.txt"
echo "PASS: backup file bodies are never included; only the transaction id is"

echo "ALL PASS"
