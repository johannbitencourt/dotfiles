import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.Ui

Column {
  required property var app
  spacing: 8
  PanelHeader { title: "Tray"; subtitle: "Pin or hide reported items"; onClose: app.popups.close() }
  Text { visible: SystemTray.items.values.length === 0; text: "No tray items reporting."; color: Theme.muted; font.family: Theme.fontFamily }
  Repeater { model: SystemTray.items
    Row { required property var modelData; width: parent.width; spacing: 5
      Text { anchors.verticalCenter: parent.verticalCenter; width: 180; text: modelData.tooltipTitle || modelData.title || modelData.id; color: Theme.foreground; font.family: Theme.fontFamily; elide: Text.ElideRight }
      PillButton { text: app.tray.contains(app.tray.pinnedIds, modelData.id) ? "Unpin" : "Pin"; onClicked: app.tray.togglePinned(modelData.id) }
      PillButton { text: app.tray.contains(app.tray.hiddenIds, modelData.id) ? "Show" : "Hide"; onClicked: app.tray.toggleHidden(modelData.id) }
    }
  }
}
