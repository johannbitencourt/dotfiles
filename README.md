# CachyOS + Hyprland + DMS dotfiles

Personal, machine-aware configuration managed by [chezmoi](https://www.chezmoi.io/).
The repository expects a minimal CachyOS installation and deliberately does not
vendor CachyOS, Hyprland, or DankMaterialShell defaults.

## Ownership model

- CachyOS owns the operating system, kernel, drivers, and package repositories.
- DMS owns its settings and generated files under `~/.config/DankMaterialShell`
  and `~/.config/hypr/dms`.
- Chezmoi owns stable personal configuration around those generated files.
- DMS owns machine-specific display profiles; CachyOS owns GPU drivers.

Waybar, Walker, Mako, SwayOSD, and Omarchy are intentionally absent. DMS
provides the bar, launcher, notifications, OSD, lock screen, wallpaper,
clipboard, process list, and power UI.

## Fresh installation

Install CachyOS Minimal without a desktop, connect to the network, then run:

```bash
sudo pacman -S --needed git chezmoi git-delta
sudo mkdir /dotfiles
sudo chown "$USER:$USER" /dotfiles
git clone <repository-url> /dotfiles
chezmoi init --source /dotfiles
chezmoi diff
chezmoi apply
```

`chezmoi init` prompts for identity, performance preference, and optional
package profiles. Maximum-efficiency mode disables Hyprland animations, blur,
and shadows by default; choose `false` to retain those visual effects. The apply
installs packages, asks DMS to generate its integration files, and connects DMS
to the Hyprland user-session target. The greeter is disabled by default because
enabling it replaces the current display manager with greetd.

The apply performs a full system upgrade, can change the hostname, enables
selected system services, and can add the user to privileged Docker/libvirt
groups. Review `chezmoi apply --dry-run --verbose` before applying. On an
existing installation, back up `~/.config/hypr` first. The legacy migration
only removes `.conf` files carrying this repository's previous ownership marker
and saves them under `~/.config/hypr/legacy-conf-backup`.

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

## Package profiles

The default installation is intentionally limited to Hyprland, DMS, audio,
networking, portals, the configured terminal/editor/file manager, and the CLI
tools referenced by these dotfiles. Additional prompts control independent
profiles:

| Profile | Packages |
|---|---|
| Bluetooth | `bluez`, `bluez-utils` |
| Laptop | `brightnessctl`, `power-profiles-daemon` |
| Development | Godot, GitHub CLI, lazygit/lazydocker, jq/yq, OpenCode |
| Docker | Docker Engine, Buildx, Compose, root-equivalent group access, socket-activated daemon |
| Virtualization | QEMU, socket-activated libvirt, virt-manager, swtpm, dnsmasq |
| Gaming | Steam, Lutris, GameMode, Gamescope, MangoHud |
| Desktop apps | Brave, Zen, Spotify, Obsidian, LibreOffice, mpv, imv, Flatpak |

Steam and Lutris are never installed unless the gaming profile is selected.
GPU drivers, including matching 32-bit gaming libraries, are never selected by
chezmoi. CachyOS owns the kernel and driver branch. Confirm the correct Vulkan
and 32-bit driver stack before enabling the gaming profile.

AUR packages use `paru` or `yay`. A selected AUR-backed profile fails clearly
when no helper is available; selected repository packages also fail rather than
leaving a partially installed desktop.

Package profiles are install-only. Turning a profile off later does not remove
packages, revoke group membership, disable an existing greeter, or undo system
configuration automatically.
