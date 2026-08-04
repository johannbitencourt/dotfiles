#!/usr/bin/env bash
# Builds a redacted, portable local diagnostics bundle. Never uploaded
# anywhere — this is purely a local artifact for the user to inspect or
# attach to a bug report themselves.

# diagnose::_redact_kv_file <src> <dest>
# Line-level redaction for the one local/untracked KEY=VALUE file this
# project reads (~/.config/dotfiles/hosts/<name>.local.conf). Reuses the
# same secret-shape patterns as tests/unit/test-secrets.sh: if KEY looks
# like a secret name, or VALUE looks like a private-key header or an AWS
# access key id, the value is replaced with <redacted>; every other line
# (including comments/blanks) is kept verbatim. Full-file omission would
# throw away the one thing worth showing ("what did this host override")
# for no real safety gain over reusing already-tested patterns.
diagnose::_redact_kv_file() {
	local src=$1 dest=$2
	local line key value
	: >"$dest"
	while IFS= read -r line || [[ -n $line ]]; do
		if [[ $line =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
			key=${BASH_REMATCH[1]}
			value=${BASH_REMATCH[2]}
			if [[ $key =~ (SECRET|PASSWORD|TOKEN|API_?KEY) ]] ||
				[[ $value =~ ^-----BEGIN\ (RSA|OPENSSH|EC|DSA|PGP)\ PRIVATE\ KEY----- ]] ||
				[[ $value =~ AKIA[0-9A-Z]{16} ]]; then
				printf '%s=<redacted>\n' "$key" >>"$dest"
			else
				printf '%s\n' "$line" >>"$dest"
			fi
		else
			printf '%s\n' "$line" >>"$dest"
		fi
	done <"$src"
}

diagnose::run() {
	command -v tar &>/dev/null || log::die "dotctl diagnose: tar not found"

	apply::ensure_state_dir

	local bundle_dir
	bundle_dir=$(mktemp -d)
	cleanup::register "$bundle_dir"

	# 1. doctor's own full check output.
	doctor::run 1 >"${bundle_dir}/doctor.json"

	# 2-4. project state, verbatim — paths/checksums/ids only, no user data.
	[[ -f "${STATE_DIR}/install.json" ]] && cp "${STATE_DIR}/install.json" "${bundle_dir}/install.json"
	[[ -f "${STATE_DIR}/managed-checksums.tsv" ]] && cp "${STATE_DIR}/managed-checksums.tsv" "${bundle_dir}/managed-checksums.tsv"
	[[ -f "${STATE_DIR}/active-transaction" ]] && cp "${STATE_DIR}/active-transaction" "${bundle_dir}/active-transaction"

	# 5. transaction ids only — never manifest.tsv content or backup file
	# bodies, which can hold arbitrary pre-existing user content from
	# before this project touched a path. `|| true` guards the same
	# find-on-nonexistent-dir pipefail trap fixed in rollback.sh.
	find "${STATE_DIR}/backups" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null |
		sort >"${bundle_dir}/transactions.txt" || true

	# 6. repo checkout state (never $HOME).
	{
		printf 'commit: %s\n' "$(git -C "$DOTFILES_ROOT" rev-parse HEAD 2>/dev/null || printf '%s' unknown)"
		printf 'branch: %s\n' "$(git -C "$DOTFILES_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '%s' unknown)"
		printf 'status:\n'
		git -C "$DOTFILES_ROOT" status --porcelain 2>/dev/null
	} >"${bundle_dir}/git.txt"

	# 7. this project's own generated output — no secrets by design, and
	# the single most useful artifact for a "broken Hyprland config" report.
	if [[ -d "${HOME}/.config/hypr/conf.d" ]]; then
		mkdir -p "${bundle_dir}/hyprland-conf.d"
		cp "${HOME}/.config/hypr/conf.d"/*.conf "${bundle_dir}/hyprland-conf.d/" 2>/dev/null || true
	fi

	# 8. the one local/untracked, user-authored KEY=VALUE file, redacted.
	local host_name
	host_name=$(hostname -s 2>/dev/null || printf '%s' arch)
	local local_override="${HOME}/.config/dotfiles/hosts/${host_name}.local.conf"
	if [[ -f $local_override ]]; then
		mkdir -p "${bundle_dir}/hosts"
		diagnose::_redact_kv_file "$local_override" "${bundle_dir}/hosts/${host_name}.local.conf.redacted"
	fi

	# 9. bundle metadata.
	jq -n \
		--argjson schema_version 1 \
		--arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		--arg commit "$(git -C "$DOTFILES_ROOT" rev-parse --short HEAD 2>/dev/null || printf '%s' unknown)" \
		--arg hostname "$host_name" \
		--arg home "$HOME" \
		'{schema_version: $schema_version, generated_at: $generated_at, project_commit: $commit, hostname: $hostname, home: $home}' \
		>"${bundle_dir}/meta.json"

	local out_dir="${HOME}/.local/share/dotfiles/diagnostics"
	mkdir -p "$out_dir"
	local out_path="${out_dir}/dotfiles-diagnostics-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
	tar -czf "$out_path" -C "$bundle_dir" .

	log::info "diagnose: bundle written to ${out_path}"
}
