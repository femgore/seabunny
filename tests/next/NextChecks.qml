import QtQuick
import QtTest
import app.seabunny

Item {
    id: test
    SeabunnyCore { id: settings }
    TestEvent { id: events }
    property var window: null
    property var explorer: null
    property int phase: 0
    property int attempts: 0
    property int mergeCase: 0
    property bool cancelled: false
    property string savedSort: ""
    readonly property string base: settings.user_dir("HOME")
    readonly property string incoming: base + "/merge" + mergeCase + "/incoming/Shared ö"
    readonly property string destination: base + "/merge" + mergeCase + "/destination"
    readonly property string target: destination + "/Shared ö"
    QtObject {
        id: request
        property var config: ({title:"Synthetic Seabunny chooser", save:true, directory:false, multiple:false,
            folder:base + "/work", name:"suggested 日本語.txt", filters:["Text", "Images"], filterIndex:0,
            choices:[], acceptLabel:"Save", acceptKey:""})
        property int cancelled: 0
        property int accepted: 0
        property var submitted: ({})
        function filterRules(index) { return JSON.stringify([{kind:0,pattern:index === 1 ? "*.png" : "*.txt"}]); }
        function saveName(name, index) { if (!name) return ""; return name.indexOf(".") < 0 ? name + (index === 1 ? ".png" : ".txt") : name; }
        function cancel() { cancelled++; }
        function accept(folder, paths, name, filter, choices, overwrite) {
            submitted = {folder:folder,paths:paths,name:name};
            if (name === "a.txt" && !overwrite) return {overwrite:true,path:folder + "/a.txt"};
            accepted++; return {};
        }
    }
    function check(ok, message) {
        if (!ok) throw new Error(message);
        console.log("PASS " + message);
    }
    function exists(path) { return JSON.parse(window.testCore.get_item_info(path)).exists === true; }
    function row(name) {
        for (var i = 0; i < window.engine.item_count; i++)
            if (JSON.parse(window.engine.item_json(i)).name === name) return i;
        return -1;
    }
    function select(name) {
        var index = row(name); check(index >= 0, "selection target exists: " + name);
        window.activePane.selectRow(index, false, false); window.testKeys.forceActiveFocus();
    }
    function key(code, modifiers) { events.keyClick(code, modifiers || Qt.NoModifier, 1); }
    function create(chooser) {
        var component = Qt.createComponent("file://" + settings.get_setting("test_ui"));
        if (component.status !== Component.Ready) throw new Error(component.errorString());
        var w = component.createObject(null, {chooser:chooser || null});
        if (!w) throw new Error("window creation failed");
        w.testTheme.reduceMotionSetting = true; w.requestActivate(); return w;
    }
    Timer {
        id: testTimer
        interval: 100; running:true; repeat:true
        onTriggered: {
            try {
                if (++attempts > 900) throw new Error("timeout at phase " + phase);
                if (!window) { window = create(null); window.engine.set_path(base + "/work"); return; }
                var w = window, core = w.testCore, engine = w.engine;
                if (engine.loading || core.busy) return;
                switch (phase) {
                case 0:
                    check(Qt.application.version === "0.2.2", "application reports Seabunny 0.2.2");
                    check(w.homeLaunchTarget(true) === "tab" && w.homeLaunchTarget(false) === "window", "plain launches route to a tab only when Seabunny is active");
                    check(engine.show_hidden && row(".hidden") >= 0, "hidden files are shown by default");
                    check(JSON.parse(core.places_json).some(function(p) { return p.name === "Legacy favorite"; }), "existing Seabunny favorites are present alongside desktop places");
                    select("a.txt"); key(Qt.Key_C, Qt.ControlModifier); w.newTab(base + "/work/destination"); break;
                case 1:
                    w.testKeys.forceActiveFocus(); key(Qt.Key_V, Qt.ControlModifier); break;
                case 2:
                    check(exists(base + "/work/destination/a.txt") && exists(base + "/work/a.txt"), "keyboard copy/paste works across tabs with background jobs");
                    w.testKeys.forceActiveFocus(); key(Qt.Key_Z, Qt.ControlModifier); break;
                case 3:
                    check(!exists(base + "/work/destination/a.txt"), "background copy has working Undo");
                    engine.set_path(base + "/work"); break;
                case 4:
                    select("a.txt"); key(Qt.Key_C, Qt.ControlModifier); key(Qt.Key_V, Qt.ControlModifier); break;
                case 5:
                    check(exists(base + "/work/a (2).txt"), "same-folder paste creates a numbered copy");
                    engine.set_sort("size", false); engine.set_path(base + "/work/destination"); break;
                case 6:
                    check(engine.sort_by === "name" && engine.sort_ascending, "another folder retains its default sorting");
                    engine.set_path(base + "/work"); break;
                case 7:
                    check(engine.sort_by === "size" && !engine.sort_ascending, "returning restores this folder's sorting");
                    engine.set_sort("name", true); engine.change_folder_position("mixed");
                    key(Qt.Key_F3); break;
                case 8:
                    check(w.splitView, "split view remains available");
                    key(Qt.Key_F3); w.testSidebar.expanded = true; w.testSidebar.expandedWidth = 342;
                    select("program.AppImage"); w.showProperties([base + "/work/program.AppImage"]); break;
                case 9:
                    check(w.testProperties.visible && w.testProperties.info.permission_identity.length > 0, "Properties uses the pinned permission identity");
                    w.testProperties.tab = 1; break;
                case 10:
                    var toggle = find(w.testProperties.contentItem, "makeExecutableSwitch");
                    check(!!toggle && toggle.visible, "applicable files have Make executable");
                    events.mouseClick(toggle, toggle.width - 22, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 1); break;
                case 11:
                    check((JSON.parse(core.get_item_info(base + "/work/program.AppImage")).permission_mode & 0o100) !== 0, "Make executable changes the test file's mode");
                    w.testProperties.close(); w.testOpenWith.showFor([base + "/work/a.txt"]); break;
                case 12:
                    check(w.testOpenWith.visible && w.testOpenWith.applications.some(function(app) { return app.id === "test-viewer.desktop"; }), "Open With popup lists the disposable installed application");
                    check(!w.testOpenWith.applications.some(function(app) { return app.id === "org.femgore.Seabunny.desktop"; }), "Open With excludes Seabunny as a document handler");
                    w.testOpenWith.close(); break;
                case 13:
                    if (w.testOpenWith.visible) return;
                    select("a.txt"); key(Qt.Key_F2); break;
                case 14:
                    check(w.activePane.renamingPath === base + "/work/a.txt" && w.textInputFocused, "F2 focuses the inline filename editor");
                    var input = w.activeFocusItem, original = input.text;
                    key(Qt.Key_Delete); key(Qt.Key_Z, Qt.ControlModifier);
                    check(input.text === original && exists(base + "/work/a (2).txt"), "Delete and Undo edit the filename without undoing a file operation");
                    key(Qt.Key_Escape); break;
                case 15:
                    check(w.activePane.renamingPath === "" && exists(base + "/work/a.txt"), "Escape cancels inline rename without changing the file");
                    phase = 30; return;
                case 30:
                    w.transfer([incoming], destination, mergeCase === 1 ? "move" : "copy", mergeCase === 1); break;
                case 31:
                    check(w.testConflict.visible && w.testConflict.canMerge, "matching folders offer Merge");
                    w.testConflict.applyResolution("merge"); break;
                case 32:
                    check(w.testConflict.resolvingMerge && w.testConflict.mergeConflicts.length === 3, "Merge prompts for nested file collisions");
                    if (!cancelled) { w.testConflict.chooseMergeFile("keep_both"); w.testConflict.close(); cancelled = true; phase = 40; return; }
                    w.testConflict.chooseMergeFile("keep_both"); break;
                case 33:
                    check(w.testConflict.mergeIndex === 1, "per-file decisions advance independently");
                    w.testConflict.chooseMergeFile("keep_existing"); break;
                case 34:
                    w.testConflict.chooseMergeFile("replace"); break;
                case 35:
                    check(exists(target + "/new.txt") && exists(target + "/01 (2).txt") && exists(target + "/nested/03.txt"), "background merge combines folders and honors collision decisions");
                    check(exists(target + "/untouched.txt"), "unrelated destination files are preserved");
                    core.undo(); break;
                case 36:
                    check(!exists(target + "/new.txt") && !exists(target + "/01 (2).txt"), "grouped merge Undo removes the new copies");
                    check(exists(incoming + "/new.txt") && exists(incoming + "/nested/03.txt"), "merge Undo restores cut sources");
                    core.redo(); break;
                case 37:
                    check(exists(target + "/new.txt"), "grouped merge Redo succeeds");
                    if (mergeCase === 0) { mergeCase = 1; phase = 30; return; }
                    mergeCase = 2; phase = 42; return;
                case 40:
                    check(!exists(target + "/new.txt") && exists(incoming + "/01.txt"), "cancelling a planned merge changes no files");
                    phase = 30; return;
                case 42:
                    w.transfer([incoming], destination, "copy", false); break;
                case 43:
                    w.testConflict.applyResolution("merge"); break;
                case 44:
                    var all = find(w.testConflict.contentItem, "applyToAllConflictsSwitch");
                    check(!!all && all.visible, "merge exposes Apply to all remaining conflicts");
                    events.mouseClick(all, all.width - 22, all.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    check(all.checked, "Apply to all is selectable");
                    w.testConflict.chooseMergeFile("keep_both"); break;
                case 45:
                    check(exists(target + "/02 (2).txt") && exists(target + "/nested/03 (2).txt"), "one decision resolves every remaining collision");
                    engine.set_path(base + "/archive # 日本語.zip"); break;
                case 46:
                    check(engine.location_kind === "archive" && engine.read_only && row("inner # 日本語.txt") >= 0, "safe archive browser loads Unicode and hash paths");
                    select("inner # 日本語.txt"); key(Qt.Key_C, Qt.ControlModifier); engine.set_path(base + "/work/destination"); break;
                case 47:
                    w.testKeys.forceActiveFocus(); key(Qt.Key_V, Qt.ControlModifier); break;
                case 48:
                    check(exists(base + "/work/destination/inner # 日本語.txt"), "archive member clipboard copies through the safe reader");
                    explorer = window; explorer.hide(); window = create(request); phase = 50; return;
                case 50:
                    check(w.chooserMode && w.title === request.config.title, "portal opens in dedicated chooser mode using the shared browser");
                    check(w.testName.text === "suggested 日本語.txt" && w.testName.selectedText === "suggested 日本語", "suggested filename and visible extension are retained");
                    check(w.testName.height === 44 && w.testName.width <= 440, "save field remains centered, compact and 44 pixels tall");
                    check(row("a.txt") >= 0 && row("image.png") < 0, "portal filter applies to the native list model");
                    check(!w.testSidebar.expanded && w.testSidebar.expandedWidth !== 342, "chooser has independent sidebar state");
                    w.activePane.selectAll(); check(w.activePane.selectedCount === 1, "single-selection chooser constrains Select All");
                    w.testName.text = "a.txt"; key(Qt.Key_Return); break;
                case 51:
                    check(w.testOverwrite.visible && request.accepted === 0, "saving over an existing file asks for confirmation");
                    w.testOverwrite.close(); w.acceptChooser(true); check(request.accepted === 1, "explicit overwrite approval submits the chooser response");
                    w.chooserFilter = 1; break;
                case 52:
                    if (w.testOverwrite.visible) return;
                    check(row("image.png") >= 0 && row("a.txt") < 0, "changing portal filter updates the shared pane");
                    w.testName.forceActiveFocus(); w.testName.selectAll(); key(Qt.Key_Delete);
                    check(w.testName.text === "" && exists(base + "/work/a.txt"), "Delete edits the filename without deleting a file");
                    w.testKeys.forceActiveFocus(); key(Qt.Key_F2); key(Qt.Key_Delete); key(Qt.Key_N, Qt.ControlModifier | Qt.ShiftModifier);
                    check(!w.testInput.visible && exists(base + "/work/a.txt"), "chooser blocks rename, trash and new-folder shortcuts");
                    key(Qt.Key_Escape); check(request.cancelled === 1, "Escape cancels the chooser (count=" + request.cancelled + ", modal=" + w.anyModalOpen + ", overwrite="+w.testOverwrite.visible+", props="+w.testProperties.visible+", openWith="+w.testOpenWith.visible+", batch="+w.testBatch.visible+", confirm="+w.testConfirm.visible+", pattern="+w.testPattern.visible+", command="+w.testCommand.visible+", path="+w.isEditingPath+")");
                    w.testSidebar.expanded = true; w.testSidebar.expandedWidth = 228;
                    phase = 60; return;
                case 60:
                    check(explorer.testSidebar.expandedWidth === 342, "chooser resizing preserves the explorer sidebar size");
                    w.testTheme.accentName = "serpantinum"; break;
                case 61:
                    check(w.testTheme.followsSerpantinum && w.testTheme.primary.toString() === "#abcdef", "Seabunny follows the native Serpantinum palette");
                    console.log("REQUEST_PALETTE_UPDATE"); break;
                case 62:
                    if (w.testTheme.primary.toString() !== "#123456") return;
                    check(w.testTheme.primary.toString() === "#123456", "atomic palette changes update the running chooser live");
                    request.config = Object.assign({}, request.config, {save:false,multiple:true,name:""});
                    w.hide(); window = create(request); break;
                case 63:
                    check(w.chooser.config.multiple && !w.testName.visible, "Open File enables multiple selection without a filename field");
                    w.activePane.selectAll(); check(w.activePane.selectedCount > 1, "multiple chooser selects several files");
                    w.acceptChooser(false); check(request.submitted.paths.length > 1, "multiple chooser submits all selected paths");
                    request.config = Object.assign({}, request.config, {directory:true,multiple:false});
                    w.hide(); window = create(request); break;
                case 64:
                    check(row("a.txt") < 0 && row("destination") >= 0, "folder chooser shows directories only");
                    select("destination"); w.acceptChooser(false);
                    check(request.submitted.paths[0] === base + "/work/destination", "folder chooser submits the selected directory");
                    testTimer.stop(); console.log("NEXT_CHECKS_PASSED"); Qt.quit(); return;
                }
                phase++;
            } catch (error) { console.error("NEXT_CHECKS_FAILED " + error); Qt.exit(1); }
        }
    }
    function find(root, name) {
        if (root.objectName === name) return root;
        var children = root.children || [];
        for (var i = 0; i < children.length; i++) { var item = find(children[i], name); if (item) return item; }
        return null;
    }
}
