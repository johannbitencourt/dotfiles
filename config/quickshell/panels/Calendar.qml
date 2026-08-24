import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.Ui

Column {
  id: root
  property var app
  property date shown: new Date()
  property bool editingLife: false
  readonly property bool mondayFirst: app.barSettings.calendarMondayFirst
  readonly property date today: clock.date
  readonly property int birthYear: app.barSettings.calendarBirthYear
  readonly property int lifeExpectancy: app.barSettings.calendarLifeExpectancy
  readonly property int age: birthYear > 0 ? today.getFullYear() - birthYear : 0
  readonly property real yearDone: yearProgress(today)
  readonly property real lifeDone: lifeExpectancy > 0 ? Math.max(0, Math.min(1, age / lifeExpectancy)) : 0
  spacing: 10
  function shifted(delta) { return new Date(shown.getFullYear(), shown.getMonth() + delta, 1) }
  function shiftedYear(delta) { return new Date(shown.getFullYear() + delta, shown.getMonth(), 1) }
  function handleKey(key, text, modifiers) {
    if (editingLife) return false
    if (key === Qt.Key_Left || text === "h" || text === "[") shown = shifted(-1)
    else if (key === Qt.Key_Right || text === "l" || text === "]") shown = shifted(1)
    else if (key === Qt.Key_Up || text === "k" || text === "{") shown = shiftedYear(-1)
    else if (key === Qt.Key_Down || text === "j" || text === "}") shown = shiftedYear(1)
    else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space || text === "t") shown = new Date()
    else if (text === "w") app.barSettings.toggleCalendarWeekStart()
    else return false
    return true
  }
  function yearProgress(d) { var start = Date.UTC(d.getFullYear(), 0, 1); var end = Date.UTC(d.getFullYear() + 1, 0, 1); var day = Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()); return Math.max(0, Math.min(1, (day - start) / (end - start))) }
  function validBirthYear(value) { var text = String(value || "").trim(); var year = /^\d{4}$/.test(text) ? Number(text) : 0; return year <= today.getFullYear() && year >= today.getFullYear() - 120 ? year : 0 }
  function validLifeExpectancy(value) { var text = String(value || "").trim(); var years = /^\d+$/.test(text) ? Number(text) : 90; return years > 0 && years <= 150 ? years : 90 }
  function startEditingLife() { editingLife = true; Qt.callLater(function() { bornField.text = birthYear > 0 ? String(birthYear) : ""; expectancyField.text = String(lifeExpectancy); bornField.selectAll(); bornField.forceActiveFocus() }) }
  function cancelEditingLife() { editingLife = false }
  function commitLife() { app.barSettings.setCalendarLife(validBirthYear(bornField.text), validLifeExpectancy(expectancyField.text)); editingLife = false }
  function clearLife() { app.barSettings.setCalendarLife(0, lifeExpectancy) }
  function weekNumber(d) { var x = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate())); x.setUTCDate(x.getUTCDate() + 4 - (x.getUTCDay() || 7)); var y = new Date(Date.UTC(x.getUTCFullYear(), 0, 1)); return Math.ceil((((x - y) / 86400000) + 1) / 7) }
  function cells() { var first = new Date(shown.getFullYear(), shown.getMonth(), 1); var offset = mondayFirst ? (first.getDay() + 6) % 7 : first.getDay(); var out = []; for (var i = 0; i < 42; i++) out.push(new Date(shown.getFullYear(), shown.getMonth(), i - offset + 1)); return out }
  function weekdayHeaders() { return mondayFirst ? ["W", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"] : ["W", "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"] }
  function gridCells() { var dates = cells(), out = []; for (var row = 0; row < 6; row++) { out.push({ week: true, value: weekNumber(dates[row * 7]) }); for (var day = 0; day < 7; day++) out.push({ week: false, value: dates[row * 7 + day] }) } return out }
  PanelHeader { title: Qt.formatDateTime(clock.date, "h:mm:ss AP"); subtitle: Qt.formatDate(shown, "MMMM yyyy"); onClose: app.popups.close(); SystemClock { id: clock; precision: SystemClock.Seconds } }
  Item { width: parent.width; implicitHeight: root.editingLife ? lifeEditor.implicitHeight : 24
    TapHandler { enabled: !root.editingLife; onDoubleTapped: root.startEditingLife() }
    Row { id: lifeEditor; visible: root.editingLife; anchors.centerIn: parent; spacing: 5
      Text { anchors.verticalCenter: parent.verticalCenter; text: "BORN"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Math.max(9, Theme.fontSize - 2) }
      TextField { id: bornField; width: 68; placeholderText: "year"; inputMethodHints: Qt.ImhDigitsOnly; onAccepted: root.commitLife(); Keys.onEscapePressed: root.cancelEditingLife() }
      Text { anchors.verticalCenter: parent.verticalCenter; text: "LIVE TO"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Math.max(9, Theme.fontSize - 2) }
      TextField { id: expectancyField; width: 54; placeholderText: "90"; inputMethodHints: Qt.ImhDigitsOnly; onAccepted: root.commitLife(); Keys.onEscapePressed: root.cancelEditingLife() }
      PillButton { text: "Save"; onClicked: root.commitLife() }
      PillButton { text: "Cancel"; onClicked: root.cancelEditingLife() }
    }
    Item { visible: !root.editingLife; anchors.fill: parent
      Text { id: yearLabel; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: root.today.getFullYear(); color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Math.max(9, Theme.fontSize - 2) }
      Text { id: yearPercent; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Math.round(root.yearDone * 100) + "%"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Math.max(9, Theme.fontSize - 2) }
      Rectangle { anchors.left: yearLabel.right; anchors.right: yearPercent.left; anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; height: 5; radius: height / 2; color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
        Rectangle { width: Math.round(parent.width * root.yearDone); height: parent.height; radius: parent.radius; color: Theme.accent; Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
      }
    }
  }
  Item { visible: root.birthYear > 0; width: parent.width; implicitHeight: visible ? 24 : 0
    TapHandler { onDoubleTapped: root.clearLife() }
    Text { id: lifeLabel; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "LIFE"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Math.max(9, Theme.fontSize - 2) }
    Text { id: lifePercent; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Math.round(root.lifeDone * 100) + "%"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Math.max(9, Theme.fontSize - 2) }
    Rectangle { anchors.left: lifeLabel.right; anchors.right: lifePercent.left; anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; height: 5; radius: height / 2; color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
      Rectangle { width: Math.round(parent.width * root.lifeDone); height: parent.height; radius: parent.radius; color: Theme.accent; Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
    }
  }
  Row { width: parent.width; spacing: 5
    PillButton { text: "‹"; onClicked: root.shown = root.shifted(-1) }
    PillButton { text: "Today"; onClicked: root.shown = new Date() }
    PillButton { text: "W"; tooltip: root.mondayFirst ? "Weeks start Monday" : "Weeks start Sunday"; onClicked: app.barSettings.toggleCalendarWeekStart() }
    PillButton { text: "›"; onClicked: root.shown = root.shifted(1) }
  }
  GridLayout { width: parent.width; columns: 8; columnSpacing: 2; rowSpacing: 2
    WheelHandler { onWheel: event => root.shown = root.shifted(event.angleDelta.y > 0 ? -1 : 1) }
    Repeater { model: root.weekdayHeaders()
      Text { required property string modelData; Layout.fillWidth: true; text: modelData; color: Theme.muted; font.family: Theme.fontFamily; horizontalAlignment: Text.AlignHCenter }
    }
    Repeater { model: root.gridCells()
      Rectangle { required property var modelData; Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 7
        readonly property date now: new Date()
        color: !modelData.week && modelData.value.toDateString() === now.toDateString() ? Theme.accent : "transparent"
        opacity: modelData.week || modelData.value.getMonth() === root.shown.getMonth() ? 1 : 0.35
        Text { anchors.centerIn: parent; text: parent.modelData.week ? parent.modelData.value : parent.modelData.value.getDate(); color: parent.modelData.week ? Theme.muted : (parent.color === Theme.accent ? Theme.background : Theme.foreground); font.family: Theme.fontFamily }
      }
    }
  }
}
