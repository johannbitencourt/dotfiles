import Quickshell.Io
import QtQuick

QtObject {
  id: root
  required property string scripts
  property bool enabled: false
  property string backend: "native"
  property string error: ""
  property bool stopping: false
  function toggle() { if (!toggleProc.running) { error = ""; toggleProc.running = true } }
  function refresh() { if (!stateProc.running) stateProc.running = true }
  function reconcile() {
    if (backend === "omarchy") {
      if (inhibitor.running) { stopping = true; inhibitor.running = false }
    } else if (enabled && !inhibitor.running) inhibitor.running = true
    else if (!enabled && inhibitor.running) { stopping = true; inhibitor.running = false }
  }
  onEnabledChanged: reconcileTimer.restart()
  property Process inhibitor: Process {
    command: [root.scripts + "/stay-awake"]
    onExited: (code, status) => {
      if (root.enabled && root.stopping) {
        root.stopping = false
        root.reconcileTimer.restart()
      } else if (root.enabled) {
        root.error = "No idle inhibitor could be started"
        root.enabled = false
      } else root.stopping = false
    }
  }
  property Process stateProc: Process {
    command: [root.scripts + "/stay-awake-control", "state"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: { var parts = text.trim().split(":"); root.backend = parts[0] || "native"; root.enabled = parts[1] === "on"; root.reconcileTimer.restart() } }
  }
  property Process toggleProc: Process { command: [root.scripts + "/stay-awake-control", "toggle"]; onExited: root.refresh() }
  property Timer stateTimer: Timer { interval: 3000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
  property Timer reconcileTimer: Timer { interval: 0; onTriggered: root.reconcile() }
}
