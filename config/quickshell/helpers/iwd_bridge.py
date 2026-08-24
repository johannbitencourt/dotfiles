#!/usr/bin/env python3
"""JSON-lines bridge from Quickshell to iwd's native D-Bus API.

Credentials are accepted only on stdin and are never included in process argv
or diagnostic output. Requires Python 3, PyGObject and Gio.
"""
import json
import sys
import threading
import uuid
import warnings

import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

warnings.filterwarnings("ignore", category=DeprecationWarning)

BUS = "net.connman.iwd"
AGENT_PATH = "/org/quickshell/IwdAgent"
AGENT_XML = """<node><interface name='net.connman.iwd.Agent'>
<method name='RequestPassphrase'><arg type='o' direction='in'/><arg type='s' direction='out'/></method>
<method name='RequestPrivateKeyPassphrase'><arg type='o' direction='in'/><arg type='s' direction='out'/></method>
<method name='RequestUserNameAndPassword'><arg type='o' direction='in'/><arg type='s' direction='out'/><arg type='s' direction='out'/></method>
<method name='Cancel'><arg type='s' direction='in'/></method><method name='Release'/>
</interface></node>"""


class Bridge:
    def __init__(self):
        self.loop = GLib.MainLoop()
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.manager = None
        self.objects = {}
        self.pending = {}
        self.agent_registration = 0
        self.name_watch = Gio.bus_watch_name(
            Gio.BusType.SYSTEM,
            BUS,
            Gio.BusNameWatcherFlags.NONE,
            self.name_appeared,
            self.name_vanished,
        )

    def emit(self, payload):
        print(json.dumps(payload, separators=(",", ":")), flush=True)

    def call(self, path, interface, method, params=None):
        proxy = Gio.DBusProxy.new_sync(self.bus, Gio.DBusProxyFlags.NONE, None, BUS, path, interface, None)
        return proxy.call_sync(method, params, Gio.DBusCallFlags.NONE, 30000, None)

    def call_async(self, path, interface, method, params=None, operation=None):
        proxy = Gio.DBusProxy.new_sync(self.bus, Gio.DBusProxyFlags.NONE, None, BUS, path, interface, None)

        def complete(source, result, _data=None):
            try:
                source.call_finish(result)
                if operation:
                    self.emit({"type": "operation", **operation, "ok": True})
                GLib.timeout_add(150, self.snapshot)
            except GLib.Error as exc:
                if operation:
                    self.emit({"type": "operation", **operation, "ok": False, "message": exc.message})
                else:
                    self.emit({"type": "error", "message": exc.message})

        proxy.call(method, params, Gio.DBusCallFlags.NONE, 30000, None, complete)

    def name_appeared(self, *_args):
        GLib.idle_add(self.connect_manager)

    def name_vanished(self, *_args):
        self.manager = None
        for request_id in self.pending:
            self.emit({"type": "credential-cancelled", "id": request_id})
        self.pending.clear()
        self.emit({"type": "snapshot", "available": False, "powered": False,
                   "scanning": False, "state": "unavailable", "networks": [],
                   "error": "iwd D-Bus service unavailable"})

    def connect_manager(self):
        try:
            self.manager = Gio.DBusObjectManagerClient.new_sync(
                self.bus, Gio.DBusObjectManagerClientFlags.NONE, BUS, "/", None, None, None)
            if not self.manager.get_name_owner():
                self.name_vanished()
                return False
            self.manager.connect("object-added", lambda *_: self.snapshot())
            self.manager.connect("object-removed", lambda *_: self.snapshot())
            self.manager.connect("interface-proxy-properties-changed", lambda *_: self.snapshot())
            self.register_agent()
            self.snapshot()
        except GLib.Error as exc:
            self.manager = None
            self.emit({"type": "snapshot", "available": False, "powered": False,
                       "scanning": False, "state": "unavailable", "networks": [],
                       "error": "iwd D-Bus service unavailable"})
        return False

    @staticmethod
    def props(interface):
        out = {}
        for name in interface.get_cached_property_names() or []:
            value = interface.get_cached_property(name)
            out[name] = value.unpack() if value is not None else None
        return out

    def interfaces(self, name):
        if not self.manager:
            return []
        found = []
        for obj in self.manager.get_objects():
            iface = obj.get_interface(name)
            if iface:
                found.append((obj.get_object_path(), iface, self.props(iface)))
        return found

    def snapshot(self):
        if not self.manager:
            return False
        devices = self.interfaces("net.connman.iwd.Device")
        adapters = self.interfaces("net.connman.iwd.Adapter")
        stations = self.interfaces("net.connman.iwd.Station")
        known = {(p.get("Name", ""), p.get("Type", "")): path
                 for path, _, p in self.interfaces("net.connman.iwd.KnownNetwork")}
        networks = []
        scanning = False
        state = "disconnected"
        for _, _, props in stations:
            scanning = scanning or bool(props.get("Scanning", False))
            state = props.get("State", state)
        for path, _, props in self.interfaces("net.connman.iwd.Network"):
            name = props.get("Name", "")
            networks.append({"path": path, "name": name, "type": props.get("Type", ""),
                             "connected": props.get("Connected", False),
                              "knownPath": known.get((name, props.get("Type", "")), "")})
        networks.sort(key=lambda n: (not n["connected"], n["name"].lower()))
        powered = any(bool(props.get("Powered", True)) for _, _, props in adapters) if adapters else bool(devices)
        self.emit({"type": "snapshot", "available": True, "powered": powered,
                   "scanning": scanning, "state": state, "networks": networks, "error": ""})
        return False

    def register_agent(self):
        if not self.agent_registration:
            node = Gio.DBusNodeInfo.new_for_xml(AGENT_XML)
            self.agent_registration = self.bus.register_object(
                AGENT_PATH, node.interfaces[0], self.agent_call, None, None)
        try:
            self.call("/net/connman/iwd", "net.connman.iwd.AgentManager", "RegisterAgent",
                      GLib.Variant("(o)", (AGENT_PATH,)))
        except GLib.Error:
            pass

    def agent_call(self, _conn, _sender, _path, _iface, method, params, invocation):
        if method in ("RequestPassphrase", "RequestPrivateKeyPassphrase", "RequestUserNameAndPassword"):
            request_id = uuid.uuid4().hex
            kind = "user-password" if method == "RequestUserNameAndPassword" else ("private-key" if "PrivateKey" in method else "passphrase")
            network_path = params.unpack()[0] if params.n_children() else ""
            self.pending[request_id] = {"invocation": invocation, "kind": kind}
            self.emit({"type": "credential-request", "id": request_id,
                       "kind": kind, "path": network_path})
        elif method == "Cancel":
            for request_id, pending in self.pending.items():
                pending["invocation"].return_dbus_error("net.connman.iwd.Agent.Error.Canceled", "Canceled")
                self.emit({"type": "credential-cancelled", "id": request_id})
            self.pending.clear()
            invocation.return_value(None)
        else:
            invocation.return_value(None)

    def station_path(self):
        stations = self.interfaces("net.connman.iwd.Station")
        return stations[0][0] if stations else ""

    def command(self, msg):
        cmd = msg.get("command", "")
        operation = {"id": str(msg.get("id", "")), "action": cmd, "path": str(msg.get("path", ""))}
        try:
            if cmd == "credential":
                pending = self.pending.pop(str(msg.get("id", "")), None)
                if pending:
                    if pending["kind"] == "user-password":
                        pending["invocation"].return_value(GLib.Variant("(ss)", (str(msg.get("username", "")), str(msg.get("value", "")))))
                    else:
                        pending["invocation"].return_value(GLib.Variant("(s)", (str(msg.get("value", "")),)))
                return
            if cmd == "cancel-credential":
                request_id = str(msg.get("id", ""))
                pending = self.pending.pop(request_id, None)
                if pending:
                    pending["invocation"].return_dbus_error("net.connman.iwd.Agent.Error.Canceled", "Canceled")
                    self.emit({"type": "credential-cancelled", "id": request_id})
                return
            if not self.manager:
                raise RuntimeError("iwd unavailable")
            if cmd == "scan":
                path = self.station_path()
                if not path:
                    raise RuntimeError("iwd station unavailable")
                self.call_async(path, "net.connman.iwd.Station", "Scan", operation=operation)
            elif cmd == "connect":
                # Keep the main loop free to answer Agent.RequestPassphrase
                # while iwd completes the pending Connect method.
                self.call_async(str(msg["path"]), "net.connman.iwd.Network", "Connect", operation=operation)
            elif cmd == "disconnect":
                path = self.station_path()
                if not path:
                    raise RuntimeError("iwd station unavailable")
                self.call_async(path, "net.connman.iwd.Station", "Disconnect", operation=operation)
            elif cmd == "forget":
                self.call_async(str(msg["path"]), "net.connman.iwd.KnownNetwork", "Forget", operation=operation)
            elif cmd == "toggle":
                adapters = self.interfaces("net.connman.iwd.Adapter")
                if not adapters:
                    raise RuntimeError("iwd adapter unavailable")
                parameters = GLib.Variant("(ssv)", ("net.connman.iwd.Adapter", "Powered",
                                                       GLib.Variant("b", bool(msg.get("enabled")))))
                self.call_async(adapters[0][0], "org.freedesktop.DBus.Properties", "Set",
                                parameters, operation=operation)
            elif cmd != "snapshot":
                raise ValueError("unknown command")
            else:
                self.snapshot()
        except (GLib.Error, KeyError, RuntimeError, ValueError) as exc:
            if operation["id"] and cmd in ("scan", "connect", "disconnect", "forget", "toggle"):
                self.emit({"type": "operation", **operation, "ok": False, "message": str(exc)})
            else:
                self.emit({"type": "error", "message": str(exc)})

    def stdin_loop(self):
        for line in sys.stdin:
            try:
                msg = json.loads(line)
                GLib.idle_add(self.command, msg)
            except (ValueError, TypeError):
                self.emit({"type": "error", "message": "invalid JSON command"})
        self.loop.quit()

    def run(self):
        threading.Thread(target=self.stdin_loop, daemon=True).start()
        self.loop.run()


if __name__ == "__main__":
    Bridge().run()
