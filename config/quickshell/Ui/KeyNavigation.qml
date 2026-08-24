import QtQuick

Item {
  signal move(int dx, int dy)
  signal activate()
  signal dismiss()
  signal remove()
  focus: true; Keys.priority: Keys.BeforeItem
  Keys.onPressed: event => {
    if (event.key === Qt.Key_Escape) dismiss()
    else if (event.key === Qt.Key_Up || event.text === "k") move(0, -1)
    else if (event.key === Qt.Key_Down || event.text === "j") move(0, 1)
    else if (event.key === Qt.Key_Left || event.text === "h") move(-1, 0)
    else if (event.key === Qt.Key_Right || event.text === "l") move(1, 0)
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) activate()
    else if (event.key === Qt.Key_Delete || event.text === "x") remove()
    else return
    event.accepted = true
  }
}
