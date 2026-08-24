import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.Commons
import "../widgets" as Widgets
import "../panels" as Panels

PanelWindow {
  id: root
  required property var app
  visible: Quickshell.env("QS_VALIDATE") !== "1" && !remap.remapping
  anchors { top: true; left: true; right: true }
  implicitHeight: Style.shellHeight; exclusiveZone: Style.shellHeight
  color: "transparent"; surfaceFormat.opaque: false
  WlrLayershell.namespace: "standalone-quickshell-bar"
  WlrLayershell.layer: WlrLayer.Top
  ScreenMoveRemap { id: remap; window: root }
  Component.onCompleted: {
    var validationPanel = Quickshell.env("QS_VALIDATE_PANEL")
    if (validationPanel && app.popups.page === "") Qt.callLater(function() { app.popups.show(validationPanel, root.screen, root.panelAnchor(validationPanel) || menuButton) })
  }

  function open(page, anchor) { app.popups.toggle(page, screen, anchor) }
  function panelAnchor(page) {
    var anchors = ({ system: menuButton, calendar: clockButton, weather: weatherButton, tray: trayButton, bluetooth: bluetoothButton, network: networkButton, audio: audioButton, monitor: monitorButton, power: powerButton })
    return anchors[page] || null
  }
  function cyclePanel(delta) {
    var groups = [["calendar", "weather"], ["tray", "bluetooth", "network", "audio", "monitor", "power"]]
    for (var g = 0; g < groups.length; g++) {
      var index = groups[g].indexOf(app.popups.page)
      if (index < 0) continue
      for (var step = 1; step <= groups[g].length; step++) {
        var page = groups[g][(index + delta * step + groups[g].length * 2) % groups[g].length]
        var anchor = panelAnchor(page)
        if (anchor && anchor.visible) { app.popups.show(page, screen, anchor); return }
      }
    }
  }

  Row {
    id: leftSections
    anchors.left: parent.left; anchors.leftMargin: Style.outerMargin
    anchors.top: parent.top; anchors.topMargin: 5
    height: Style.barHeight; spacing: Style.sectionGap
    Rectangle {
      visible: activeWindow.visible
      width: visible ? activeWindow.implicitWidth : 0; height: Style.barHeight
      radius: Style.radius; color: Style.alpha(Theme.background, 1)
      Widgets.ActiveWindow { id: activeWindow; screen: root.screen; anchors.fill: parent }
    }
    Rectangle {
      width: leftModules.implicitWidth + 8; height: Style.barHeight
      radius: Style.radius; color: Style.alpha(Theme.background, 1)
      Row {
        id: leftModules
        anchors.centerIn: parent; spacing: 0
        PillButton {
          id: menuButton
          barStyle: true; popupOpen: app.popups.page === "system" && app.popups.screenName === root.screen.name
          text: "\uDB82\uDCC7"; fontFamily: "CaskaydiaMono Nerd Font"; horizontalPadding: 7.5
          tooltip: "System menu"; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
          onClicked: mouse => { if (mouse.button === Qt.RightButton) app.commands.terminal(""); else if (app.platform.id === "omarchy") app.commands.run("menu", []); else root.open("system", menuButton) }
        }
        Widgets.Workspaces { screen: root.screen }
      }
    }
  }

  Rectangle {
    id: centerSection
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top; anchors.topMargin: 5
    width: centerModules.implicitWidth + 12; height: Style.barHeight
    radius: Style.radius; color: Style.alpha(Theme.background, 1)
    Row {
      id: centerModules
      anchors.centerIn: parent; height: Style.barHeight; spacing: 0
      Widgets.Clock { id: clockButton; app: root.app; popupOpen: app.popups.page === "calendar" && app.popups.screenName === root.screen.name; onClicked: mouse => { if (mouse.button === Qt.RightButton) cycleFormat(); else if (mouse.button === Qt.MiddleButton) app.commands.run("timezone", []); else root.open("calendar", clockButton) } }
      Widgets.Weather { id: weatherButton; app: root.app; popupOpen: app.popups.page === "weather" && app.popups.screenName === root.screen.name; onClicked: mouse => { if (mouse.button === Qt.MiddleButton) app.weather.refresh(); else if (mouse.button === Qt.RightButton) notifyStatus(); else root.open("weather", weatherButton) } }
      Widgets.Updates { app: root.app }
      Widgets.Indicators { app: root.app }
    }
  }

  Rectangle {
    id: rightSection
    anchors.right: parent.right; anchors.rightMargin: Style.outerMargin
    anchors.top: parent.top; anchors.topMargin: 5
    width: rightModules.implicitWidth + 12; height: Style.barHeight
    radius: Style.radius; color: Style.alpha(Theme.background, 1)
    Row {
      id: rightModules
      anchors.centerIn: parent; height: Style.barHeight; spacing: Style.rightGap
      Widgets.Tray { id: trayButton; app: root.app; onManageRequested: root.open("tray", trayButton) }
      Widgets.Bluetooth { id: bluetoothButton; popupOpen: app.popups.page === "bluetooth" && app.popups.screenName === root.screen.name; onClicked: mouse => { if (mouse.button === Qt.RightButton && adapter) adapter.enabled = !adapter.enabled; else root.open("bluetooth", bluetoothButton) } }
      Widgets.Network { id: networkButton; app: root.app; popupOpen: app.popups.page === "network" && app.popups.screenName === root.screen.name; onClicked: root.open("network", networkButton) }
      Widgets.Audio { id: audioButton; app: root.app; popupOpen: app.popups.page === "audio" && app.popups.screenName === root.screen.name; onClicked: mouse => { if (mouse.button === Qt.RightButton) app.toggleAllMuted(); else root.open("audio", audioButton) } }
      Widgets.Microphone { app: root.app; onOpenAudio: root.open("audio", audioButton) }
      Widgets.Monitor { id: monitorButton; app: root.app; popupOpen: app.popups.page === "monitor" && app.popups.screenName === root.screen.name; onClicked: root.open("monitor", monitorButton) }
      Widgets.Cpu { app: root.app }
      Widgets.Power { id: powerButton; app: root.app; popupOpen: app.popups.page === "power" && app.popups.screenName === root.screen.name; onClicked: mouse => { if (mouse.button === Qt.RightButton) app.barSettings.toggleBatteryPercentage(); else root.open("power", powerButton) } }
    }
  }

  PopupCard {
    id: popup
    coordinator: app.popups; barWindow: root; screen: root.screen
    panelItem: panelLoader.item; cyclePanel: delta => root.cyclePanel(delta)
    contentItem: Loader {
      id: panelLoader
      width: parent.width
      sourceComponent: {
        if (app.popups.page === "calendar") return calendarPanel
        if (app.popups.page === "weather") return weatherPanel
        if (app.popups.page === "bluetooth") return bluetoothPanel
        if (app.popups.page === "network") return networkPanel
        if (app.popups.page === "audio") return audioPanel
        if (app.popups.page === "monitor") return monitorPanel
        if (app.popups.page === "power") return powerPanel
        if (app.popups.page === "tray") return trayPanel
        if (app.popups.page === "system") return systemPanel
        return null
      }
    }
  }

  Component { id: calendarPanel; Panels.Calendar { app: root.app } }
  Component { id: weatherPanel; Panels.Weather { app: root.app } }
  Component { id: bluetoothPanel; Panels.Bluetooth { app: root.app } }
  Component { id: networkPanel; Panels.Network { app: root.app } }
  Component { id: audioPanel; Panels.Audio { app: root.app } }
  Component { id: monitorPanel; Panels.Monitor { app: root.app; screen: root.screen } }
  Component { id: powerPanel; Panels.Power { app: root.app } }
  Component { id: trayPanel; Panels.TrayManager { app: root.app } }
  Component { id: systemPanel; Panels.SystemMenu { app: root.app } }
}
