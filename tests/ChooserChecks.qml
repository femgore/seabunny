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
    QtObject {
        id: request
        property var config: ({title: "Synthetic Save", save: true, directory: false, multiple: false,
            folder: settings.place_path(""), name: "Suggested 日本語", filters: ["Text", "All files", "PNG"], filterIndex: 0,
            choices: [{id: "flag", label: "Flag", options: [{id: "true", label: "Yes"}, {id: "false", label: "No"}], selected: "true"}], acceptLabel: "Save"})
        property int accepted: 0
        property int canceled: 0
        property string lastName: ""
        function saveName(name, filter) {
            return name && name.lastIndexOf(".") <= 0 ? name + (filter === 0 ? ".txt" : filter === 2 ? ".png" : "") : name;
        }
        function matches(path, filter) { return filter === 1 || !path.endsWith(".png"); }
        function accept(folder, paths, name, filter, choices, overwrite) {
            lastName = name;
            if (!overwrite) return {overwrite: true, path: folder + "/" + name};
            accepted++;
            return {accepted: true};
        }
        function cancel() { canceled++; }
    }
    function verify(value, message) {
        if (!value) throw new Error(message);
        console.log("PASS " + message);
    }
    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: {
            try {
                if (++checks.attempts > 100) throw new Error("chooser checks timed out at " + checks.phase);
                if (!checks.window) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    checks.window = component.createObject(null, {chooser: request});
                    checks.window.benchmarkTheme.reducedMotion = true;
                    checks.window.show();
                    checks.window.requestActivate();
                    return;
                }
                var w = checks.window;
                if (w.engine.is_loading) return;
                var grid = w.benchmarkContainer;
                if (checks.phase === 0) {
                    verify(w.chooserMode && w.title === "Synthetic Save", "request title and dedicated chooser mode");
                    verify(w.benchmarkName.text === "Suggested 日本語.txt", "suggested Unicode filename includes its extension");
                    verify(w.benchmarkName.selectedText === "Suggested 日本語", "initial selection edits the basename while keeping the extension visible");
                    verify(w.benchmarkName.activeFocus, "filename receives initial keyboard focus");
                    verify(grid.allTargetItems.every(function(it) { return it.name !== "image.png"; }), "portal filter applies to shared browser");
                    w.benchmarkName.text = "Typed name";
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 1);
                    checks.phase++;
                } else if (checks.phase === 1) {
                    verify(w.benchmarkOverwrite.visible && request.accepted === 0, "filename Enter opens overwrite confirmation without accepting");
                    verify(request.lastName === "Typed name.txt" && w.benchmarkName.text === request.lastName, "Enter submits exactly the full filename shown in the field");
                    w.benchmarkOverwrite.close();
                    w.acceptChooser(true);
                    verify(request.accepted === 1, "explicit overwrite confirmation accepts");
                    w.chooserFilter = 2;
                    checks.phase++;
                } else if (checks.phase === 2) {
                    verify(w.benchmarkName.text === "Typed name.png", "changing type updates an automatically suggested extension in the field");
                    w.benchmarkName.text = "Explicit.custom";
                    w.chooserFilter = 0;
                    checks.phase++;
                } else if (checks.phase === 3) {
                    verify(w.benchmarkName.text === "Explicit.custom", "changing type preserves an explicitly edited extension");
                    w.chooserFilter = 1;
                    checks.phase++;
                } else if (checks.phase === 4) {
                    verify(grid.allTargetItems.some(function(it) { return it.name === "image.png"; }), "changing filter refreshes shared browser");
                    grid.selectItem(0, false, false); grid.selectItem(1, true, true);
                    verify(grid.selectedCount === 1, "single chooser ignores multi-select modifiers");
                    var c = Object.assign({}, request.config); c.multiple = true; c.save = false; request.config = c;
                    grid.selectAll();
                    verify(grid.selectedCount === grid.allTargetItems.length, "multiple chooser supports Select All");
                    w.benchmarkName.focus = false;
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 1);
                    checks.phase++;
                } else if (checks.phase === 5) {
                    verify(request.canceled === 1, "Escape cancels chooser");
                    w.close();
                    verify(request.canceled === 2, "window close cancels chooser");
                    verify(settings.get_setting("folderTabs") === "", "chooser does not persist tab session");
                    console.log("CHOOSER_CHECKS_PASSED"); Qt.quit();
                }
            } catch(error) { console.error("CHOOSER_CHECKS_FAILED", error); Qt.quit(); }
        }
    }
}
