import Quickshell
import QtQuick
import QtQuick.Controls
import qs
import qs.Ui

Column {
  id: root
  required property var app
  property string confirmation: ""
  property int selectedIndex: 0
  readonly property var applications: DesktopEntries.applications ? DesktopEntries.applications.values.filter(entry => entry && !entry.noDisplay && entry.name).sort((a, b) => String(a.name).localeCompare(String(b.name))) : []
  readonly property var results: filteredApplications(search.text)
  spacing: 7
  function searchText(entry) { return [entry.name, entry.genericName, entry.comment, (entry.keywords || []).join(" ")].join(" ").toLowerCase() }
  function filteredApplications(query) {
    var terms = String(query || "").toLowerCase().trim().split(/\s+/).filter(term => term !== "")
    var matches = applications.filter(function(entry) {
      if (terms.length === 0) return true
      var haystack = searchText(entry)
      return terms.every(term => haystack.indexOf(term) !== -1)
    })
    return matches.slice(0, 10)
  }
  function launchSelected() {
    if (results.length === 0) return
    results[Math.max(0, Math.min(selectedIndex, results.length - 1))].execute()
    app.popups.close()
  }
  function moveSelection(delta) { if (results.length > 0) selectedIndex = (selectedIndex + delta + results.length) % results.length }
  function handleKey(key, text, modifiers) {
    if (key === Qt.Key_Up) moveSelection(-1)
    else if (key === Qt.Key_Down) moveSelection(1)
    else if (key === Qt.Key_Return || key === Qt.Key_Enter) launchSelected()
    else return false
    return true
  }
  Component.onCompleted: Qt.callLater(function() { search.forceActiveFocus() })
  PanelHeader { title: "Applications"; subtitle: applications.length + " desktop entries"; onClose: app.popups.close() }
  Confirm { visible: root.confirmation !== ""; width: parent.width; question: "Confirm " + root.confirmation + "?"; onRejected: root.confirmation = ""; onAccepted: { app.commands.run("session-action", [root.confirmation]); app.popups.close() } }
  Column { visible: root.confirmation === ""; width: parent.width; spacing: 5
    TextField {
      id: search
      width: parent.width
      placeholderText: "Search applications"
      onTextChanged: root.selectedIndex = 0
      Keys.onPressed: event => {
        if (event.key === Qt.Key_Up) root.moveSelection(-1)
        else if (event.key === Qt.Key_Down) root.moveSelection(1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.launchSelected()
        else if (event.key === Qt.Key_Escape && text !== "") { text = ""; root.selectedIndex = 0 }
        else return
        event.accepted = true
      }
    }
    Repeater { model: root.results
      PillButton { required property var modelData; required property int index; width: parent.width; active: index === root.selectedIndex; text: modelData.genericName && modelData.genericName !== modelData.name ? modelData.name + " - " + modelData.genericName : modelData.name; tooltip: modelData.comment || modelData.name; onClicked: { modelData.execute(); app.popups.close() } }
    }
    Text { visible: root.results.length === 0; width: parent.width; text: "No matching applications"; color: Theme.muted; font.family: Theme.fontFamily; horizontalAlignment: Text.AlignHCenter }
    Rectangle { width: parent.width; height: 1; color: Theme.border }
    PillButton { width: parent.width; text: "External launcher"; onClicked: { app.commands.run("launch", ["launcher"]); app.popups.close() } }
    PillButton { width: parent.width; text: "Terminal"; onClicked: { app.commands.terminal(""); app.popups.close() } }
    PillButton { width: parent.width; text: "Network"; onClicked: app.popups.page = "network" }
    PillButton { width: parent.width; text: "Bluetooth"; onClicked: app.popups.page = "bluetooth" }
    PillButton { width: parent.width; text: app.stayAwake.enabled ? "Disable stay awake" : "Enable stay awake"; onClicked: app.stayAwake.toggle() }
    PillButton { width: parent.width; text: app.dnd.enabled ? "Disable do not disturb" : "Enable do not disturb"; onClicked: app.dnd.toggle() }
    PillButton { width: parent.width; text: "Lock"; onClicked: { app.commands.run("session-action", ["lock"]); app.popups.close() } }
    PillButton { width: parent.width; text: "Suspend"; onClicked: { app.commands.run("session-action", ["suspend"]); app.popups.close() } }
    Row { spacing: 5
      PillButton { text: "Reboot"; textColor: Theme.warning; onClicked: root.confirmation = "reboot" }
      PillButton { text: "Power off"; textColor: Theme.critical; onClicked: root.confirmation = "poweroff" }
    }
  }
}
