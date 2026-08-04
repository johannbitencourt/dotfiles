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

Start the session from a TTY:

```bash
Hyprland
```

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
