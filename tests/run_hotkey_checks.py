"""Exercise real Qt keyboard events and file operations in an isolated profile."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="seabunny-hotkeys-") as tmp:
    fixture = Path(tmp)
    for name in ("home/work", "config/seabunny", "data", "cache", "state", "runtime"):
        (fixture / name).mkdir(parents=True, mode=0o700)
    for name in ("a.txt", "b.txt", ".hidden"):
        (fixture / "home/work" / name).write_text("synthetic test file\n")
    shutil.copytree(root / "qml", fixture / "qml")
    main = fixture / "qml/main.qml"
    aliases = {"Engine": "preferencesEngine", "Container": "gridContainer", "Keys": "globalKeyHandler",
        "Theme": "theme", "Prompt": "inputModal", "Properties": "propsModal", "Search": "searchInput", "Name": "chooserName"}
    # Tests use the active tab's engine, just like the production window.
    additions = "    readonly property var benchmarkEngine: window.engine\n" + "".join(
        f"    property alias benchmark{name}: {target}\n" for name, target in aliases.items() if name != "Engine")
    source = main.read_text().replace('readonly property var chooser: typeof portalRequest !== "undefined" ? portalRequest : null', 'property var chooser: null')
    main.write_text(source.replace("    id: window\n", "    id: window\n" + additions, 1))
    (fixture / "config/seabunny/config.json").write_text(json.dumps({"ui_source": str(main)}))
    env = dict(os.environ, HOME=str(fixture / "home"), XDG_CONFIG_HOME=str(fixture / "config"),
        XDG_DATA_HOME=str(fixture / "data"), XDG_CACHE_HOME=str(fixture / "cache"),
        XDG_STATE_HOME=str(fixture / "state"), XDG_RUNTIME_DIR=str(fixture / "runtime"),
        QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", GSETTINGS_BACKEND="memory",
        QT_FORCE_STDERR_LOGGING="1", DISPLAY="", WAYLAND_DISPLAY="",
        DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent", SEABUNNY_SERPANTINUM_COLORS=str(fixture / "absent"),
        SEABUNNY_QML=str(root / "tests/HotkeyChecks.qml"))
    result = subprocess.run([str(root / "target/release/seabunny")], env=env,
        text=True, capture_output=True, timeout=45)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "HOTKEY_CHECKS_PASSED" in output
    assert not any(error in output for error in ("HOTKEY_CHECKS_FAILED", "ReferenceError", "TypeError", "Unable to assign", "Binding loop"))
    assert (fixture / "home/work/renamed.txt").read_text() == "synthetic test file\n"
    assert (fixture / "home/work/Created ö").is_dir()
    assert (fixture / "home/work/b.txt").is_file()
    assert not (fixture / "home/work/searched.txt").exists()
    print("PASS on-disk rename, Trash undo and folder creation use only disposable files")
