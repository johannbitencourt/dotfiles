import QtQuick
import qs

Column {
  id: root
  property string question: "Are you sure?"
  signal accepted()
  signal rejected()
  spacing: 10
  Text { width: parent.width; text: root.question; color: Theme.foreground; font.family: Theme.fontFamily; wrapMode: Text.WordWrap }
  Row { spacing: 6
    PillButton { text: "Cancel"; onClicked: root.rejected() }
    PillButton { text: "Confirm"; textColor: Theme.critical; onClicked: root.accepted() }
  }
}
