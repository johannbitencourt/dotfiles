# dotfiles — minimal Hyprland

A small Hyprland desktop. The Hyprland config is Lua
(`config/hypr/hyprland.lua`), not hyprlang — hyprlang was deprecated in
Hyprland 0.55 and is slated for removal around 0.57.

**0.57 has not been released.** As of August 2026 the latest tag is v0.56.2 and
the 0.57 milestone has no due date, so being "0.57-ready" means exactly one
thing: the config is written in Lua, which is the format that survives the
hyprlang removal whenever it lands. Every `hl.*` call and every `hl.config` key
used here is checked against the API stub the installed package ships
(`/usr/share/hypr/stubs/hl.meta.lua`), so it is current for what exists today.
`hyprlock.conf` and `hypridle.conf` stay hyprlang on purpose — hyprlock and
hypridle are separate projects with their own config format, unaffected by
Hyprland's deprecation.

When 0.57 does land, two things are worth rechecking: whether any `hl.config`
keys were renamed (0.55 removed `dwindle:pseudotile` and others), and whether
the `hl.dsp.*` dispatcher names shifted. Both are one-file fixes here.

```
config/hypr/hyprland.lua    entry point: monitors, env, and the requires below
config/hypr/looknfeel.lua   borders, gaps, decoration, animation curves
config/hypr/input.lua       keyboard, pointer, touchpad, gestures
config/hypr/rules.lua       window and layer rules
config/hypr/autostart.lua   what starts with the session
config/hypr/bindings.lua    every keybind
config/hypr/hyprlock.conf   lock screen (hyprlock is separate, still hyprlang)
config/hypr/hypridle.conf   lock at 5 min, screen off at 6 min
config/waybar/config.jsonc  bar: workspaces, clock, network, battery, volume
config/waybar/style.css     bar styling
config/foot/foot.ini        terminal
config/fuzzel/fuzzel.ini    launcher
config/mako/config          notifications (symlink into the current theme)
config/nvim/                LazyVim; lua/plugins/theme.lua rides the theme switch
config/herdr/config.toml    terminal workspaces (prefix ctrl+a) — config only
config/mise/config.toml     pinned tool versions (node, bun, zig, java, …)
config/imv/config           image viewer keybinds (print, delete, rotate)
config/themes/current       symlink naming the active theme — see Themes below
config/themes/tokyo-*/      one colour file per app, per theme
etc/systemd/network/*       DHCP for wifi and ethernet (copied into /etc)
packages.txt                what to install
install.sh                  installs packages, symlinks config/* into ~/.config/*
```

Started by `hyprland.lua`'s `hyprland.start` handler: `mako` (notifications),
`foot --server`, `waybar`, `hypridle`, `swaybg` (solid colour, so the repo
carries no image asset), `hyprpolkitagent` (GUI auth prompts), and a
`wl-paste --watch cliphist store` clipboard watcher. `grim` and `slurp` have no
config and no daemon — they run per screenshot, and installing them is also what
makes the desktop portal's screenshot and screencast path work for other apps.

## Prerequisites

`packages.txt` covers the desktop, but it can't bootstrap the things needed to
run `install.sh` in the first place. The `base` metapackage has no `sudo`, no
`git`, no editor, and no pager — so `man` doesn't work and `pacman -Si` can't
page. `linux-firmware` is only an *optional* dep of the kernel, and without it
the wifi and bluetooth radios never appear, which makes `impala` and `bluetui`
useless. On a minimal Arch install, first:

```bash
pacman -S --needed sudo git less nano man-db man-pages linux-firmware base-devel
```

Two entries in `packages.txt` — `zen-browser-bin` and `herdr` — are AUR-only, so
you also need a helper. `install.sh` uses `paru` when it's on `PATH` and falls
back to plain `pacman` otherwise (which will then fail loudly on exactly those
two names). `paru` itself has to be bootstrapped by hand, which is what
`base-devel` above is for:

```bash
git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si
```

`paru-bin` rather than `paru` because the latter builds from source and pulls in
the whole Rust toolchain to do it. If you added the CachyOS repos above, skip the
clone entirely — `paru` is prebuilt there:

```bash
sudo pacman -S paru
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

### On the CachyOS kernel

Nothing in `packages.txt` is kernel-coupled — it's all userspace, so the desktop
is identical on `linux`, `linux-zen`, or `linux-cachyos`. The kernel, its
headers, the bootloader, and the CachyOS repos themselves are install-time
concerns this repo deliberately stays out of.

`linux-cachyos`, `cachyos-settings`, `chwd`, and `uksmd` are **not** in Arch's
own repos — a fresh minimal Arch reaches them only after adding CachyOS's, which
their script does in one step:

```bash
curl https://mirror.cachyos.org/cachyos-repo.tar.xz | tar xJ && \
    cd cachyos-repo && sudo ./cachyos-repo.sh
sudo pacman -S linux-cachyos linux-cachyos-headers
```

That adds `cachyos`, `cachyos-core-v3`, and `cachyos-extra-v3`, which also carry
`-O3`/`x86-64-v3` rebuilds of ordinary Arch packages. Install the headers in the
same transaction as the kernel, or `nvidia-open-dkms` has nothing to build
against.

Two optional extras that pair well with it, both in Arch's own `extra`:

```bash
sudo pacman -S --needed scx-scheds ananicy-cpp
```

`scx-scheds` is the sched_ext scheduler set — `scx_lavd` is the one tuned for
interactive latency. It needs `CONFIG_SCHED_CLASS_EXT`, which CachyOS enables and
stock Arch has had since 6.12; check with `ls /sys/kernel/sched_ext`.
`ananicy-cpp` applies nice/ioclass rules per process.

One thing CachyOS gives you for free that plain Arch does not: zram, via
`cachyos-settings`. On stock Arch it's the `zram-generator` package plus a short
`/etc/systemd/zram-generator.conf`. Check with `zramctl`.

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

`zen-browser-bin` is installed but **not** configured here — its profile lives
in `~/.zen`, is 689 MB, and is machine-state rather than config. Same reasoning
for `herdr`: `config.toml` is tracked, while the sockets, logs, and
`release-notes.json` that share that directory are not.

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
| `SHIFT + Q` | power menu (suspend / reboot / poweroff, via fuzzel) |
| `S` | show/hide the scratchpad workspace |
| `SHIFT + M` | move window to the scratchpad |
| `SHIFT + S` | screenshot region to clipboard |
| `Print` | screenshot whole screen to `~/Pictures` |
| `SHIFT + V` | clipboard history (cliphist via fuzzel) |
| `SHIFT + T` | theme picker |
| `SHIFT + N` | night light on/off (hyprsunset, 4000K) |
| `B` | status notification: time, battery, network |
| arrows | move focus |
| `SHIFT` + arrows | move window |
| `1`–`5` | switch workspace |
| `SHIFT` + `1`–`5` | move window to workspace |
| drag / right-drag | move / resize window |

Volume, brightness, and media function keys are bound too, and the volume and
brightness ones keep working while the lock screen is up.

## Themes

`config/themes/current` is a symlink naming the active theme, and flipping it is
the entire mechanism — there is no generator and nothing is templated. Each app
pulls its colours out of `current/` through its own native include:

| App | How |
| --- | --- |
| foot, fuzzel | `include=~/.config/themes/current/…` |
| hyprlock | `source = …`, then `$bg` / `$fg` / `$accent` / `$field` |
| waybar | `@import url("../themes/current/waybar.css")` |
| mako | `config/mako/config` *is* a symlink — mako has no include |
| nvim | `lua/plugins/theme.lua` *is* a symlink, returning a LazyVim spec |
| Hyprland | `hyprland.lua` `dofile`s `current/hyprland.lua` for border colours |
| swaybg | `swaybg -c "$(cat …/current/background)"` — one hex per theme |

`SUPER+SHIFT+T` lists the theme directories in fuzzel, repoints `current`, then
reloads in place everything that can: mako, waybar, and Hyprland itself via
`hyprctl reload`. foot, fuzzel, hyprlock and nvim pick the new colours up the
next time they launch.

Three themes ship: `tokyo-night`, `tokyo-day`, and `aura` (ported from the
Omarchy theme of the same name). To add a fourth, copy any of them and edit the
eight files — it shows up in the picker with no other change.

The one thing deliberately not themed is waybar's critical-battery red: critical
is critical whatever the palette.

## Changing things

`config/hypr/hyprland.lua` is the entry point — monitors, environment, and five
`require()`s. Each of those is its own Lua scope, so a syntax error in one file
costs you that file's settings rather than the session. Upstream recommends this
split in the comments of its own example config.

| File | Holds |
| --- | --- |
| `looknfeel.lua` | borders, gaps, decoration, animation curves |
| `input.lua` | keyboard, pointer, touchpad, gestures |
| `rules.lua` | window and layer rules |
| `autostart.lua` | the `hyprland.start` handler |
| `bindings.lua` | keybinds |

The full Lua API is stubbed at `/usr/share/hypr/stubs/hl.meta.lua`, and
upstream's annotated example config at `/usr/share/hypr/hyprland.lua` is worth
reading — it has ready-made blocks for gestures, window rules, and per-device
input settings.

To add another autostarted program, write its config under `config/` and add one
`hl.exec_cmd("…")` line to the `hyprland.start` handler. Check it before you
restart into it — `luac -p config/hypr/*.lua` catches the syntax errors that
would otherwise greet you as a black screen.
