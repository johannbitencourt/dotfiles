#!/usr/bin/env bash
# fuzzel::reload — no-op: Fuzzel isn't long-lived, it exits after each use
# and re-reads its config fresh on the next launch (HLD: "Fuzzel is not
# counted as long-lived because it exits after use").

fuzzel::reload() {
	log::info "fuzzel::reload: nothing to do, fuzzel re-reads config on next launch"
}
