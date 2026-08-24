import QtQuick
import qs
import qs.Commons
import qs.Ui

Row {
  required property var app
  spacing: 0
  PillButton { barStyle: true; fixedWidth: Style.statusSlot; horizontalPadding: 0; fontSize: Style.captionFontSize; text: "󰍬"; opacity: 0.45; tooltip: "Dictation unavailable"; acceptedButtons: Qt.NoButton }
  PillButton { barStyle: true; fixedWidth: Style.statusSlot; horizontalPadding: 0; fontSize: Style.captionFontSize; text: "󰻂"; opacity: 0.45; tooltip: "Screen recording unavailable"; acceptedButtons: Qt.NoButton }
  PillButton { barStyle: true; fixedWidth: Style.statusSlot; horizontalPadding: 0; fontSize: Style.captionFontSize; text: "󰅶"; tooltip: app.stayAwake.error || (app.stayAwake.enabled ? "Allow Idle Lock & Screensaver" : "Stay Awake"); opacity: app.stayAwake.enabled ? 1 : 0.45; onClicked: app.stayAwake.toggle() }
  PillButton { barStyle: true; fixedWidth: Style.statusSlot; horizontalPadding: 0; fontSize: Style.captionFontSize; text: "󰂛"; tooltip: app.dnd.enabled ? "Allow Notifications" : "Silence Notifications"; opacity: app.dnd.enabled ? 1 : 0.45; onClicked: app.dnd.toggle() }
}
