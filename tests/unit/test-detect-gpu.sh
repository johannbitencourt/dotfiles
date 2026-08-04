#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

source "${DOTFILES_ROOT}/scripts/lib/log.sh"
source "${DOTFILES_ROOT}/install/detect.sh"

# 1. Regression: no lspci output matches NVIDIA/AMD/Intel (a VM's
#    virtio/QXL/Cirrus display, or any other vendor string) — every grep
#    in the pipeline legitimately finds nothing. Under pipefail, that used
#    to kill the whole script SILENTLY via the bare `vendors=$(...)`
#    assignment, with no error text at all — exactly the real symptom hit
#    on a real machine (install.sh stopping dead right after "preflight:
#    all checks passed", no further output). Called directly, not inside
#    $(...) — a nameref's writes would be lost in a subshell, and a
#    silent-death regression should kill this whole test script anyway,
#    which is itself a clear enough failure signal.
lspci() { printf '00:02.0 "Display controller" "Red Hat, Inc." "Virtio GPU"\n'; }
declare -A facts=()
detect::gpu facts
[[ ${facts[GPU_VENDOR]} == unknown ]] || fail "expected GPU_VENDOR=unknown, got: ${facts[GPU_VENDOR]:-<unset>}"
[[ ${facts[GPU_MODE]} == unknown ]] || fail "expected GPU_MODE=unknown, got: ${facts[GPU_MODE]:-<unset>}"
echo "PASS: an unmatched GPU vendor (e.g. a VM display) degrades to unknown/unknown, not a silent death"

# 2. A single recognized vendor.
lspci() { printf '00:02.0 "VGA compatible controller" "NVIDIA Corporation" "Some GPU"\n'; }
declare -A facts2=()
detect::gpu facts2
[[ ${facts2[GPU_VENDOR]} == nvidia ]] || fail "expected GPU_VENDOR=nvidia, got: ${facts2[GPU_VENDOR]:-<unset>}"
[[ ${facts2[GPU_MODE]} == single ]] || fail "expected GPU_MODE=single, got: ${facts2[GPU_MODE]:-<unset>}"
echo "PASS: a single recognized GPU vendor is detected correctly"

# 3. Two recognized vendors (hybrid).
lspci() {
	printf '00:02.0 "VGA compatible controller" "Intel Corporation" "iGPU"\n'
	printf '01:00.0 "3D controller" "NVIDIA Corporation" "dGPU"\n'
}
declare -A facts3=()
detect::gpu facts3
[[ ${facts3[GPU_MODE]} == hybrid ]] || fail "expected GPU_MODE=hybrid, got: ${facts3[GPU_MODE]:-<unset>}"
echo "PASS: two recognized GPU vendors are detected as hybrid"

# 4. lspci itself produces nothing at all (unreadable/empty output).
lspci() { :; }
declare -A facts4=()
detect::gpu facts4
[[ ${facts4[GPU_VENDOR]} == unknown ]] || fail "expected GPU_VENDOR=unknown for empty lspci output, got: ${facts4[GPU_VENDOR]:-<unset>}"
echo "PASS: empty lspci output also degrades to unknown, not a silent death"

# 5. The real lspci on this actual host — read-only, safe to run for real.
unset -f lspci
declare -A facts5=()
detect::gpu facts5
[[ -n ${facts5[GPU_VENDOR]:-} ]] || fail "detect::gpu set no GPU_VENDOR at all against the real host"
echo "PASS: detect::gpu runs cleanly against this real host (GPU_VENDOR=${facts5[GPU_VENDOR]})"

echo "ALL PASS"
