#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/scripts/lib/kv-parser.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# valid file: comments, blank lines, whitespace, values with special chars
cat >"${tmp}/valid.conf" <<'EOF'
# a comment
FOO=bar

  BAR=baz
BAZ_1=hello world
EOF

declare -A out=()
kv_parse_file "${tmp}/valid.conf" out
[[ ${out[FOO]} == bar ]] || { echo "FAIL: FOO"; exit 1; }
[[ ${out[BAR]} == baz ]] || { echo "FAIL: BAR"; exit 1; }
[[ ${out[BAZ_1]} == "hello world" ]] || { echo "FAIL: BAZ_1"; exit 1; }
echo "PASS: valid KEY=VALUE, comments, blank lines, whitespace"

# kv_parse_file hard-exits (log::die) on bad input by design, so each
# negative case runs in a subshell — otherwise the exit would kill this
# test script instead of just failing the assertion.

# invalid file: lowercase key must be rejected
cat >"${tmp}/invalid.conf" <<'EOF'
foo=bar
EOF
if (declare -A out2=() && kv_parse_file "${tmp}/invalid.conf" out2) 2>/dev/null; then
	echo "FAIL: lowercase key was accepted"
	exit 1
fi
echo "PASS: lowercase key rejected"

# invalid file: line with no '=' must be rejected
cat >"${tmp}/invalid2.conf" <<'EOF'
NOT_A_KV_LINE
EOF
if (declare -A out3=() && kv_parse_file "${tmp}/invalid2.conf" out3) 2>/dev/null; then
	echo "FAIL: line without '=' was accepted"
	exit 1
fi
echo "PASS: line without '=' rejected"

# missing file must be rejected
if (declare -A out4=() && kv_parse_file "${tmp}/does-not-exist.conf" out4) 2>/dev/null; then
	echo "FAIL: missing file was accepted"
	exit 1
fi
echo "PASS: missing file rejected"

echo "ALL PASS"
