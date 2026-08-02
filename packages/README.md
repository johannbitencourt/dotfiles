# Package rationale

Package manifests are the bootstrap source of truth. Only selected profile
contents are embedded in the onchange installer, so unrelated optional-profile
edits do not trigger package installation.

## Required desktop

| Packages | Reason |
|---|---|
| `hyprland`, `uwsm` | Compositor and systemd-managed Wayland session |
| `greetd-tuigreet` | Small console display manager with fixed UWSM startup |
| `foot`, `fuzzel`, `mako` | Terminal, launcher, and notifications |
| `waybar` | Status bar; the only GTK toolkit process in the session |
| `hypridle`, `hyprlock` | Idle handling and secure locking |
| `iwd`, systemd networking | Optional managed Wi-Fi, DHCP, and DNS stack |
| `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` | Screen sharing and file chooser portals |
| `pipewire`, `pipewire-pulse`, `wireplumber` | Audio server and session manager |
| `polkit-gnome` | Authentication agent for privileged desktop actions |
| `wl-clipboard`, `grim`, `slurp`, `libnotify` | Clipboard and screenshots without history recording |
| `noto-fonts`, `noto-fonts-emoji`, `ttf-cascadia-mono-nerd` | Text, emoji, and terminal glyph coverage |

The browser is not a manifest entry. Whatever the `browser` prompt names is
installed when that name is also an official repository package, so choosing
Firefox does not drag Chromium in. An AUR or Flatpak browser is reported and
left to the user. Chromium's managed policy disabling its built-in password
manager is installed only when Chromium is the chosen browser.

CLI packages are initialized by shell configuration, referenced by bindings,
used by Neovim, or configured in this repository. They consume no memory merely
because they are installed.

## Deliberately absent

| Package | Replaced by |
|---|---|
| `swayosd` | `~/.local/bin/osd`, which drives `wpctl`/`brightnessctl` and draws feedback through the already-running notification daemon. Avoids a resident GTK4 and libadwaita process. |
| `swaybg` | Hyprland's built-in `misc:background_color`. Avoids a resident process for a solid background. |

Adding `swaybg` or `hyprpaper` back is the supported way to use an image
wallpaper; nothing else in the configuration depends on their absence.

## Optional profiles

- `laptop.txt`: brightness controls and power profiles.
- `bluetooth.txt`: Bluetooth daemon and diagnostics.
- `development.txt`: Godot, OpenCode, GitHub, and development TUI tools.
- `docker.txt`: Docker with socket activation and explicit privileged access.
- `virtualization.txt`: QEMU/libvirt; group access is a separate prompt.
- `gaming.txt`: Steam, Lutris, GameMode, Gamescope, and MangoHud.
- `desktop.txt`: optional official-repository GUI applications.
- `desktop-aur.txt`: optional third-party AUR applications.
- `aur-base.txt`: AUR build prerequisites.

GPU drivers, kernel modules, monitor identifiers, and bootloader settings remain
hardware-specific and owned by the operating system. Optional profiles are not
automatically uninstalled when their prompts are later disabled.
