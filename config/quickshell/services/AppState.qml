import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick

QtObject {
  id: root
  readonly property CommandService commands: CommandService {}
  readonly property PopupCoordinator popups: PopupCoordinator {}
  readonly property PlatformService platform: PlatformService { scripts: root.commands.scripts }
  readonly property UpdatesService updates: UpdatesService { scripts: root.commands.scripts }
  readonly property WeatherService weather: WeatherService { scripts: root.commands.scripts }
  readonly property CpuService cpu: CpuService { scripts: root.commands.scripts }
  readonly property BrightnessService brightness: BrightnessService { scripts: root.commands.scripts }
  readonly property MonitorService monitors: MonitorService { scripts: root.commands.scripts }
  readonly property DndService dnd: DndService { scripts: root.commands.scripts }
  readonly property TraySettings tray: TraySettings { scripts: root.commands.scripts }
  readonly property BarSettings barSettings: BarSettings { scripts: root.commands.scripts }
  readonly property StayAwakeService stayAwake: StayAwakeService { scripts: root.commands.scripts }
  readonly property PowerService power: PowerService { scripts: root.commands.scripts }
  readonly property IwdService iwd: IwdService {}
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var pipewireNodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var battery: UPower.displayDevice
  readonly property bool onBattery: UPower.onBattery
  readonly property var tracked: [sink, source].concat(pipewireNodes)
  property PwObjectTracker tracker: PwObjectTracker { objects: root.tracked }
  function setOutputVolume(v) { if (sink && sink.audio) sink.audio.volume = Math.max(0, Math.min(1, v)) }
  function setInputVolume(v) { if (source && source.audio) source.audio.volume = Math.max(0, Math.min(1, v)) }
  function toggleAllMuted() {
    var mute = !!((sink && sink.audio && !sink.audio.muted) || (source && source.audio && !source.audio.muted))
    if (sink && sink.audio) sink.audio.muted = mute
    if (source && source.audio) source.audio.muted = mute
  }
}
