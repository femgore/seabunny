"""Build Rust tests normally, then execute them with a disposable HOME/XDG profile."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[2]
command = ["cargo", "test", "--release", "--locked", "--no-run", "--bin", "seabunny", "--message-format=json"]
if "--offline" in sys.argv:
    command.append("--offline")
build = subprocess.run(command, cwd=root, text=True, capture_output=True, timeout=900)
print(build.stderr)
if build.returncode:
    print(build.stdout)
build.check_returncode()
executables = []
for line in build.stdout.splitlines():
    try:
        message = json.loads(line)
    except json.JSONDecodeError:
        continue
    if message.get("reason") == "compiler-artifact" and message.get("profile", {}).get("test") and message.get("executable"):
        executables.append(message["executable"])
assert executables, "Rust test executable was not produced"
with tempfile.TemporaryDirectory(prefix="seabunny-next-rust-") as tmp:
    fixture = Path(tmp)
    for name in ("home", "config", "data", "cache", "state", "runtime", "tmp"):
        (fixture / name).mkdir(mode=0o700)
    env = dict(os.environ, HOME=str(fixture / "home"), XDG_CONFIG_HOME=str(fixture / "config"),
        XDG_DATA_HOME=str(fixture / "data"), XDG_CACHE_HOME=str(fixture / "cache"), XDG_STATE_HOME=str(fixture / "state"),
        XDG_RUNTIME_DIR=str(fixture / "runtime"), TMPDIR=str(fixture / "tmp"),
        QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", GSETTINGS_BACKEND="memory",
        DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent", DISPLAY="", WAYLAND_DISPLAY="")
    for binary in executables:
        subprocess.run([binary, "--test-threads=1"], env=env, check=True, timeout=180)
