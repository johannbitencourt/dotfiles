import Quickshell.Wayland
import QtQuick
import qs.Ui

PillButton {
  id: root
  acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
  required property var screen
  readonly property var toplevel: ToplevelManager.activeToplevel
  text: toplevel ? String(toplevel.title || toplevel.appId || "") : ""
  visible: text !== ""; width: visible ? implicitWidth : 0
  barStyle: true; horizontalPadding: 10; maxTextWidth: 240; textOpacity: 0.85
  tooltip: text
  Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  onClicked: mouse => { if (!toplevel) return; if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton) toplevel.close(); else toplevel.activate() }
}
