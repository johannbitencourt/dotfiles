# dotfiles — minimal Hyprland

A Hyprland desktop in seven files. The Hyprland config is Lua
(`config/hypr/hyprland.lua`), not hyprlang — hyprlang was deprecated in
Hyprland 0.55 and is slated for removal around 0.57.

```
config/hypr/hyprland.lua    compositor: monitors, input, look, autostart, binds
config/hypr/hyprlock.conf   lock screen (hyprlock is a separate project, still hyprlang)
config/foot/foot.ini        terminal
config/fuzzel/fuzzel.ini    launcher
config/mako/config          notifications
install.sh                  symlinks config/* into ~/.config/*
```

## Install

```bash
sudo pacman -S --needed hyprland foot fuzzel mako hyprlock \
    ttf-jetbrains-mono-nerd wl-clipboard xdg-desktop-portal-hyprland

./install.sh
```

`install.sh` symlinks each directory under `config/` to the matching path in
`~/.config`, moving any existing real directory aside to `<name>.bak` first.
Because the links point at the repo, editing a file here takes effect
directly. To uninstall, delete the symlinks.

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
| arrows | move focus |
| `SHIFT` + arrows | move window |
| `1`–`5` | switch workspace |
| `SHIFT` + `1`–`5` | move window to workspace |
| drag / right-drag | move / resize window |

## Changing things

`config/hypr/hyprland.lua` is the whole compositor config; edit it directly.
The full Lua API is stubbed at `/usr/share/hypr/stubs/hl.meta.lua`, and
upstream's annotated example config at `/usr/share/hypr/hyprland.lua` is worth
reading — it has ready-made blocks for media keys, gestures, and window rules.

To add a bar, a wallpaper, or an idle daemon, write its config under `config/`
and add one `hl.exec_cmd("…")` line to the `hyprland.start` handler.
