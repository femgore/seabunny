"""Test native launching and the Open With UI with disposable applications only."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--native-only", action="store_true")
parser.add_argument("--native-binary", default=str(root / "target/rebrand-qt-tests/open-with-tests"))
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix="seabunny-open-with-") as name:
    fixture = Path(name)
    locations = {"HOME": "home", "XDG_CONFIG_HOME": "config", "XDG_DATA_HOME": "data",
                 "XDG_DATA_DIRS": "system-data", "XDG_CONFIG_DIRS": "system-config",
                 "XDG_CACHE_HOME": "cache", "XDG_STATE_HOME": "state", "XDG_RUNTIME_DIR": "runtime"}
    env = dict(os.environ)
    for key, directory in locations.items():
        path = fixture / directory
        path.mkdir(mode=0o700)
        env[key] = str(path)
    # Supply MIME definitions and icons, never the host's application registry.
    for directory in ("mime", "icons"):
        (fixture / "system-data" / directory).symlink_to(Path("/usr/share") / directory, target_is_directory=True)
    env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", QT_FORCE_STDERR_LOGGING="1",
               GSETTINGS_BACKEND="memory", DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent",
               DISPLAY="", WAYLAND_DISPLAY="", SEABUNNY_ISOLATED_OPEN_WITH_TEST="1")
    native = subprocess.run([args.native_binary], env=env,
                            capture_output=True, text=True, timeout=30)
    print(native.stdout + native.stderr)
    assert native.returncode == 0
    if args.native_only:
        raise SystemExit(0)

    # A separate profile prevents GIO's cached native-test registrations/defaults
    # from affecting the UI scenarios, and tests persistence across processes.
    for key, directory in locations.items():
        path = fixture / "ui" / directory
        path.mkdir(parents=True, mode=0o700)
        env[key] = str(path)
    for directory in ("mime", "icons"):
        (fixture / "ui/system-data" / directory).symlink_to(Path("/usr/share") / directory, target_is_directory=True)
    home = fixture / "ui/home"
    work = home / "work"
    work.mkdir()
    for file in ("First # 日本語.txt", "Second %.txt", "Other.pdf"):
        (work / file).write_text("synthetic fixture\n")
    receipt = home / "ui-launches.jsonl"
    env["SEABUNNY_OPEN_WITH_UI_RECEIPT"] = str(receipt)
    recorder = home / "record app"
    recorder.write_text("#!/usr/bin/python3\nimport json,os,sys\nwith open(os.environ['SEABUNNY_OPEN_WITH_UI_RECEIPT'],'a') as output: output.write(json.dumps({'app':sys.argv[1], 'args':sys.argv[2:], 'cwd':os.getcwd()})+'\\n')\n")
    recorder.chmod(0o700)
    program = work / "Run ö.AppImage"
    program.write_text("#!/usr/bin/python3\nimport json,os\nwith open(os.environ['SEABUNNY_OPEN_WITH_UI_RECEIPT'],'a') as output: output.write(json.dumps({'app':'direct','args':[], 'cwd':os.getcwd()})+'\\n')\n")
    program.chmod(0o600)
    applications = fixture / "ui/data/applications"
    applications.mkdir()
    for identifier in ("one", "two"):
        (applications / (identifier + ".desktop")).write_text(
            f'[Desktop Entry]\nType=Application\nName={identifier} Viewer\nExec="{recorder}" {identifier} %F\n'
            'Icon=application-x-executable\nMimeType=text/plain;\n')
    (applications / "mimeinfo.cache").write_text("[MIME Cache]\ntext/plain=one.desktop;two.desktop;\n")
    shutil.copytree(root / "qml", fixture / "ui/qml")
    main = fixture / "ui/qml/main.qml"
    additions = "    readonly property var benchmarkEngine: window.engine\n" + "".join(
        f"    property alias benchmark{key}: {value}\n" for key, value in {
            "Theme": "theme", "Context": "contextMenu", "OpenWith": "openWithModal",
            "Container": "gridContainer", "View": "filesGridView"}.items())
    main.write_text(main.read_text().replace("    id: window\n", "    id: window\n" + additions, 1))
    config = fixture / "ui/config/seabunny"
    config.mkdir()
    (config / "config.json").write_text(json.dumps({"ui_source": str(main), "open_with_preview": str(root / "target/open-with-preview.png")}))
    env.update(SEABUNNY_QML=str(root / "tests/OpenWithChecks.qml"), SEABUNNY_SERPANTINUM_COLORS=str(fixture / "absent"))
    result = subprocess.run([str(root / "target/release/seabunny")], env=env,
                            capture_output=True, text=True, timeout=40)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "OPEN_WITH_CHECKS_PASSED" in output
    assert not any(error in output for error in ("OPEN_WITH_CHECKS_FAILED", "ReferenceError", "TypeError", "Unable to assign", "Binding loop"))
    for _ in range(30):
        launches = [json.loads(line) for line in receipt.read_text().splitlines()] if receipt.exists() else []
        if len(launches) >= 3:
            break
        time.sleep(0.1)
    assert [entry["app"] for entry in launches].count("two") == 2
    assert [entry["app"] for entry in launches].count("direct") == 1
    for entry in launches:
        if entry["app"] == "two":
            assert entry["args"] == [str(work / "First # 日本語.txt")]
        else:
            assert entry["cwd"] == str(work)
    assert "text/plain=two.desktop;" in (fixture / "ui/config/mimeapps.list").read_text()
    print("PASS default association and executable launches affect only the disposable profile")
