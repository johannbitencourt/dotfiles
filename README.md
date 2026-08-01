# CachyOS + Hyprland + DMS dotfiles

Personal, machine-aware configuration managed by [chezmoi](https://www.chezmoi.io/).
The repository expects a minimal CachyOS installation and deliberately does not
vendor CachyOS, Hyprland, or DankMaterialShell defaults.

## Ownership model

- CachyOS owns the operating system, kernel, drivers, and package repositories.
- DMS owns its settings and generated files under `~/.config/DankMaterialShell`
  and `~/.config/hypr/dms`.
- Chezmoi owns stable personal configuration around those generated files.
- Machine-specific monitor and NVIDIA settings are rendered from chezmoi data.

Waybar, Walker, Mako, SwayOSD, and Omarchy are intentionally absent. DMS
provides the bar, launcher, notifications, OSD, lock screen, wallpaper,
clipboard, process list, and power UI.

## Fresh installation

Install CachyOS Minimal without a desktop, connect to the network, then run:

```bash
sudo pacman -S --needed git chezmoi
sudo mkdir /dotfiles
sudo chown "$USER:$USER" /dotfiles
git clone <repository-url> /dotfiles
chezmoi init --source /dotfiles
chezmoi diff
chezmoi apply
```

The first apply prompts for identity, hardware, optional applications, and the
DMS greeter. It installs packages, asks DMS to generate its integration files,
and connects DMS to the Hyprland user-session target. Selecting the greeter
runs the official `dms greeter install` flow, which configures greetd.

Reboot after the initial apply. At the next session, customize bars, displays,
wallpaper, sleep, and theme from DMS Settings. Those runtime values are not
committed because they are DMS state rather than portable preferences.

## Existing installation

Review changes before applying:

```bash
chezmoi init --source /dotfiles
chezmoi diff
chezmoi apply --dry-run --verbose
chezmoi apply
```

## Maintenance

```bash
chezmoi cd
chezmoi status
chezmoi diff
chezmoi apply
dms doctor
hyprctl reload
hyprctl configerrors
```

Use `chezmoi data` to inspect machine values. Change them in the local chezmoi
config and re-run `chezmoi apply`; do not hardcode hardware values in tracked
files.

## Optional AUR applications

The bootstrap installs only packages available through configured pacman
repositories. Install personal AUR applications separately as needed:

```bash
paru -S brave-bin zen-browser-bin spotify obsidian opencode
```
# dotfiles
# dotfiles
