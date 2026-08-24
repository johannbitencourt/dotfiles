import Quickshell
import QtQuick
import qs.Commons
import qs.Ui

PillButton {
  required property var app
  function icon(condition) {
    var value = String(condition || "").toLowerCase()
    if (value.indexOf("thunder") >= 0) return "󰙾"
    if (value.indexOf("snow") >= 0 || value.indexOf("sleet") >= 0) return "󰖘"
    if (value.indexOf("rain") >= 0 || value.indexOf("drizzle") >= 0) return "󰖗"
    if (value.indexOf("fog") >= 0 || value.indexOf("mist") >= 0) return "󰖑"
    if (value.indexOf("sun") >= 0 || value.indexOf("clear") >= 0) return "󰖙"
    return "󰖐"
  }
  barStyle: true; fixedWidth: Style.statusSlot; horizontalPadding: 0; fontSize: Style.iconFontSize
  visible: app.weather.data.condition !== ""; width: visible ? implicitWidth : 0
  text: icon(app.weather.data.condition)
  function notifyStatus() { Quickshell.execDetached(["notify-send", app.weather.data.location || "Weather", app.weather.data.current + "  " + app.weather.data.condition]) }
}
