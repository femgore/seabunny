import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="seabunny-chooser-") as tmp:
    fixture=Path(tmp)
    for directory in ("home/folder", "config/seabunny", "data", "cache", "state", "runtime"):
        (fixture/directory).mkdir(parents=True,mode=0o700)
    (fixture/"home/one.txt").write_text("test")
    (fixture/"home/image.png").write_bytes(b"not an image")
    shutil.copytree(root/"qml", fixture/"qml")
    main=fixture/"qml/main.qml"
    source=main.read_text().replace('readonly property var chooser: typeof portalRequest !== "undefined" ? portalRequest : null', 'property var chooser: null')
    source=source.replace('    id: window\n', '    id: window\n    property alias benchmarkContainer: gridContainer\n    property alias benchmarkName: chooserName\n    property alias benchmarkOverwrite: chooserOverwrite\n    property alias benchmarkTheme: theme\n',1)
    main.write_text(source)
    (fixture/"config/seabunny/config.json").write_text(json.dumps({"ui_source": str(main)}))
    env=dict(os.environ)
    env.update(HOME=str(fixture/"home"),XDG_CONFIG_HOME=str(fixture/"config"),XDG_DATA_HOME=str(fixture/"data"),
        XDG_CACHE_HOME=str(fixture/"cache"),XDG_STATE_HOME=str(fixture/"state"),XDG_RUNTIME_DIR=str(fixture/"runtime"),
        QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software",GSETTINGS_BACKEND="memory",QT_FORCE_STDERR_LOGGING="1",
        DISPLAY="",WAYLAND_DISPLAY="",DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent",
        SEABUNNY_SERPANTINUM_COLORS=str(fixture/"absent"),SEABUNNY_QML=str(root/"tests/ChooserChecks.qml"))
    result=subprocess.run([str(root/"target/release/seabunny")],env=env,text=True,capture_output=True,timeout=20)
    output=result.stdout+result.stderr
    print(output)
    assert result.returncode==0 and "CHOOSER_CHECKS_PASSED" in output and "CHOOSER_CHECKS_FAILED" not in output
    assert "ReferenceError" not in output and "TypeError" not in output and "Unable to assign" not in output
