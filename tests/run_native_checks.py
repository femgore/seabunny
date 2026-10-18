import json
import os
from pathlib import Path
import subprocess
import tempfile
import shutil

repository = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="seabunny-native-checks-") as name:
    fixture = Path(name)
    for directory in ("home/large", "home/small", "home/Resimler ö", "home/previews", "home/pin # ö %", "home/move me # ö", "home/copy me", "outside-home", "config/seabunny", "cache", "state", "runtime"):
        (fixture / directory).mkdir(parents=True, mode=0o700, exist_ok=True)
    for index in range(1200):
        (fixture / "home/large" / f"file-{index:05}.txt").write_text("synthetic fixture\n")
    (fixture / "home/small/sentinel.txt").write_text("synthetic fixture\n")
    (fixture / "home/move me # ö/sentinel.txt").write_text("synthetic fixture\n")
    (fixture / "home/copy me/sentinel.txt").write_text("synthetic fixture\n")
    (fixture / "home/archives").mkdir()
    (fixture / "home/archive-copy").mkdir()
    import zipfile
    archive_path = fixture / "home/archives/Sample # 日本語.zip"
    with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("folder/inner/hello ö.txt", b"synthetic archive contents\n")
        archive.writestr("folder/second.txt", b"second file\n")
        archive.writestr("README.txt", b"readme\n")
    original_archive = archive_path.read_bytes()
    (fixture / "bin").mkdir()
    opener = fixture / "bin/xdg-open"
    opener.write_text("#!/usr/bin/python3\nimport os, sys\nfrom pathlib import Path\nPath(os.environ['SEABUNNY_TEST_OPEN_RECEIPT']).write_text(sys.argv[1])\n")
    opener.chmod(0o700)
    with zipfile.ZipFile(fixture / "home/archives/unsafe.zip", "w") as archive:
        archive.writestr("../escaped.txt", "must never be extracted")
    (fixture / "home/alias-small").symlink_to(fixture / "home/small", target_is_directory=True)
    from PIL import Image, ImageDraw
    for index in range(3):
        image = Image.new("RGB", (360, 260), (40 + index * 40, 90, 130))
        drawing = ImageDraw.Draw(image)
        drawing.rectangle((25, 25, 335, 235), outline=(230, 200, 160), width=8)
        drawing.ellipse((70, 45, 290, 215), fill=(190, 150 + index * 30, 80))
        drawing.text((130, 115), "SYNTHETIC " + str(index + 1), fill="black")
        image.save(fixture / "home/previews" / ("Preview " + str(index + 1) + ".png"))
    (fixture / "config/user-dirs.dirs").write_text('XDG_PICTURES_DIR="$HOME/Resimler ö"\n')
    roles = "base mantle crust text subtext0 subtext1 surface0 surface1 surface2 overlay0 overlay1 overlay2 blue sapphire peach green red mauve pink yellow maroon teal".split()
    palette = {role: "#555577" for role in roles}
    palette.update(base="#101010", text="#f0f0f0", blue="#abcdef")
    (fixture / "palette.json").write_text(json.dumps(palette))
    environment = dict(os.environ)
    environment.update({
        "HOME": str(fixture / "home"), "XDG_CONFIG_HOME": str(fixture / "config"),
        "XDG_DATA_HOME": str(fixture / "data"), "XDG_CACHE_HOME": str(fixture / "cache"),
        "XDG_STATE_HOME": str(fixture / "state"), "XDG_RUNTIME_DIR": str(fixture / "runtime"),
        "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software", "QT_FORCE_STDERR_LOGGING": "1",
        "GSETTINGS_BACKEND": "memory",
        "PATH": str(fixture / "bin") + os.pathsep + os.environ.get("PATH", ""),
        "SEABUNNY_TEST_OPEN_RECEIPT": str(fixture / "open-receipt.txt"),
        "DBUS_SESSION_BUS_ADDRESS": "unix:path=/nonexistent", "WAYLAND_DISPLAY": "", "DISPLAY": "",
        "SEABUNNY_QML": str(repository / "tests/NativeChecks.qml"),
        "SEABUNNY_SERPANTINUM_COLORS": str(fixture / "palette.json"),
    })
    result = subprocess.run([str(repository / "target/release/seabunny")], env=environment,
                            text=True, capture_output=True, timeout=20)
    log = result.stdout + result.stderr
    print(log)
    if result.returncode != 0 or "NATIVE_CHECKS_PASSED" not in log or "NATIVE_CHECKS_FAILED" in log:
        raise SystemExit(1)
    shutil.copytree(repository / "qml", fixture / "qml")
    main = fixture / "qml/main.qml"
    source = main.read_text()
    source = source.replace("    id: window\n", "    id: window\n"
        "    readonly property var benchmarkEngine: window.engine\n"
        "    property alias benchmarkView: filesGridView\n"
        "    property alias benchmarkNav: navRepeater\n"
        "    property alias benchmarkPath: pathInput\n", 1)
    source = source.replace("    id: window\n", "    id: window\n"
        "    property alias benchmarkMenu: contextMenu\n"
        "    property alias benchmarkFavoriteMenu: favoriteMenu\n"
        "    property alias benchmarkFavoritePrompt: favoritePrompt\n"
        "    property alias benchmarkNavScroll: navRailArea\n"
        "    property alias benchmarkSearch: searchInput\n", 1)
    source = source.replace("    id: window\n", "    id: window\n"
        "    property alias benchmarkSidebarDrag: sidebarDragProxy\n"
        "    property alias benchmarkFileDrag: dragProxy\n"
        "    property alias benchmarkFileDragController: dragManager\n"
        "    property alias benchmarkPinDrop: sidebarPinDrop\n", 1)
    source = source.replace("    id: window\n", "    id: window\n"
        "    property alias benchmarkTheme: theme\n"
        "    property alias benchmarkSettings: settingsView\n"
        "    property alias benchmarkResize: sidebarResizeHandle\n"
        "    property alias benchmarkTabs: folderTabs\n"
        "    property alias benchmarkTabBar: tabBar\n"
        "    property alias benchmarkShell: appShell\n"
        "    property alias benchmarkContainer: gridContainer\n"
        "    property alias benchmarkList: filesListView\n", 1)
    main.write_text(source)
    configuration = fixture / "config/seabunny/config.json"
    settings = json.loads(configuration.read_text())
    settings.update(ui_source=str(main), outside_fixture=str(fixture / "outside-home"), accentName="lavender", themeMode="dark", gridItemSize="124", layout_preview=str(repository / "target/sidebar-preview.png"), tabs_preview=str(repository / "target/tabs-preview.png"))
    settings["archive_preview"] = str(repository / "target/archive-preview.png")
    configuration.write_text(json.dumps(settings))
    # Each UI fixture starts with independent sidebar state; relaunch persistence
    # across shared state directories is covered by run_sidebar_persistence.py.
    environment["SEABUNNY_QML"] = str(repository / "tests/UiChecks.qml")
    environment["XDG_STATE_HOME"] = str(fixture / "state" / "UiChecks")
    result = subprocess.run([str(repository / "target/release/seabunny")], env=environment,
                            text=True, capture_output=True, timeout=20)
    log = result.stdout + result.stderr
    print(log)
    if (result.returncode != 0 or "UI_CHECKS_PASSED" not in log or "UI_CHECKS_FAILED" in log
            or any(error in log for error in ("Binding loop detected", "ReferenceError:", "TypeError:"))):
        raise SystemExit(1)

    environment["SEABUNNY_QML"] = str(repository / "tests/SidebarChecks.qml")
    environment["XDG_STATE_HOME"] = str(fixture / "state" / "SidebarChecks")
    (fixture / "home/small/inner").mkdir()
    (fixture / "home/small/inner/content.txt").write_text("synthetic child contents\n")
    result = subprocess.run([str(repository / "target/release/seabunny")], env=environment,
                            text=True, capture_output=True, timeout=30)
    log = result.stdout + result.stderr
    print(log)
    if (result.returncode != 0 or "SIDEBAR_CHECKS_PASSED" not in log or "SIDEBAR_CHECKS_FAILED" in log
            or any(error in log for error in ("Binding loop detected", "ReferenceError:", "TypeError:"))):
        raise SystemExit(1)
    stored = json.loads(configuration.read_text())
    layout = json.loads(stored["sidebarLayout"])
    assert "place:Pictures" in layout["hidden"]
    assert layout["icons"]["folder:" + str(fixture / "home/small")] == "image"
    print("PASS sidebar order, hidden places and custom icons are persisted on disk")
    preview = Image.open(repository / "target/sidebar-preview.png").convert("RGB")
    pixels = preview.load()
    colorful = sum(1 for row in range(preview.height) for column in range(preview.width)
                   if pixels[column, row][0] > 160 and pixels[column, row][1] > 120 and pixels[column, row][2] < 120)
    assert colorful > 20000, "large synthetic image previews must actually render, not just reserve space"
    print("PASS rendered grid contains large, visible image thumbnails")
    environment["SEABUNNY_QML"] = str(repository / "tests/AppearanceChecks.qml")
    environment["XDG_STATE_HOME"] = str(fixture / "state" / "AppearanceChecks")
    result = subprocess.run([str(repository / "target/release/seabunny")], env=environment,
                            text=True, capture_output=True, timeout=30)
    log = result.stdout + result.stderr
    print(log)
    if (result.returncode != 0 or "APPEARANCE_CHECKS_PASSED" not in log or "APPEARANCE_CHECKS_FAILED" in log
            or any(error in log for error in ("Binding loop detected", "ReferenceError:", "TypeError:"))):
        raise SystemExit(1)

    environment["SEABUNNY_QML"] = str(repository / "tests/TabsChecks.qml")
    environment["XDG_STATE_HOME"] = str(fixture / "state" / "TabsChecks")
    result = subprocess.run([str(repository / "target/release/seabunny")], env=environment,
                            text=True, capture_output=True, timeout=40)
    log = result.stdout + result.stderr
    print(log)
    if (result.returncode != 0 or "TABS_CHECKS_PASSED" not in log or "TABS_CHECKS_FAILED" in log
            or any(error in log for error in ("Binding loop detected", "ReferenceError:", "TypeError:"))):
        raise SystemExit(1)
    saved_tabs = json.loads(json.loads(configuration.read_text())["folderTabs"])
    assert saved_tabs["version"] == 1 and len(saved_tabs["paths"]) == 1
    assert all(Path(path).is_dir() for path in saved_tabs["paths"])
    assert 0 <= saved_tabs["active"] < len(saved_tabs["paths"])
    print("PASS restored tab paths and active index survive in the actual settings file")

    environment["SEABUNNY_QML"] = str(repository / "tests/ArchiveChecks.qml")
    environment["XDG_STATE_HOME"] = str(fixture / "state" / "ArchiveChecks")
    result = subprocess.run([str(repository / "target/release/seabunny")], env=environment,
                            text=True, capture_output=True, timeout=50)
    log = result.stdout + result.stderr
    print(log)
    if (result.returncode != 0 or "ARCHIVE_CHECKS_PASSED" not in log or "ARCHIVE_CHECKS_FAILED" in log
            or any(error in log for error in ("Binding loop detected", "ReferenceError:", "TypeError:"))):
        raise SystemExit(1)
    assert archive_path.read_bytes() == original_archive
    assert (fixture / "home/archive-copy/second.txt").read_bytes() == b"second file\n"
    selected = fixture / "home/archives/Sample # 日本語"
    whole = fixture / "home/archives/Sample # 日本語 (1)"
    assert (selected / "folder/second.txt").read_bytes() == b"second file\n"
    assert not (selected / "README.txt").exists()
    assert (whole / "README.txt").read_bytes() == b"readme\n"
    assert not (fixture / "home/archives/escaped.txt").exists()
    opened_path = Path((fixture / "open-receipt.txt").read_text())
    assert opened_path.is_relative_to(fixture / "cache/seabunny/archive-open")
    assert opened_path.read_bytes() == b"synthetic archive contents\n"
    assert opened_path.stat().st_mode & 0o222 == 0
    print("PASS archive bytes are unchanged, selected/full exports contain the intended files, and traversal writes are absent")
    print("PASS opening an archived file launches only the mocked opener with a read-only cached copy")
    environment["SEABUNNY_QML"] = str(repository / "tests/NavigationChecks.qml")
    environment["XDG_STATE_HOME"] = str(fixture / "state" / "NavigationChecks")
    result = subprocess.run([str(repository / "target/release/seabunny")], env=environment,
                            text=True, capture_output=True, timeout=30)
    log = result.stdout + result.stderr
    print(log)
    if (result.returncode != 0 or "NAVIGATION_CHECKS_PASSED" not in log
            or any(error in log for error in ("NAVIGATION_CHECKS_FAILED", "ReferenceError:", "TypeError:"))):
        raise SystemExit(1)
    environment["SEABUNNY_QML"] = str(repository / "tests/StartupChecks.qml")
    environment["XDG_STATE_HOME"] = str(fixture / "state" / "StartupChecks")
    result = subprocess.run([str(repository / "target/release/seabunny"),
                             (fixture / "outside-home").as_uri(), archive_path.as_uri()],
                            env=environment, text=True, capture_output=True, timeout=30)
    log = result.stdout + result.stderr
    print(log)
    if (result.returncode != 0 or "STARTUP_CHECKS_PASSED" not in log
            or any(error in log for error in ("STARTUP_CHECKS_FAILED", "ReferenceError:", "TypeError:"))):
        raise SystemExit(1)
