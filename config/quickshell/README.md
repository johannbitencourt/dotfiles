# Standalone Quickshell desktop bar

This is a standalone Quickshell 0.3 desktop surface. It does not load Omarchy's
plugin host, `bar.shell`, plugin registry, or `OMARCHY_PATH`. `shell.qml`
creates exactly one `AppState` service graph and one `Bar` view per screen.
Polling and long-lived helpers belong to the shared graph, so adding monitors
does not duplicate network, weather, update, CPU, brightness, DND, or power
work.

## Architecture

- `Commons/`: structural style tokens and small utilities.
- `Ui/`: bar, buttons, cards, tooltips, sliders, cursor/key navigation,
  confirmation, popup coordination surfaces, and screen-move remapping.
- `services/`: shared application state, command adapters, popup ownership,
  updates, weather, CPU, iwd, brightness, DND, stay-awake, and power profiles.
- `widgets/`: the 14 independently composable bar widgets.
- `panels/`: Calendar, Weather, Bluetooth, Network, Audio, Monitor, Power, and
  SystemMenu popups.
- `helpers/iwd_bridge.py`: one long-lived Gio D-Bus bridge to iwd with a
  registered passphrase agent and JSON-lines stdin/stdout protocol.
- `scripts/`: small Arch/Void and session adapters.

Only one popup can be open globally. Its coordinator records the owning screen
and anchor item. `HyprlandFocusGrab` provides outside-click dismissal and
Escape closes the focused popup. Tab and Shift-Tab move between popup-capable
widgets in the same bar section, while panels expose their relevant
arrow/`hjkl`, activation, refresh, and toggle keys.

Bar mouse behavior follows the Omarchy widget contract: workspace and status
buttons accept every mouse button, clock middle/right actions open timezone
selection and cycle formats, weather middle/right actions refresh and notify,
Bluetooth right-click toggles power, audio right-click toggles output and input
mute together, microphone middle-click opens audio, and power right-click
toggles percentage display. Clock format, calendar week start, battery display,
Stay Awake, and tray pin/hide choices persist across shell restarts.

Weather supports a persisted city/location override while retaining cached
last-good data. Monitor controls enumerate enabled and disabled Hyprland
outputs, expose scale and Omarchy text-size presets, and refuse to disable the
final active display. Bluetooth rows report BlueZ transition and battery state,
allow pairing cancellation, and surface operation timeouts; discovery remains
stopped when stopped manually instead of immediately restarting.
iwd operations carry IDs so duplicate actions are blocked and failures stay
attached to the active operation instead of disappearing on the next snapshot.
The calendar includes year progress and an optional persisted life-progress
rail; double-click the year rail to configure it and double-click LIFE to clear
it.
On non-Omarchy systems, the system popup includes a keyboard-searchable native
desktop application list backed by Quickshell's DesktopEntries model. Omarchy
continues to open its own menu instead.

On Omarchy, the menu, update, DND, Stay Awake, terminal, monitor text size, and
power-profile adapters use the installed Omarchy commands and services. On
plain Arch and Void they use the standalone command, notification, inhibitor,
and power-profile backends instead. The standalone shell still does not load
the Omarchy plugin host.

## Dependencies

Required: Quickshell 0.3, Qt 6, Hyprland, Python 3, PyGObject (`gi`) and Gio.
The network panel talks directly to `net.connman.iwd`; NetworkManager and
`iwctl` are intentionally unsupported. Weather needs `curl`. Audio and media
use PipeWire and MPRIS through Quickshell. Bluetooth uses
`Quickshell.Bluetooth`. Battery details use UPower.

Optional adapters: `brightnessctl`, `powerprofilesctl`, `checkupdates`/Pacman
or XBPS, `makoctl`, `dunstctl`, `systemd-inhibit`,
`wayland-idle-inhibitor`, `hypridle`, and `btop`. A terminal is selected from
`$TERMINAL`, Foot, Alacritty, Kitty, Ghostty, WezTerm, or XTerm.

The theme is read from
`$HOME/.config/themes/current/quickshell.json`; missing or invalid files use
built-in defaults. `theme.example.json` documents the keys. Reload it with:

```sh
qs ipc call dotbar reloadTheme
```

## Validation

Static and hidden runtime checks:

```sh
qmllint shell.qml Theme.qml Commons/*.qml Ui/*.qml services/*.qml widgets/*.qml panels/*.qml
for file in scripts/*; do sh -n "$file"; done
python3 -m py_compile helpers/iwd_bridge.py
QS_VALIDATE=1 timeout 15 qs -p "$PWD"
QS_VALIDATE=1 QS_VALIDATE_PANEL=network timeout 15 qs -p "$PWD"
```

`QS_VALIDATE=1` keeps all bar and popup surfaces unmapped while constructing
the service and view graph. `QS_VALIDATE_PANEL` additionally constructs one of
`calendar`, `weather`, `bluetooth`, `network`, `audio`, `monitor`, `power`,
`system`, or `tray`. A portal registration warning can appear when another
QApplication-based shell is already connected; it is harmless.

## Known constraints

- Quickshell 0.3 does not expose monitor DDC/CI controls. External monitors
  therefore show an explicit unsupported brightness state; internal backlights
  use `brightnessctl`.
- Tray submenus use Quickshell's native platform menu fallback. The entry-point
  pragma enables QApplication mode for this. Custom in-popup nested menus are
  not reimplemented.
- Bluetooth pairing is available only when the installed Quickshell Bluetooth
  backend and BlueZ can complete the requested pairing method. Unsupported
  agent interactions remain explicit backend errors.
- iwd radio power control depends on the optional `Adapter.Powered` property.
  The bridge remains available and reports an operation error if an iwd build
  omits it.
- Native iwd scan/connect/disconnect/forget, passphrase, private-key passphrase,
  and username/password agent flows require validation on an iwd host. The
  current Omarchy development machine runs NetworkManager instead.
- Per-monitor active-window labels use Hyprland's toplevel/monitor mapping.
  On an unfocused output, Hyprland exposes the most recently enumerated
  toplevel rather than a compositor-defined "active" client.

## Attribution

The segmented visual language, popup interaction patterns, keyboard cursor
model, screen remap guard, and workspace behavior were designed with the MIT
licensed Omarchy shell under `/usr/share/omarchy/shell` as a reference. The
retained MIT notice and attribution are in `LICENSES/README.md`. This project
contains no Agents, Dictation, or Screen Recording components.
