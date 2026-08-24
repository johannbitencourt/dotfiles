import Quickshell.Io
import QtQuick

QtObject {
  id: root
  required property string scripts
  property var outputs: []
  property string error: ""
  property string pendingName: ""
  function refresh() { if (!stateProc.running) stateProc.running = true }
  function setEnabled(name, enabled) {
    if (actionProc.running) return
    pendingName = name; error = ""
    actionProc.command = [scripts + "/monitor-control", enabled ? "enable" : "disable", name]
    actionProc.running = true
  }
  property Process stateProc: Process {
    command: [root.scripts + "/monitor-control", "state"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: { try { root.outputs = JSON.parse(text); root.error = "" } catch (exception) { root.error = "Invalid monitor state" } } }
  }
  property Process actionProc: Process {
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: if (text.trim()) root.error = text.trim() }
    onExited: { root.pendingName = ""; root.refresh() }
  }
  property Timer timer: Timer { interval: 3000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
