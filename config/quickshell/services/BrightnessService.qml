import Quickshell.Io
import QtQuick

QtObject {
  id: root
  required property string scripts
  property int value: 0
  property bool supported: value > 0
  property int sentValue: 0
  function refresh() { if (!proc.running && !setProc.running && !writeTimer.running) proc.running = true }
  function set(next) { value = Math.max(1, Math.min(100, Math.round(next))); writeTimer.restart() }
  function write() {
    if (setProc.running) { writeTimer.restart(); return }
    sentValue = value
    setProc.command = [scripts + "/brightness", "set", String(sentValue)]
    setProc.running = true
  }
  property Process proc: Process { command: [root.scripts + "/brightness", "get"]; stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.value = Number(text.trim()) || 0 } }
  property Process setProc: Process { onExited: if (root.value !== root.sentValue) root.writeTimer.restart() }
  property Timer writeTimer: Timer { interval: 80; onTriggered: root.write() }
  property Timer timer: Timer { interval: 30000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
