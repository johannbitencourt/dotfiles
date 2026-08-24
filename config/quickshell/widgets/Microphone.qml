import QtQuick
import qs
import qs.Commons
import qs.Ui

PillButton {
  required property var app
  signal openAudio()
  readonly property var audio: app.source && app.source.audio ? app.source.audio : null
  readonly property bool inUse: app.pipewireNodes.some(n => n && n.isStream && !n.isSink && n.audio && !n.audio.muted)
  barStyle: true; fixedWidth: Style.iconSlot; horizontalPadding: 0; fontSize: Style.iconFontSize
  visible: audio !== null; width: visible ? implicitWidth : 0
  text: audio && audio.muted ? "󰍭" : "󰍬"
  tooltip: audio && audio.muted ? "Microphone muted" : (inUse ? "Microphone in use" : "Microphone live")
  onClicked: mouse => { if (mouse.button === Qt.MiddleButton) openAudio(); else if (audio) audio.muted = !audio.muted }
  onWheel: wheel => app.setInputVolume((audio ? audio.volume : 0) + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
}
