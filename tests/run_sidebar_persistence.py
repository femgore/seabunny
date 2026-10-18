"""Exercise explorer and chooser sidebar state across separate app processes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="seabunny-sidebar-persistence-") as tmp:
    fixture = Path(tmp)
    for name in ("home", "config/seabunny", "data", "cache", "state", "runtime"):
        (fixture / name).mkdir(parents=True, mode=0o700)
    shutil.copytree(root / "qml", fixture / "qml")
    source = fixture / "qml/main.qml"
    source.write_text(source.read_text().replace(
        'readonly property var chooser: typeof portalRequest !== "undefined" ? portalRequest : null',
        'property var chooser: null'))
    config_path = fixture / "config/seabunny/config.json"
    config_path.write_text(json.dumps({"sidebarWidth": "332", "ui_source": str(source)}))
    environment = dict(os.environ, HOME=str(fixture / "home"), XDG_CONFIG_HOME=str(fixture / "config"),
        XDG_DATA_HOME=str(fixture / "data"), XDG_CACHE_HOME=str(fixture / "cache"),
        XDG_STATE_HOME=str(fixture / "state"), XDG_RUNTIME_DIR=str(fixture / "runtime"),
        QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", GSETTINGS_BACKEND="memory",
        QT_FORCE_STDERR_LOGGING="1",
        DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent", DISPLAY="", WAYLAND_DISPLAY="",
        SEABUNNY_SERPANTINUM_COLORS=str(fixture / "absent"), SEABUNNY_QML=str(root / "tests/SidebarPersistenceChecks.qml"))
    cases = [("explorer", "expand", False, 332), ("explorer", "collapse", True, 410),
        ("explorer", "read", False, 410), ("chooser", "expand", False, 410),
        ("chooser", "collapse", True, 350), ("chooser", "read", False, 350),
        ("explorer", "read", False, 410)]
    for role, stage, expanded, width in cases:
        config = json.loads(config_path.read_text())
        config.update(sidebar_test_role=role, sidebar_test_stage=stage,
            sidebar_expected_expanded=str(expanded).lower(), sidebar_expected_width=str(width))
        config_path.write_text(json.dumps(config))
        result = subprocess.run([str(root / "target/release/seabunny")], env=environment,
            text=True, capture_output=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "SIDEBAR_PERSISTENCE_PASSED" in output, (role, stage, result.returncode)
        assert "SIDEBAR_PERSISTENCE_FAILED" not in output
        assert not any(marker in output for marker in ("ReferenceError", "TypeError", "Unable to assign", "Binding loop"))
    for role, width in (("explorer", 410), ("chooser", 350)):
        stored = json.loads((fixture / "state/seabunny" / (role + "-sidebar.json")).read_text())
        assert stored == {"version": 1, "expanded": False, "width": width}
    print("PASS separate persisted roles, expanded and collapsed relaunches, legacy width fallback and unchanged explorer width after chooser changes")
