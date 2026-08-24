import QtQuick
import qs
import qs.Commons

Rectangle {
  id: root
  property string text: ""
  property string tooltip: ""
  property color textColor: Theme.foreground
  property color normalColor: Theme.background
  property bool active: false
  property bool barStyle: false
  property bool popupOpen: false
  property real horizontalPadding: 9
  property real fixedWidth: -1
  property real maxTextWidth: -1
  property real textOpacity: 1
  property string fontFamily: Theme.fontFamily
  property real fontSize: Theme.fontSize
  property bool interactive: true
  property int acceptedButtons: barStyle ? Qt.LeftButton | Qt.MiddleButton | Qt.RightButton : Qt.LeftButton
  signal clicked(var mouse)
  signal wheel(var wheel)
  implicitWidth: fixedWidth > 0 ? fixedWidth : Math.max(barStyle ? 12 : 26, (maxTextWidth > 0 ? Math.min(maxTextWidth, label.implicitWidth) : label.implicitWidth) + horizontalPadding * 2)
  implicitHeight: Style.barHeight
  radius: barStyle ? 0 : Style.radius
  color: barStyle ? "transparent" : (pointer.containsMouse || active ? Theme.surfaceHover : normalColor)
  border.width: !barStyle && active ? 1 : 0
  border.color: Theme.accent

  Text {
    id: label
    anchors.centerIn: parent
    width: Math.min(implicitWidth, root.width - root.horizontalPadding * 2)
    text: root.text; color: root.textColor
    opacity: root.textOpacity
    font.family: root.fontFamily; font.pixelSize: root.fontSize
    font.weight: !root.barStyle && root.active ? Font.DemiBold : Font.Normal
    renderType: Text.NativeRendering
    elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
  }
  Rectangle {
    visible: root.barStyle && root.popupOpen
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height - height - 2
    width: Math.max(10, parent.width * 0.55); height: 2
    radius: 1; color: Theme.accent; opacity: 0.9
  }
  MouseArea {
    id: pointer
    anchors.fill: parent; hoverEnabled: true
    acceptedButtons: root.acceptedButtons; enabled: root.interactive
    cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: mouse => root.clicked(mouse)
    onWheel: wheel => root.wheel(wheel)
  }
  ToolTip { target: root; text: root.tooltip; shown: pointer.containsMouse && root.tooltip !== "" }
}
