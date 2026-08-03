#!/usr/bin/env bash
# Read-only system health checks. Every check function reports a verdict
# and keeps going — none of them may call log::die, unlike install.sh's
# fail-fast phases. That's why these are separate functions from
# detect.sh/preflight.sh rather than reusing those directly: this file
# duplicates the *essence* of a few of their checks in a non-dying style,
# which is a deliberate, small amount of duplication in service of doctor's
# different contract (report everything, abort nothing).
#
# Session-gated checks (Waybar/Mako/hypridle/swaybg/portals/D-Bus/GPU-in-use)
# are added in a later milestone, once hypr-session writes a liveness
# marker doctor can check for.

declare -g DOCTOR_RESULTS_FILE=""

doctor::_record() {
	local check=$1 status=$2 detail=$3
	jq -nc --arg check "$check" --arg status "$status" --arg detail "$detail" \
		'{check: $check, status: $status, detail: $detail}' >>"$DOCTOR_RESULTS_FILE"
}

# doctor::_detect_host — minimal, non-dying GPU detection (detect::gpu
# itself never dies). Deliberately skips detect::distro/plan::resolve_host:
# distro detection is doctor's own check below, and a full host-profile
# resolution isn't needed just to report GPU_VENDOR.
doctor::_detect_host() {
	local -A facts=()
	detect::gpu facts
	HOST[GPU_VENDOR]=${facts[GPU_VENDOR]}
	HOST[GPU_MODE]=${facts[GPU_MODE]}
}

doctor::_check_distro() {
	if ! adapter_detect; then
		doctor::_record distro FAIL "unsupported distribution (only Arch is supported)"
		return
	fi
	local rc
	adapter_check_hyprland_version && rc=0 || rc=$?
	case $rc in
	0) doctor::_record distro PASS "arch, hyprland ${ADAPTER_CANDIDATE_VERSION} >= ${ADAPTER_MIN_VERSION}" ;;
	2) doctor::_record distro WARN "could not query hyprland candidate version (pacman unreachable?)" ;;
	*) doctor::_record distro FAIL "hyprland candidate ${ADAPTER_CANDIDATE_VERSION} is older than required ${ADAPTER_MIN_VERSION}" ;;
	esac
}

doctor::_check_kernel() {
	doctor::_record kernel PASS "$(uname -r)"
}

doctor::_check_disk_space() {
	local avail_kb avail_mb
	avail_kb=$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}') || avail_kb=0
	[[ $avail_kb =~ ^[0-9]+$ ]] || avail_kb=0
	avail_mb=$((avail_kb / 1024))

	if ((avail_mb < 100)); then
		doctor::_record disk-space FAIL "${avail_mb}MiB free on \$HOME's filesystem"
	elif ((avail_mb < 1024)); then
		doctor::_record disk-space WARN "${avail_mb}MiB free on \$HOME's filesystem"
	else
		doctor::_record disk-space PASS "${avail_mb}MiB free on \$HOME's filesystem"
	fi
}

doctor::_check_pacman_lock() {
	if [[ -e /var/lib/pacman/db.lck ]]; then
		doctor::_record pacman-lock WARN "db.lck present — another pacman operation may be running or crashed"
	else
		doctor::_record pacman-lock PASS "no pacman lock file present"
	fi
}

doctor::_check_required_commands() {
	local cmd
	local -a missing=()
	for cmd in "${PREFLIGHT_REQUIRED_COMMANDS[@]}"; do
		command -v "$cmd" &>/dev/null || missing+=("$cmd")
	done
	if [[ ${#missing[@]} -eq 0 ]]; then
		doctor::_record required-commands PASS "all present"
	else
		doctor::_record required-commands FAIL "missing: ${missing[*]}"
	fi
}

doctor::_check_managed_drift() {
	local ledger="${STATE_DIR}/managed-checksums.tsv"
	if [[ ! -s $ledger ]]; then
		doctor::_record managed-drift SKIP "no managed files recorded yet"
		return
	fi

	local path _sum
	local -a drifted=()
	while IFS=$'\t' read -r path _sum; do
		[[ -z $path ]] && continue
		[[ $(commit::classify "$path") == managed-modified ]] && drifted+=("$path")
	done <"$ledger"

	if [[ ${#drifted[@]} -eq 0 ]]; then
		doctor::_record managed-drift PASS "no drift detected"
	else
		doctor::_record managed-drift WARN "drifted: ${drifted[*]}"
	fi
}

doctor::_check_incomplete_transaction() {
	local marker="${STATE_DIR}/active-transaction"
	if [[ -f $marker ]]; then
		local txn
		txn=$(cat "$marker")
		doctor::_record incomplete-transaction FAIL "transaction ${txn} did not complete — run: dotctl restore-config --transaction ${txn}"
	else
		doctor::_record incomplete-transaction PASS "no incomplete transaction"
	fi
}

doctor::_check_systemd_units_present() {
	local unit_dir="${HOME}/.config/systemd/user"
	local -a expected=(dotfiles-graphical-session.target waybar.service mako.service hypridle.service swaybg.service)
	local u
	local -a missing=()
	for u in "${expected[@]}"; do
		[[ -f "${unit_dir}/${u}" ]] || missing+=("$u")
	done
	if [[ ${#missing[@]} -eq 0 ]]; then
		doctor::_record systemd-units PASS "all 5 unit files present"
	else
		doctor::_record systemd-units FAIL "missing: ${missing[*]}"
	fi
}

# doctor::_check_hyprland_config — verifies the REAL, live
# ~/.config/hypr/conf.d, not staged output. Known limitation: on a host
# where another project (e.g. Omarchy) owns ~/.config/hypr, this validates
# *that* config, not this project's — there's no way yet to distinguish
# "valid" from "valid but not ours."
doctor::_check_hyprland_config() {
	local conf_d="${HOME}/.config/hypr/conf.d"
	if [[ ! -d $conf_d ]]; then
		doctor::_record hyprland-config SKIP "${conf_d} does not exist yet"
		return
	fi

	local flattened
	flattened=$(mktemp)
	cleanup::register "$flattened"
	cat "${conf_d}"/*.conf >"$flattened" 2>/dev/null || true

	local output
	if output=$(Hyprland --config "$flattened" --verify-config 2>&1); then
		doctor::_record hyprland-config PASS "config parses cleanly"
	else
		doctor::_record hyprland-config FAIL "$(printf '%s' "$output" | tail -1)"
	fi
}

doctor::_check_networkmanager() {
	if systemctl is-active --quiet NetworkManager 2>/dev/null; then
		doctor::_record networkmanager PASS "active"
	else
		doctor::_record networkmanager FAIL "not active"
	fi
}

doctor::_check_pipewire() {
	local pw=inactive wp=inactive
	systemctl --user is-active --quiet pipewire 2>/dev/null && pw=active
	systemctl --user is-active --quiet wireplumber 2>/dev/null && wp=active

	if [[ $pw == active && $wp == active ]]; then
		doctor::_record audio PASS "pipewire+wireplumber active"
	elif [[ $pw == active || $wp == active ]]; then
		doctor::_record audio WARN "pipewire=${pw} wireplumber=${wp}"
	else
		doctor::_record audio FAIL "pipewire=${pw} wireplumber=${wp}"
	fi
}

doctor::_check_gpu_driver() {
	local vendor=${HOST[GPU_VENDOR]:-unknown}
	if [[ $vendor != nvidia ]]; then
		doctor::_record gpu-driver SKIP "GPU_VENDOR=${vendor} (only nvidia is checked so far)"
		return
	fi

	local module_loaded=0 pkg_present=0
	lsmod | grep -q '^nvidia ' && module_loaded=1
	pacman -Q nvidia-utils &>/dev/null && pkg_present=1

	if ((module_loaded == 1 && pkg_present == 1)); then
		doctor::_record gpu-driver PASS "nvidia module loaded, nvidia-utils installed"
	elif ((pkg_present == 1)); then
		doctor::_record gpu-driver WARN "nvidia-utils installed but module not loaded (reboot required?)"
	else
		doctor::_record gpu-driver FAIL "nvidia-utils not installed"
	fi
}

# --- Session-gated checks below. All PENDING when this project's own
# Hyprland session isn't currently running (see session::marker_active in
# install/session.sh).

# doctor::_check_user_service <check-name> <unit>
doctor::_check_user_service() {
	local check=$1 unit=$2
	if ! session::marker_active; then
		doctor::_record "$check" PENDING "no dotfiles-hyprland session detected"
		return
	fi
	if systemctl --user is-active --quiet "$unit" 2>/dev/null; then
		doctor::_record "$check" PASS "${unit} active"
	else
		doctor::_record "$check" FAIL "${unit} not active"
	fi
}

doctor::_check_waybar() { doctor::_check_user_service waybar waybar.service; }
doctor::_check_mako() { doctor::_check_user_service mako mako.service; }
doctor::_check_hypridle() { doctor::_check_user_service hypridle hypridle.service; }
doctor::_check_swaybg() { doctor::_check_user_service swaybg swaybg.service; }

doctor::_check_portals() {
	if ! session::marker_active; then
		doctor::_record portals PENDING "no dotfiles-hyprland session detected"
		return
	fi
	if pgrep -x xdg-desktop-portal &>/dev/null; then
		doctor::_record portals PASS "xdg-desktop-portal running"
	else
		doctor::_record portals WARN "xdg-desktop-portal not running (it may be D-Bus-activated on demand)"
	fi
}

doctor::_check_polkit_agent() {
	if ! session::marker_active; then
		doctor::_record polkit-agent PENDING "no dotfiles-hyprland session detected"
		return
	fi
	if pgrep -x hyprpolkitagent &>/dev/null; then
		doctor::_record polkit-agent PASS "hyprpolkitagent running"
	else
		doctor::_record polkit-agent FAIL "hyprpolkitagent not running"
	fi
}

doctor::_check_dbus_env() {
	if ! session::marker_active; then
		doctor::_record dbus-env PENDING "no dotfiles-hyprland session detected"
		return
	fi
	if systemctl --user show-environment 2>/dev/null | grep -q '^WAYLAND_DISPLAY='; then
		doctor::_record dbus-env PASS "WAYLAND_DISPLAY propagated to the systemd/D-Bus activation environment"
	else
		doctor::_record dbus-env FAIL "WAYLAND_DISPLAY missing from systemd --user environment (exec-once's import-environment step may not have run)"
	fi
}

# doctor::_check_monitors — covers both "monitor outputs" and "GPU-in-use"
# from a single `hyprctl monitors` call, exactly as planned: a monitor
# actively reporting through hyprctl implies the GPU is rendering. A real
# Vulkan/EGL probe is out of scope here (that's the excluded gaming check).
# Reads HYPRLAND_INSTANCE_SIGNATURE from /proc/<marker-pid>/environ so this
# works even when dotctl itself isn't running inside that Hyprland session
# (e.g. invoked from a plain TTY or over SSH).
doctor::_check_monitors() {
	if ! session::marker_active; then
		doctor::_record monitors PENDING "no dotfiles-hyprland session detected"
		return
	fi
	local sig out count
	sig=$(tr '\0' '\n' <"/proc/${SESSION_MARKER_PID}/environ" 2>/dev/null | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p')
	if [[ -z $sig ]]; then
		doctor::_record monitors WARN "HYPRLAND_INSTANCE_SIGNATURE not found for the marked session"
		return
	fi
	if ! out=$(hyprctl -i "$sig" monitors 2>/dev/null); then
		doctor::_record monitors WARN "hyprctl monitors failed for the marked session"
		return
	fi
	count=$(printf '%s\n' "$out" | grep -c '^Monitor ')
	if ((count > 0)); then
		doctor::_record monitors PASS "${count} monitor(s) reporting via hyprctl (GPU actively rendering)"
	else
		doctor::_record monitors WARN "hyprctl reachable but reported zero monitors"
	fi
}

doctor::_print_human() {
	local status check detail
	while IFS=$'\t' read -r status check detail; do
		printf '%-7s %-24s %s\n' "$status" "$check" "$detail"
	done < <(jq -r '[.status, .check, .detail] | @tsv' "$DOCTOR_RESULTS_FILE")
}

# doctor::run <json-mode: 0|1>
doctor::run() {
	local json_mode=$1
	DOCTOR_RESULTS_FILE=$(mktemp)
	cleanup::register "$DOCTOR_RESULTS_FILE"

	apply::ensure_state_dir
	doctor::_detect_host

	doctor::_check_distro
	doctor::_check_kernel
	doctor::_check_disk_space
	doctor::_check_pacman_lock
	doctor::_check_required_commands
	doctor::_check_managed_drift
	doctor::_check_incomplete_transaction
	doctor::_check_systemd_units_present
	doctor::_check_hyprland_config
	doctor::_check_networkmanager
	doctor::_check_pipewire
	doctor::_check_gpu_driver
	doctor::_check_waybar
	doctor::_check_mako
	doctor::_check_hypridle
	doctor::_check_swaybg
	doctor::_check_portals
	doctor::_check_polkit_agent
	doctor::_check_dbus_env
	doctor::_check_monitors

	if [[ $json_mode -eq 1 ]]; then
		jq -sc '.' "$DOCTOR_RESULTS_FILE"
	else
		doctor::_print_human
	fi
}
