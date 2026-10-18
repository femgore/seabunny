import QtQuick
import QtTest
import app.seabunny

Item {
    id: checks
    SeabunnyEngine { id: settings }
    TestEvent { id: events }
    property var window: null
    property var first: null
    property var second: null
    property int phase: 0
    property int attempts: 0
    property bool stepping: false
    property bool listReady: false
    property real savedY: 0
    property real singleTabHeight: 0
    property real multipleTabHeight: 0
    property string selectedPath: ""

    function verify(value, message) {
        if (!value) throw new Error(message);
        console.log("PASS " + message);
    }
    function key(key, modifiers) {
        events.keyClick(key, modifiers, 2);
    }
    function find(root, name) {
        if (root.objectName === name) return root;
        for (var index = 0; index < root.children.length; index++) {
            var result = find(root.children[index], name);
            if (result) return result;
        }
        return null;
    }

    Timer {
        interval: 80
        running: true
        repeat: true
        onTriggered: {
            if (checks.stepping) return;
            checks.stepping = true;
            try {
                if (++checks.attempts > 300) throw new Error("tab checks timed out at phase " + checks.phase);
                if (!checks.window) {
                    settings.set_setting("folderTabs", "");
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    checks.window = component.createObject(null);
                    checks.window.benchmarkTheme.reducedMotion = true;
                    checks.window.benchmarkTheme.showThumbnails = false;
                    checks.window.requestActivate();
                    checks.window.benchmarkEngine.set_path(settings.place_path("") + "/large");
                    return;
                }
                var window = checks.window;
                var tabs = window.benchmarkTabs;
                var engine = window.benchmarkEngine;
                var grid = window.benchmarkContainer;
                if (engine.is_loading) return;
                var home = settings.place_path("");
                if (checks.phase === 0) {
                    verify(tabs.entries.length === 1 && engine.current_path === home + "/large", "startup creates an independent folder tab");
                    verify(!window.benchmarkTabBar.visible, "tab strip is hidden with only one tab");
                    checks.singleTabHeight = window.benchmarkView.height;
                    checks.first = engine;
                    window.benchmarkSearch.text = "file-00";
                    checks.phase = 1;
                } else if (checks.phase === 1) {
                    grid.selectItem(80, false, false);
                    window.benchmarkView.contentY = 420;
                    checks.savedY = window.benchmarkView.contentY;
                    checks.selectedPath = engine.current_path + "/" + grid.getSelectedItems()[0].name;
                    key(Qt.Key_T, Qt.ControlModifier);
                    checks.phase = 2;
                } else if (checks.phase === 2) {
                    verify(tabs.entries.length === 2 && engine !== checks.first, "Ctrl+T creates a separate Rust navigation engine");
                    verify(tabs.entries[0].state.gridY === checks.savedY, "opening the tab strip preserves the outgoing tab's user scroll position (saved " + tabs.entries[0].state.gridY + ", expected " + checks.savedY + ")");
                    verify(window.benchmarkTabBar.visible && window.benchmarkView.height < checks.singleTabHeight - 40, "second tab reveals the strip and reserves its layout space");
                    checks.second = engine;
                    engine.set_path(home + "/small");
                    checks.phase = 3;
                } else if (checks.phase === 3) {
                    verify(checks.first.current_path === home + "/large", "navigation in the second tab leaves the first folder unchanged");
                    verify(window.benchmarkSearch.text === "" && grid.selectedCount === 0, "new tabs start with independent search and selection");
                    key(Qt.Key_Backtab, Qt.ControlModifier | Qt.ShiftModifier);
                    checks.phase = 4;
                } else if (checks.phase === 4) {
                    verify(engine === checks.first, "Ctrl+Shift+Tab selects the preceding tab");
                    verify(window.benchmarkSearch.text === "file-00", "tab switching restores the first search query");
                    verify(grid.selectedCount === 1 && engine.current_path + "/" + grid.getSelectedItems()[0].name === checks.selectedPath, "tab switching restores selection by file identity");
                    verify(Math.abs(window.benchmarkView.contentY - checks.savedY) < 2, "tab switching restores the previous scroll position (actual " + window.benchmarkView.contentY + ", expected " + checks.savedY + ")");
                    engine.go_back();
                    checks.phase = 5;
                } else if (checks.phase === 5) {
                    verify(engine.current_path === home && checks.second.current_path === home + "/small", "back history is independent between tabs");
                    engine.go_forward();
                    key(Qt.Key_Tab, Qt.ControlModifier);
                    checks.phase = 6;
                } else if (checks.phase === 6) {
                    verify(engine === checks.second && engine.current_path === home + "/small", "Ctrl+Tab restores the second tab and its folder");
                    verify(checks.first.current_path === home + "/large", "forward navigation is scoped to its original tab");
                    engine.copy_items(JSON.stringify([home + "/small/sentinel.txt"]), false);
                    tabs.activate(0);
                    verify(window.benchmarkEngine.has_clipboard, "clipboard state is synchronized when activating another tab");
                    tabs.activate(1);
                    checks.phase = 7;
                } else if (checks.phase === 7) {
                    var items = grid.displayedItems;
                    var index = items.findIndex(function(item) { return item.name === "inner"; });
                    var card = window.benchmarkView.itemAtIndex(index);
                    if (!card) return;
                    events.mouseClick(card, card.width / 2, card.height / 2, Qt.MiddleButton, Qt.NoModifier, 2);
                    checks.phase = 8;
                } else if (checks.phase === 8) {
                    verify(tabs.entries.length === 3 && engine === checks.second, "middle-click opens a folder in a background tab");
                    verify(tabs.entries[2].engine.current_path === home + "/small/inner", "background tab targets the clicked directory");
                    var folder = grid.displayedItems.filter(function(item) { return item.name === "inner"; })[0];
                    window.benchmarkMenu.currentTargetItem = folder;
                    verify(window.benchmarkMenu.buildItemModel().some(function(item) { return item.text === "Open in New Tab"; }), "folder context menu offers Open in New Tab");
                    var active = tabs.activeEngine;
                    var handle = find(window.benchmarkTabBar.itemAtIndex(1), "folderTabDrag");
                    var distance = handle.width + 6;
                    events.mousePress(handle, 30, 18, Qt.LeftButton, Qt.NoModifier, 1);
                    events.mouseMove(handle, 30 - distance, 18, 5, Qt.LeftButton, Qt.NoModifier);
                    events.mouseRelease(handle, 30 - distance, 18, Qt.LeftButton, Qt.NoModifier, 1);
                    verify(tabs.currentIndex === 0 && tabs.activeEngine === active, "actual tab dragging reorders tabs without changing the active engine");
                    engine.toggle_view_mode();
                    engine.create_file(home + "/small", "created-in-tab.txt");
                    window.openFolderTab(home + "/small", true);
                    checks.phase = 9;
                } else if (checks.phase === 9) {
                    if (tabs.entries[3].engine.is_loading) return;
                    if (!checks.listReady) {
                        verify(engine.view_mode === "list" && checks.first.view_mode === "grid", "each tab retains its own grid or list mode");
                        tabs.activate(1);
                        tabs.activate(0);
                        verify(window.benchmarkEngine === checks.second && engine.view_mode === "list", "tab switching restores the native list view");
                        checks.listReady = true;
                        return;
                    }
                    var index = grid.displayedItems.findIndex(function(item) { return item.name === "inner"; });
                    var row = window.benchmarkList.itemAtIndex(index);
                    if (!row) return;
                    events.mouseClick(row, row.width / 2, row.height / 2, Qt.MiddleButton, Qt.NoModifier, 2);
                    verify(tabs.entries.length === 5 && tabs.activeEngine === checks.second, "middle-click opens folders in background tabs from list mode too");
                    tabs.close(4);
                    engine.create_file(home + "/small", "shared-refresh.txt");
                    checks.phase = 10;
                } else if (checks.phase === 10) {
                    var other = tabs.entries[3].engine;
                    if (other.is_loading) return;
                    verify(JSON.parse(other.files_json).some(function(item) { return item.name === "shared-refresh.txt"; }), "file operations refresh other open tabs without replacing their histories");
                    var before = tabs.entries.length;
                    verify(!window.openFolderTab(home + "/unavailable", false) && tabs.entries.length === before, "unavailable folders cannot create broken tabs");
                    var doomed = tabs.entries[2].engine;
                    doomed.set_path(home + "/large");
                    tabs.close(2);
                    verify(tabs.activeEngine === engine, "closing a loading background tab preserves the active tab");
                    key(Qt.Key_W, Qt.ControlModifier);
                    checks.phase = 11;
                } else if (checks.phase === 11) {
                    verify(tabs.entries.length === 2 && tabs.activeEngine !== checks.second, "Ctrl+W closes only the active tab");
                    tabs.activate(1);
                    tabs.persist();
                    var saved = JSON.parse(settings.get_setting("folderTabs"));
                    verify(saved.version === 1 && saved.paths.length === 2, "open tab paths and active index are persisted");
                    saved.paths.push(home + "/missing-after-restart");
                    settings.set_setting("folderTabs", JSON.stringify(saved));
                    var oldWindow = checks.window;
                    oldWindow.visible = false;
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    checks.window = component.createObject(null);
                    oldWindow.destroy();
                    checks.phase = 12;
                } else if (checks.phase === 12) {
                    verify(tabs.entries.length === 2 && tabs.currentIndex === 1, "restart restores valid tabs and the selected index while skipping unavailable folders");
                    verify(tabs.entries.every(function(entry) { return entry.engine.current_path.indexOf("missing-after-restart") < 0; }), "restoration never leaves an unusable missing tab");
                    checks.multipleTabHeight = window.benchmarkView.height;
                    tabs.close(0);
                    checks.phase = 13;
                } else if (checks.phase === 13) {
                    verify(tabs.entries.length === 1 && !window.benchmarkTabBar.visible
                           && window.benchmarkView.height > checks.multipleTabHeight + 40,
                           "closing down to one tab hides the strip and gives its space back to the file view");
                    tabs.persist();
                    checks.phase = 100;
                    window.sidebarExpanded = true;
                    Qt.callLater(function() {
                        window.benchmarkShell.grabToImage(function(result) {
                            if (!result.saveToFile(settings.get_setting("tabs_preview"))) { Qt.exit(1); return; }
                            console.log("TABS_CHECKS_PASSED");
                            Qt.quit();
                        });
                    });
                }
            } catch (error) {
                console.error("TABS_CHECKS_FAILED", error);
                Qt.exit(1);
            } finally { checks.stepping = false; }
        }
    }
}
