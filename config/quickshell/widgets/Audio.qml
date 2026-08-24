import QtQuick
import qs.Commons
import qs.Ui

PillButton {
  required property var app
  readonly property var audio: app.sink && app.sink.audio ? app.sink.audio : null
  readonly property real volume: audio ? audio.volume : 0
  function icon() {
    var label = String(app.sink ? (app.sink.description || app.sink.name || "") : "").toLowerCase()
    if (!audio || audio.muted || volume <= 0) return ""
    if (label.indexOf("headphone") >= 0 || label.indexOf("headset") >= 0) return "󰋋"
    return volume >= 0.67 ? "" : (volume >= 0.34 ? "" : "")
  }
  barStyle: true; fixedWidth: Style.iconSlot * 2; horizontalPadding: 0
  text: Math.round(volume * 100) + "% " + icon(); tooltip: "Audio"
  onWheel: wheel => app.setOutputVolume(volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
}
