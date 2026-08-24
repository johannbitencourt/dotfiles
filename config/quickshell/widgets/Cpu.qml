import QtQuick
import qs.Ui

PillButton { required property var app; barStyle: true; horizontalPadding: 7.5; text: app.cpu.usage + "% 󰍛"; tooltip: app.cpu.details; onClicked: app.commands.run("btop", []) }
