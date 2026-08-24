import QtQuick

QtObject {
  property string page: ""
  property string screenName: ""
  property var anchorItem: null
  function show(name, screen, anchor) { page = name; screenName = String(screen ? screen.name : ""); anchorItem = anchor }
  function toggle(name, screen, anchor) {
    var same = page === name && screenName === String(screen ? screen.name : "")
    if (same) close(); else show(name, screen, anchor)
  }
  function close() { page = ""; screenName = ""; anchorItem = null }
}
