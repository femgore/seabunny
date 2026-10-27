"""Try this checkout's chooser on a private bus without registering or enabling it."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
BUS = "org.freedesktop.impl.portal.desktop.seabunny"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=["all", "open", "multiple", "folder", "save", "savefiles"], default="all")
    parser.add_argument("--auto-cancel", action="store_true", help="Cancel all dialogs automatically for a smoke test")
    parser.add_argument("--private-session", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    binary = ROOT / "target/release/xdg-desktop-portal-seabunny"
    if not binary.is_file():
        parser.error("Build this checkout first: cargo build --release --locked")
    if not args.private_session:
        (ROOT / "target").mkdir(exist_ok=True)
        fixture = Path(tempfile.mkdtemp(prefix="portal-development-", dir=ROOT / "target"))
        for name in ("home", "config", "data", "cache", "state"):
            (fixture / name).mkdir(mode=0o700)
        desktop_state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
        env = dict(os.environ, HOME=str(fixture / "home"), XDG_CONFIG_HOME=str(fixture / "config"),
            XDG_DATA_HOME=str(fixture / "data"), XDG_CACHE_HOME=str(fixture / "cache"), XDG_STATE_HOME=str(fixture / "state"),
            SEABUNNY_DESKTOP_STATE_HOME=str(desktop_state), SEABUNNY_DEVELOPMENT_PORTAL_TEST=str(fixture),
            GSETTINGS_BACKEND="memory")
        # Preserve the desktop's palette path without copying application settings.
        if not any(env.get(key) for key in ("SEABUNNY_SERPANTINUM_COLORS", "QS_COLORS_JSON", "QS_STATE_DIR")):
            for path in (desktop_state / "seabunny/serpantinum-colors.json", desktop_state / "serpantinum/qs_colors.json",
                    Path.home() / "serpantinum-migration/stock-session/state/qs_colors.json"):
                if path.exists() or path.is_symlink():
                    env["SEABUNNY_SERPANTINUM_COLORS"] = str(path)
                    break
        command = ["dbus-run-session", "--", sys.executable, "-u", "-B", str(Path(__file__).resolve()),
            "--private-session", "--case", args.case]
        if args.auto_cancel:
            command.append("--auto-cancel")
        print("Using the development backend on a private bus. Installed services and portal routing stay unchanged.", flush=True)
        print("Test profile and backend log: " + str(fixture), flush=True)
        return subprocess.run(command, env=env).returncode

    fixture_path = os.environ.get("SEABUNNY_DEVELOPMENT_PORTAL_TEST")
    if not fixture_path:
        parser.error("The private session must be started by this helper")
    from gi.repository import Gio, GLib
    fixture = Path(fixture_path)
    with (fixture / "backend.log").open("w") as log:
        backend = subprocess.Popen([str(binary)], stdout=log, stderr=subprocess.STDOUT)
        try:
            bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
            deadline = time.monotonic() + 15
            while True:
                if backend.poll() is not None:
                    raise RuntimeError("Development backend exited; see " + str(fixture / "backend.log"))
                owner = bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameHasOwner",
                    GLib.Variant("(s)", (BUS,)), GLib.VariantType("(b)"), Gio.DBusCallFlags.NONE, 2000, None).unpack()[0]
                if owner:
                    break
                if time.monotonic() >= deadline:
                    raise RuntimeError("Development backend did not activate; see " + str(fixture / "backend.log"))
                time.sleep(0.05)
            command = [sys.executable, "-u", "-B", str(ROOT / "tests/manual_portal_test.py"), "--case", args.case]
            if args.auto_cancel:
                command.append("--auto-cancel")
            return subprocess.run(command).returncode
        finally:
            if backend.poll() is None:
                backend.terminate()
                try:
                    backend.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    backend.kill()
                    backend.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
