import Quickshell.Io
import QtQuick

QtObject {
  id: root
  required property string scripts
  property string id: "linux"
  property string family: "linux"
  property Process proc: Process { command: [root.scripts + "/platform", "family"]; running: true; stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.family = text.trim() || "linux" } }
  property Process idProc: Process { command: [root.scripts + "/platform", "id"]; running: true; stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.id = text.trim() || "linux" } }
}
