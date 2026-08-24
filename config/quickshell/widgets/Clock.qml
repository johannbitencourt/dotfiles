import Quickshell
import QtQuick
import qs.Ui

PillButton {
  required property var app
  readonly property int formatIndex: app.barSettings.clockFormatIndex
  readonly property var formats: ["h:mm AP", "MMM dd 'W'ww"]
  function cycleFormat() { app.barSettings.cycleClock(formats.length) }
  function isoWeek(date) {
    var value = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
    value.setUTCDate(value.getUTCDate() + 4 - (value.getUTCDay() || 7))
    var first = new Date(Date.UTC(value.getUTCFullYear(), 0, 1))
    return String(Math.ceil((((value - first) / 86400000) + 1) / 7)).padStart(2, "0")
  }
  function formatted() {
    var format = formats[formatIndex]
    if (format.indexOf("ww") >= 0) format = format.replace("ww", isoWeek(clock.date))
    return Qt.formatDateTime(clock.date, format)
  }
  barStyle: true; horizontalPadding: 8.75
  SystemClock { id: clock; precision: SystemClock.Minutes }
  text: formatted()
}
