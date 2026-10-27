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
    property int scenario: 0
    property bool cancelled: false
    readonly property var cases: ["individual", "keep", "replace", "both", "drop"]
    readonly property var decisions: ["keep_both", "keep_existing", "replace"]
    readonly property string base: settings.place_path("") + "/" + cases[scenario]
    readonly property string source: base + "/incoming/Shared ö"
    readonly property string destination: base + "/destination"
    readonly property string target: destination + "/Shared ö"
    function verify(value, message) {
        if (!value) throw new Error(message);
        console.log("PASS " + message);
    }
    function info(path) { return JSON.parse(window.benchmarkEngine.get_item_info(path)); }
    function exists(path) { return info(path).size !== "-"; }
    function find(root, name) {
        if (root.objectName === name) return root;
        var children = root.children || [];
        for (var index = 0; index < children.length; index++) {
            var result = find(children[index], name); if (result) return result;
        }
        return null;
    }
    function click(name) {
        var item = find(window.benchmarkConflict.contentItem, name);
        if (!item) throw new Error("Missing control " + name);
        events.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                if (++attempts > 450) throw new Error("Merge timeout at " + scenario + "/" + phase);
                if (!window) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    window = component.createObject(null); window.benchmarkTheme.reducedMotion = true;
                    window.requestActivate(); return;
                }
                var engine = window.benchmarkEngine, popup = window.benchmarkConflict;
                if (engine.is_loading) return;
                switch (phase) {
                case 0:
                    engine.copy_items(JSON.stringify([source]), scenario === 1 || scenario === 3);
                    engine.set_path(destination); break;
                case 1:
                    if (scenario === 4) popup.showForDrop(JSON.parse(engine.check_paste_conflicts(JSON.stringify([source]), destination)), [source], destination, true);
                    else window.triggerPaste();
                    break;
                case 2:
                    verify(popup.visible && popup.canMerge, cases[scenario] + ": folder conflicts offer Merge");
                    click("mergeFoldersButton"); break;
                case 3:
                    verify(popup.resolvingMerge && popup.mergeConflicts.length === 3, "Merge prompts for nested file collisions");
                    verify(!find(popup.contentItem, "applyToAllConflictsSwitch").checked, "Apply to all starts off");
                    if (scenario === 0 && !cancelled) {
                        popup.chooseMergeFile("keep_both");
                        events.keyClick(Qt.Key_Escape, Qt.NoModifier, 1);
                        cancelled = true; phase = 20; return;
                    }
                    if (scenario === 0) { phase = 30; return; }
                    var toggle = find(popup.contentItem, "applyToAllConflictsSwitch");
                    events.mouseClick(toggle, toggle.width - 23, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    verify(toggle.checked, "Apply to all remaining conflicts can be enabled");
                    click(scenario === 1 ? "keepExistingMergeButton" : scenario === 2 ? "replaceExistingMergeButton" : "keepBothMergeButton");
                    break;
                case 20:
                    verify(!popup.visible && !exists(target + "/new.txt"), "Cancel after a file decision leaves the merge uncommitted");
                    verify(exists(source + "/01.txt") && info(target + "/01.txt").size === "4 B", "Cancel preserves both copies");
                    phase = 1; return;
                case 30:
                    verify(popup.mergeIndex === 0, "first collision is shown independently");
                    click("keepBothMergeButton"); phase = 31; return;
                case 31:
                    verify(popup.visible && popup.mergeIndex === 1, "Keep Both advances to the next conflict");
                    click("keepExistingMergeButton"); phase = 32; return;
                case 32:
                    verify(popup.visible && popup.mergeIndex === 2, "Keep Existing advances to the last conflict");
                    phase = 60;
                    if (!popup.contentItem.grabToImage(function(image) {
                        if (!image.saveToFile(settings.get_setting("merge_preview"))) { Qt.exit(1); return; }
                        phase = 61;
                    })) throw new Error("Could not capture merge prompt");
                    return;
                case 60: return;
                case 61:
                    click("replaceExistingMergeButton"); phase = 4; return;
                case 4:
                    verify(!popup.visible && exists(target + "/new.txt"), cases[scenario] + ": merges copy the contents directly into the existing folder");
                    verify(exists(target + "/untouched.txt") && !exists(target + "/Shared ö"), "existing destination files remain and no extra folder nesting is created");
                    verify(engine.navigation_error.length === 0, "merge finishes without an operation error");
                    if (scenario === 1) verify(engine.has_clipboard && exists(source + "/01.txt"), "cut merge retains skipped files in the source and clipboard");
                    if (scenario === 3) verify(!exists(source) && !engine.has_clipboard, "complete cut merge removes the empty source and clears its clipboard entry");
                    engine.undo(); break;
                case 5:
                    verify(!exists(target + "/new.txt") && exists(source + "/new.txt"), cases[scenario] + ": Undo restores source/new-file state");
                    verify(info(target + "/nested/03.txt").size === "4 B" && exists(target + "/untouched.txt"), "Undo restores replaced originals and preserves unrelated files");
                    if (scenario === 2) verify(info(target + "/01.txt").is_symlink, "Undo restores a replaced symlink as a link");
                    engine.redo(); break;
                case 6:
                    verify(exists(target + "/new.txt"), cases[scenario] + ": Redo reapplies the merge");
                    if (++scenario < cases.length) { phase = 0; return; }
                    console.log("MERGE_CHECKS_PASSED"); window.destroy(); Qt.quit(); return;
                }
                phase++;
            } catch (error) { console.error("MERGE_CHECKS_FAILED " + error); Qt.exit(1); }
        }
    }
}
