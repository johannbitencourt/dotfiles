# Package rationale

The manifests are the source of truth for the package bootstrap. The onchange
installer embeds and reads them directly, so edits retrigger installation.
Selected repository packages are required and a missing package aborts cleanly.

## Required desktop

| Packages | Reason |
|---|---|
| `hyprland` | Wayland compositor |
| `dms-shell` | Desktop shell; already depends on Quickshell, `dgop`, AccountsService, and the DMS compositor integration |
| `networkmanager` | Recommended DMS network backend |
| `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` | Screen sharing plus GTK file chooser fallback |
| `pipewire`, `pipewire-pulse`, `wireplumber` | Audio server and session manager |
| `wl-clipboard`, `wtype` | DMS clipboard and paste support without a persistent external clipboard recorder |
| `matugen`, `adw-gtk-theme` | Dynamic DMS, terminal, editor, and GTK colors |
| `gnome-keyring` | Secret Service storage for browsers and desktop applications |
| `ghostty`, `nautilus`, `chromium` | Default terminal, file manager, and repository-provided browser |
| `noto-fonts`, `noto-fonts-emoji`, `ttf-cascadia-mono-nerd` | UI, emoji, terminal, and icon glyph coverage |
| `git`, `chezmoi`, `git-delta` | Dotfile management and configured diff pager |

## Required CLI

The CLI manifest contains programs directly initialized by shell config,
referenced by keybindings, used by Neovim/LazyVim, or configured in this repo:
Neovim, Starship, mise, zoxide, eza, bat, fd, ripgrep, fzf, Git LFS, btop,
fastfetch, unzip, less, Bash completion, and man pages.

## Optional profiles

- `laptop.txt`: internal display brightness and DMS power profiles.
- `bluetooth.txt`: Bluetooth daemon and diagnostics.
- `development.txt`: Godot, OpenCode, GitHub and development TUI tools.
- `docker.txt`: Docker Engine and CLI plugins; group access is a separate explicit opt-in and the daemon is socket-activated.
- `virtualization.txt`: QEMU/libvirt stack.
- `gaming.txt`: Steam, Lutris, GameMode, Gamescope, and MangoHud.
- `desktop.txt`: nonessential GUI applications from official repositories.
- `aur-base.txt`: AUR build prerequisites, only requested when an AUR-backed profile or DMS greeter is selected.

## Deliberate omissions

- GPU kernel drivers and kernel headers are owned by CachyOS, not dotfiles.
- Steam and Lutris are gaming applications, not Hyprland or DMS dependencies.
- `dsearch`, Cava, calendar integration, printer tooling, I2C/DDC brightness,
  Qt sound effects, fingerprint support, and screenshot tools are optional DMS
  features and are not installed until the corresponding feature is wanted.
- Waybar, Walker, Mako, and SwayOSD are replaced by DMS.
