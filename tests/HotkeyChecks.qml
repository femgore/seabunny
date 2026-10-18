import QtQuick
import QtTest
import app.seabunny

Item {
    id: checks
    SeabunnyEngine { id: settings }
    TestEvent { id: events }
    property var window: null
    property int phase: 0
    property int attempts: 0
    property bool stepping: false
    property bool oldSidebar: false
    property bool oldHidden: false
    QtObject {
        id: request
        property var config: ({title: "Synthetic chooser hotkeys", save: true, directory: false, multiple: false,
            folder: settings.place_path("") + "/work", name: "output.txt", filters: [], filterIndex: -1,
            choices: [], acceptLabel: "Save"})
        function matches(path, filter) { return true; }
        function saveName(name, filter) { return name; }
        function cancel() {}
    }
    function verify(ok, message) {
        if (!ok) throw new Error(message);
        console.log("PASS " + message);
    }
    function key(code, modifiers) { events.keyClick(code, modifiers || Qt.NoModifier, 1); }
    function has(name) { return JSON.parse(window.benchmarkEngine.files_json).some(function(item) { return item.name === name; }); }
    function select(name) {
        var grid = window.benchmarkContainer;
        var index = grid.displayedItems.findIndex(function(item) { return item.name === name; });
        verify(index >= 0, "selection target exists: " + name);
        grid.selectItem(index, false, false);
        window.benchmarkKeys.forceActiveFocus();
    }
    Timer {
        interval: 80; running: true; repeat: true
        onTriggered: {
            if (checks.stepping) return;
            checks.stepping = true;
            try {
                if (++checks.attempts > 400) throw new Error("hotkey timeout at phase " + checks.phase);
                if (!checks.window) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    checks.window = component.createObject(null);
                    window.benchmarkTheme.reducedMotion = true;
                    window.benchmarkEngine.set_path(settings.place_path("") + "/work");
                    window.requestActivate();
                    return;
                }
                var w = checks.window, engine = w.benchmarkEngine;
                if (engine.is_loading) return;
                switch (checks.phase) {
                case 0:
                    select("a.txt"); key(Qt.Key_F2); break;
                case 1:
                    verify(w.benchmarkPrompt.visible && w.activeFocusItem.selectedText === "a", "F2 opens Rename and selects the basename while retaining the extension (visible=" + w.benchmarkPrompt.visible + ", selection=" + (w.activeFocusItem ? w.activeFocusItem.selectedText : "none") + ", ready=" + w.fileActionsReady + ", count=" + w.benchmarkContainer.selectedCount + ")");
                    key(Qt.Key_Delete);
                    verify(w.activeFocusItem.text === ".txt" && has("a.txt"), "Delete edits the rename field without trashing a file");
                    key(Qt.Key_Z, Qt.ControlModifier);
                    verify(!engine.can_undo && w.benchmarkPrompt.visible, "text Undo does not invoke filesystem Undo");
                    key(Qt.Key_Escape); break;
                case 2:
                    select("a.txt"); key(Qt.Key_F2); break;
                case 3:
                    w.activeFocusItem.text = "renamed.txt"; key(Qt.Key_Return); break;
                case 4:
                    verify(has("renamed.txt") && !has("a.txt"), "Enter commits the F2 rename on disk");
                    w.benchmarkKeys.forceActiveFocus(); key(Qt.Key_Z, Qt.ControlModifier); break;
                case 5:
                    verify(has("a.txt") && !has("renamed.txt"), "Ctrl+Z undoes the rename");
                    key(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier); break;
                case 6:
                    verify(has("renamed.txt"), "Ctrl+Shift+Z redoes the rename");
                    select("renamed.txt"); key(Qt.Key_Delete); break;
                case 7:
                    verify(!has("renamed.txt") && engine.can_undo, "Delete moves the selected file to reversible Trash");
                    key(Qt.Key_Z, Qt.ControlModifier); break;
                case 8:
                    verify(has("renamed.txt"), "Ctrl+Z restores the trashed file");
                    key(Qt.Key_2, Qt.ControlModifier); break;
                case 9:
                    verify(engine.view_mode === "list", "Ctrl+2 switches to list view");
                    key(Qt.Key_A, Qt.ControlModifier);
                    verify(w.benchmarkContainer.selectedCount === w.benchmarkContainer.displayedItems.length, "Ctrl+A selects all items in list view");
                    select("renamed.txt"); key(Qt.Key_F2); break;
                case 10:
                    verify(w.benchmarkPrompt.visible, "F2 also works in list view");
                    key(Qt.Key_Escape); key(Qt.Key_1, Qt.ControlModifier); break;
                case 11:
                    verify(engine.view_mode === "grid", "Ctrl+1 switches to grid view");
                    key(Qt.Key_N, Qt.ControlModifier | Qt.ShiftModifier); break;
                case 12:
                    verify(w.benchmarkPrompt.visible && w.benchmarkPrompt.mode === "new_folder", "Ctrl+Shift+N opens New Folder");
                    w.activeFocusItem.text = "Created ö"; key(Qt.Key_Return); break;
                case 13:
                    verify(has("Created ö"), "Enter creates the named folder");
                    select("renamed.txt"); key(Qt.Key_Return, Qt.AltModifier); break;
                case 14:
                    verify(w.benchmarkProperties.visible && w.benchmarkProperties.info.name === "renamed.txt", "Alt+Enter shows selected-file properties");
                    key(Qt.Key_F5); key(Qt.Key_N, Qt.ControlModifier | Qt.ShiftModifier);
                    verify(w.benchmarkProperties.visible && !w.benchmarkPrompt.visible && !engine.is_loading, "browser actions stay blocked behind a modal");
                    w.benchmarkProperties.close(); w.benchmarkKeys.forceActiveFocus();
                    key(Qt.Key_F, Qt.ControlModifier); break;
                case 15:
                    verify(w.benchmarkSearch.activeFocus, "Ctrl+F focuses search");
                    w.benchmarkSearch.text = "rename"; w.benchmarkSearch.selectAll();
                    key(Qt.Key_Delete);
                    verify(w.benchmarkSearch.text === "" && has("renamed.txt"), "Delete in search edits text without touching the selected file");
                    key(Qt.Key_F2); verify(!w.benchmarkPrompt.visible, "F2 cannot rename while a text field has focus");
                    key(Qt.Key_Escape); w.benchmarkKeys.forceActiveFocus();
                    checks.oldSidebar = w.sidebarExpanded; key(Qt.Key_F9); break;
                case 16:
                    verify(w.sidebarExpanded !== checks.oldSidebar, "F9 toggles the sidebar");
                    checks.oldHidden = engine.show_hidden; key(Qt.Key_H, Qt.ControlModifier); break;
                case 17:
                    verify(engine.show_hidden !== checks.oldHidden && !has(".hidden"), "Ctrl+H toggles hidden files");
                    key(Qt.Key_H, Qt.ControlModifier); key(Qt.Key_F5); break;
                case 18:
                    verify(has(".hidden"), "F5 refreshes the directory");
                    key(Qt.Key_R, Qt.ControlModifier); break;
                case 19:
                    verify(has("renamed.txt"), "Ctrl+R refreshes the directory");
                    key(Qt.Key_Home, Qt.AltModifier); break;
                case 20:
                    verify(engine.current_path === settings.place_path(""), "Alt+Home opens Home");
                    key(Qt.Key_Left, Qt.AltModifier); break;
                case 21:
                    verify(engine.current_path.endsWith("/work"), "Alt+Left navigates back");
                    key(Qt.Key_Right, Qt.AltModifier); break;
                case 22:
                    verify(engine.current_path === settings.place_path(""), "Alt+Right navigates forward");
                    engine.set_path(settings.place_path("") + "/work/Created ö"); break;
                case 23:
                    key(Qt.Key_Up, Qt.AltModifier); break;
                case 24:
                    verify(engine.current_path.endsWith("/work"), "Alt+Up opens the parent folder");
                    engine.set_path(settings.place_path("")); break;
                case 25:
                    engine.search_everywhere("renamed"); break;
                case 26:
                    if (!engine.is_searching_everywhere || !w.benchmarkContainer.displayedItems.some(function(item) { return item.name === "renamed.txt"; })) return;
                    select("renamed.txt"); key(Qt.Key_F2); break;
                case 27:
                    verify(w.benchmarkPrompt.visible && w.benchmarkPrompt.targetDirectory.endsWith("/work") && !engine.current_path.endsWith("/work"), "F2 resolves a search result outside the current directory");
                    w.activeFocusItem.text = "searched.txt"; key(Qt.Key_Return); break;
                case 28:
                    verify(JSON.parse(engine.get_item_info(settings.place_path("") + "/work/searched.txt")).size !== "-", "search-result rename changes the intended file");
                    w.benchmarkKeys.forceActiveFocus(); key(Qt.Key_Z, Qt.ControlModifier); break;
                case 29:
                    verify(JSON.parse(engine.get_item_info(settings.place_path("") + "/work/renamed.txt")).size !== "-", "search-result rename can be undone");
                    w.hide();
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    checks.window = component.createObject(null, {chooser: request});
                    checks.window.benchmarkTheme.reducedMotion = true;
                    checks.window.show(); checks.window.requestActivate(); break;
                case 30:
                    verify(w.chooserMode, "hotkey guards run in a dedicated chooser window");
                    select("renamed.txt"); key(Qt.Key_F2); key(Qt.Key_Delete);
                    key(Qt.Key_N, Qt.ControlModifier | Qt.ShiftModifier);
                    key(Qt.Key_Z, Qt.ControlModifier);
                    verify(!w.benchmarkPrompt.visible && has("renamed.txt") && !engine.is_loading, "chooser blocks rename, trash, new-folder and filesystem-undo hotkeys");
                    w.benchmarkName.forceActiveFocus(); w.benchmarkName.selectAll(); key(Qt.Key_Delete);
                    verify(w.benchmarkName.text === "" && has("renamed.txt"), "chooser filename Delete edits text without changing files");
                    console.log("HOTKEY_CHECKS_PASSED"); Qt.quit(); break;
                }
                checks.phase++;
            } catch (error) {
                console.error("HOTKEY_CHECKS_FAILED " + error); Qt.exit(1);
            } finally { checks.stepping = false; }
        }
    }
}
