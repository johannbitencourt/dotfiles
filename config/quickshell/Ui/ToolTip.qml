import Quickshell
import QtQuick
import qs
import qs.Commons

PopupWindow {
  id: root
  required property Item target
  property string text: ""
  property bool shown: false
  property bool ready: false
  readonly property Item windowContent: target && target.QsWindow.window ? target.QsWindow.window.contentItem : null
  visible: shown && ready && text !== ""
  onShownChanged: { if (shown) delay.restart(); else ready = false }
  color: "transparent"; implicitWidth: label.implicitWidth + 18; implicitHeight: 28
  anchor.window: target ? target.QsWindow.window : null
  anchor.rect.x: {
    return windowContent ? target.mapToItem(windowContent, target.width / 2 - implicitWidth / 2, 0).x : 0
  }
  anchor.rect.y: {
    return windowContent ? target.mapToItem(windowContent, 0, target.height + 5).y : 0
  }
  anchor.rect.width: 1; anchor.rect.height: 1
  anchor.edges: Edges.Top | Edges.Left; anchor.gravity: Edges.Bottom | Edges.Right
  Timer { id: delay; interval: 400; onTriggered: if (root.shown) root.ready = true }
  Rectangle { anchors.fill: parent; radius: 7; color: Style.alpha(Theme.background, 0.97); border.color: Theme.foreground; border.width: 1
    Text { id: label; anchors.centerIn: parent; text: root.text; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
  }
}
