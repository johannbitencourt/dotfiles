import QtQuick
import QtQuick.Controls
import qs
import qs.Ui

Column {
  id: root
  required property var app
  property bool editingLocation: false
  spacing: 12
  Component.onCompleted: app.weather.refresh()
  function handleKey(key, text, modifiers) { if (text === "r") { app.weather.refresh(); return true } if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) { editingLocation = true; locationField.forceActiveFocus(); return true } return false }
  PanelHeader { title: app.weather.loading ? "Loading weather" : app.weather.data.current + "  " + app.weather.data.condition; subtitle: app.weather.data.location; onClose: app.popups.close() }
  Text { visible: app.weather.error !== ""; width: parent.width; text: app.weather.error; color: Theme.critical; wrapMode: Text.WordWrap; font.family: Theme.fontFamily }
  Text { visible: !app.weather.loading && !app.weather.error; text: "Feels like " + app.weather.data.feelsLike + "° · Humidity " + app.weather.data.humidity + "% · Wind " + app.weather.data.wind; color: Theme.muted; font.family: Theme.fontFamily; width: parent.width; wrapMode: Text.WordWrap }
  Repeater { model: app.weather.data.forecast || []
    CursorSurface { required property var modelData; width: parent.width; implicitHeight: 52
      Row { anchors.fill: parent; anchors.margins: 8
        Text { width: 95; text: Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd, MMM d"); color: Theme.foreground; font.family: Theme.fontFamily }
        Text { width: parent.width - 165; text: modelData.condition; color: Theme.muted; font.family: Theme.fontFamily; elide: Text.ElideRight }
        Text { text: modelData.high + "° / " + modelData.low + "°"; color: Theme.foreground; font.family: Theme.fontFamily }
      }
    }
  }
  Column { visible: root.editingLocation; width: parent.width; spacing: 5
    TextField { id: locationField; width: parent.width; text: app.weather.locationQuery; placeholderText: "City or location"; onAccepted: { app.weather.setLocation(text); root.editingLocation = false } }
    Row { spacing: 5
      PillButton { text: "Cancel"; onClicked: root.editingLocation = false }
      PillButton { text: "Clear"; onClicked: { app.weather.setLocation(""); locationField.text = ""; root.editingLocation = false } }
      PillButton { text: "Save"; onClicked: { app.weather.setLocation(locationField.text); root.editingLocation = false } }
    }
  }
  Row { visible: !root.editingLocation; spacing: 5
    PillButton { text: "Location"; onClicked: { root.editingLocation = true; locationField.forceActiveFocus() } }
    PillButton { text: "Refresh"; onClicked: app.weather.refresh() }
  }
}
