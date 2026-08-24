import QtQuick
import QtQuick.Layouts
import qs

RowLayout {
  id: root
  property string title: ""
  property string subtitle: ""
  signal close()
  width: parent ? parent.width : implicitWidth
  ColumnLayout { Layout.fillWidth: true; spacing: 1
    Text { text: root.title; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 3; font.bold: true }
    Text { visible: root.subtitle !== ""; text: root.subtitle; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; elide: Text.ElideRight; Layout.fillWidth: true }
  }
  PillButton { text: "×"; tooltip: "Close"; onClicked: root.close() }
}
