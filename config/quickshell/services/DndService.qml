import Quickshell.Io
import QtQuick

QtObject {
  id: root
  required property string scripts
  property bool enabled: false
  property string backend: "unavailable"
  property string error: ""
  function refresh() { if (!stateProc.running) stateProc.running = true }
  function toggle() { if (!toggleProc.running) { error = ""; toggleProc.running = true } }
  property Process stateProc: Process { command: [root.scripts + "/dnd", "state"]; stdout: StdioCollector { waitForEnd: true; onStreamFinished: { var p = text.trim().split(":"); root.backend = p[0] || "unavailable"; root.enabled = p[1] === "on" } } }
  property Process toggleProc: Process { command: [root.scripts + "/dnd", "toggle"]; onExited: (code, status) => { if (code) root.error = "DND toggle failed"; root.refresh() } }
  property Timer timer: Timer { interval: 10000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
