import Quickshell.Io
import QtQuick

QtObject {
  id: root
  required property string scripts
  property string profile: "unavailable"
  property var profiles: []
  property string pendingProfile: ""
  function refresh() { if (!proc.running) proc.running = true }
  function setProfile(value, onBattery) { pendingProfile = value; pendingSource = onBattery ? "battery" : "ac"; applyPending() }
  property string pendingSource: "ac"
  function applyPending() {
    if (setter.running || pendingProfile === "") return
    setter.command = [scripts + "/power-profile", "set", pendingProfile, pendingSource]
    pendingProfile = ""
    setter.running = true
  }
  property Process proc: Process { command: [root.scripts + "/power-profile", "get"]; stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.profile = text.trim() || "unavailable" } }
  property Process listProc: Process { command: [root.scripts + "/power-profile", "list"]; stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.profiles = text.trim() ? text.trim().split("\n") : [] } }
  property Process setter: Process { onExited: { root.refresh(); root.applyPending() } }
  Component.onCompleted: listProc.running = true
  property Timer timer: Timer { interval: 30000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
