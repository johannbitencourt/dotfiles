import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.Commons

PopupWindow {
  id: root
  required property var coordinator
  required property var barWindow
  required property var screen
  property var panelItem: null
  property var cyclePanel: null
  default property alias contentItem: holder.data
  property int desiredHeight: holder.children.length ? holder.children[0].implicitHeight + Style.pad * 2 : 200
  readonly property bool open: coordinator.page !== "" && coordinator.screenName === String(screen.name)
  visible: open && Quickshell.env("QS_VALIDATE") !== "1"
  grabFocus: true
  color: "transparent"; implicitWidth: Math.min(Style.panelWidth, screen.width - Style.outerMargin * 2)
  implicitHeight: Math.min(desiredHeight, screen.height - 50)
  anchor.window: barWindow
  anchor.adjustment: PopupAdjustment.Slide
  anchor.edges: Edges.Top | Edges.Left; anchor.gravity: Edges.Bottom | Edges.Right
  anchor.rect.width: 1; anchor.rect.height: 1
  anchor.rect.x: {
    var item = coordinator.anchorItem
    if (!item || !item.QsWindow || item.QsWindow.window !== barWindow) return barWindow.width / 2 - implicitWidth / 2
    var p = item.mapToItem(barWindow.contentItem, item.width / 2, 0)
    return Math.max(Style.outerMargin, Math.min(barWindow.width - implicitWidth - Style.outerMargin, p.x - implicitWidth / 2))
  }
  anchor.rect.y: 31
  HyprlandFocusGrab { active: root.open; windows: [root, barWindow]; onCleared: coordinator.close() }
  Card { anchors.fill: parent
    Flickable {
      id: scroll
      anchors.fill: parent; anchors.margins: Style.pad
      clip: true; contentWidth: width; contentHeight: holder.height
      interactive: contentHeight > height
      Item {
        id: holder
        width: scroll.width
        height: children.length ? children[0].implicitHeight : 0
      }
    }
  }
  Item {
    id: keyHandler; focus: root.open; Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape) coordinator.close()
      else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
        if (root.cyclePanel) root.cyclePanel(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1)
      } else if (root.panelItem && typeof root.panelItem.handleKey === "function") {
        if (!root.panelItem.handleKey(event.key, event.text, event.modifiers)) return
      } else return
      event.accepted = true
    }
  }
  onVisibleChanged: if (visible) keyHandler.forceActiveFocus()
}
