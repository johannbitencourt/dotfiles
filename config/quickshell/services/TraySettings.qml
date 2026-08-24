import Quickshell.Io
import QtQuick

QtObject {
  id: root
  required property string scripts
  property var pinnedIds: []
  property var hiddenIds: []
  property string pending: ""
  function contains(values, id) { return values.indexOf(String(id || "")) >= 0 }
  function togglePinned(id) {
    id = String(id || ""); if (!id) return
    var pinned = pinnedIds.slice(), hidden = hiddenIds.slice(), index = pinned.indexOf(id)
    if (index >= 0) pinned.splice(index, 1); else { pinned.push(id); index = hidden.indexOf(id); if (index >= 0) hidden.splice(index, 1) }
    pinnedIds = pinned; hiddenIds = hidden; save()
  }
  function toggleHidden(id) {
    id = String(id || ""); if (!id) return
    var pinned = pinnedIds.slice(), hidden = hiddenIds.slice(), index = hidden.indexOf(id)
    if (index >= 0) hidden.splice(index, 1); else { hidden.push(id); index = pinned.indexOf(id); if (index >= 0) pinned.splice(index, 1) }
    pinnedIds = pinned; hiddenIds = hidden; save()
  }
  function save() { pending = JSON.stringify({ pinned: pinnedIds, hidden: hiddenIds }); write() }
  function write() {
    if (writer.running || pending === "") return
    var value = pending; pending = ""
    writer.command = [scripts + "/tray-settings", "set", value]
    writer.running = true
  }
  property Process reader: Process {
    command: [root.scripts + "/tray-settings", "get"]
    running: true
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: { try { var value = JSON.parse(text); root.pinnedIds = value.pinned || []; root.hiddenIds = value.hidden || [] } catch (error) {} } }
  }
  property Process writer: Process { onExited: root.write() }
}
