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
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (checks.stepping) return;
            checks.stepping = true;
            try {
                if (++checks.attempts > 200) throw new Error("navigation checks timed out at " + checks.phase);
                if (!checks.window) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    checks.window = component.createObject(null);
                    checks.window.benchmarkTheme.reducedMotion = true;
                    checks.window.benchmarkEngine.set_path(settings.place_path("") + "/small");
                    checks.window.requestActivate();
                    return;
                }
                var window = checks.window;
                var engine = window.benchmarkEngine;
                var search = window.benchmarkSearch;
                var grid = window.benchmarkContainer;
                var home = settings.place_path("");
                if (engine.is_loading) return;
                if (checks.phase === 0) {
                    if (engine.view_mode !== "grid") engine.toggle_view_mode();
                    var bar = find(window.contentItem, "pathBar");
                    events.mouseClick(bar, bar.width - 5, bar.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    checks.phase = 1;
                } else if (checks.phase === 1) {
                    verify(window.isEditingPath && window.benchmarkPath.activeFocus, "single-clicking the path bar opens its editable field");
                    verify(window.benchmarkPath.selectedText === engine.current_path, "path field selects the full current path for copying");
                    window.benchmarkPath.text = home + "/small/inner";
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 1);
                    checks.phase = 2;
                } else if (checks.phase === 2) {
                    verify(engine.current_path === home + "/small/inner" && !window.isEditingPath, "typed path navigates on Enter");
                    engine.set_path(home + "/small");
                    checks.phase = 3;
                } else if (checks.phase === 3) {
                    search.forceActiveFocus();
                    search.text = "inner";
                    search.selectAll();
                    checks.phase = 4;
                } else if (checks.phase === 4) {
                    verify(grid.displayedItems.length === 1 && grid.displayedItems[0].name === "inner", "local search filters the parent directory (query=" + search.text + ", items=" + grid.displayedItems.map(function(item) { return item.name; }).join(",") + ")");
                    var view = window.benchmarkView;
                    events.mouseClick(view, view.width - 40, 20, Qt.LeftButton, Qt.NoModifier, 1);
                    checks.phase = 5;
                } else if (checks.phase === 5) {
                    verify(!search.activeFocus && search.selectedText.length === 0, "clicking empty space blurs and deselects the search field (focus=" + search.activeFocus + ", selection=" + search.selectedText + ", view=" + window.activeView + ", visible=" + window.benchmarkView.visible + ", size=" + window.benchmarkView.width + "x" + window.benchmarkView.height + ")");
                    search.forceActiveFocus();
                    search.selectAll();
                    events.mouseClick(window.contentItem, 8, 8, Qt.LeftButton, Qt.NoModifier, 1);
                    verify(!search.activeFocus && search.selectedText.length === 0, "clicking outside the file view also dismisses search focus and selection");
                    grid.selectItem(0, false, false);
                    grid.openSelected();
                    checks.phase = 6;
                } else if (checks.phase === 6) {
                    verify(engine.current_path === home + "/small/inner" && search.text === "", "opening a local search folder clears the previous query");
                    verify(grid.displayedItems.some(function(item) { return item.name === "content.txt"; }), "new folder contents are not filtered by its parent's query");
                    engine.set_path(home + "/small");
                    checks.phase = 7;
                } else if (checks.phase === 7) {
                    search.text = "inner";
                    engine.search_everywhere(search.text);
                    checks.phase = 8;
                } else if (checks.phase === 8) {
                    var index = grid.displayedItems.findIndex(function(item) { return item.is_dir && item.name === "inner"; });
                    if (index < 0) return;
                    grid.selectItem(index, false, false);
                    grid.openSelected();
                    checks.phase = 9;
                } else if (checks.phase === 9) {
                    verify(!engine.is_searching_everywhere && search.text === "" && engine.current_path === home + "/small/inner", "opening a recursive search result ends recursive search");
                    var view = window.benchmarkView;
                    var card = view.itemAtIndex(0);
                    events.mouseClick(card, card.width / 2, card.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    verify(grid.selectedCount === 1, "single-clicking a file still selects it");
                    events.mouseClick(view, view.width - 40, 20, Qt.LeftButton, Qt.NoModifier, 1);
                    checks.phase = 10;
                } else if (checks.phase === 10) {
                    verify(grid.selectedCount === 0, "clicking empty grid space clears the selected item");
                    engine.toggle_view_mode();
                    checks.phase = 11;
                } else if (checks.phase === 11) {
                    var list = window.benchmarkList;
                    var row = list.itemAtIndex(0);
                    events.mouseClick(row, row.width / 2, row.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    verify(grid.selectedCount === 1, "single-clicking a list row still selects it");
                    events.mouseClick(list, list.width - 40, 100, Qt.LeftButton, Qt.NoModifier, 1);
                    checks.phase = 12;
                } else {
                    verify(grid.selectedCount === 0, "clicking empty list space clears the selected item");
                    console.log("NAVIGATION_CHECKS_PASSED");
                    Qt.quit();
                }
            } catch (error) {
                console.error("NAVIGATION_CHECKS_FAILED", error);
                Qt.exit(1);
            } finally { checks.stepping = false; }
        }
    }
}
