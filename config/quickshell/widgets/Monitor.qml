import Quickshell
import QtQuick
import qs.Commons
import qs.Ui

PillButton { required property var app; barStyle: true; fixedWidth: Style.iconSlot; horizontalPadding: 0; fontSize: Style.iconFontSize; text: Quickshell.screens.length > 1 ? "󰍺" : "󰍹"; tooltip: app.brightness.supported ? "Display brightness" : "External display: brightness unsupported"; onWheel: wheel => { if (app.brightness.supported) app.brightness.set(app.brightness.value + (wheel.angleDelta.y > 0 ? 5 : -5)) } }
