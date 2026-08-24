import Quickshell.Io
import QtQuick

QtObject {
  id: root
  required property string scripts
  property int clockFormatIndex: 0
  property bool showBatteryPercentage: true
  property bool calendarMondayFirst: true
  property int calendarBirthYear: 0
  property int calendarLifeExpectancy: 90
  property string pending: ""
  function cycleClock(count) { clockFormatIndex = (clockFormatIndex + 1) % count; save() }
  function toggleBatteryPercentage() { showBatteryPercentage = !showBatteryPercentage; save() }
  function toggleCalendarWeekStart() { calendarMondayFirst = !calendarMondayFirst; save() }
  function setCalendarLife(birthYear, lifeExpectancy) { calendarBirthYear = birthYear; calendarLifeExpectancy = lifeExpectancy; save() }
  function save() { pending = JSON.stringify({ clockFormat: clockFormatIndex, batteryPercentage: showBatteryPercentage, calendarMondayFirst: calendarMondayFirst, calendarBirthYear: calendarBirthYear, calendarLifeExpectancy: calendarLifeExpectancy }); write() }
  function write() {
    if (writer.running || pending === "") return
    var value = pending; pending = ""
    writer.command = [scripts + "/bar-settings", "set", value]
    writer.running = true
  }
  property Process reader: Process {
    command: [root.scripts + "/bar-settings", "get"]
    running: true
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: { try { var value = JSON.parse(text); root.clockFormatIndex = Number(value.clockFormat) || 0; root.showBatteryPercentage = value.batteryPercentage !== false; root.calendarMondayFirst = value.calendarMondayFirst !== false; root.calendarBirthYear = Number(value.calendarBirthYear) || 0; root.calendarLifeExpectancy = Number(value.calendarLifeExpectancy) || 90 } catch (error) {} } }
  }
  property Process writer: Process { onExited: root.write() }
}
