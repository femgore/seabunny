"""Run native Qt/GIO and private-bus controller checks with disposable state."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--build-dir", required=True)
args = parser.parse_args()
build = Path(args.build_dir).resolve()
with tempfile.TemporaryDirectory(prefix="seabunny-next-native-") as tmp:
    fixture = Path(tmp)
    for name in ("home", "config", "data", "cache", "state", "runtime"):
        (fixture / name).mkdir(mode=0o700)
    env = dict(os.environ, HOME=str(fixture / "home"), XDG_CONFIG_HOME=str(fixture / "config"),
        XDG_DATA_HOME=str(fixture / "data"), XDG_CACHE_HOME=str(fixture / "cache"), XDG_STATE_HOME=str(fixture / "state"),
        XDG_RUNTIME_DIR=str(fixture / "runtime"), QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
        GSETTINGS_BACKEND="memory", DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent", DISPLAY="", WAYLAND_DISPLAY="")
    subprocess.run(["ctest", "--test-dir", str(build), "--output-on-failure"], env=env, check=True, timeout=90)
    env["SEABUNNY_PRIVATE_BUS_TEST"] = "1"
    subprocess.run(["dbus-run-session", "--", str(build / "portal-tests")], env=env, check=True, timeout=30)
