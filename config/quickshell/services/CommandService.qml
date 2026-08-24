import Quickshell
import QtQuick

QtObject {
  readonly property string scripts: Quickshell.shellDir + "/scripts"
  function run(script, args) { Quickshell.execDetached([scripts + "/" + script].concat(args || [])) }
  function terminal(command) { run("terminal", command ? [command] : []) }
}
