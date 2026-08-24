import QtQuick
import QtQuick.Controls
import qs

Slider {
  id: control
  property color foreground: Theme.foreground
  background: Rectangle { x: control.leftPadding; y: control.topPadding + control.availableHeight / 2 - 2; width: control.availableWidth; height: 4; radius: 2; color: Theme.border
    Rectangle { width: control.visualPosition * parent.width; height: parent.height; radius: 2; color: Theme.accent }
  }
  handle: Rectangle { x: control.leftPadding + control.visualPosition * (control.availableWidth - width); y: control.topPadding + control.availableHeight / 2 - height / 2; width: 14; height: 14; radius: 7; color: control.pressed ? Theme.accent : control.foreground }
}
