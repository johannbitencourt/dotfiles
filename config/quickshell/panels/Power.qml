import QtQuick
import qs
import qs.Commons
import qs.Ui

Column {
  id: root
  required property var app
  readonly property var battery: app.battery
  property int profileIndex: Math.max(0, app.power.profiles.indexOf(app.power.profile))
  function handleKey(key, text, modifiers) {
    if (key === Qt.Key_Left || key === Qt.Key_Up || text === "h" || text === "k") profileIndex = Math.max(0, profileIndex - 1)
    else if (key === Qt.Key_Right || key === Qt.Key_Down || text === "l" || text === "j") profileIndex = Math.min(app.power.profiles.length - 1, profileIndex + 1)
    else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) { if (app.power.profiles[profileIndex]) app.power.setProfile(app.power.profiles[profileIndex], app.onBattery) }
    else return false
    return true
  }
  spacing: 10
  PanelHeader { title: battery && battery.isPresent ? Math.round(battery.percentage * 100) + "% Battery" : "Power"; subtitle: app.onBattery ? "On battery" : "External power"; onClose: app.popups.close() }
  Text { visible: !!battery; text: battery ? (battery.model || battery.nativePath || "Battery") : ""; color: Theme.foreground; font.family: Theme.fontFamily }
  Text { visible: !!battery; text: battery ? (battery.timeToEmpty > 0 ? "Remaining: " + Util.minutes(battery.timeToEmpty) : (battery.timeToFull > 0 ? "Until full: " + Util.minutes(battery.timeToFull) : "No time estimate")) : ""; color: Theme.muted; font.family: Theme.fontFamily }
  Text { visible: battery && battery.healthSupported; text: "Health: " + Math.round(battery.healthPercentage) + "%"; color: Theme.muted; font.family: Theme.fontFamily }
  Text { text: "POWER PROFILE"; color: Theme.muted; font.family: Theme.fontFamily }
  Row { spacing: 5
    Repeater { model: app.power.profiles
      PillButton { required property string modelData; text: modelData === "power-saver" ? "Saver" : (modelData === "balanced" ? "Balanced" : "Performance"); active: app.power.profile === modelData; onClicked: app.power.setProfile(modelData, app.onBattery) }
    }
  }
}
