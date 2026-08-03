#!/usr/bin/env bash
# Validates staged files before they're committed into $HOME.
# One case per file type is added as each application module lands;
# Milestone 2 only has bash-syntax files to check.

validate::staging() {
	local root=$1
	[[ -d $root ]] || return 0
	local f
	while IFS= read -r -d '' f; do
		# extension for *.bash files, shebang for extensionless scripts
		# (e.g. the staged hypr-session).
		if [[ $f == *.bash ]] || head -n1 "$f" | grep -q '^#!.*bash'; then
			validate::_bash "$f"
		fi
	done < <(find "$root" -type f -print0)
	log::info "validate::staging: ${root} OK"
}

validate::_bash() {
	local f=$1
	bash -n "$f" || log::die "validate::staging: bash -n failed for ${f}"
}

# validate::_ini <file>
# Generic structural check for INI-style configs (fuzzel, mako): every
# non-blank, non-comment line must be a [section] header or a key=value
# pair. Used as a fallback when the real binary isn't installed on this host
# yet to check against directly — not a substitute for its actual parser.
validate::_ini() {
	local f=$1 line_no=0 line trimmed
	while IFS= read -r line || [[ -n $line ]]; do
		line_no=$((line_no + 1))
		trimmed=${line#"${line%%[![:space:]]*}"}
		[[ -z $trimmed || $trimmed == \#* ]] && continue
		if [[ ! $trimmed =~ ^\[.+\]$ && ! $trimmed =~ ^[^=[:space:]][^=]*=.*$ ]]; then
			log::die "validate::_ini: ${f}:${line_no}: not a [section] header or key=value line: ${trimmed}"
		fi
	done <"$f"
}

# validate::_braces <file>
# Generic brace-balance check for block-based configs (Hyprland-family
# syntax: hyprlock, hypridle). Neither ships a --verify-config equivalent,
# and actually running either binary against this host's live session would
# lock the screen (hyprlock) or fight a running idle daemon (hypridle) — not
# a real parser, but catches an unclosed/extra brace before it reaches one.
validate::_braces() {
	local f=$1 open close
	open=$(tr -cd '{' <"$f" | wc -c)
	close=$(tr -cd '}' <"$f" | wc -c)
	if [[ $open -ne $close ]]; then
		log::die "validate::_braces: ${f}: unbalanced braces (${open} open, ${close} close)"
	fi
}

# validate::applications — discovers applications/*/validate.sh and calls
# each module's <app>::validate. New app modules need no change here.
validate::applications() {
	local script app
	for script in "${DOTFILES_ROOT}"/applications/*/validate.sh; do
		[[ -f $script ]] || continue
		app=$(basename "$(dirname "$script")")
		# shellcheck disable=SC1090  # genuinely dynamic: one per app module, not a fixed path
		source "$script"
		"${app}::validate"
	done
}
