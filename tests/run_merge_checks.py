"""Exercise folder-merge decisions and undo using disposable files and Trash."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="seabunny-merge-") as name:
    fixture = Path(name)
    for directory in ("home", "config/seabunny", "data", "state", "cache", "runtime"):
        (fixture / directory).mkdir(parents=True, mode=0o700)
    home = fixture / "home"
    (home / "external-old.txt").write_text("old\n")
    for case in ("individual", "keep", "replace", "both", "drop"):
        source, target = home / case / "incoming/Shared ö", home / case / "destination/Shared ö"
        for directory in (source / "nested", target / "nested"):
            directory.mkdir(parents=True)
        (source / "empty").mkdir()
        (source / "new.txt").write_text("new file\n")
        (target / "untouched.txt").write_text("never modify this\n")
        for filename in ("01.txt", "02.txt", "nested/03.txt"):
            (source / filename).write_text("incoming contents\n")
            (target / filename).write_text("old\n")
        if case == "replace":
            (target / "01.txt").unlink()
            (target / "01.txt").symlink_to(home / "external-old.txt")
    shutil.copytree(root / "qml", fixture / "qml")
    main = fixture / "qml/main.qml"
    additions = "    readonly property var benchmarkEngine: window.engine\n" + "".join(
        f"    property alias benchmark{key}: {value}\n" for key, value in {
            "Theme": "theme", "Conflict": "conflictModal"}.items())
    main.write_text(main.read_text().replace("    id: window\n", "    id: window\n" + additions, 1))
    (fixture / "config/seabunny/config.json").write_text(json.dumps({"ui_source": str(main),
        "merge_preview": str(root / "target/merge-conflict-preview.png")}))
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(fixture / "config"),
        XDG_DATA_HOME=str(fixture / "data"), XDG_STATE_HOME=str(fixture / "state"),
        XDG_CACHE_HOME=str(fixture / "cache"), XDG_RUNTIME_DIR=str(fixture / "runtime"),
        QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", QT_FORCE_STDERR_LOGGING="1",
        GSETTINGS_BACKEND="memory", DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent", DISPLAY="", WAYLAND_DISPLAY="",
        SEABUNNY_SERPANTINUM_COLORS=str(fixture / "absent"), SEABUNNY_QML=str(root / "tests/MergeChecks.qml"))
    result = subprocess.run([str(root / "target/release/seabunny")], env=env, capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "MERGE_CHECKS_PASSED" in output
    assert not any(error in output for error in ("MERGE_CHECKS_FAILED", "ReferenceError", "TypeError", "Unable to assign", "Binding loop"))
    for case in ("individual", "keep", "replace", "both", "drop"):
        source, target = home / case / "incoming/Shared ö", home / case / "destination/Shared ö"
        assert (target / "untouched.txt").read_text() == "never modify this\n"
        assert (target / "new.txt").read_text() == "new file\n"
        assert (target / "empty").is_dir()
        assert not (target / "Shared ö").exists()
        for filename in ("01.txt", "02.txt", "nested/03.txt"):
            value = "incoming contents\n" if case == "replace" or (case == "individual" and filename == "nested/03.txt") else "old\n"
            assert (target / filename).read_text() == value
            if case in ("both", "drop") or (case == "individual" and filename == "01.txt"):
                renamed = Path(filename).with_name(Path(filename).stem + " (1).txt")
                assert (target / renamed).read_text() == "incoming contents\n"
        if case == "both":
            assert not source.exists()
        elif case == "keep":
            assert source.is_dir() and not (source / "new.txt").exists()
            assert (source / "nested/03.txt").read_text() == "incoming contents\n"
        else:
            assert (source / "new.txt").read_text() == "new file\n"
    print("PASS all collision choices, nested merging, source retention, and untouched destination files on disk")
    assert (home / "external-old.txt").read_text() == "old\n"
    print("PASS replacing and undoing a colliding symlink never modifies its target")
