# dotfiles-hyprland

A minimal, from-scratch Hyprland desktop for Arch (and Arch-family distros —
CachyOS, EndeavourOS, etc.), installed and managed by a plain Bash
generator plus a `dotctl` CLI — no Chezmoi, no UWSM, no framework.

Still not built: a first-run wizard, a themes engine, additional distro
adapters (Fedora/openSUSE/Debian), and most of the tool-profile catalog
(only `dev` ships so far — see `profiles/`).

## Requirements

- Arch Linux or an Arch-family distro with `pacman` (detected via
  `/etc/os-release`'s `ID` or `ID_LIKE`), `x86_64`
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

### `dotctl`

Day-to-day lifecycle management, installed to `~/.local/bin/dotctl`
(run `./scripts/dotctl` directly from a checkout). Every command supports
`--help`.

```text
dotctl apply           regenerate and commit config (like install.sh --config-only)
dotctl diff             show what apply would change, without changing anything
dotctl validate         generate and validate config, without committing
dotctl doctor           report on system health (--json for machine-readable output)
dotctl restore-config   restore files from a backup transaction
dotctl uninstall        restore/remove managed files, stop services, write a report
dotctl update config    fetch, fast-forward, and apply upstream changes
dotctl update packages  ask pacman for the native upgrade plan, then upgrade after approval
dotctl update all       config, then packages, with a separate confirmation at each step
dotctl diagnose         write a redacted, portable local diagnostics bundle
dotctl recover          inspect current state and offer the matching fix
dotctl profile ...      list/show/plan/install/remove a tool profile (e.g. 'dev')
```

`diff`/`validate`/`doctor`/`diagnose`/`recover` (detection)/`profile
list|show|plan` are read-only. Everything else mutates and asks for
confirmation before doing anything irreversible.

### Uninstalling

```bash
./uninstall.sh --dry-run
```

Restores every managed file to its pre-project original where a backup
exists, otherwise removes it. Native packages and project state are kept
unless `--remove-packages`/`--remove-state` are given. See
`./uninstall.sh --help`.

## What's here

Hyprland, Waybar, Fuzzel, Mako, hyprlock, hypridle, swaybg, Foot, wl-clipboard,
PipeWire/WirePlumber, NetworkManager, XDG portals — one instance of each,
managed as systemd user services under `dotfiles-graphical-session.target`,
started explicitly by Hyprland's `exec-once` (not by login/boot).

`Super+Alt+Space` opens a Fuzzel-based system menu (session power actions,
`dotctl` maintenance commands, keybinding/version reference) — see
`install/menu.sh`.

## Repository layout

```
install.sh              entrypoint: detect -> plan -> stage -> validate -> commit
uninstall.sh             entrypoint for ./uninstall.sh
install/                 installer phases, the Arch adapter, and dotctl's logic modules
packages/                capability -> package name mapping
profiles/                tool/workflow profile definitions (e.g. dev.conf)
preferences/             project-wide app-tuning defaults
hosts/                   this host's real, committed data (hardware facts, overrides)
compat/                  compatibility data (e.g. minimum Hyprland version)
applications/<name>/     one self-contained module per managed app
config/                  source templates rendered by applications/*/generate.sh
scripts/                 dotctl, hypr-session, hypr-menu + shared Bash libraries
tests/unit/              static/self-contained checks, no framework
```

## Testing

```bash
for t in tests/unit/*.sh; do bash "$t" || echo "FAILED: $t"; done
```

## Local overrides

A personal, untracked override for this host's committed profile lives
outside the repo and is never committed:

```
~/.config/dotfiles/hosts/<hostname>.local.conf
```
