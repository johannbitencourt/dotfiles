import Quickshell.Io
import QtQuick

QtObject {
  id: root
  required property string scripts
  property bool loading: true
  property string error: ""
  property string locationQuery: ""
  property var data: ({ current: "--", condition: "", location: "", forecast: [] })
  function refresh() { if (!proc.running) { loading = true; proc.command = [scripts + "/weather", locationQuery]; proc.running = true } }
  function setLocation(value) { locationQuery = String(value || "").trim(); locationWriter.command = [scripts + "/weather-location", "set", locationQuery]; locationWriter.running = true }
  function apply(raw) { loading = false; try { data = JSON.parse(raw); error = data.error || "" } catch (e) { error = "Invalid weather response" } }
  property Process proc: Process {
    command: [root.scripts + "/weather", root.locationQuery]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.apply(text) }
    onExited: (code, status) => { root.loading = false; if (code !== 0 && !root.error) root.error = "Weather unavailable" }
  }
  property Process locationReader: Process {
    command: [root.scripts + "/weather-location", "get"]
    running: true
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.locationQuery = text.trim() }
    onExited: root.refresh()
  }
  property Process locationWriter: Process { onExited: root.refresh() }
  property Timer timer: Timer { interval: 900000; repeat: true; running: true; onTriggered: root.refresh() }
}
