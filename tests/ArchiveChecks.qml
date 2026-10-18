import QtQuick
import QtTest
import app.seabunny

Item {
    id: checks
    SeabunnyEngine { id: settings }
    SeabunnyEngine { id: destination }
    TestEvent { id: events }
    property var window: null
    property int phase: 0
    property int attempts: 0
    property bool stepping: false
    property string rootLocation: ""
    readonly property string home: settings.place_path("")
    readonly property string archiveFile: home + "/archives/Sample # 日本語.zip"

    function verify(value, message) {
        if (!value) throw new Error(message);
        console.log("PASS " + message);
    }
    function find(root, name) {
        if (root.objectName === name) return root;
        for (var index = 0; index < root.children.length; index++) {
            var result = find(root.children[index], name);
            if (result) return result;
        }
        return null;
    }
    function names(engine) {
        return JSON.parse(engine.files_json).map(function(item) { return item.name; });
    }

    Timer {
        interval: 80
        running: true
        repeat: true
        onTriggered: {
            if (checks.stepping) return;
            checks.stepping = true;
            try {
                if (++checks.attempts > 400) throw new Error("archive checks timed out at phase " + checks.phase);
                if (!checks.window) {
                    settings.set_setting("folderTabs", "");
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    checks.window = component.createObject(null);
                    checks.window.benchmarkTheme.reducedMotion = true;
                    checks.window.requestActivate();
                    checks.window.benchmarkEngine.set_path(checks.home + "/archives");
                    destination.set_path(checks.home + "/archive-copy");
                    return;
                }
                var window = checks.window;
                var engine = window.benchmarkEngine;
                var grid = window.benchmarkContainer;
                if (engine.is_loading || engine.archive_busy || destination.is_loading || destination.archive_busy) return;
                if (checks.phase === 0) {
                    verify(engine.archive_path === "", "ordinary directories are not in archive mode");
                    var index = grid.displayedItems.findIndex(function(item) { return item.name === "Sample # 日本語.zip"; });
                    grid.selectItem(index, false, false);
                    grid.openSelected();
                    checks.phase = 1;
                } else if (checks.phase === 1) {
                    verify(engine.archive_path === checks.archiveFile && names(engine).indexOf("folder") >= 0, "opening a ZIP browses its root without extracting it");
                    checks.rootLocation = engine.current_path;
                    var crumbs = JSON.parse(engine.breadcrumbs_json);
                    verify(crumbs[crumbs.length - 1].name === "Sample # 日本語.zip", "archive breadcrumbs display the real archive name");
                    var button = find(window.contentItem, "archiveExtractButton");
                    verify(button && button.visible && button.enabled, "native item-count row exposes the archive Extract button");
                    var folder = grid.displayedItems.filter(function(item) { return item.name === "folder"; })[0];
                    window.benchmarkMenu.currentTargetItem = folder;
                    var menu = window.benchmarkMenu.buildItemModel();
                    verify(menu.some(function(item) { return item.text === "Copy"; })
                        && menu.some(function(item) { return item.text === "Extract Selected"; })
                        && !menu.some(function(item) { return item.text === "Rename" || item.text === "Cut" || item.text === "Move to Trash"; }),
                        "archive context menus expose safe copying/extraction instead of mutation actions");
                    engine.set_path(checks.rootLocation + "/folder/inner");
                    checks.phase = 2;
                } else if (checks.phase === 2) {
                    verify(names(engine).indexOf("hello ö.txt") >= 0, "nested archive folders list Unicode member names");
                    engine.open_item(engine.current_path + "/hello ö.txt");
                    checks.phase = 20;
                } else if (checks.phase === 20) {
                    verify(engine.archive_status.indexOf("archive-open") >= 0 && engine.navigation_error === "",
                           "opening an archived file creates a read-only preview copy through the asynchronous backend");
                    engine.navigate_up();
                    checks.phase = 3;
                } else if (checks.phase === 3) {
                    verify(engine.current_path === checks.rootLocation + "/folder", "Up navigates to the archive's parent member folder");
                    engine.go_back();
                    checks.phase = 4;
                } else if (checks.phase === 4) {
                    verify(engine.current_path === checks.rootLocation + "/folder/inner", "Back restores archive navigation state");
                    engine.go_forward();
                    checks.phase = 5;
                } else if (checks.phase === 5) {
                    verify(engine.current_path === checks.rootLocation + "/folder", "Forward restores archive navigation state");
                    var index = grid.displayedItems.findIndex(function(item) { return item.name === "second.txt"; });
                    grid.selectItem(index, false, false);
                    engine.create_file(engine.current_path, "must-not-exist.txt");
                    verify(engine.navigation_error.indexOf("read-only") >= 0, "backend independently rejects writes inside archives");
                    events.keyClick(Qt.Key_C, Qt.ControlModifier, 1);
                    destination.sync_shared_state();
                    verify(destination.has_clipboard, "archive members can be copied across independently owned tab engines");
                    destination.paste_items(checks.home + "/archive-copy");
                    checks.phase = 6;
                } else if (checks.phase === 6) {
                    verify(names(destination).indexOf("second.txt") >= 0 && destination.navigation_error === "", "pasting outside an archive materializes only the selected member");
                    var button = find(window.contentItem, "archiveExtractButton");
                    events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    checks.phase = 7;
                } else if (checks.phase === 7) {
                    verify(engine.archive_status.indexOf("Sample # 日本語") >= 0 && engine.navigation_error === "", "actual Extract button extracts the current selection into an archive-named folder");
                    engine.set_path(checks.rootLocation);
                    checks.phase = 8;
                } else if (checks.phase === 8) {
                    grid.clearSelection();
                    var button = find(window.contentItem, "archiveExtractButton");
                    events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    checks.phase = 9;
                } else if (checks.phase === 9) {
                    verify(engine.archive_status.indexOf("(1)") >= 0 && engine.navigation_error === "", "Extract with no selection exports the whole archive without overwriting previous extraction");
                    window.openFolderTab(checks.rootLocation + "/folder", false);
                    checks.phase = 10;
                } else if (checks.phase === 10) {
                    verify(window.benchmarkTabs.entries.length === 2 && engine.archive_path === checks.archiveFile, "archive folders can be opened in independent tabs");
                    window.benchmarkTabs.persist();
                    var oldWindow = window;
                    oldWindow.visible = false;
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    checks.window = component.createObject(null);
                    oldWindow.destroy();
                    checks.phase = 11;
                } else if (checks.phase === 11) {
                    verify(engine.archive_path === checks.archiveFile && engine.current_path === checks.rootLocation + "/folder", "archive tabs restore their member directory after reopening Seabunny");
                    engine.set_path(checks.rootLocation);
                    engine.navigate_up();
                    checks.phase = 12;
                } else if (checks.phase === 12) {
                    verify(engine.archive_path === "" && engine.current_path === checks.home + "/archives", "Up at the archive root returns to the real containing folder");
                    verify(!find(window.contentItem, "archiveExtractButton").visible, "archive-only controls disappear in normal folders");
                    engine.set_path(checks.home + "/archives/unsafe.zip");
                    checks.phase = 13;
                } else if (checks.phase === 13) {
                    verify(engine.navigation_error.indexOf("Unsafe") >= 0, "malicious archive paths become a visible error rather than filesystem writes");
                    engine.set_path(checks.archiveFile);
                    engine.set_path(checks.home + "/archive-copy");
                    checks.phase = 14;
                } else if (checks.phase === 14) {
                    verify(engine.archive_path === "" && names(engine).indexOf("second.txt") >= 0, "stale archive listing work cannot replace a newly opened real directory");
                    engine.set_path(checks.archiveFile);
                    checks.phase = 15;
                } else if (checks.phase === 15) {
                    checks.phase = 100;
                    window.benchmarkShell.grabToImage(function(result) {
                        if (!result.saveToFile(settings.get_setting("archive_preview"))) { Qt.exit(1); return; }
                        console.log("ARCHIVE_CHECKS_PASSED");
                        Qt.quit();
                    });
                }
            } catch (error) {
                console.error("ARCHIVE_CHECKS_FAILED", error);
                Qt.exit(1);
            } finally { checks.stepping = false; }
        }
    }
}
