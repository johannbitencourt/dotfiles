import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "johann.cpu"

  property string usageText: "0% 󰍛"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.usageText
    horizontalMargin: 7.5
    onPressed: function() {
      if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
    }
  }

  Process {
    id: cpuProcess
    command: ["bash", "-lc", "\"$HOME/.config/omarchy/bar/scripts/cpu-status\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.usageText = String(text).trim() || root.usageText
    }
  }

  Timer {
    interval: 5000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!cpuProcess.running) cpuProcess.running = true
  }
}
