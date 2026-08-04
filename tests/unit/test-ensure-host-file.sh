#!/usr/bin/env bash
set -Eeuo pipefail

REAL_DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

source "${REAL_DOTFILES_ROOT}/scripts/lib/log.sh"
source "${REAL_DOTFILES_ROOT}/scripts/lib/kv-parser.sh"
source "${REAL_DOTFILES_ROOT}/install/profile.sh"
source "${REAL_DOTFILES_ROOT}/install/plan.sh"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "${SCRATCH}/hosts" "${SCRATCH}/preferences"
touch "${SCRATCH}/preferences/defaults.conf" # plan::resolve_host reads this too
DOTFILES_ROOT=$SCRATCH
OPT_DRY_RUN=0

# 1. Missing host file: created, with every expected key, returns 0.
plan::_ensure_host_file testhost && rc=0 || rc=$?
[[ $rc -eq 0 ]] || fail "expected rc=0 when creating a missing host file, got ${rc}"
host_file="${SCRATCH}/hosts/testhost.conf"
[[ -f $host_file ]] || fail "host file was not created"
declare -A fields=()
kv_parse_file "$host_file" fields
for key in HOST_TYPE SESSION_MODE PRIMARY_OUTPUT INTERNAL_OUTPUT INTERNAL_ENABLED KEYBOARD_LAYOUT; do
	[[ -v fields[$key] ]] || fail "generated host file is missing key: ${key}"
done
[[ ${fields[SESSION_MODE]} == tty ]] || fail "expected SESSION_MODE=tty, got: ${fields[SESSION_MODE]}"
[[ ${fields[KEYBOARD_LAYOUT]} == us ]] || fail "expected KEYBOARD_LAYOUT=us, got: ${fields[KEYBOARD_LAYOUT]}"
echo "PASS: a missing host file is created with every expected key"

# 2. HOST_TYPE matches this real test machine's actual battery presence —
#    real, read-only check, safe to run for real (same posture as
#    adapter_detect's real-/etc/os-release check).
expected_type=desktop
compgen -G '/sys/class/power_supply/BAT*' >/dev/null && expected_type=laptop
[[ ${fields[HOST_TYPE]} == "$expected_type" ]] ||
	fail "expected HOST_TYPE=${expected_type} (real battery presence), got: ${fields[HOST_TYPE]}"
echo "PASS: HOST_TYPE reflects this real machine's actual battery presence"

# 3. The generated file round-trips through plan::resolve_host without
#    dying (proves it's not just parseable in isolation, but actually
#    satisfies the real consumer).
declare -gA DETECTED=()
declare -gA CLI_PREFERENCES=()
HOME="$SCRATCH"
plan::resolve_host testhost >/dev/null 2>&1 || fail "plan::resolve_host died on the auto-generated host file"
echo "PASS: the generated host file satisfies plan::resolve_host"

# 4. An already-existing host file is never touched: content and mtime
#    unchanged, returns 1.
before_content=$(cat "$host_file")
before_mtime=$(stat -c %Y "$host_file")
sleep 1
plan::_ensure_host_file testhost && rc=0 || rc=$?
[[ $rc -eq 1 ]] || fail "expected rc=1 when a host file already exists, got ${rc}"
after_content=$(cat "$host_file")
after_mtime=$(stat -c %Y "$host_file")
[[ $before_content == "$after_content" ]] || fail "an existing host file's content was changed"
[[ $before_mtime -eq $after_mtime ]] || fail "an existing host file's mtime was changed (it was rewritten)"
echo "PASS: an already-existing host file is never touched"

# 5. --dry-run: no file is written for a genuinely missing host, and the
#    function reports rc=1 (nothing was actually created).
rm -f "${SCRATCH}/hosts/dryhost.conf"
OPT_DRY_RUN=1
plan::_ensure_host_file dryhost && rc=0 || rc=$?
[[ $rc -eq 1 ]] || fail "expected rc=1 under --dry-run (nothing created), got ${rc}"
[[ ! -f "${SCRATCH}/hosts/dryhost.conf" ]] || fail "--dry-run wrote a host file — dry-run must change nothing"
echo "PASS: --dry-run reports what it would do without writing anything"
OPT_DRY_RUN=0

echo "ALL PASS"
