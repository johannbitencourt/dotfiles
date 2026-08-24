import Quickshell.Services.UPower
import QtQuick
import qs
import qs.Commons
import qs.Ui

PillButton {
  required property var app
  readonly property bool showPercentage: app.barSettings.showBatteryPercentage
  readonly property var battery: app.battery
  readonly property int percent: battery && battery.isPresent ? Math.round(battery.percentage * 100) : 0
  function icon() {
    if (!battery || !battery.isPresent) return "󰐥"
    var charging = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
    var normal = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    var index = Math.max(0, Math.min(9, Math.floor(battery.percentage * 10)))
    if (battery.state === UPowerDeviceState.FullyCharged) return "󰂅"
    return app.onBattery ? normal[index] : charging[index]
  }
  barStyle: true; fixedWidth: Style.iconSlot * (showPercentage ? 2 : 1); horizontalPadding: 0
  visible: !!battery && battery.isPresent; width: visible ? implicitWidth : 0
  text: showPercentage ? percent + "% " + icon() : icon()
  textColor: percent < 15 && app.onBattery ? Theme.critical : Theme.foreground; tooltip: "Power"
}
