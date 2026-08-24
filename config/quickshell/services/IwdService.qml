import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
  id: root
  property bool available: false
  property bool powered: false
  property bool scanning: false
  property string state: "unavailable"
  property string error: ""
  property string pendingCredentialId: ""
  property string pendingCredentialKind: ""
  property string pendingCredentialPath: ""
  property int operationSerial: 0
  property string pendingOperationId: ""
  property string pendingAction: ""
  property string pendingPath: ""
  property var networks: []
  function send(command) { bridge.write(JSON.stringify(command) + "\n") }
  function operate(action, path, extra) { operationSerial++; pendingOperationId = String(operationSerial); pendingAction = action; pendingPath = path || ""; var value = extra || {}; value.command = action; value.id = pendingOperationId; if (path) value.path = path; error = ""; send(value) }
  function scan() { operate("scan", "", {}) }
  function connect(path) { operate("connect", path, {}) }
  function disconnect() { operate("disconnect", "", {}) }
  function forget(path) { operate("forget", path, {}) }
  function toggle() { operate("toggle", "", { enabled: !powered }) }
  function provideCredential(value, username) { send({ command: "credential", id: pendingCredentialId, value: value, username: username || "" }); clearCredential() }
  function cancelCredential() { if (pendingCredentialId !== "") send({ command: "cancel-credential", id: pendingCredentialId }); clearCredential() }
  function clearCredential() { pendingCredentialId = ""; pendingCredentialKind = ""; pendingCredentialPath = "" }
  function apply(line) {
    try {
      var event = JSON.parse(line)
      if (event.type === "snapshot") { available = event.available; powered = event.powered; scanning = event.scanning; state = event.state; networks = event.networks || []; if (event.error) error = event.error }
      else if (event.type === "credential-request") { pendingCredentialId = event.id; pendingCredentialKind = event.kind || "passphrase"; pendingCredentialPath = event.path || "" }
      else if (event.type === "credential-cancelled" && (!event.id || event.id === pendingCredentialId)) clearCredential()
      else if (event.type === "operation" && event.id === pendingOperationId) { if (!event.ok) error = event.message || (event.action + " failed"); pendingOperationId = ""; pendingAction = ""; pendingPath = "" }
      else if (event.type === "error") error = event.message || "iwd operation failed"
    } catch (e) { error = "Invalid iwd bridge response" }
  }
  property Process bridge: Process {
    command: ["python3", Quickshell.shellDir + "/helpers/iwd_bridge.py"]
    running: true; stdinEnabled: true
    stdout: SplitParser { onRead: line => root.apply(line) }
    stderr: SplitParser { onRead: line => root.error = line }
    onExited: (code, status) => { root.available = false; root.state = "unavailable"; root.error = "iwd bridge stopped"; restart.restart() }
  }
  property Timer restart: Timer { interval: 3000; onTriggered: root.bridge.running = true }
}
