pragma Singleton
import QtQuick
import qs

QtObject {
  readonly property int barHeight: 26
  readonly property int shellHeight: 33
  readonly property int radius: 8
  readonly property int cardRadius: 12
  readonly property int outerMargin: 8
  readonly property int panelWidth: 380
  readonly property int gap: 4
  readonly property int pad: 12
  readonly property int sectionGap: 8
  readonly property int rightGap: 6
  readonly property int iconSlot: 27
  readonly property int statusSlot: 21
  readonly property int iconCanvas: 16
  readonly property int iconFontSize: 13
  readonly property int captionFontSize: 10
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
