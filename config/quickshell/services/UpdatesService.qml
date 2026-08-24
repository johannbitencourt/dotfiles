import Quickshell.Io
import QtQuick

QtObject {
  id: root
  required property string scripts
  property int count: 0
  property string error: ""
  function refresh() { if (!proc.running) proc.running = true }
  property Process proc: Process {
    command: [root.scripts + "/updates", "count"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: { var n = Number(text.trim()); root.count = isFinite(n) ? n : 0 } }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.error = text.trim() }
  }
  property Timer timer: Timer { interval: 21600000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
