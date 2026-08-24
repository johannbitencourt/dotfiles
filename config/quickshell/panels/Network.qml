import QtQuick
import QtQuick.Controls
import qs
import qs.Ui

Column {
  id: root
  required property var app
  spacing: 8
  function credentialNetwork() { for (var i = 0; i < app.iwd.networks.length; i++) if (app.iwd.networks[i].path === app.iwd.pendingCredentialPath) return app.iwd.networks[i]; return null }
  function handleKey(key, text, modifiers) { if (text === "r") { if (app.iwd.available && app.iwd.powered) app.iwd.scan(); return true } if (text === "w") { if (app.iwd.available) app.iwd.toggle(); return true } return false }
  Component.onCompleted: if (app.iwd.available && app.iwd.powered && !app.iwd.scanning) app.iwd.scan()
  Component.onDestruction: app.iwd.cancelCredential()
  PanelHeader { title: "Network"; subtitle: app.iwd.available ? "iwd · " + app.iwd.state : "iwd unavailable"; onClose: app.popups.close() }
  Text { visible: app.iwd.error !== ""; width: parent.width; text: app.iwd.error; color: Theme.critical; font.family: Theme.fontFamily; wrapMode: Text.WordWrap }
  Row { spacing: 6
    PillButton { text: app.iwd.pendingAction === "toggle" ? "Working…" : (app.iwd.powered ? "Wi-Fi on" : "Wi-Fi off"); interactive: app.iwd.available && app.iwd.pendingAction === ""; onClicked: app.iwd.toggle() }
    PillButton { text: app.iwd.scanning || app.iwd.pendingAction === "scan" ? "Scanning…" : "Scan"; interactive: app.iwd.available && app.iwd.powered && !app.iwd.scanning && app.iwd.pendingAction === ""; onClicked: app.iwd.scan() }
    PillButton { text: app.iwd.pendingAction === "disconnect" ? "Disconnecting…" : "Disconnect"; interactive: app.iwd.available && app.iwd.state === "connected" && app.iwd.pendingAction === ""; onClicked: app.iwd.disconnect() }
  }
  Text { visible: app.iwd.available && !app.iwd.powered; text: "Turn Wi-Fi on to scan for networks."; color: Theme.muted; font.family: Theme.fontFamily }
  Text { visible: app.iwd.available && app.iwd.powered && !app.iwd.scanning && app.iwd.networks.length === 0; text: "No networks found."; color: Theme.muted; font.family: Theme.fontFamily }
  Repeater { model: app.iwd.networks
    CursorSurface { id: net; required property var modelData; width: parent.width; implicitHeight: 38; current: modelData.connected
      Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.right: forget.left; anchors.verticalCenter: parent.verticalCenter; text: modelData.name + (modelData.type ? "  " + modelData.type : ""); color: Theme.foreground; font.family: Theme.fontFamily; elide: Text.ElideRight }
      PillButton { id: connect; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; interactive: app.iwd.pendingAction === ""; text: app.iwd.pendingAction === "connect" && app.iwd.pendingPath === net.modelData.path ? "Connecting…" : (net.modelData.connected ? "Connected" : "Connect"); onClicked: if (!net.modelData.connected) app.iwd.connect(net.modelData.path) }
      PillButton { id: forget; visible: !!net.modelData.knownPath && !net.modelData.connected; width: visible ? implicitWidth : 0; anchors.right: connect.left; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter; interactive: app.iwd.pendingAction === ""; text: app.iwd.pendingAction === "forget" && app.iwd.pendingPath === net.modelData.knownPath ? "Forgetting…" : "Forget"; textColor: Theme.critical; onClicked: app.iwd.forget(net.modelData.knownPath) }
    }
  }
  Column { visible: app.iwd.pendingCredentialId !== ""; width: parent.width; spacing: 5
    readonly property var network: root.credentialNetwork()
    Text { text: (parent.network ? parent.network.name + ": " : "") + (app.iwd.pendingCredentialKind === "user-password" ? "Credentials requested" : "Passphrase requested"); color: Theme.foreground; font.family: Theme.fontFamily }
    TextField { id: username; visible: app.iwd.pendingCredentialKind === "user-password"; width: parent.width; placeholderText: "Username" }
    TextField { id: password; width: parent.width; echoMode: TextInput.Password; placeholderText: app.iwd.pendingCredentialKind === "private-key" ? "Private key passphrase" : "Passphrase"; onVisibleChanged: if (visible) forceActiveFocus(); onAccepted: { app.iwd.provideCredential(text, username.text); text = ""; username.text = "" } }
    Row { spacing: 5
      PillButton { text: "Cancel"; onClicked: { app.iwd.cancelCredential(); password.text = ""; username.text = "" } }
      PillButton { text: "Connect"; onClicked: { app.iwd.provideCredential(password.text, username.text); password.text = ""; username.text = "" } }
    }
  }
}
