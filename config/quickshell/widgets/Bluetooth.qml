import Quickshell.Bluetooth
import QtQuick
import qs
import qs.Commons
import qs.Ui

PillButton {
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property int connected: { var n = 0; for (var i = 0; i < devices.length; i++) if (devices[i].connected) n++; return n }
  barStyle: true; fixedWidth: Style.iconSlot; horizontalPadding: 0; fontSize: Style.iconFontSize
  visible: adapter !== null; width: visible ? implicitWidth : 0
  text: !adapter || !adapter.enabled ? "󰂲" : (connected ? "󰂱" : "󰂯")
  tooltip: "Bluetooth"
}
