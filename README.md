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
packages.txt                what to install
install.sh                  installs packages, symlinks config/* into ~/.config/*
```

Started from `hyprland.lua` with no config of their own: `swaybg` (solid
colour background), `hyprpolkitagent` (GUI auth prompts), and `grim`/`slurp`
(screenshots — also what makes the desktop portal's screenshot and screencast
path work for other apps).

## Install

On a fresh machine, this is the whole thing:

```bash
./install.sh
```

It reads `packages.txt`, runs `sudo pacman -S --needed` on the list (so it
prompts once for your password and skips anything already present), enables
NetworkManager and bluetooth, then symlinks each directory under `config/` to
the matching path in `~/.config`, moving any existing real directory aside to
`<name>.bak` first. Every package is in the official repos — no AUR helper
needed.

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

This repo installs no session entry and touches nothing outside `~/.config`.
It doesn't need to: the `hyprland` package already ships
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
