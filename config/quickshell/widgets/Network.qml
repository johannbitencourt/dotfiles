import QtQuick
import qs.Commons
import qs.Ui

PillButton { required property var app; barStyle: true; fixedWidth: Style.iconSlot; horizontalPadding: 0; fontSize: Style.iconFontSize; text: !app.iwd.available ? "󰤮" : (app.iwd.state === "connected" ? "󰤨" : "󰤭"); tooltip: app.iwd.error || "iwd: " + app.iwd.state }
