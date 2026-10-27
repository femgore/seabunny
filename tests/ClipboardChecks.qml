import QtQuick
import QtTest
import app.seabunny

Item {
    id: checks
    SeabunnyEngine { id: settings }
    SeabunnyEngine { id: otherWindow }
    TestEvent { id: events }
    property var window: null
    property int phase: 0
    property int attempts: 0
    readonly property string base: settings.place_path("") + "/work"
    function verify(ok, message) {
        if (!ok) throw new Error(message);
        console.log("PASS " + message);
    }
    function key(code, modifiers) { events.keyClick(code, modifiers || Qt.NoModifier, 1); }
    function select(name) {
        var grid = window.benchmarkContainer;
        var index = grid.displayedItems.findIndex(function(item) { return item.name === name; });
        verify(index >= 0, "selection target exists: " + name);
        grid.selectItem(index, false, false);
        window.benchmarkKeys.forceActiveFocus();
    }
    function exists(path) { return JSON.parse(window.benchmarkEngine.get_item_info(path)).size !== "-"; }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                if (++attempts > 300) throw new Error("clipboard timeout at phase " + phase);
                if (!window) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    window = component.createObject(null);
                    window.benchmarkTheme.reducedMotion = true;
                    window.benchmarkEngine.set_path(base);
                    window.requestActivate(); return;
                }
                var engine = window.benchmarkEngine;
                if (engine.is_loading) return;
                switch (phase) {
                case 0:
                    select("a.txt"); key(Qt.Key_C, Qt.ControlModifier); break;
                case 1:
                    verify(engine.has_clipboard, "Ctrl+C populates the file clipboard");
                    engine.set_path(base + "/destination"); break;
                case 2:
                    window.benchmarkKeys.forceActiveFocus(); key(Qt.Key_V, Qt.ControlModifier); break;
                case 3:
                    verify(exists(base + "/destination/a.txt") && exists(base + "/a.txt"), "Ctrl+V copies a file without moving its source");
                    key(Qt.Key_Z, Qt.ControlModifier); break;
                case 4:
                    verify(!exists(base + "/destination/a.txt"), "pasted copy can be undone");
                    engine.set_path(base); break;
                case 5:
                    select("a.txt"); key(Qt.Key_X, Qt.ControlModifier);
                    engine.set_path(base + "/destination"); break;
                case 6:
                    window.benchmarkKeys.forceActiveFocus(); key(Qt.Key_V, Qt.ControlModifier); break;
                case 7:
                    verify(exists(base + "/destination/a.txt") && !exists(base + "/a.txt"), "Ctrl+X then Ctrl+V moves the selected file");
                    verify(!engine.has_clipboard, "successful cut clears the file clipboard");
                    key(Qt.Key_Z, Qt.ControlModifier); break;
                case 8:
                    verify(exists(base + "/a.txt"), "cut paste can be undone");
                    engine.set_path(base); break;
                case 9:
                    select("a.txt"); key(Qt.Key_C, Qt.ControlModifier);
                    key(Qt.Key_V, Qt.ControlModifier); break;
                case 10:
                    verify(exists(base + "/a (1).txt"), "copy and paste in the same folder creates a duplicate");
                    select("Folder"); key(Qt.Key_C, Qt.ControlModifier); key(Qt.Key_V, Qt.ControlModifier); break;
                case 11:
                    verify(exists(base + "/Folder (1)/inside.txt"), "same-folder directory copy duplicates its contents");
                    engine.set_path(base + "/Folder/subdir"); break;
                case 12:
                    window.benchmarkKeys.forceActiveFocus(); key(Qt.Key_V, Qt.ControlModifier); break;
                case 13:
                    verify(engine.navigation_error.length > 0 && !exists(base + "/Folder/subdir/Folder"), "pasting a directory into its own descendant is rejected before copying");
                    engine.set_path(base); break;
                case 14:
                    select("a.txt"); key(Qt.Key_X, Qt.ControlModifier); key(Qt.Key_V, Qt.ControlModifier); break;
                case 15:
                    verify(exists(base + "/a.txt") && engine.has_clipboard, "cut and paste in place preserves the source and selection");
                    select("a.txt");
                    var grid = window.benchmarkContainer;
                    var index = grid.displayedItems.findIndex(function(item) { return item.name === "b # 日本語.txt"; });
                    grid.selectItem(index, true, false);
                    key(Qt.Key_C, Qt.ControlModifier);
                    window.openFolderTab(base + "/destination", false); break;
                case 16:
                    window.benchmarkKeys.forceActiveFocus();
                    var menu = window.benchmarkMenu;
                    var paste = menu.buildEmptyModel().find(function(item) { return item.text === "Paste"; });
                    verify(!!paste, "new destination tab offers Paste in its context menu");
                    paste.action(); break;
                case 17:
                    verify(exists(base + "/destination/a.txt") && exists(base + "/destination/b # 日本語.txt"), "context-menu Paste copies multiple files across tabs with spaces and Unicode");
                    engine.copy_items(JSON.stringify([base + "/a.txt"]), false);
                    window.triggerPaste(); break;
                case 18:
                    verify(window.benchmarkConflict.visible, "a colliding paste prompts before transfer");
                    otherWindow.copy_items(JSON.stringify([base + "/b # 日本語.txt"]), false);
                    window.benchmarkConflict.applyResolution("rename"); break;
                case 19:
                    verify(exists(base + "/destination/a (1).txt") && !exists(base + "/destination/b # 日本語 (1).txt"), "a changed system clipboard cannot replace the selection in an open conflict prompt");
                    window.triggerPaste(); break;
                case 20:
                    verify(window.benchmarkConflict.visible, "the next paste uses the new clipboard selection");
                    window.benchmarkConflict.close(); break;
                case 21:
                    verify(!window.benchmarkConflict.visible, "cancel closes a pending paste without copying");
                    console.log("CLIPBOARD_CHECKS_PASSED"); Qt.quit(); break;
                }
                phase++;
            } catch (error) { console.error("CLIPBOARD_CHECKS_FAILED " + error); Qt.exit(1); }
        }
    }
}
