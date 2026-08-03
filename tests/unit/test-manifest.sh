#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/scripts/lib/cleanup.sh"
source "${DOTFILES_ROOT}/install/manifest.sh"

fail() {
	echo "FAIL: $*"
	exit 1
}

STAGE_DIR=$(mktemp -d)
STATE_DIR=$(mktemp -d)
cleanup::register "$STAGE_DIR"
cleanup::register "$STATE_DIR"

manifest::init
manifest::add_fragment '{"schema_version":1,"transaction_id":"test-txn"}'
manifest::add_fragment '{"host_profile":"arch"}'
manifest::add_managed_file "/home/x/.bashrc" "abc123" "install"
manifest::add_managed_file "/home/x/.config/hypr/hyprland.conf" "def456" "update"
manifest::write

out="${STATE_DIR}/install.json"
[[ -f $out ]] || fail "install.json was not written"

jq empty "$out" || fail "install.json is not valid JSON"
echo "PASS: install.json is valid JSON"

[[ $(jq -r '.schema_version' "$out") == 1 ]] || fail "schema_version missing from merged fragments"
[[ $(jq -r '.host_profile' "$out") == arch ]] || fail "host_profile missing from merged fragments"
echo "PASS: disjoint fragments merge into one object"

[[ $(jq -r '.managed_files | length' "$out") -eq 2 ]] || fail "managed_files does not have 2 entries"
[[ $(jq -r '.managed_files[0].checksum' "$out") == "sha256:abc123" ]] || fail "managed_files checksum not prefixed with sha256:"
echo "PASS: managed_files accumulates incrementally with sha256: prefix"

# A run that adds no fragments at all must still produce a valid (empty)
# manifest rather than erroring on missing glob matches.
STATE_DIR2=$(mktemp -d)
cleanup::register "$STATE_DIR2"
STAGE_DIR="$STATE_DIR2/stage"
manifest::init
STATE_DIR="$STATE_DIR2"
manifest::write
jq empty "${STATE_DIR2}/install.json" || fail "manifest with zero fragments is not valid JSON"
[[ $(jq -r '.managed_files | length' "${STATE_DIR2}/install.json") -eq 0 ]] || fail "empty manifest should have an empty managed_files array"
echo "PASS: zero-fragment manifest is still valid JSON with an empty managed_files array"

echo "ALL PASS"
