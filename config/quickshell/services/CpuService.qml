import Quickshell.Io
import QtQuick

QtObject {
  id: root
  required property string scripts
  property int usage: 0
  property string details: ""
  function refresh() { if (!proc.running) proc.running = true }
  property Process proc: Process { command: [root.scripts + "/cpu"]; stdout: StdioCollector { waitForEnd: true; onStreamFinished: { root.usage = Number(text.trim()) || 0; root.details = "CPU utilization: " + root.usage + "%" } } }
  property Timer timer: Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
