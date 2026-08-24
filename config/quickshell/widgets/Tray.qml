import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.Commons
import qs.Ui

Item {
  id: root
  required property var app
  signal manageRequested()
  property bool expanded: hover.hovered
  property real reveal: expanded ? 1 : 0
  readonly property var allItems: SystemTray.items.values.filter(item => item && item.status !== Status.Passive)
  readonly property var pinnedItems: allItems.filter(item => app.tray.contains(app.tray.pinnedIds, item.id))
  readonly property var drawerItems: allItems.filter(item => !app.tray.contains(app.tray.pinnedIds, item.id) && !app.tray.contains(app.tray.hiddenIds, item.id))
  implicitWidth: Style.iconSlot + pinnedItems.length * Style.iconSlot + drawerItems.length * Style.iconSlot * reveal
  implicitHeight: Style.barHeight
  clip: true
  Behavior on reveal { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
  HoverHandler { id: hover }

  component TrayItem: Item {
    id: slot
    required property var modelData
    width: Style.iconSlot; height: Style.barHeight
    Image { anchors.centerIn: parent; width: 12; height: 12; source: slot.modelData.icon; fillMode: Image.PreserveAspectFit }
    MouseArea {
      id: pointer
      anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      hoverEnabled: true; cursorShape: Qt.PointingHandCursor
      onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) slot.modelData.secondaryActivate()
        else if (mouse.button === Qt.RightButton || slot.modelData.onlyMenu) {
          var window = slot.QsWindow.window, point = slot.mapToItem(window.contentItem, mouse.x, mouse.y)
          slot.modelData.display(window, point.x, point.y)
        } else slot.modelData.activate()
      }
      onWheel: wheel => slot.modelData.scroll(wheel.angleDelta.y, false)
    }
    ToolTip { target: slot; text: slot.modelData.tooltipTitle || slot.modelData.title || slot.modelData.id; shown: pointer.containsMouse }
  }

  Row {
    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 0
    Item {
      width: Style.iconSlot; height: Style.barHeight
      Text { anchors.centerIn: parent; text: ""; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Style.iconFontSize; renderType: Text.NativeRendering }
      MouseArea { anchors.fill: parent; acceptedButtons: Qt.RightButton; cursorShape: Qt.PointingHandCursor; onClicked: root.manageRequested() }
    }
    Repeater { model: root.drawerItems; TrayItem {} }
    Repeater { model: root.pinnedItems; TrayItem {} }
  }
}
