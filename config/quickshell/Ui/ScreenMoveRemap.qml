import QtQuick

Item {
  id: root
  required property var window
  readonly property var watchedScreen: window ? window.screen : null
  property bool remapping: false
  visible: false
  Timer { id: settle; interval: 200; onTriggered: root.remapping = true }
  Timer { interval: 50; running: root.remapping; onTriggered: root.remapping = false }
  Connections { target: root.watchedScreen; function onXChanged() { settle.restart() } function onYChanged() { settle.restart() } }
}
