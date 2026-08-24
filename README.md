# dotfiles: Hyprland on Arch and Void

A small Hyprland desktop shared by Arch Linux and Void Linux. Hyprland is
configured with Lua; hyprlock and hypridle retain their own hyprlang formats.
The desktop runs the standalone Quickshell configuration in `config/quickshell/`
when its `shell.qml` exists, while the tracked Waybar installation and
configuration remain a complete fallback.

## Layout

```text
install.sh                    distro detection, packages, services, config links
packages/arch.txt             Arch package names
packages/void.txt             Void package names
etc/systemd/network/          Arch networkd DHCP matches
config/hypr/                  Hyprland Lua, lock, and idle configuration
config/quickshell/            standalone bar, widgets, panels, and platform adapters
config/waybar/                fallback bar configuration
config/themes/*/              per-application theme files, including quickshell.json
config/{foot,fuzzel,mako,...} application configuration
```

The installer treats Quickshell as a normal config directory and links it to
`$XDG_CONFIG_HOME/quickshell` (normally `~/.config/quickshell`). Session startup
checks for the standard `shell.qml` entry point rather than assuming the
directory is usable; removing or renaming that entry point selects Waybar.

## Prerequisites

Run `install.sh` as a normal user with `sudo` configured. A minimal installation
also needs Git to obtain this repository and suitable kernel firmware and
graphics drivers for the machine.

Arch example:

```bash
sudo pacman -S --needed sudo git less man-db man-pages linux-firmware base-devel
```

Void example:

```bash
sudo xbps-install -Suy
sudo xbps-install sudo git less man-pages linux-firmware
```

Graphics drivers, kernels, bootloaders, display managers, and hardware-specific
firmware are deliberately outside the manifests. For example, NVIDIA packages
differ by distribution and must match the installed kernel.

## Install

```bash
./install.sh
```

The installer reads `/etc/os-release` and accepts Arch or Void through `ID` or
`ID_LIKE`, including Arch derivatives such as Omarchy. It then reads the matching
file under `packages/`, installs the packages, configures the distro's
service/network path, and links every directory under `config/` to the matching
directory in `${XDG_CONFIG_HOME:-$HOME/.config}`. An existing real config
directory is moved to `<name>.bak`; an existing symlink is replaced.

Use this to install only the config links:

```bash
./install.sh --no-packages
```

`--no-packages` does not inspect the distribution or alter system services.

### Arch package path

Arch packages come from `packages/arch.txt`. The installer first checks that
each package is installed or available in an enabled repository, then runs:

```bash
sudo pacman -S --needed -- ...
```

The manifest includes the existing desktop applications plus Quickshell,
Waybar, UPower, power-profiles-daemon, `curl`, `jq`, PyGObject, portals,
PipeWire, network/Bluetooth tools, and the runtime helpers used by bindings.

The installer retains the existing Arch network architecture:

- iwd associates with wireless networks.
- systemd-networkd obtains addresses for wireless and Ethernet interfaces.
- systemd-resolved supplies DNS.
- Root-owned `.network` files are copied from `etc/systemd/network/` with
  `cp -n`, so an existing file is never overwritten.
- iwd, networkd, resolved, Bluetooth, CUPS, and power-profiles-daemon are
  enabled and started with systemd. UPower starts through D-Bus activation.

Optional AUR applications such as `herdr`, `zen-browser-bin`, `bruno-bin`, and
`localsend-bin` are not installed. Their availability is not required by the
desktop; the tracked `herdr` config is ready if it is installed separately.

### Void package path

Void packages come from `packages/void.txt`. The installer refreshes repository
metadata, checks every required name with `xbps-query -R`, and prints the full
missing-package list before installing anything. Once preflight succeeds it
runs `xbps-install` for the complete manifest.

Some Hyprland ecosystem packages are not present in every Void repository or
architecture. Enable a trusted XBPS repository that supplies all names in the
manifest before running the installer. The installer does not silently build
packages, substitute an unrelated compositor, or leave a partially installed
desktop; unavailable required packages are a clear error. The package names in
`packages/void.txt` are the contract and can be audited before enabling an
additional repository.

The Void manifest uses the small `nerd-fonts-symbols-ttf` package rather than
the 1.5 GB all-font aggregate. Quickshell asks Fontconfig for `monospace`, then
uses the symbols font as a fallback for bar glyphs.

Void uses its native non-systemd network path:

- iwd handles association, DHCP, and route setup with
  `EnableNetworkConfiguration=true`.
- iwd sends DNS information to openresolv with
  `NameResolvingService=resolvconf`.
- `/etc/iwd/main.conf` is created only when absent. Existing administrator or
  user configuration is reported and preserved unchanged.
- The installer only creates missing `/var/service/<name>` symlinks for `dbus`,
  `iwd`, `bluetoothd`, `cupsd`, and `power-profiles-daemon`. Existing files and
  links are never replaced. A missing `/etc/sv/<name>` is treated as an error.
- UPower is available through system D-Bus activation and does not need a
  persistent service link.

If an existing Void iwd configuration does not enable built-in network
configuration, another DHCP client must provide addresses. Do not run two DHCP
stacks on the same interface. Likewise, if the existing configuration names a
different DNS manager, keep that manager rather than adding the openresolv
setting blindly.

## Session Startup

Start the package-provided Hyprland session from a display manager or a TTY. The
session's `hyprland.start` handler starts:

- mako, the foot server, hypridle, swaybg, and the cliphist watcher
- PipeWire, pipewire-pulse, and WirePlumber directly on Void; Arch continues to
  use its systemd user units
- a polkit agent, preferring the hyprpolkitagent user unit/binary and falling
  back to Void's polkit-gnome agent
- Quickshell with exactly `qs -d -n` when the standard standalone
  `quickshell/shell.qml` exists
- Waybar otherwise

Waybar remains installed and configured on both distributions. To force the
fallback, move the standalone `shell.qml` out of the standard location and log
in again. To start Quickshell, place a valid standalone config there and restart
the session (or run `qs -d -n`).

The handler always imports Wayland and Hyprland variables with
`dbus-update-activation-environment`. On systemd it additionally imports them
into the user manager; on Void it does not require or invoke a systemd user
session. This lets D-Bus-activated portals inherit `WAYLAND_DISPLAY`,
`XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`, and
`HYPRLAND_INSTANCE_SIGNATURE` on either init system.

## Themes

`config/themes/current` points to the active theme. Each theme contains native
configuration for foot, fuzzel, mako, Hyprland, hyprlock, Neovim, Waybar, and
swaybg, plus `quickshell.json` with the keys consumed by `Theme.qml`:

```text
background surface surfaceHover foreground muted accent warning critical border
fontFamily fontSize
```

Quickshell reads `~/.config/themes/current/quickshell.json` directly; `jq`
remains available for helper scripts and validation. The shipped palettes are
`aura`, `tokyo-day`, and `tokyo-night`.

`SUPER+SHIFT+T` selects a theme, updates `themes/current`, reloads mako and
Hyprland, and calls Quickshell's `dotbar.reloadTheme` IPC endpoint. If IPC is
unavailable it restarts the default Quickshell instance. If no standalone
Quickshell config exists, it sends Waybar `SIGUSR2` instead. Waybar colors
continue to come from each theme's `waybar.css`.

## Keybindings

`SUPER` is the modifier.

| Bind | Action |
| --- | --- |
| `Return` | foot terminal |
| `Space` | fuzzel launcher |
| `L` | lock |
| `W` | close window |
| `F` | fullscreen |
| `V` | toggle floating |
| `SHIFT+E` | exit Hyprland |
| `SHIFT+Q` | suspend/reboot/poweroff menu |
| `SHIFT+S` | region screenshot to clipboard |
| `Print` | full screenshot to `~/Pictures` |
| `SHIFT+V` | clipboard history |
| `SHIFT+T` | theme picker and shell/bar reload |
| `SHIFT+N` | night-light toggle |
| `B` | time, battery, and network notification |
| `S` | toggle scratchpad |
| `SHIFT+M` | move window to scratchpad |
| arrows | focus direction |
| `SHIFT` + arrows | move window |
| `1` to `5` | switch workspace |
| `SHIFT+1` to `SHIFT+5` | move window to workspace |

The power menu uses systemd on Arch and elogind's `loginctl` on Void, with
Void's `zzz` as a suspend-only fallback. It reports an unavailable action rather
than assuming `systemctl` exists. Volume, brightness, and media keys are also
configured and remain active while locked.

## Validation

Check the installer and JSON files without changing the machine:

```bash
bash -n install.sh
jq empty config/themes/*/quickshell.json
```

If Lua 5.4 is installed, Hyprland modules can also be parsed with:

```bash
luac -p config/hypr/*.lua
```

Package and service installation must be tested on the target distribution;
`--no-packages` is the non-privileged way to exercise only config linking.
