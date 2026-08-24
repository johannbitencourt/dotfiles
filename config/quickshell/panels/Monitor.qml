import Quickshell.Hyprland
import QtQuick
import qs
import qs.Ui

Column {
  id: root
  required property var app
  required property var screen
  readonly property var monitor: Hyprland.monitorFor(screen)
  function handleKey(key, text, modifiers) { if (key === Qt.Key_Left || text === "h") { if (app.brightness.supported) app.brightness.set(app.brightness.value - 5); return true } if (key === Qt.Key_Right || text === "l") { if (app.brightness.supported) app.brightness.set(app.brightness.value + 5); return true } return false }
  spacing: 10
  PanelHeader { title: "Monitor"; subtitle: monitor ? monitor.name : screen.name; onClose: app.popups.close() }
  Text { text: monitor ? monitor.description : "Focused output unavailable"; color: Theme.foreground; font.family: Theme.fontFamily; width: parent.width; wrapMode: Text.WordWrap }
  Text { text: monitor ? monitor.width + "×" + monitor.height + "  scale " + monitor.scale : screen.width + "×" + screen.height; color: Theme.muted; font.family: Theme.fontFamily }
  Text { text: app.brightness.supported ? "INTERNAL BRIGHTNESS  " + app.brightness.value + "%" : "External display brightness is unsupported (no internal backlight)."; color: app.brightness.supported ? Theme.foreground : Theme.warning; font.family: Theme.fontFamily; width: parent.width; wrapMode: Text.WordWrap }
  PanelSlider { visible: app.brightness.supported; width: parent.width; from: 1; to: 100; value: app.brightness.value; onMoved: app.brightness.set(value) }
  Text { visible: app.platform.id === "omarchy"; text: "TEXT SIZE"; color: Theme.muted; font.family: Theme.fontFamily }
  Row { visible: app.platform.id === "omarchy"; spacing: 4
    Repeater { model: [9, 10, 11, 12, 14, 16, 20]
      PillButton { required property int modelData; text: String(modelData); onClicked: app.commands.run("monitor-control", ["text", String(modelData)]) }
    }
  }
  Text { text: "DISPLAY SCALE"; color: Theme.muted; font.family: Theme.fontFamily }
  Row { spacing: 4
    Repeater { model: [1, 1.25, 1.6, 2, 3, 4]
      PillButton { required property real modelData; text: String(modelData); active: root.monitor && Math.abs(root.monitor.scale - modelData) < 0.01; onClicked: if (root.monitor) app.commands.run("monitor-control", ["scale", root.monitor.name, String(modelData)]) }
    }
  }
  Text { text: "DISPLAYS"; color: Theme.muted; font.family: Theme.fontFamily }
  Text { visible: app.monitors.error !== ""; width: parent.width; text: app.monitors.error; color: Theme.critical; font.family: Theme.fontFamily; wrapMode: Text.WordWrap }
  Repeater { model: app.monitors.outputs
    Row { required property var modelData; width: parent.width; spacing: 5
      Text { anchors.verticalCenter: parent.verticalCenter; width: 255; text: modelData.name + "  " + (modelData.description || ""); color: modelData.disabled ? Theme.muted : Theme.foreground; font.family: Theme.fontFamily; elide: Text.ElideRight }
      PillButton { text: app.monitors.pendingName === modelData.name ? "Working…" : (modelData.disabled ? "Enable" : "Disable"); interactive: app.monitors.pendingName === ""; onClicked: app.monitors.setEnabled(modelData.name, modelData.disabled) }
    }
  }
}
