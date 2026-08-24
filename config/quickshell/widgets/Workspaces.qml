import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  required property var screen
  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5], values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) if (values[i].id > 0 && values[i].id <= 10 && ids.indexOf(values[i].id) < 0) ids.push(values[i].id)
    return ids.sort((a, b) => a - b)
  }
  function workspace(id) { var v = Hyprland.workspaces.values; for (var i = 0; i < v.length; i++) if (v[i].id === id) return v[i]; return null }
  implicitWidth: row.implicitWidth + 1.5; implicitHeight: Style.barHeight
  Row { id: row; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 1
    Repeater { model: root.workspaceIds()
      PillButton {
        required property int modelData
        readonly property var ws: root.workspace(modelData)
        readonly property bool focused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData
        text: focused ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData))
        barStyle: true; fixedWidth: 20; horizontalPadding: 0
        opacity: focused || (ws && ws.toplevels && ws.toplevels.values.length > 0) ? 1 : 0.5
        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + modelData + "\" })"])
      }
    }
  }
}
