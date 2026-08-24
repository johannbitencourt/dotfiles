import Quickshell.Services.Pipewire
import QtQuick
import qs
import qs.Ui

Column {
  id: root
  required property var app
  readonly property var sink: app.sink
  readonly property var source: app.source
  readonly property var sinks: app.pipewireNodes.filter(n => n && n.isSink && !n.isStream)
  readonly property var sources: app.pipewireNodes.filter(n => n && !n.isSink && !n.isStream && n.audio)
  function isPlaybackStream(node) { var type = String(node ? node.type || "" : ""); return !!node && node.isStream && (node.isSink === true || type.indexOf("Stream/Output/Audio") >= 0 || type.indexOf("AudioOutStream") >= 0 || type.indexOf("Output") >= 0) }
  readonly property var streams: app.pipewireNodes.filter(n => isPlaybackStream(n) && n.audio && String(n.name || "").indexOf("omarchy_speaker_tuning") !== 0)
  function handleKey(key, text, modifiers) {
    if (text === "m" || key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) { app.toggleAllMuted(); return true }
    if (key === Qt.Key_Left || text === "h") { app.setOutputVolume((sink && sink.audio ? sink.audio.volume : 0) - 0.05); return true }
    if (key === Qt.Key_Right || text === "l") { app.setOutputVolume((sink && sink.audio ? sink.audio.volume : 0) + 0.05); return true }
    return false
  }
  spacing: 9
  PanelHeader { title: "Audio"; subtitle: sink ? (sink.description || sink.name || "Output") : "No output"; onClose: app.popups.close() }
  Row { spacing: 5
    Text { anchors.verticalCenter: parent.verticalCenter; width: 250; text: "OUTPUT  " + Math.round((sink && sink.audio ? sink.audio.volume : 0) * 100) + "%"; color: Theme.muted; font.family: Theme.fontFamily }
    PillButton { text: sink && sink.audio && sink.audio.muted ? "Unmute" : "Mute"; onClicked: if (sink && sink.audio) sink.audio.muted = !sink.audio.muted }
  }
  PanelSlider { width: parent.width; from: 0; to: 1; value: sink && sink.audio ? sink.audio.volume : 0; onMoved: app.setOutputVolume(value) }
  Repeater { model: root.sinks
    PillButton { required property var modelData; width: parent.width; text: modelData.description || modelData.name; active: root.sink && modelData.id === root.sink.id; onClicked: Pipewire.preferredDefaultAudioSink = modelData }
  }
  Row { visible: !!source; spacing: 5
    Text { anchors.verticalCenter: parent.verticalCenter; width: 250; text: "INPUT  " + Math.round((source && source.audio ? source.audio.volume : 0) * 100) + "%"; color: Theme.muted; font.family: Theme.fontFamily }
    PillButton { text: source && source.audio && source.audio.muted ? "Unmute" : "Mute"; onClicked: if (source && source.audio) source.audio.muted = !source.audio.muted }
  }
  PanelSlider { visible: !!source; width: parent.width; from: 0; to: 1; value: source && source.audio ? source.audio.volume : 0; onMoved: app.setInputVolume(value) }
  Repeater { model: root.sources
    PillButton { required property var modelData; width: parent.width; text: modelData.description || modelData.name; active: root.source && modelData.id === root.source.id; onClicked: Pipewire.preferredDefaultAudioSource = modelData }
  }
  Text { visible: streams.length > 0; text: "APPLICATION STREAMS"; color: Theme.muted; font.family: Theme.fontFamily }
  Repeater { model: root.streams
    Row { required property var modelData; width: parent.width; spacing: 5
      PillButton { width: 38; text: modelData.audio && modelData.audio.muted ? "󰖁" : "󰕾"; onClicked: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted }
      Text { anchors.verticalCenter: parent.verticalCenter; width: 105; text: modelData.description || modelData.name || "Application"; color: Theme.foreground; font.family: Theme.fontFamily; elide: Text.ElideRight }
      PanelSlider { width: parent.width - 153; from: 0; to: 1.5; value: modelData && modelData.audio ? modelData.audio.volume : 0; onMoved: if (modelData && modelData.audio) modelData.audio.volume = value }
    }
  }
}
