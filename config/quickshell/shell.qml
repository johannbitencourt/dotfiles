//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import "services"
import "Ui"

ShellRoot {
  id: root

  // Exactly one service graph. Per-screen views receive it by injection.
  property AppState appState: AppState {}

  IpcHandler {
    target: "dotbar"
    function reloadTheme(): string {
      Theme.reload()
      return "ok"
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      Bar {
        required property var modelData
        screen: modelData
        app: root.appState
      }
    }
  }
}
