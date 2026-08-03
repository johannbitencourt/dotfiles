#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

fail() {
	echo "FAIL: $*"
	exit 1
}

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
GIT_ID=(-c user.email=test@test.local -c user.name=test)

# A real `git clone` of this repo right now would only include *committed*
# history, which predates scripts/dotctl/install/apply.sh entirely (all
# currently untracked). So the scratch "local checkout" is a full copy of
# the working tree with a fresh throwaway history on top — since
# install/apply.sh sits right next to scripts/dotctl there, dotctl's own
# existing bootstrap resolves DOTFILES_ROOT to the scratch dir automatically.

# 0. A checkout with no remote configured at all -> "no origin/<branch>",
#    exit 0, not an error (a local-only branch isn't a broken tool).
lonely="${WORKDIR}/lonely"
cp -a "${DOTFILES_ROOT}/." "$lonely"
rm -rf "${lonely}/.git"
git -C "$lonely" init -q -b hyprland
git -C "$lonely" add -A
git -C "$lonely" "${GIT_ID[@]}" commit -q -m initial
output=$("${lonely}/scripts/dotctl" update config --non-interactive 2>&1) && rc=0 || rc=$?
[[ $rc -eq 0 ]] || fail "no-remote case exited nonzero: ${rc} (output: ${output})"
echo "$output" | grep -qi "no 'origin' remote" || fail "no-remote case did not warn about a missing origin remote: ${output}"
echo "PASS: no 'origin' remote configured warns and exits 0"

# Build checkout + bare "origin" + a "contributor" clone that pushes new
# commits, to simulate a real incoming update without any network access.
checkout="${WORKDIR}/checkout"
cp -a "${DOTFILES_ROOT}/." "$checkout"
rm -rf "${checkout}/.git"
git -C "$checkout" init -q -b hyprland
git -C "$checkout" add -A
git -C "$checkout" "${GIT_ID[@]}" commit -q -m initial

origin="${WORKDIR}/origin.git"
git init -q --bare -b hyprland "$origin"
git -C "$checkout" remote add origin "$origin"
git -C "$checkout" push -q -u origin hyprland

# 1. Freshly pushed -> local HEAD already equals origin/<branch> -> "already up to date".
output=$("${checkout}/scripts/dotctl" update config --non-interactive 2>&1) || fail "update config failed right after push: ${output}"
echo "$output" | grep -qi "already up to date" || fail "did not report already up to date right after push: ${output}"
echo "PASS: already up to date when local HEAD equals origin/<branch>"

# 2. A "contributor" pushes a new commit -> --dry-run shows it but changes nothing.
contributor="${WORKDIR}/contributor"
git clone -q "$origin" "$contributor"
git -C "$contributor" checkout -q hyprland
echo "incoming change" >>"${contributor}/README.md"
git -C "$contributor" add -A
git -C "$contributor" "${GIT_ID[@]}" commit -q -m "incoming change"
git -C "$contributor" push -q origin hyprland

before_head=$(git -C "$checkout" rev-parse HEAD)
output=$("${checkout}/scripts/dotctl" update config --dry-run --non-interactive 2>&1) || fail "--dry-run run failed: ${output}"
after_head=$(git -C "$checkout" rev-parse HEAD)
[[ $before_head == "$after_head" ]] || fail "--dry-run moved the checkout's HEAD"
echo "$output" | grep -qi "incoming change" || fail "--dry-run did not show the incoming commit: ${output}"
echo "PASS: --dry-run shows the incoming commit, moves nothing"

# 3. A real (non-dry-run) update: fast-forwards the checkout AND applies
#    into a scratch \$HOME (never the real one).
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$WORKDIR" "$FAKE_HOME"' EXIT
# `find` on a not-yet-existing .config exits 1 even though `wc -l` still
# prints 0 — under pipefail the pipeline's own status is 1, which would
# trip `set -e` on this bare assignment. FAKE_HOME is brand new here, so
# .config genuinely doesn't exist yet; guard with `|| true`.
before_config_count=$(find "${FAKE_HOME}/.config" -type f 2>/dev/null | wc -l) || true
HOME="$FAKE_HOME" "${checkout}/scripts/dotctl" update config --non-interactive >/dev/null 2>&1 ||
	fail "real update config run failed"
after_head=$(git -C "$checkout" rev-parse HEAD)
remote_head=$(git -C "$checkout" rev-parse origin/hyprland)
[[ $after_head == "$remote_head" ]] || fail "checkout did not fast-forward to origin/hyprland"
after_config_count=$(find "${FAKE_HOME}/.config" -type f 2>/dev/null | wc -l) || true
[[ $after_config_count -gt $before_config_count ]] || fail "apply::commit_config did not commit anything into the scratch \$HOME"
echo "PASS: real update fast-forwards the checkout and applies into a scratch \$HOME"

# 4. Diverged: a local-only commit in checkout, plus another contributor
#    push to origin -> refuses, never forces anything.
echo "local-only change" >>"${checkout}/README.md"
git -C "$checkout" add -A
git -C "$checkout" "${GIT_ID[@]}" commit -q -m "local only"

echo "another incoming change" >>"${contributor}/README.md"
git -C "$contributor" add -A
git -C "$contributor" "${GIT_ID[@]}" commit -q -m "another incoming change"
git -C "$contributor" push -q origin hyprland

before_head=$(git -C "$checkout" rev-parse HEAD)
if "${checkout}/scripts/dotctl" update config --non-interactive >/tmp/update-diverged.log 2>&1; then
	fail "update config did not refuse a diverged branch"
fi
after_head=$(git -C "$checkout" rev-parse HEAD)
[[ $before_head == "$after_head" ]] || fail "a diverged update still moved the checkout's HEAD"
grep -qi "diverged" /tmp/update-diverged.log || fail "refusal did not mention divergence: $(cat /tmp/update-diverged.log)"
echo "PASS: a diverged branch refuses and moves nothing"

# 5. Dirty working tree refuses before even fetching.
echo "uncommitted" >>"${checkout}/README.md"
if "${checkout}/scripts/dotctl" update config --non-interactive >/tmp/update-dirty.log 2>&1; then
	fail "update config did not refuse a dirty working tree"
fi
grep -qi "not clean" /tmp/update-dirty.log || fail "refusal did not mention a dirty tree: $(cat /tmp/update-dirty.log)"
echo "PASS: a dirty working tree refuses"

echo "ALL PASS"
