#!/usr/bin/env bash
# Tool/workflow profiles (HLD section 9.8) — named, installable bundles of
# optional capabilities (e.g. "dev"). NOT the same concept as this
# project's --host <name> host profile (hosts/<name>.conf, a single
# machine's own hardware/session identity) — that sense already owns the
# bare word "profile" everywhere else in this codebase (install.json's
# host_profile key, --host's help text). Every user-facing string in this
# file says "profile" only for the tool/workflow sense, since this file
# owns none of the other.
#
# Capability naming: this codebase's existing capabilities
# (packages/capabilities.conf) are all bare tool names ("hyprland", "jq",
# "git"), never HLD's purpose-prefixed example style ("editor-neovim",
# "json-tool-jq") — the prefixed style exists in HLD's example specifically
# for capabilities with a provider-style choice among alternatives, and the
# provider abstraction itself doesn't exist anywhere in this codebase yet
# (HLD 9.7). Profile capabilities below follow the existing bare-name
# convention; "jq" in profiles/dev.conf is a deliberate reuse of the
# existing core "jq" capability, not a new "json-tool-jq".
#
# Profile-owned capabilities (packages/mappings/arch.conf's "Profile-owned
# capabilities" section) are NEVER added to packages/capabilities.conf:
# that file is read unconditionally by install.sh's core-desktop phase, so
# adding a profile-only tool there would install it for every user on
# every plain './install.sh' run, regardless of whether any profile
# requested it.
#
# Fields kept deliberately minimal: PROFILE_ID, PROFILE_DESCRIPTION,
# REQUIRED_CAPABILITIES, PREFERENCE_DEFAULTS. HLD 9.8 also lists optional
# capabilities, recommended/conflicting profiles, and hardware constraints
# as profile metadata — dropped here (ponytail: "dev", the only profile
# this project ships, never sets any of them). Add back whichever one a
# real profile actually needs once that profile exists, not before.

# profile::_split_list <comma-joined-value>
# Splits REQUIRED_CAPABILITIES into one item per line. Empty input prints
# nothing (zero items, not one empty item) — kv_parse_file itself has no
# list support; this is the caller-side split.
profile::_split_list() {
	local value=$1
	[[ -z $value ]] && return 0
	local -a items=()
	IFS=',' read -ra items <<<"$value"
	printf '%s\n' "${items[@]}"
}

# profile::_split_preference_defaults <comma-joined-KEY=VALUE-pairs> <assoc-array-name>
# Same split idiom dotctl's own --preference flag already uses: split on
# the first '=' only, so a value itself containing '=' is preserved.
profile::_split_preference_defaults() {
	local value=$1
	local -n _pref_out_ref=$2
	[[ -z $value ]] && return 0
	local -a pairs=()
	IFS=',' read -ra pairs <<<"$value"
	local pair
	for pair in "${pairs[@]}"; do
		_pref_out_ref[${pair%%=*}]=${pair#*=}
	done
}

# profile::collect_preference_defaults <assoc-array-name>
# Populates the caller's associative array with the PREFERENCE_DEFAULTS of
# every currently-installed profile (per ${STATE_DIR}/profiles.json), read
# LIVE off each profile's current profiles/<id>.conf — not the profiles.json
# install-time snapshot — so an edited profile's preferences apply on every
# 'dotctl apply', the same way the host file itself is always re-read live,
# never snapshotted. No-op if profiles.json doesn't exist (every host that
# has never run 'dotctl profile install' behaves exactly as before this
# layer existed — regression-safe for every existing apply/diff/validate
# test). Two installed profiles setting the same key tie-break by sorted
# id — arbitrary but deterministic; untested against a real second profile
# since only "dev" ships this pass.
profile::collect_preference_defaults() {
	local -n out_ref=$1
	local profiles_file="${STATE_DIR:-}/profiles.json"
	[[ -f $profiles_file ]] || return 0

	local id conf
	while IFS= read -r id; do
		[[ -z $id ]] && continue
		conf="${DOTFILES_ROOT}/profiles/${id}.conf"
		[[ -f $conf ]] || continue
		local -A fields=()
		kv_parse_file "$conf" fields
		profile::_split_preference_defaults "${fields[PREFERENCE_DEFAULTS]:-}" out_ref
	done < <(jq -r '.profiles // {} | keys[]' "$profiles_file" 2>/dev/null | sort)
}

# profile::_load <id> <assoc-array-name>
profile::_load() {
	local id=$1
	local -n _load_out_ref=$2
	local conf="${DOTFILES_ROOT}/profiles/${id}.conf"
	[[ -f $conf ]] || log::die "profile: no such profile: ${id} (looked for ${conf})"
	kv_parse_file "$conf" _load_out_ref
}

# profile::_installed_ids — every currently-installed profile id, one per
# line, sorted. Empty output (not an error) if profiles.json doesn't exist
# or has no entries.
profile::_installed_ids() {
	local profiles_file="${STATE_DIR:-}/profiles.json"
	[[ -f $profiles_file ]] || return 0
	jq -r '.profiles // {} | keys[]' "$profiles_file" 2>/dev/null | sort
}

profile::_is_installed() {
	local id=$1
	profile::_installed_ids | grep -qx "$id"
}

# profile::_join_or_none <array-name> — "none" for an empty array, else a
# comma-space-joined list. bash's ${arr[*]:-none} can't do this (an empty
# array expands to an empty STRING, not unset, so that idiom never
# triggers the fallback).
profile::_join_or_none() {
	local -n _join_ref=$1
	if [[ ${#_join_ref[@]} -eq 0 ]]; then
		printf 'none'
		return
	fi
	local IFS=', '
	printf '%s' "${_join_ref[*]}"
}

# profile::_resolve_required <fields-array-name> <present-out-array-name> <missing-out-array-name>
# Resolves REQUIRED_CAPABILITIES to real packages and partitions them by
# whether each is already installed. Shared by profile::plan (preview) and
# profile::install (the same resolution, right before acting on it) — both
# had their own identical copy of this loop.
profile::_resolve_required() {
	local -n _res_fields_ref=$1
	local -n _res_present_ref=$2
	local -n _res_missing_ref=$3

	local -a required
	mapfile -t required < <(profile::_split_list "${_res_fields_ref[REQUIRED_CAPABILITIES]:-}")

	local cap pkg
	for cap in "${required[@]}"; do
		pkg=$(adapter_resolve_capability "$cap") || log::die "profile: capability unsupported by this adapter: ${cap}"
		if adapter_package_installed "$pkg"; then
			_res_present_ref+=("$pkg")
		else
			_res_missing_ref+=("$pkg")
		fi
	done
}

# profile::list — every available profile: id, installed y/n, required-
# capability count, description. Read-only.
profile::list() {
	apply::ensure_state_dir
	local -a installed
	mapfile -t installed < <(profile::_installed_ids)

	printf '%-10s %-11s %-6s %s\n' ID INSTALLED CAPS DESCRIPTION
	local f id status
	local -a caps
	for f in "${DOTFILES_ROOT}"/profiles/*.conf; do
		[[ -f $f ]] || continue
		local -A fields=()
		kv_parse_file "$f" fields
		id=${fields[PROFILE_ID]}
		status=no
		printf '%s\n' "${installed[@]}" | grep -qx "$id" && status=yes
		mapfile -t caps < <(profile::_split_list "${fields[REQUIRED_CAPABILITIES]:-}")
		printf '%-10s %-11s %-6s %s\n' "$id" "$status" "${#caps[@]}" "${fields[PROFILE_DESCRIPTION]:-}"
	done
}

# profile::show <id> — declared metadata + capabilities resolved to real
# package names for display + install status. Read-only.
profile::show() {
	apply::ensure_state_dir
	local id=$1
	local -A fields=()
	profile::_load "$id" fields

	local -a required
	mapfile -t required < <(profile::_split_list "${fields[REQUIRED_CAPABILITIES]:-}")
	local -A prefs=()
	profile::_split_preference_defaults "${fields[PREFERENCE_DEFAULTS]:-}" prefs

	local installed=no
	profile::_is_installed "$id" && installed=yes

	printf 'id                  : %s\n' "$id"
	printf 'description         : %s\n' "${fields[PROFILE_DESCRIPTION]:-}"
	printf 'installed           : %s\n' "$installed"

	printf 'required capabilities (%d):\n' "${#required[@]}"
	local cap pkg
	for cap in "${required[@]}"; do
		pkg=$(adapter_resolve_capability "$cap" 2>/dev/null) || pkg=unsupported
		printf '  - %-12s -> %s\n' "$cap" "$pkg"
	done

	if [[ ${#prefs[@]} -eq 0 ]]; then
		printf 'preference defaults : none\n'
	else
		printf 'preference defaults:\n'
		local k
		for k in "${!prefs[@]}"; do printf '  - %s=%s\n' "$k" "${prefs[$k]}"; done
	fi
}

# profile::plan <id> — preview of what 'profile install <id>' would do.
# Read-only: resolves capabilities and partitions present/missing without
# ever calling adapter_install_packages, and shows which PREFERENCE_DEFAULTS
# keys would actually change the currently-resolved HOST value.
profile::plan() {
	apply::ensure_state_dir
	local id=$1
	local -A fields=()
	profile::_load "$id" fields

	apply::detect_and_plan_host

	local -a present=() missing=()
	profile::_resolve_required fields present missing

	printf '\nProfile plan: %s\n' "$id"
	printf '  packages present (%d): %s\n' "${#present[@]}" "$(profile::_join_or_none present)"
	printf '  packages to install (%d):\n' "${#missing[@]}"
	local p
	for p in "${missing[@]}"; do printf '    - %s\n' "$p"; done

	local -A prefs=()
	profile::_split_preference_defaults "${fields[PREFERENCE_DEFAULTS]:-}" prefs
	printf '  preference changes:\n'
	local k
	for k in "${!prefs[@]}"; do
		if [[ ${HOST[$k]:-} == "${prefs[$k]}" ]]; then
			printf '    %s=%s (already this value)\n' "$k" "${prefs[$k]}"
		else
			printf '    %s: %s -> %s\n' "$k" "${HOST[$k]:-<unset>}" "${prefs[$k]}"
		fi
	done
	printf '\n'
}

# profile::_confirm <description>
# Dies under --non-interactive or on decline (cli::confirm_or_die's shared
# shape) — not uninstall::_confirm's proceed-under-non-interactive shape:
# uninstall's scope is fully known just from having invoked the command; a
# profile install/remove's real scope (which packages, how many orphan on
# remove) is only known after runtime resolution.
profile::_confirm() {
	local description=$1
	cli::confirm_or_die profile "$description" "Proceed?"
}

# profile::_array_to_json <array-name>
# printf '%s\n' "${arr[@]}" with a genuinely EMPTY array still executes its
# format string once (printf pads missing conversions with an empty string
# rather than running zero times), producing [""] instead of [] once piped
# through jq — guard explicitly rather than relying on printf to degrade
# gracefully to no output.
profile::_array_to_json() {
	local -n _arr_ref=$1
	if [[ ${#_arr_ref[@]} -eq 0 ]]; then
		printf '[]'
		return
	fi
	printf '%s\n' "${_arr_ref[@]}" | jq -R . | jq -sc .
}

# profile::_record_install <id> <required-array-name> <present-array-name>
#                           <installed-array-name> <prefs-assoc-array-name>
# Writes/overwrites the ${STATE_DIR}/profiles.json entry for <id>. Split
# out of profile::install so the recording logic (the actual "removal
# impact" attribution this whole feature exists for) is testable directly,
# without going through profile::_confirm's /dev/tty read — same reason
# update.sh's report-writing got its own function.
profile::_record_install() {
	local id=$1
	local -n _rec_required_ref=$2
	local -n _rec_present_ref=$3
	local -n _rec_installed_ref=$4
	local -n _rec_prefs_ref=$5

	local prefs_json
	prefs_json=$(
		local k
		for k in "${!_rec_prefs_ref[@]}"; do printf '%s\t%s\n' "$k" "${_rec_prefs_ref[$k]}"; done |
			jq -R -c 'split("\t") | {(.[0]): .[1]}' | jq -sc 'add // {}'
	)

	local required_json present_json installed_json
	required_json=$(profile::_array_to_json _rec_required_ref)
	present_json=$(profile::_array_to_json _rec_present_ref)
	installed_json=$(profile::_array_to_json _rec_installed_ref)

	local profiles_file="${STATE_DIR}/profiles.json"
	local existing='{"schema_version":1,"profiles":{}}'
	[[ -f $profiles_file ]] && existing=$(cat "$profiles_file")

	local project_commit
	project_commit=$(git -C "$DOTFILES_ROOT" rev-parse --short HEAD 2>/dev/null || printf '%s' unknown)

	jq --arg id "$id" \
		--arg installed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		--arg commit "$project_commit" \
		--argjson required "$required_json" \
		--argjson already_present "$present_json" \
		--argjson installed_by_profile "$installed_json" \
		--argjson prefs "$prefs_json" \
		'.profiles[$id] = {
			installed_at: $installed_at,
			project_commit: $commit,
			required_capabilities: $required,
			packages: {already_present: $already_present, installed_by_profile: $installed_by_profile},
			preference_defaults_applied: $prefs
		}' <<<"$existing" >"$profiles_file"
}

# profile::install <id>
# Resolves required capabilities, confirms (skipped when nothing needs
# installing — there's nothing to confirm), installs the missing ones,
# records the profiles.json entry. Never regenerates/commits config —
# 'dotctl apply' stays the one gateway to $HOME mutation; installing
# packages and committing config are different blast radii, and bundling
# them here would risk an ambiguous rollback story this function has no
# transaction machinery for.
profile::install() {
	apply::ensure_state_dir
	local id=$1
	local -A fields=()
	profile::_load "$id" fields

	profile::_is_installed "$id" && log::die "profile install: '${id}' is already installed (see 'dotctl profile show ${id}')"

	apply::detect_and_plan_host

	local -a required
	mapfile -t required < <(profile::_split_list "${fields[REQUIRED_CAPABILITIES]:-}")
	local -a present=() missing=()
	profile::_resolve_required fields present missing

	printf '\nProfile install: %s\n' "$id"
	printf '  packages present (%d): %s\n' "${#present[@]}" "$(profile::_join_or_none present)"
	printf '  packages to install (%d): %s\n' "${#missing[@]}" "$(profile::_join_or_none missing)"

	if [[ $OPT_DRY_RUN -eq 1 ]]; then
		log::info "profile install: --dry-run, installing nothing"
		return 0
	fi

	if [[ ${#missing[@]} -gt 0 ]]; then
		profile::_confirm "install profile '${id}' — ${#missing[@]} package(s) to install"
		adapter_install_packages "${missing[@]}"
	else
		log::info "profile install: every required package is already present, nothing to confirm"
	fi

	local -A prefs=()
	profile::_split_preference_defaults "${fields[PREFERENCE_DEFAULTS]:-}" prefs
	profile::_record_install "$id" required present missing prefs

	log::info "profile install: '${id}' installed. Run 'dotctl apply' to pick up its preference defaults."
	doctor::run 0 >/dev/null
}

# profile::_compute_orphans <id> <keep-array-name> <remove-array-name>
# Classifies <id>'s recorded installed_by_profile packages into "keep"
# (still required by another currently-installed profile's required
# capabilities, or by the core capability set) vs "remove" (nothing else
# needs it). Split out of profile::remove so the actual orphan-detection
# logic — the "removal impact" this whole feature exists for — is testable
# directly, without going through profile::_confirm's /dev/tty read.
profile::_compute_orphans() {
	local id=$1
	local -n _orph_keep_ref=$2
	local -n _orph_remove_ref=$3

	local profiles_file="${STATE_DIR}/profiles.json"
	local -a installed_by_profile
	mapfile -t installed_by_profile < <(jq -r --arg id "$id" '.profiles[$id].packages.installed_by_profile[]?' "$profiles_file")

	local -a other_ids
	mapfile -t other_ids < <(profile::_installed_ids | grep -vx "$id")

	local -a other_pkgs=()
	local oid ocap opkg
	for oid in "${other_ids[@]}"; do
		local -A ofields=()
		profile::_load "$oid" ofields
		local -a ocaps
		mapfile -t ocaps < <(profile::_split_list "${ofields[REQUIRED_CAPABILITIES]:-}")
		for ocap in "${ocaps[@]}"; do
			opkg=$(adapter_resolve_capability "$ocap" 2>/dev/null) || continue
			other_pkgs+=("$opkg")
		done
	done

	local -a core_pkgs=()
	local ccap cpkg
	while IFS= read -r ccap; do
		[[ -z $ccap || $ccap == \#* ]] && continue
		cpkg=$(adapter_resolve_capability "$ccap" 2>/dev/null) || continue
		core_pkgs+=("$cpkg")
	done <"${DOTFILES_ROOT}/packages/capabilities.conf"

	local pkg
	for pkg in "${installed_by_profile[@]}"; do
		if printf '%s\n' "${other_pkgs[@]}" "${core_pkgs[@]}" 2>/dev/null | grep -qx "$pkg"; then
			_orph_keep_ref+=("$pkg")
		else
			_orph_remove_ref+=("$pkg")
		fi
	done
}

# profile::remove <id>
# Dies if not currently installed (unlike uninstall's tolerant "already
# gone": this scope isn't enumerable in advance the way uninstall's is — a
# typo here shouldn't silently succeed).
profile::remove() {
	apply::ensure_state_dir
	local id=$1
	profile::_is_installed "$id" || log::die "profile remove: '${id}' is not currently installed"

	local -a keep=() to_remove=()
	profile::_compute_orphans "$id" keep to_remove

	printf '\nProfile remove: %s\n' "$id"
	printf '  keeping (%d, still needed elsewhere): %s\n' "${#keep[@]}" "$(profile::_join_or_none keep)"
	printf '  removing (%d): %s\n' "${#to_remove[@]}" "$(profile::_join_or_none to_remove)"

	if [[ $OPT_DRY_RUN -eq 1 ]]; then
		log::info "profile remove: --dry-run, removing nothing"
		return 0
	fi

	if [[ ${#to_remove[@]} -gt 0 ]]; then
		profile::_confirm "remove profile '${id}' — ${#to_remove[@]} package(s) to remove"
		adapter_remove_packages "${to_remove[@]}"
	else
		log::info "profile remove: nothing still exclusively needed by '${id}', nothing to confirm"
	fi

	local profiles_file="${STATE_DIR}/profiles.json"
	jq --arg id "$id" 'del(.profiles[$id])' "$profiles_file" >"${profiles_file}.tmp"
	mv "${profiles_file}.tmp" "$profiles_file"

	log::info "profile remove: '${id}' removed. Preferences it set are not automatically reverted — adjust preferences/hosts manually if needed."
	doctor::run 0 >/dev/null
}
