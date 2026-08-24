pragma Singleton
import QtQuick

QtObject {
  function clamp(value, low, high) { return Math.max(low, Math.min(high, value)) }
  function minutes(seconds) {
    if (!seconds || seconds <= 0) return ""
    var m = Math.round(seconds / 60)
    return m >= 60 ? Math.floor(m / 60) + "h " + (m % 60) + "m" : m + "m"
  }
  function label(value, fallback) {
    var text = String(value || "").trim()
    return text || fallback
  }
}
