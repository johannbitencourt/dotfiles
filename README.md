# dotfiles — minimal Hyprland

A small Hyprland desktop. The Hyprland config is Lua
(`config/hypr/hyprland.lua`), not hyprlang — hyprlang was deprecated in
Hyprland 0.55 and is slated for removal around 0.57.

```
config/hypr/hyprland.lua    compositor: monitors, input, look, autostart, binds
config/hypr/hyprlock.conf   lock screen (hyprlock is separate, still hyprlang)
config/hypr/hypridle.conf   lock at 5 min, screen off at 6 min
config/waybar/config.jsonc  bar: workspaces, clock, network, battery, volume
config/waybar/style.css     bar styling
config/foot/foot.ini        terminal
config/fuzzel/fuzzel.ini    launcher
config/mako/config          notifications
etc/systemd/network/*       DHCP for wifi and ethernet (copied into /etc)
packages.txt                what to install
install.sh                  installs packages, symlinks config/* into ~/.config/*
```

Started from `hyprland.lua` with no config of their own: `swaybg` (solid
colour background), `hyprpolkitagent` (GUI auth prompts), and `grim`/`slurp`
(screenshots — also what makes the desktop portal's screenshot and screencast
path work for other apps).

## Prerequisites

`packages.txt` covers the desktop, but it can't bootstrap the things needed to
run `install.sh` in the first place. The `base` metapackage has no `sudo` and
no `git`, and `linux-firmware` is only an *optional* dep of the kernel — without
it the wifi and bluetooth radios never appear, which makes `impala` and
`bluetui` useless. On a minimal Arch install, first:

```bash
pacman -S --needed sudo git linux-firmware
```

**Graphics drivers are not in `packages.txt`** — they're host hardware, not
desktop config, and they're the one part of this setup that is coupled to which
kernel you booted. `hyprland` satisfies its `opengl-driver` dependency with
`mesa`, which is right for Intel and AMD and wrong for NVIDIA. This host is an
NVIDIA RTX 3060 Mobile with no iGPU, and runs:

```bash
sudo pacman -S --needed nvidia-open-dkms nvidia-utils
```

`nvidia-open-dkms` pulls in `dkms` (and so `gcc`, `make`), and needs the headers
for your running kernel installed *first* — `linux-headers`, or
`linux-cachyos-headers` on the CachyOS kernel. The prebuilt `nvidia-open`
package is compiled against `extra/linux` and will not load on a CachyOS
kernel. CachyOS also ships prebuilt `linux-cachyos-nvidia-open`, which skips
DKMS entirely and is less to maintain.

## Install

On a fresh machine, this is the whole thing:

```bash
./install.sh
```

It reads `packages.txt`, runs `sudo pacman -S --needed` on the list (so it
prompts once for your password and skips anything already present), copies the
`.network` files into `/etc/systemd/network/` if they aren't already there,
enables iwd/networkd/resolved/bluetooth, then symlinks each directory under
`config/` to the matching path in `~/.config`, moving any existing real
directory aside to `<name>.bak` first. Every package is in the official repos —
no AUR helper needed.

Wifi is **iwd**, not NetworkManager: `impala` is an iwd frontend
(`Depends On: iwd`), and the two are competing backends that fight over the
radio if both run. `iwd` handles association; `systemd-networkd` and
`systemd-resolved` handle addresses and DNS, and both ship inside `systemd`, so
they cost no extra package. They do need a `.network` file to match on — systemd
ships only inert `.example` ones — which is what `etc/systemd/network/` is for.
Those two files are the only thing this repo puts outside `~/.config`, they're
copied rather than symlinked (root shouldn't read config from a user-writable
path), and `cp -n` means a hand-tuned `/etc` survives a re-run.

No file manager, GTK/Qt theme configurator, logout menu, or OSD daemon is
included. Each is one line in `packages.txt` if you find you want it; none of
them is needed for the desktop to work.

Pass `--no-packages` to only do the symlinking. Because the links point at the
repo, editing a file here takes effect directly. To uninstall, delete the
symlinks.

## Starting a session

From a TTY, either works — `Hyprland` directly, or the wrapper the package
ships and the desktop entry uses:

```bash
start-hyprland
```

### Booting into it

This repo installs no session entry. It doesn't need to: the `hyprland` package
already ships
`/usr/share/wayland-sessions/hyprland.desktop`, which runs
`/usr/bin/start-hyprland`. Both are package-owned, so they survive updates and
need no maintenance here.

Point your display manager at that entry. For SDDM autologin, the session name
is the desktop file's basename:

```ini
# /etc/sddm.conf.d/autologin.conf  (root)
[Autologin]
User=<you>
Session=hyprland
```

Nothing else is required — no uwsm, no `systemd --user` target, no session
wrapper script. Hyprland's own `hyprland.start` handler in `hyprland.lua`
pushes `WAYLAND_DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE` into the D-Bus
activation environment so portals work.

Note that files under `/etc/sddm.conf.d/` are usually unowned by any package —
whatever installed your current setup wrote them by hand, so check what's there
before changing it.

## Keybindings

`SUPER` is the modifier.

| Bind | Action |
| --- | --- |
| `Return` | terminal (foot) |
| `Space` | launcher (fuzzel) |
| `L` | lock (hyprlock) |
| `W` | close window |
| `F` | fullscreen |
| `V` | toggle floating |
| `SHIFT + E` | exit Hyprland |
| `SHIFT + S` | screenshot region to clipboard |
| `SHIFT + V` | clipboard history (cliphist via fuzzel) |
| `SHIFT + N` | night light on/off (hyprsunset, 4000K) |
| `B` | status notification: time, battery, network |
| arrows | move focus |
| `SHIFT` + arrows | move window |
| `1`–`5` | switch workspace |
| `SHIFT` + `1`–`5` | move window to workspace |
| drag / right-drag | move / resize window |

Volume and brightness function keys are bound too, and keep working while the
lock screen is up.

## Changing things

`config/hypr/hyprland.lua` is the whole compositor config; edit it directly.
The full Lua API is stubbed at `/usr/share/hypr/stubs/hl.meta.lua`, and
upstream's annotated example config at `/usr/share/hypr/hyprland.lua` is worth
reading — it has ready-made blocks for media keys, gestures, and window rules.

To add a bar, a wallpaper, or an idle daemon, write its config under `config/`
and add one `hl.exec_cmd("…")` line to the `hyprland.start` handler.
