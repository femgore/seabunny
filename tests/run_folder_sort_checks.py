"""Real backend persistence across processes using only synthetic folder state."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="seabunny-folder-sort-") as tmp:
    fixture = Path(tmp)
    for name in ("home/Pictures ö", "home/Default", "config/seabunny", "data", "cache", "state", "runtime"):
        (fixture / name).mkdir(parents=True, mode=0o700)
    for folder in ("Pictures ö", "Default"):
        (fixture / "home" / folder / ".visible-by-default").write_text("synthetic hidden file")
    (fixture / "home/alias").symlink_to(fixture / "home/Pictures ö", target_is_directory=True)
    env = dict(os.environ, HOME=str(fixture / "home"), XDG_CONFIG_HOME=str(fixture / "config"),
        XDG_DATA_HOME=str(fixture / "data"), XDG_CACHE_HOME=str(fixture / "cache"),
        XDG_STATE_HOME=str(fixture / "state"), XDG_RUNTIME_DIR=str(fixture / "runtime"),
        QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", GSETTINGS_BACKEND="memory",
        QT_FORCE_STDERR_LOGGING="1", DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent",
        DISPLAY="", WAYLAND_DISPLAY="", SEABUNNY_SERPANTINUM_COLORS=str(fixture / "absent"),
        SEABUNNY_QML=str(root / "tests/FolderSortChecks.qml"))
    state = fixture / "state/seabunny/folder-sorting.json"
    config = fixture / "config/seabunny/config.json"
    for stage in ("seed", "reset", "read"):
        config.write_text(json.dumps({"sort_test_stage": stage}))
        result = subprocess.run([str(root / "target/release/seabunny")], env=env,
            text=True, capture_output=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "FOLDER_SORT_PASSED" in output
        assert "FOLDER_SORT_FAILED" not in output
        saved = json.loads(state.read_text())
        if stage == "seed":
            assert saved == {"version": 1, "folders": {
                str(fixture / "home/Pictures ö"): {"field": "size", "ascending": True, "folders": "first"}}}
        else:
            assert saved == {"version": 1, "folders": {}}
    print("PASS only non-default folders occupy state; resetting removes the entry")
