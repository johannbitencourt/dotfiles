import QtQuick
import qs
import qs.Commons
import qs.Ui

PillButton { required property var app; barStyle: true; fixedWidth: Style.statusSlot; horizontalPadding: 0; fontSize: Style.captionFontSize; visible: app.updates.count > 0; width: visible ? implicitWidth : 0; text: ""; tooltip: "System updates"; onClicked: app.commands.terminal(app.commands.scripts + "/updates run") }
