pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
  id: root

  readonly property string path: Quickshell.env("HOME") + "/.config/themes/current/quickshell.json"
  property var values: ({})
  property int revision: 0

  readonly property color background: get("background", "#d914171c")
  readonly property color surface: get("surface", "#ed20242b")
  readonly property color surfaceHover: get("surfaceHover", "#ff303640")
  readonly property color foreground: get("foreground", "#f2f2f2")
  readonly property color muted: get("muted", "#a5acb8")
  readonly property color accent: get("accent", "#7aa2f7")
  readonly property color warning: get("warning", "#e0af68")
  readonly property color critical: get("critical", get("error", "#f7768e"))
  readonly property color border: get("border", "#35ffffff")
  readonly property string fontFamily: get("fontFamily", "monospace")
  readonly property int fontSize: Number(get("fontSize", 12))

  function get(name, fallback) {
    revision
    return values && values[name] !== undefined ? values[name] : fallback
  }

  function apply(raw) {
    if (!String(raw || "").trim()) {
      values = ({})
      revision++
      return
    }
    try {
      var parsed = JSON.parse(String(raw || ""))
      values = parsed && typeof parsed === "object" ? parsed : ({})
    } catch (error) {
      console.warn("quickshell theme parse failed, using defaults:", error)
      values = ({})
    }
    revision++
  }

  function reload() { themeFile.reload() }

  property FileView themeFile: FileView {
    path: root.path
    watchChanges: true
    printErrors: false
    onLoaded: root.apply(text())
    onLoadFailed: root.apply("")
    onFileChanged: reload()
  }
}
