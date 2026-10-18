"""Real private-bus activation, wire types, concurrent windows and cancellation.
Run with system Python (PyGObject), no live session or personal profile.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import json
import shutil
import urllib.request
import signal

ROOT = Path(__file__).resolve().parents[1]
NAME = "org.freedesktop.impl.portal.desktop.seabunny"
OBJECT = "/org/freedesktop/portal/desktop"
IFACE = "org.freedesktop.impl.portal.FileChooser"


def inner():
    from gi.repository import Gio, GLib
    subprocess.run([str(ROOT / "target/seabunny-qt-tests/portal-tests")],
        env=dict(os.environ, SEABUNNY_PRIVATE_BUS_TEST="1"), check=True, timeout=20)
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    def call(path, interface, method, args=None, signature=None):
        return bus.call_sync(NAME, path, interface, method, args,
            GLib.VariantType(signature) if signature else None, Gio.DBusCallFlags.NONE, 10000, None)
    # Auto-activation is intentionally exercised; the test does not launch the backend.
    xml = call(OBJECT, "org.freedesktop.DBus.Introspectable", "Introspect", signature="(s)").unpack()[0]
    for method in ("OpenFile", "SaveFile", "SaveFiles"):
        assert 'name="'+method+'"' in xml or "name='"+method+"'" in xml
    version = call(OBJECT, "org.freedesktop.DBus.Properties", "Get", GLib.Variant("(ss)", (IFACE,"version")), "(v)")
    assert version.unpack()[0] == 3
    pending = {}; loop = GLib.MainLoop()
    def completed(connection, result, key):
        try:
            reply = connection.call_finish(result)
            assert reply.get_type_string() == "(ua{sv})"
            pending[key] = reply.unpack()
        except Exception as error:
            pending[key] = error
    for i, method in enumerate(("OpenFile", "SaveFile", "SaveFiles")):
        options = {"current_folder": GLib.Variant("ay", (str(Path.home())+"\0").encode()),
            "filters": GLib.Variant("a(sa(us))", [("Text", [(0,"*.txt")])]),
            "choices": GLib.Variant("a(ssa(ss)s)", [("flag", "Flag", [], "true")]),
            "current_name": GLib.Variant("s", "suggested 日本語.txt"),
            "files": GLib.Variant("aay", [b"one.txt\0", b"two.txt\0"])}
        path = OBJECT+"/request/test/"+str(i)
        bus.call(NAME, OBJECT, IFACE, method, GLib.Variant("(osssa{sv})", (path,"test.app","",method,options)),
                 GLib.VariantType("(ua{sv})"), Gio.DBusCallFlags.NONE, 15000, None, completed, i)
    deadline=time.monotonic()+10
    # Confirm all three request objects exist, then cancel independently.
    for i in range(3):
        path=OBJECT+"/request/test/"+str(i)
        while True:
            text=call(path,"org.freedesktop.DBus.Introspectable","Introspect",signature="(s)").unpack()[0]
            if "org.freedesktop.impl.portal.Request" in text: break
            assert time.monotonic()<deadline, text
            time.sleep(.05)
        call(path,"org.freedesktop.impl.portal.Request","Close", signature="()")
    while len(pending)<3 and time.monotonic()<deadline:
        GLib.MainContext.default().iteration(False)
        time.sleep(.01)
    assert pending == {0:(1,{}),1:(1,{}),2:(1,{})}, pending
    # The service remains alive after closing its last chooser.
    call(OBJECT,"org.freedesktop.DBus.Properties","Get",GLib.Variant("(ss)",(IFACE,"version")),"(v)")
    assert not (Path(os.environ["XDG_CONFIG_HOME"])/"seabunny/config.json").exists(), "chooser must not save preferences/tabs"
    print("PASS private D-Bus activation, signatures, 3 concurrent chooser windows, cancellation, service lifetime")
    # Act as a portal-aware application against the real xdg-desktop-portal frontend.
    for method in ("OpenFile", "SaveFile", "SaveFiles"):
        opts={"handle_token":GLib.Variant("s", "public_"+method), "current_name":GLib.Variant("s", "public.txt"),
              "files": GLib.Variant("aay", [b"public.txt\0"])}
        reply=bus.call_sync("org.freedesktop.portal.Desktop", OBJECT, "org.freedesktop.portal.FileChooser", method,
            GLib.Variant("(ssa{sv})", ("", "Public "+method, opts)), GLib.VariantType("(o)"), Gio.DBusCallFlags.NONE,10000,None)
        path=reply.unpack()[0]
        deadline=time.monotonic()+8
        while True:
            xml=call(path,"org.freedesktop.DBus.Introspectable","Introspect",signature="(s)").unpack()[0]
            if "org.freedesktop.impl.portal.Request" in xml: break
            assert time.monotonic()<deadline, "Frontend did not route to Seabunny: "+method
            time.sleep(.05)
        bus.call_sync("org.freedesktop.portal.Desktop",path,"org.freedesktop.portal.Request","Close",None,
                      GLib.VariantType("()"),Gio.DBusCallFlags.NONE,10000,None)
    print("PASS portal-aware client: public OpenFile/SaveFile/SaveFiles route through frontend to Seabunny and cancel")
    if "--helium" in sys.argv: helium_check(bus)


def helium_check(bus):
    from gi.repository import Gio, GLib
    from websockets.sync.client import connect
    # A separate private-bus monitor verifies Helium actually calls SaveFile.
    monitor=Gio.DBusConnection.new_for_address_sync(os.environ["DBUS_SESSION_BUS_ADDRESS"],
        Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,None,None)
    seen=[]
    def incoming(connection,message,incoming,*unused):
        if incoming and message.get_interface()==IFACE and message.get_member()=="SaveFile":
            seen.append(message.get_body().unpack())
            return None  # Monitors must not dispatch/reply to observed method calls.
        return message
    monitor.add_filter(incoming,None)
    monitor.call_sync("org.freedesktop.DBus","/org/freedesktop/DBus","org.freedesktop.DBus.Monitoring","BecomeMonitor",
        GLib.Variant("(asu)",(["type='method_call',interface='"+IFACE+"',member='SaveFile'"],0)),None,Gio.DBusCallFlags.NONE,5000,None)
    wrapper=shutil.which("helium-browser")
    assert wrapper, "Helium is not installed"
    binary=Path(wrapper).resolve().parent/"helium"
    profile=Path.home()/"disposable-helium"
    (profile/"Default").mkdir(parents=True)
    (profile/"Default/Preferences").write_text(json.dumps({"download":{"prompt_for_download":True,"default_directory":str(Path.home())}}))
    page=Path.home()/"Portal Save Test.html"
    page.write_text("<html><title>Seabunny portal test</title><body>Synthetic Save As test.</body></html>")
    with (Path.home()/"helium-test.log").open("w+") as log:
        process=subprocess.Popen([str(binary),"--ozone-platform=headless","--disable-gpu","--user-data-dir="+str(profile),
            "--remote-debugging-port=0","--no-first-run","--no-default-browser-check","--disable-background-networking",
            "--disable-component-update","--disable-sync",page.as_uri()],stdout=log,stderr=log)
        try:
            port_file=profile/"DevToolsActivePort"
            deadline=time.monotonic()+15
            while not port_file.exists():
                assert process.poll() is None, "Helium exited before DevTools startup"
                assert time.monotonic()<deadline, "Helium startup timeout"
                time.sleep(.1)
            port=int(port_file.read_text().splitlines()[0])
            targets=json.load(urllib.request.urlopen("http://127.0.0.1:"+str(port)+"/json"))
            target=next(t for t in targets if t["type"]=="page")
            with connect(target["webSocketDebuggerUrl"],open_timeout=5) as websocket:
                websocket.send(json.dumps({"id":90,"method":"Page.bringToFront"}))
                while json.loads(websocket.recv(timeout=5)).get("id")!=90: pass
                time.sleep(1)
                for i,kind in enumerate(("rawKeyDown","keyUp"),1):
                    websocket.send(json.dumps({"id":i,"method":"Input.dispatchKeyEvent","params":
                        {"type":kind,"key":"s","code":"KeyS","windowsVirtualKeyCode":83,"modifiers":2}}))
                    while json.loads(websocket.recv(timeout=5)).get("id")!=i: pass
                # A prompted download also exercises Chromium's Save As dialog when
                # the headless window does not dispatch browser accelerator keys.
                websocket.send(json.dumps({"id":99,"method":"Runtime.evaluate","params":{"userGesture":True,
                    "expression":"var a=document.createElement('a'); a.download='Synthetic 日本語.txt'; a.href='data:text/plain,Synthetic%20portal%20test'; document.body.appendChild(a); a.click();"}}))
                while json.loads(websocket.recv(timeout=5)).get("id")!=99: pass
                deadline=time.monotonic()+12
                while not seen and time.monotonic()<deadline:
                    GLib.MainContext.default().iteration(False)
                    time.sleep(.05)
            assert seen, "Helium Save As did not reach Seabunny's portal backend"
            assert seen[0][4].get("current_name"), "Helium did not send a suggested filename"
            reply=bus.call_sync(NAME,seen[0][0],"org.freedesktop.DBus.Introspectable","Introspect",None,
                GLib.VariantType("(s)"),Gio.DBusCallFlags.NONE,5000,None)
            assert "org.freedesktop.impl.portal.Request" in reply.unpack()[0], "Helium chooser was not created"
            print("PASS Helium Save As reaches Seabunny SaveFile with a suggested filename (headless Ozone, disposable profile)")
        finally:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=8)
                except subprocess.TimeoutExpired: process.kill(); process.wait(timeout=5)
            log.seek(0); print(log.read()[-3000:])
            monitor.close_sync(None)


def outer():
    with tempfile.TemporaryDirectory(prefix="seabunny-portal-bus-") as tmp:
        fixture=Path(tmp)
        for name in ("home", "config", "data/dbus-1/services", "cache", "state", "runtime"):
            (fixture/name).mkdir(parents=True,mode=0o700)
        executable=ROOT/"target/release/xdg-desktop-portal-seabunny"
        (fixture/"data/dbus-1/services"/(NAME+".service")).write_text(
            '[D-BUS Service]\nName='+NAME+'\nExec="'+str(executable)+'"\n')
        (fixture/"home/example.txt").write_text("synthetic")
        (fixture/"data/xdg-desktop-portal/portals").mkdir(parents=True)
        (fixture/"data/xdg-desktop-portal/portals/seabunny.portal").write_bytes((ROOT/"packaging/seabunny/seabunny.portal").read_bytes())
        (fixture/"config/xdg-desktop-portal").mkdir()
        (fixture/"config/xdg-desktop-portal/portals.conf").write_text("[preferred]\ndefault=none\norg.freedesktop.impl.portal.FileChooser=seabunny\n")
        env=dict(os.environ)
        env.update(HOME=str(fixture/"home"),XDG_CONFIG_HOME=str(fixture/"config"),XDG_DATA_HOME=str(fixture/"data"),
            XDG_CACHE_HOME=str(fixture/"cache"),XDG_STATE_HOME=str(fixture/"state"),XDG_RUNTIME_DIR=str(fixture/"runtime"),
            QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software",GSETTINGS_BACKEND="memory",
            DISPLAY="",WAYLAND_DISPLAY="",SEABUNNY_SERPANTINUM_COLORS=str(fixture/"absent-palette"))
        with (fixture/"test.log").open("w+") as log:
            result=subprocess.run(["dbus-run-session","--",sys.executable,"-u","-B",__file__,"--inner"]+(["--helium"] if "--helium" in sys.argv else []),env=env,text=True,stdout=log,stderr=log,timeout=70)
            log.seek(0); output=log.read()
        print(output)
        assert result.returncode==0
        assert "QQmlApplicationEngine failed to load" not in output
        assert "ReferenceError" not in output and "TypeError" not in output

def cleanup_private_services():
    from gi.repository import Gio, GLib
    bus=Gio.bus_get_sync(Gio.BusType.SESSION,None)
    for name in ("org.freedesktop.portal.Desktop", NAME, "org.freedesktop.portal.Documents", "org.freedesktop.impl.portal.PermissionStore", "org.a11y.Bus"):
        try:
            reply=bus.call_sync("org.freedesktop.DBus","/org/freedesktop/DBus","org.freedesktop.DBus","GetConnectionUnixProcessID",
                GLib.Variant("(s)",(name,)),GLib.VariantType("(u)"),Gio.DBusCallFlags.NONE,1000,None)
            os.kill(reply.unpack()[0],signal.SIGTERM)
        except (GLib.Error,ProcessLookupError): pass
    time.sleep(.5)

if __name__=="__main__":
    if "--inner" in sys.argv:
        try: inner()
        finally: cleanup_private_services()
    else: outer()
