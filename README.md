# Bare-metal Hyprland dotfiles

Personal, machine-aware configuration managed by [chezmoi](https://www.chezmoi.io/)
for a minimal Arch or CachyOS installation. It uses small standalone components
instead of a desktop environment or widget shell.

## Desktop stack

- Hyprland managed as a UWSM systemd user session
- greetd with a fixed tuigreet command that always starts the UWSM session
- Foot terminal, Fuzzel launcher, and Mako notifications
- Minimal Waybar with workspaces, clock, audio, network, and optional battery
- Hypridle and Hyprlock for idle handling and screen locking
- PipeWire and WirePlumber for audio
- Native Hyprland and GTK desktop portals
- Optional repository-managed iwd, systemd-networkd, and resolved networking

DMS, Quickshell, Omarchy, Walker, Elephant, and SDDM are not used. There is no
clipboard-history daemon, graphical network applet, OSD daemon, wallpaper
daemon, or desktop shell. Animations, blur, shadows, transparency, and rounded
corners are disabled.

Four processes stay resident: `waybar`, `mako`, `hypridle`, and the polkit
agent. Volume and brightness feedback is drawn by Mako through
`~/.local/bin/osd` rather than a second on-screen-display daemon, and the
background is Hyprland's own `misc:background_color` rather than a wallpaper
process.

## Portability

The desktop layer is distribution-agnostic. Everything under `dot_config/hypr`
and `dot_local/bin` resolves its commands from `PATH` and hardcodes no
distribution paths, so it works unchanged on any distribution that ships the
packages. The polkit agent is the one component whose binary is not on `PATH`
and whose location differs per distribution, so `~/.local/bin/polkit-agent`
probes the known locations instead.

Only the bootstrap is Arch-specific: package installation uses `pacman`, and the
system pass writes `/etc/greetd`, `/etc/systemd/network`, and `/etc/iwd`. On a
non-pacman distribution the installer refuses to run; install the equivalents of
`packages/core.txt` by hand and the rest applies normally.

## Fresh installation

Start from an updated minimal Arch or CachyOS installation with a working
network connection:

```bash
sudo pacman -Syu --needed git chezmoi
git clone --branch bare-metal-hyprland <repository-url> "$HOME/dotfiles"
chezmoi init --apply --source "$HOME/dotfiles"
```

That is the whole installation. `chezmoi init` prompts for every machine value
and persists this source directory, so later runs are just `chezmoi apply`.

To review before committing to anything, split the last step:

```bash
chezmoi init --source "$HOME/dotfiles"
chezmoi diff
chezmoi apply
```

`chezmoi diff` is paged through `delta` only when `delta` is already installed,
because a configured-but-missing pager makes `chezmoi diff` hang with no output.
`delta` arrives with the first apply, so re-run `chezmoi init` once afterwards to
pick it up.

The package bootstrap runs `pacman -Syu` because Arch does not support partial
upgrades.

The system pass checks every conflict before it changes any file, unit, or
group. It refuses to replace an enabled display manager. Disable an existing
manager explicitly, then re-run:

```bash
sudo systemctl disable --now sddm.service
```

Use the actual service name if it is not SDDM. Packages install before that
check runs, so a conflict costs a download, not a broken system: no unit state
or system file is touched until every check passes. The apply then installs
greetd's configuration, enables `greetd.service`, and selects
`graphical.target`. Tuigreet uses one fixed command and cannot remember a
non-UWSM Hyprland session.

## Networking

Replacing the current network stack is a separate, default-off prompt. Leave it
disabled on the first apply to preserve the connection used for installation.
When enabled, chezmoi manages:

```text
/etc/systemd/network/20-ethernet.network
/etc/systemd/network/20-wlan.network
/etc/iwd/main.conf
/etc/resolv.conf -> /run/systemd/resolve/stub-resolv.conf
```

The migration refuses to continue while NetworkManager, ConnMan, dhcpcd,
wpa_supplicant, or netctl is active or enabled. It also refuses to replace a
different resolver configuration. Prepare and test the iwd/networkd migration
from a console before enabling the prompt; Wi-Fi credentials are not copied
from another network manager. Use `iwctl`, `networkctl`, and `resolvectl` for
diagnostics.

The system pass runs after every apply but only invokes `sudo` when managed
files, symlinks, groups, or unit state have drifted. Turning the
network-management prompt off later does not restore a previous network manager
or resolver configuration; migration reversal must be explicit.

## First login

`~/.config/hypr/monitors.conf` is created once and then never touched again, so
per-machine display settings you put there survive every later apply. Its
default uses each output's preferred mode. Hardware-specific NVIDIA modules and
environment variables remain owned by the operating system.

The background is a solid color set by `misc:background_color` in
`~/.config/hypr/hyprland.conf`. For an image wallpaper, install `swaybg` or
`hyprpaper` and add one `exec-once` line.

Session environment variables live in `~/.config/uwsm/env`, which UWSM loads
once for the whole session. `hyprland.conf` intentionally has no `env =` lines.

Useful defaults:

| Keys | Action |
|---|---|
| `SUPER+Return` | Terminal |
| `SUPER+D` | Application launcher |
| `SUPER+E` | Yazi file manager |
| `SUPER+L` | Lock |
| `SUPER+Q` | Close window |
| `SUPER+F` | Fullscreen |
| `SUPER+V` | Toggle floating |
| `Print` | Full screenshot |
| `SUPER+SHIFT+S` | Region screenshot |
| `SUPER+SHIFT+E` | Stop the UWSM session |

## Optional profiles

Prompts independently control laptop support, Bluetooth, development tools,
Docker, virtualization, gaming, desktop applications, and privileged libvirt
group access. Profiles are install-only: turning one off later does not remove
packages, disable services, or revoke group membership.

- Docker group membership is root-equivalent and is disclosed by its prompt.
- Libvirt group membership is privileged, separate, default-off, and unnecessary
  when polkit authorization is sufficient.
- Docker and libvirt are socket-activated. Conversion refuses to proceed while
  their daemons are active so running workloads are never stopped implicitly.
- Gaming requires Arch's `[multilib]` repository.
- Desktop applications require a preinstalled `paru` or `yay`; the apply checks
  this before installing anything from the AUR.
- AUR PKGBUILDs execute third-party build instructions and require review.

The browser is whatever the `browser` prompt names. It is installed when that
name is also an official repository package; an AUR or Flatpak browser is
reported during the bootstrap and left for you to install.

The required desktop deliberately has no Secret Service daemon. When Chromium
is the chosen browser, its built-in password manager is disabled through a
managed policy at `/etc/chromium/policies/managed/`. Use an external password
manager if credentials must be stored. GitHub CLI can store a token in
`~/.config/gh/hosts.yml` when no keyring is available; protect that file and use
the authentication workflow appropriate for the machine.

## Migrating from DMS

Run `chezmoi init --source "$HOME/dotfiles"` after switching branches. A
one-time `run_once_before_05-migrate-from-dms.sh` removes the old Hyprland Lua
entry points, DMS user-target relationship, DMS environment file, Ghostty files,
the previous split Hyprland configuration, and the retired SwayOSD and wallpaper
files. It does not remove packages or arbitrary DMS user state.

It runs once rather than on every apply, so those filenames stay free
afterwards: a hand-written `~/.config/hypr/autostart.conf` you add later will
not be deleted.

Before measuring memory, disable the old user service and remove unused shell
packages after reviewing reverse dependencies:

```bash
systemctl --user disable --now dms.service
```

Do not run that command while another installed desktop depends on DMS.

## Validation

```bash
dotfiles-health
chezmoi status
chezmoi diff
Hyprland --verify-config --config ~/.config/hypr/hyprland.conf
hyprctl reload
hyprctl configerrors
```

Measure the actual session after login rather than estimating from package
count:

```bash
systemd-cgtop --user
ps -eo rss,comm --sort=-rss
```
