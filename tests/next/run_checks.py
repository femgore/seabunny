"""Seabunny 0.2 acceptance checks. All settings, files and caches are disposable."""
import argparse
import struct
import zlib
import zipfile
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--screenshots", type=Path, help="Save synthetic appearance screenshots here")
args = parser.parse_args()
if args.screenshots:
    args.screenshots = args.screenshots.resolve()
    args.screenshots.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="seabunny-next-checks-") as tmp:
    fixture = Path(tmp)
    for directory in ("home/work/destination", "config/seabunny", "data/applications", "state", "cache", "runtime"):
        (fixture / directory).mkdir(parents=True, mode=0o700)
    home = fixture / "home"
    (home / "work/a.txt").write_text("source text\n")
    (home / "work/.hidden").write_text("hidden\n")
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    (home / "work/image.png").write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 320, 240, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress((b"\x00" + b"\xff\x00\x00\xff" * 320) * 240)) + chunk(b"IEND", b""))
    (home / "work/program.AppImage").write_text("synthetic file, never executed\n")
    (home / "work/program.AppImage").chmod(0o640)
    for number in range(3):
        source = home / f"merge{number}/incoming/Shared ö"
        target = home / f"merge{number}/destination/Shared ö"
        for path in (source / "nested", target / "nested"):
            path.mkdir(parents=True)
        for name in ("01.txt", "02.txt", "nested/03.txt"):
            (source / name).write_text("incoming contents\n")
            (target / name).write_text("old\n")
        (source / "new.txt").write_text("new\n")
        (target / "untouched.txt").write_text("keep this\n")
    with zipfile.ZipFile(home / "archive # 日本語.zip", "w") as archive:
        archive.writestr("inner # 日本語.txt", "archive contents\n")
    appdir = fixture / "data/applications"
    for name, display in (("test-viewer", "Test Viewer"), ("org.femgore.Seabunny", "Seabunny")):
        (appdir / (name + ".desktop")).write_text(
            f"[Desktop Entry]\nType=Application\nName={display}\nExec=/usr/bin/true %F\nMimeType=text/plain;\n")
    (appdir / "mimeinfo.cache").write_text("[MIME Cache]\ntext/plain=test-viewer.desktop;org.femgore.Seabunny.desktop;\n")
    shutil.copytree(root / "qml", fixture / "qml")
    main = fixture / "qml/main.qml"
    aliases = {"Menu":"contextMenu", "Settings":"settingsView", "Core":"core", "Theme":"theme", "Sidebar":"sidebar", "Keys":"globalKeyHandler",
        "Properties":"propsDialog", "OpenWith":"openWithModal", "Conflict":"conflictDialog",
        "Name":"chooserName", "Overwrite":"chooserOverwrite", "Input":"inputModal", "Batch":"batchRename", "Confirm":"confirmDialog", "Pattern":"patternModal", "Command":"commandModal"}
    source = main.read_text().replace('readonly property var chooser:', 'property var chooser:', 1)
    source = source.replace("    id: window\n", "    id: window\n" + "".join(
        f"    property alias test{name}: {target}\n" for name, target in aliases.items()), 1)
    main.write_text(source)
    (fixture / "config/seabunny/config.json").write_text(json.dumps({"test_ui": str(main), "reduceMotion":"true", "capture_dir":str(args.screenshots) if args.screenshots else ""}))
    (fixture / "config/seabunny/favorites.json").write_text(json.dumps([{"path":str(home / "work/destination"), "label":"Legacy favorite"}]))
    palette = {name:"#445566" for name in ("base", "mantle", "crust", "text", "subtext0", "subtext1", "surface0", "surface1", "surface2", "overlay0", "overlay1", "overlay2", "blue", "sapphire", "peach", "green", "red", "mauve", "pink", "yellow", "maroon", "teal")}
    palette.update(base="#101010", mantle="#181825", crust="#11111b", text="#fafafa", blue="#abcdef",
        subtext0="#a6adc8", subtext1="#bac2de", surface0="#313244", surface1="#45475a", surface2="#585b70",
        overlay0="#6c7086", overlay1="#7f849c", overlay2="#9399b2", green="#a6e3a1", red="#f38ba8",
        peach="#fab387", sapphire="#74c7ec", mauve="#cba6f7", pink="#f5c2e7", yellow="#f9e2af", maroon="#eba0ac", teal="#94e2d5")
    palette_path = fixture / "palette.json"
    palette_path.write_text(json.dumps(palette))
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(fixture / "config"),
        XDG_DATA_HOME=str(fixture / "data"), XDG_CACHE_HOME=str(fixture / "cache"),
        XDG_STATE_HOME=str(fixture / "state"), XDG_RUNTIME_DIR=str(fixture / "runtime"),
        QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", GSETTINGS_BACKEND="memory",
        QT_FORCE_STDERR_LOGGING="1", DISPLAY="", WAYLAND_DISPLAY="", DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent",
        SEABUNNY_SERPANTINUM_COLORS=str(palette_path), SEABUNNY_QML=str(root / "tests/next/NextChecks.qml"))
    parity = subprocess.run([str(root / "target/release/seabunny"), "--new-window"],
        env=dict(env, SEABUNNY_QML=str(root / "tests/next/AppearanceParity.qml")),
        text=True, capture_output=True, timeout=45)
    parity_output=parity.stdout + parity.stderr
    print(parity_output)
    assert parity.returncode == 0 and "APPEARANCE_PARITY_PASSED" in parity_output
    if args.screenshots:
        assert all((args.screenshots / (name+".png")).is_file() for name in ("grid", "settings"))
    assert not any(error in parity_output for error in ("ReferenceError", "TypeError", "Binding loop", "Unable to assign"))
    process = subprocess.Popen([str(root / "target/release/seabunny"), "--new-window"],
        env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    lines = []
    try:
        for line in process.stdout:
            print(line, end=""); lines.append(line)
            if "REQUEST_PALETTE_UPDATE" in line:
                palette["blue"] = "#123456"
                temporary = fixture / "palette.tmp"
                temporary.write_text(json.dumps(palette)); temporary.replace(palette_path)
        process.wait(timeout=10)
    finally:
        if process.poll() is None:
            process.terminate(); process.wait(timeout=5)
    output = "".join(lines)
    assert process.returncode == 0 and "NEXT_CHECKS_PASSED" in output
    assert not any(error in output for error in ("ReferenceError", "TypeError", "Binding loop", "Unable to assign"))
    for number in range(3):
        source = home / f"merge{number}/incoming/Shared ö"
        target = home / f"merge{number}/destination/Shared ö"
        assert (target / "01.txt").read_text() == "old\n"
        assert (target / "01 (2).txt").read_text() == "incoming contents\n"
        if number == 2:
            assert (target / "02 (2).txt").read_text() == "incoming contents\n"
            assert (target / "nested/03 (2).txt").read_text() == "incoming contents\n"
            assert (target / "nested/03.txt").read_text() == "old\n"
            continue
        assert (target / "02.txt").read_text() == "old\n"
        assert (target / "nested/03.txt").read_text() == "incoming contents\n"
        assert (target / "untouched.txt").read_text() == "keep this\n"
        assert (source / "02.txt").read_text() == "incoming contents\n"
        assert (source / "new.txt").exists() is (number == 0)
    assert (home / "work/destination/inner # 日本語.txt").read_text() == "archive contents\n"
    sorting = fixture / "state/seabunny/folder-sorting.json"
    assert not sorting.exists() or not json.loads(sorting.read_text())["folders"]
    assert json.loads((fixture / "state/seabunny/explorer-sidebar.json").read_text())["width"] == 342
    assert json.loads((fixture / "state/seabunny/chooser-sidebar.json").read_text())["width"] == 228
    print("PASS merge results, sparse sorting, independent sidebar state and executable mode verified on disk")
    for role in ("save", "load"):
        config_file = fixture / "config/seabunny/config.json"
        config = json.loads(config_file.read_text())
        config["restart_role"] = role
        config_file.write_text(json.dumps(config))
        run = subprocess.run([str(root / "target/release/seabunny"), "--new-window"],
            env=dict(env, SEABUNNY_QML=str(root / "tests/next/RestartChecks.qml")),
            text=True, capture_output=True, timeout=30)
        result = run.stdout + run.stderr
        print(result)
        assert run.returncode == 0 and "RESTART_CHECKS_PASSED" in result
        assert not any(error in result for error in ("ReferenceError", "TypeError", "Binding loop", "Unable to assign"))
