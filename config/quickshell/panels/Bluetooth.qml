import Quickshell.Bluetooth
import QtQuick
import qs
import qs.Ui

Column {
  id: root
  required property var app
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var devices: adapter && adapter.devices ? adapter.devices.values : []
  property bool ownsDiscovery: false
  property string adapterError: ""
  function beginDiscovery() { if (adapter && adapter.enabled && !adapter.discovering) { adapter.discovering = true; ownsDiscovery = true } }
  function endDiscovery() { if (adapter && ownsDiscovery && adapter.discovering) adapter.discovering = false; ownsDiscovery = false }
  function handleKey(key, text, modifiers) { if (text === "b") { if (adapter) adapter.enabled = !adapter.enabled; return true } return false }
  Component.onCompleted: beginDiscovery()
  Component.onDestruction: endDiscovery()
  Connections {
    target: root.adapter
    ignoreUnknownSignals: true
    function onEnabledChanged() { if (root.adapter.enabled) root.beginDiscovery(); else root.endDiscovery() }
    function onStateChanged() {
      if (root.adapter.state === BluetoothAdapterState.Blocked) root.adapterError = "Bluetooth is blocked by rfkill."
      else if (root.adapter.state === BluetoothAdapterState.Enabled || root.adapter.state === BluetoothAdapterState.Disabled) root.adapterError = ""
    }
  }
  spacing: 8
  PanelHeader { title: "Bluetooth"; subtitle: !root.adapter ? "No adapter" : (root.adapter.enabled ? (root.adapter.discovering ? "Scanning" : "Ready") : "Disabled"); onClose: { root.endDiscovery(); app.popups.close() } }
  Row { spacing: 6
    PillButton { interactive: !!root.adapter && root.adapter.state !== BluetoothAdapterState.Enabling && root.adapter.state !== BluetoothAdapterState.Disabling; text: !root.adapter ? "Turn on" : (root.adapter.state === BluetoothAdapterState.Enabling ? "Turning on…" : (root.adapter.state === BluetoothAdapterState.Disabling ? "Turning off…" : (root.adapter.enabled ? "Turn off" : "Turn on"))); onClicked: if (root.adapter) { root.adapterError = ""; if (root.adapter.enabled) root.endDiscovery(); root.adapter.enabled = !root.adapter.enabled } }
    PillButton { visible: !!root.adapter && root.adapter.enabled; text: root.adapter && root.adapter.discovering ? "Stop scan" : "Scan"; onClicked: { if (root.adapter.discovering) root.endDiscovery(); else root.beginDiscovery() } }
  }
  Text { visible: root.adapterError !== ""; text: root.adapterError; color: Theme.critical; font.family: Theme.fontFamily; width: parent.width; wrapMode: Text.WordWrap }
  Text { visible: !root.adapter; text: "Quickshell.Bluetooth could not find a BlueZ adapter."; color: Theme.muted; font.family: Theme.fontFamily; wrapMode: Text.WordWrap; width: parent.width }
  Repeater { model: root.devices
    CursorSurface { id: row; required property var modelData; width: parent.width; implicitHeight: error === "" ? 42 : 60; current: modelData.connected
      property string pendingAction: ""
      property string error: ""
      function finish(message) { operationTimeout.stop(); pendingAction = ""; error = message || "" }
      function run(actionName) {
        error = ""
        pendingAction = actionName
        operationTimeout.restart()
        if (actionName === "pair") modelData.pair()
        else if (actionName === "cancel") modelData.cancelPair()
        else if (actionName === "connect") modelData.connect()
        else if (actionName === "disconnect") modelData.disconnect()
        else if (actionName === "forget") modelData.forget()
      }
      Timer { id: operationTimeout; interval: 20000; onTriggered: { if (row.pendingAction === "pair" && row.modelData.pairing) row.modelData.cancelPair(); var label = row.pendingAction.charAt(0).toUpperCase() + row.pendingAction.slice(1); row.finish(label + " timed out.") } }
      Connections {
        target: row.modelData
        function onConnectedChanged() {
          if (row.pendingAction === "connect" && row.modelData.connected) row.finish("")
          else if (row.pendingAction === "disconnect" && !row.modelData.connected) row.finish("")
        }
        function onPairedChanged() {
          if (row.pendingAction === "pair" && row.modelData.paired) row.finish("")
          else if (row.pendingAction === "forget" && !row.modelData.paired) row.finish("")
        }
        function onPairingChanged() {
          if (row.pendingAction === "cancel" && !row.modelData.pairing) row.finish("")
          else if (row.pendingAction === "pair" && !row.modelData.pairing && !row.modelData.paired) row.finish("Pairing failed or was cancelled.")
        }
      }
      Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.right: battery.visible ? battery.left : forget.left; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: row.error === "" ? 0 : -8; text: row.modelData.name || row.modelData.deviceName || row.modelData.address; color: Theme.foreground; font.family: Theme.fontFamily; elide: Text.ElideRight }
      Text { visible: row.error !== ""; anchors.left: parent.left; anchors.leftMargin: 10; anchors.right: action.left; anchors.bottom: parent.bottom; anchors.bottomMargin: 5; text: row.error; color: Theme.critical; font.family: Theme.fontFamily; font.pixelSize: Math.max(9, Theme.fontSize - 2); elide: Text.ElideRight }
      PillButton { id: action; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; interactive: row.pendingAction === "" || (row.modelData.pairing && row.pendingAction === "pair"); text: row.modelData.pairing ? "Cancel" : (row.pendingAction === "connect" || row.modelData.state === BluetoothDeviceState.Connecting ? "Connecting…" : (row.pendingAction === "disconnect" || row.modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…" : (row.pendingAction === "forget" ? "Forgetting…" : (row.modelData.connected ? "Disconnect" : (row.modelData.paired ? "Connect" : "Pair"))))); onClicked: { if (row.modelData.pairing) row.run("cancel"); else if (row.modelData.connected) row.run("disconnect"); else if (row.modelData.paired) row.run("connect"); else row.run("pair") } }
      PillButton { id: forget; visible: row.modelData.paired && !row.modelData.connected; width: visible ? implicitWidth : 0; anchors.right: action.left; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter; interactive: row.pendingAction === ""; text: "Forget"; textColor: Theme.critical; onClicked: row.run("forget") }
      Text { id: battery; visible: row.modelData.batteryAvailable; anchors.right: forget.visible ? forget.left : action.left; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter; text: Math.round(row.modelData.battery * 100) + "%"; color: Theme.muted; font.family: Theme.fontFamily }
    }
  }
  Text { visible: root.adapter && root.adapter.enabled && devices.length === 0; text: "No devices. Pairing is supported by this Quickshell build; agent prompts are managed by BlueZ/Quickshell."; color: Theme.muted; font.family: Theme.fontFamily; width: parent.width; wrapMode: Text.WordWrap }
  Text { visible: root.adapter && !root.adapter.enabled; text: "Turn Bluetooth on to scan for devices."; color: Theme.muted; font.family: Theme.fontFamily; width: parent.width; wrapMode: Text.WordWrap }
}
