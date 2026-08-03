# dotfiles-hyprland

A minimal, from-scratch Hyprland desktop for Arch Linux, installed and
managed by a plain Bash generator — no Chezmoi, no UWSM, no framework.

This is **Phase 1 (narrow core)** of a larger design — only what's needed to
log in, launch applications, get notifications, lock the screen, and
recover. There is no `dotctl` CLI, no profiles, no first-run wizard, and no
themes engine yet; those are later phases.

## Requirements

- Arch Linux (or an Arch-family distro with `pacman`), `x86_64`
- systemd, Bash 5+
- Run as a normal user, from the repo root — the installer refuses `sudo`/root

## Usage

```bash
./install.sh --dry-run              # show the plan, change nothing
./install.sh --packages-only        # install missing packages only
./install.sh --config-only          # generate/commit config only
./install.sh --non-interactive      # fail instead of prompting on conflicts
```

Every replaced file is backed up under `~/.local/state/dotfiles/backups/`
before being overwritten; an unmanaged or locally-modified file is never
silently replaced. See `./install.sh --help` for the full option list.

After installing, start the session manually from a TTY:

```bash
~/.local/bin/hypr-session
```

## What's here (Phase 1 core)

Hyprland, Waybar, Fuzzel, Mako, hyprlock, hypridle, swaybg, Foot, wl-clipboard,
PipeWire/WirePlumber, NetworkManager, XDG portals — one instance of each,
managed as systemd user services under `dotfiles-graphical-session.target`,
started explicitly by Hyprland's `exec-once` (not by login/boot).

## Repository layout

```
install.sh              entrypoint: detect -> plan -> stage -> validate -> commit
install/                installer phases + the Arch adapter
packages/                capability -> package name mapping
preferences/             project-wide app-tuning defaults
hosts/                   this host's real, committed data (hardware facts, overrides)
applications/<name>/     one self-contained module per managed app
config/                  source templates rendered by applications/*/generate.sh
scripts/                 hypr-session + shared Bash libraries
tests/unit/              static/self-contained checks, no framework
```

## Testing

```bash
for t in tests/unit/*.sh; do bash "$t" || echo "FAILED: $t"; done
```

## Local overrides

Personal, untracked overrides live outside the repo and are never
committed:

```
~/.config/dotfiles/preferences.local.conf
~/.config/dotfiles/hosts/<hostname>.local.conf
```
