"""Exercise actual copy/cut/paste shortcuts using a disposable profile."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import argparse
import select
import signal
import time

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--wayland", action="store_true", default=True, help="Test separate processes on an isolated virtual KWin server")
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix="seabunny-clipboard-") as tmp:
    fixture = Path(tmp)
    for name in ("home/work/destination", "home/work/Folder/subdir", "config/seabunny", "data", "cache", "state", "runtime"):
        (fixture / name).mkdir(parents=True, mode=0o700)
    (fixture / "home/work/a.txt").write_text("synthetic clipboard contents\n")
    (fixture / "home/work/Folder/inside.txt").write_text("folder contents\n")
    (fixture / "home/work/b # 日本語.txt").write_text("second selection\n")
    shutil.copytree(root / "qml", fixture / "qml")
    main = fixture / "qml/main.qml"
    additions = "    readonly property var benchmarkEngine: window.engine\n" + "".join(
        f"    property alias benchmark{name}: {target}\n" for name, target in {
            "Container": "pane0", "Keys": "globalKeyHandler", "Theme": "theme", "Menu": "contextMenu", "Conflict": "conflictDialog"}.items())
    main.write_text(main.read_text().replace("    id: window\n", "    id: window\n" + additions, 1))
    (fixture / "config/seabunny/config.json").write_text(json.dumps({"ui_source": str(main)}))
    env = dict(os.environ, HOME=str(fixture / "home"), XDG_CONFIG_HOME=str(fixture / "config"),
        XDG_DATA_HOME=str(fixture / "data"), XDG_CACHE_HOME=str(fixture / "cache"),
        XDG_STATE_HOME=str(fixture / "state"), XDG_RUNTIME_DIR=str(fixture / "runtime"),
        QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", GSETTINGS_BACKEND="memory",
        QT_FORCE_STDERR_LOGGING="1", DISPLAY="", WAYLAND_DISPLAY="",
        DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent", SEABUNNY_SERPANTINUM_COLORS=str(fixture / "absent"),
        SEABUNNY_QML=str(root / "tests/next/ClipboardTransfer.qml"))
    env["SEABUNNY_ISOLATED_CLIPBOARD_TEST"] = "1"
    if args.wayland:
        # A private bus, runtime and virtual framebuffer prevent contact with the
        # user's compositor, clipboard, application settings or session services.
        compositor = subprocess.Popen(["dbus-run-session", "--", "kwin_wayland", "--virtual",
            "--no-lockscreen", "--no-global-shortcuts", "--no-kactivities", "--socket", "clipboard-test"],
            env=dict(env, KWIN_COMPOSE="Q"), stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
            start_new_session=True, text=True)
        writer = None
        try:
            for _ in range(100):
                if (fixture / "runtime/clipboard-test").exists():
                    break
                if compositor.poll() is not None:
                    raise RuntimeError(compositor.stderr.read())
                time.sleep(0.1)
            assert (fixture / "runtime/clipboard-test").exists(), "isolated compositor did not start"
            env.update(QT_QPA_PLATFORM="wayland", WAYLAND_DISPLAY="clipboard-test",
                SEABUNNY_QML=str(root / "tests/next/ClipboardTransfer.qml"))
            source = fixture / "home/work/a # 日本語.txt"
            target = fixture / "home/work/destination/a # 日本語.txt"
            for cut in (False, True):
                source.write_text("separate process clipboard contents\n")
                for role in ("writer", "reader"):
                    config = fixture / ("config-" + role)
                    (config / "seabunny").mkdir(parents=True, exist_ok=True)
                    (config / "seabunny/config.json").write_text(json.dumps({
                        "ui_source": str(main), "role": role, "cut": "yes" if cut else "no"}))
                writer = subprocess.Popen([str(root / "target/release/seabunny"), "--new-window"],
                    env=dict(env, XDG_CONFIG_HOME=str(fixture / "config-writer")),
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                deadline = time.monotonic() + 20
                ready = False
                while time.monotonic() < deadline:
                    if select.select([writer.stdout], [], [], 0.2)[0]:
                        line = writer.stdout.readline()
                        print(line, end="")
                        if "TRANSFER_READY" in line:
                            ready = True
                            break
                    if writer.poll() is not None:
                        break
                assert ready, "clipboard writer did not become ready"
                consumer = subprocess.run([str(root / "target/release/seabunny"), "--new-window"],
                    env=dict(env, XDG_CONFIG_HOME=str(fixture / "config-reader")),
                    capture_output=True, text=True, timeout=25)
                print(consumer.stdout + consumer.stderr)
                assert consumer.returncode == 0 and "TRANSFER_PASSED" in consumer.stderr
                assert target.read_text() == "separate process clipboard contents\n"
                assert source.exists() is not cut
                writer.terminate()
                writer.wait(timeout=5)
                writer = None
                target.unlink()  # Test-owned output only; the next case starts empty.
            print("PASS separate-process copy and cut over a private Wayland clipboard")
        finally:
            if writer is not None and writer.poll() is None:
                writer.terminate()
                writer.wait(timeout=5)
            if compositor.poll() is None:
                os.killpg(compositor.pid, signal.SIGTERM)
            compositor.wait(timeout=5)
        raise SystemExit(0)
