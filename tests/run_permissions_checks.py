"""Exercise Properties permissions and type icons using only disposable files."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="seabunny-properties-") as tmp:
    fixture = Path(tmp)
    for name in ("home/work/Folder", "config/seabunny", "data", "cache", "state", "runtime"):
        (fixture / name).mkdir(parents=True, mode=0o700)
    work = fixture / "home/work"
    for name in ("Example ö.AppImage", "Archive.RAR", "Unchanged.txt"):
        (work / name).write_text("synthetic test file; never executed\n")
        (work / name).chmod(0o640)
    (work / "Folder").chmod(0o750)
    (work / "Link.AppImage").symlink_to(work / "Example ö.AppImage")
    shutil.copytree(root / "qml", fixture / "qml")
    main = fixture / "qml/main.qml"
    additions = "    readonly property var benchmarkEngine: window.engine\n" + "".join(
        f"    property alias benchmark{name}: {target}\n" for name, target in {
            "Container": "gridContainer", "View": "filesGridView", "Properties": "propsModal", "Theme": "theme"}.items())
    main.write_text(main.read_text().replace("    id: window\n", "    id: window\n" + additions, 1))
    (fixture / "config/seabunny/config.json").write_text(json.dumps({"ui_source": str(main),
        "permissions_preview": str(root / "target/permissions-preview.png")}))
    env = dict(os.environ, HOME=str(fixture / "home"), XDG_CONFIG_HOME=str(fixture / "config"),
        XDG_DATA_HOME=str(fixture / "data"), XDG_CACHE_HOME=str(fixture / "cache"),
        XDG_STATE_HOME=str(fixture / "state"), XDG_RUNTIME_DIR=str(fixture / "runtime"),
        QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", GSETTINGS_BACKEND="memory",
        QT_FORCE_STDERR_LOGGING="1", DISPLAY="", WAYLAND_DISPLAY="",
        DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent", SEABUNNY_SERPANTINUM_COLORS=str(fixture / "absent"),
        SEABUNNY_QML=str(root / "tests/PermissionsChecks.qml"))
    result = subprocess.run([str(root / "target/release/seabunny")], env=env,
        text=True, capture_output=True, timeout=45)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "PERMISSIONS_CHECKS_PASSED" in output
    assert not any(error in output for error in ("PERMISSIONS_CHECKS_FAILED", "ReferenceError", "TypeError", "Unable to assign", "Binding loop"))
    assert (work / "Example ö.AppImage").stat().st_mode & 0o777 == 0o600
    assert (work / "Folder").stat().st_mode & 0o777 == 0o740
    for name in ("Example ö.AppImage", "Archive.RAR", "Unchanged.txt"):
        assert (work / name).read_text() == "synthetic test file; never executed\n"
    assert (work / "Link.AppImage").is_symlink()
    print("PASS permission changes preserve contents and link targets in a disposable profile")
