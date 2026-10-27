"""Interactive chooser checks on the live session; no routing or service changes.

Use only after explicitly registering the backend. Fixture files are retained under
target/ so users can inspect or reuse them. The chooser never writes output files.
"""
import argparse
import os
from pathlib import Path
import signal
import tempfile
import uuid

from gi.repository import Gio, GLib, GLibUnix


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=["all", "open", "multiple", "folder", "save", "savefiles"], default="all")
    parser.add_argument("--frontend", action="store_true", help="Test the active public desktop portal instead of calling the backend directly")
    parser.add_argument("--auto-cancel", action="store_true", help="Cancel each request automatically for a smoke test")
    args = parser.parse_args()
    repository = Path(__file__).resolve().parents[1]
    fixture = Path(tempfile.mkdtemp(prefix="portal-live-test-", dir=repository / "target"))
    (fixture / "Choose this folder").mkdir()
    for name in ("First file.txt", "Second 日本語.txt", "existing.txt"):
        (fixture / name).write_text("Disposable Seabunny chooser test.\n")
    folder = GLib.Variant("ay", str(fixture).encode() + b"\0")
    filters = GLib.Variant("a(sa(us))", [("Text files", [(0, "*.txt")]), ("All files", [(0, "*")])])
    cases = [
        ("open", "OpenFile", "Choose one test file", {"filters": filters}),
        ("multiple", "OpenFile", "Select two test files with Ctrl", {"multiple": GLib.Variant("b", True), "filters": filters}),
        ("folder", "OpenFile", "Select the test folder", {"directory": GLib.Variant("b", True)}),
        ("save", "SaveFile", "Save As — try existing.txt for overwrite confirmation", {
            "current_name": GLib.Variant("s", "Suggested 日本語"), "filters": filters}),
        ("savefiles", "SaveFiles", "Choose a folder for two output names", {
            "files": GLib.Variant("aay", [b"existing.txt\0", "New output ö.txt\0".encode()])}),
    ]
    if args.case != "all":
        cases = [case for case in cases if case[0] == args.case]
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    service = "org.freedesktop.portal.Desktop" if args.frontend else "org.freedesktop.impl.portal.desktop.seabunny"
    root = "/org/freedesktop/portal/desktop"
    loop = GLib.MainLoop()
    state = {"index": 0, "handle": None, "failed": False}
    token = "live_" + uuid.uuid4().hex

    def close_request():
        if state["handle"]:
            try:
                interface = "org.freedesktop.portal.Request" if args.frontend else "org.freedesktop.impl.portal.Request"
                bus.call_sync(service, state["handle"], interface, "Close",
                    None, GLib.VariantType("()"), Gio.DBusCallFlags.NONE, 3000, None)
            except GLib.Error:
                pass  # The backend may already have completed this exact request.
        loop.quit()
        return GLib.SOURCE_REMOVE

    def completed(connection, result, label):
        try:
            response, values = connection.call_finish(result).unpack()
        except GLib.Error as error:
            state["handle"] = None
            print("Request failed: " + error.message, flush=True)
            state["failed"] = True
            loop.quit()
            return
        finish_response(label, response, values)

    def finish_response(label, response, values):
        state["handle"] = None
        uris = values.get("uris", [])
        print(label + ": " + ({0: "accepted", 1: "cancelled", 2: "failed"}.get(response, "unknown response"))
            + (" (" + str(len(uris)) + " URI(s))" if response == 0 else ""), flush=True)
        # Do not print filenames selected outside the disposable fixture.
        if response not in (0, 1):
            state["failed"] = True
        state["index"] += 1
        GLib.idle_add(next_case)

    def frontend_response(connection, sender, object_path, interface, signal_name, parameters):
        if object_path == state["handle"]:
            finish_response(cases[state["index"]][0], *parameters.unpack())

    if args.frontend:
        bus.signal_subscribe(service, "org.freedesktop.portal.Request", "Response", None, None,
            Gio.DBusSignalFlags.NONE, frontend_response)

    def cancel_case(expected_handle):
        if state["handle"] != expected_handle:
            return GLib.SOURCE_REMOVE
        interface = "org.freedesktop.portal.Request" if args.frontend else "org.freedesktop.impl.portal.Request"
        try:
            bus.call_sync(service, expected_handle, interface, "Close", None, GLib.VariantType("()"),
                Gio.DBusCallFlags.NONE, 10000, None)
        except GLib.Error as error:
            print("Cancellation failed: " + error.message, flush=True)
            state["failed"] = True
            loop.quit()
        return GLib.SOURCE_REMOVE

    def next_case():
        index = state["index"]
        if index >= len(cases):
            print("Interactive sequence finished. Output files were not created by the chooser.", flush=True)
            loop.quit()
            return GLib.SOURCE_REMOVE
        label, method, title, options = cases[index]
        state["handle"] = root + "/request/" + token + "/step_" + str(index)
        options = dict(options, current_folder=folder)
        print("Opening " + str(index + 1) + "/" + str(len(cases)) + ": " + title, flush=True)
        if args.frontend:
            request_token = token + "_step_" + str(index)
            sender = bus.get_unique_name().removeprefix(":").replace(".", "_")
            state["handle"] = root + "/request/" + sender + "/" + request_token
            options["handle_token"] = GLib.Variant("s", request_token)
            try:
                reply = bus.call_sync(service, root, "org.freedesktop.portal.FileChooser", method,
                    GLib.Variant("(ssa{sv})", ("", "Seabunny test — " + title, options)),
                    GLib.VariantType("(o)"), Gio.DBusCallFlags.NONE, 10000, None)
                state["handle"] = reply.unpack()[0]
                if args.auto_cancel:
                    GLib.timeout_add(500, cancel_case, state["handle"])
            except GLib.Error as error:
                print("Public portal request failed: " + error.message, flush=True)
                state["failed"] = True
                close_request()
            return GLib.SOURCE_REMOVE
        bus.call(service, root, "org.freedesktop.impl.portal.FileChooser", method,
            GLib.Variant("(osssa{sv})", (state["handle"], "org.femgore.Seabunny.Test", "", "Seabunny test — " + title, options)),
            GLib.VariantType("(ua{sv})"), Gio.DBusCallFlags.NONE, 3600000, None, completed, label)
        if args.auto_cancel:
            GLib.timeout_add(500, cancel_case, state["handle"])
        return GLib.SOURCE_REMOVE

    print("Disposable files: " + str(fixture), flush=True)
    print("Accept or cancel each dialog to advance. No system-wide chooser preferences are changed.", flush=True)
    if args.frontend:
        print("Using the public desktop portal and its active FileChooser preference.", flush=True)
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, close_request)
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, close_request)
    GLib.idle_add(next_case)
    loop.run()
    return 1 if state["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
