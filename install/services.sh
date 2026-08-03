#!/usr/bin/env bash
# systemd user unit validation and reload.
#
# Units are never "enabled" — dotfiles-graphical-session.target has no
# WantedBy=; it's started explicitly by hypr-session's exec-once line in the
# generated Hyprland config (see config/hypr/conf.d/60-autostart.conf.tmpl),
# not by login/boot. So the only action needed here is telling systemd to
# notice new/changed unit files.

# services::validate_units — systemd unit files are proper INI, so the
# generic validate::_ini check (built for fuzzel/mako) applies unchanged.
services::validate_units() {
	local unit_dir="${STAGE_DIR}/config/systemd/user"
	[[ -d $unit_dir ]] || return 0
	local f
	for f in "$unit_dir"/*; do
		[[ -f $f ]] || continue
		validate::_ini "$f"
	done
	log::info "services::validate_units: OK"
}

services::reload_units() {
	if [[ $OPT_DRY_RUN -eq 1 ]]; then
		log::info "services::reload_units: [dry-run] would run systemctl --user daemon-reload"
		return 0
	fi
	systemctl --user daemon-reload
	log::info "services::reload_units: systemctl --user daemon-reload done"
}
