import QtQuick
import qs

Rectangle {
  property bool hasCursor: false
  property bool current: false
  radius: 7
  color: current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : (hasCursor ? Theme.surfaceHover : "transparent")
  border.width: hasCursor ? 1 : 0; border.color: Theme.accent
}
