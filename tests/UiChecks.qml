import QtQuick
import QtTest
import app.seabunny

Item {
    id: checks
    SeabunnyEngine { id: settings }
    TestEvent { id: events }
    property var nativeWindow: null
    property int phase: 0
    property int attempts: 0
    property real originalSize: 0
    property int originalColumns: 0
    property bool stepping: false

    function verify(condition, message) {
        if (!condition) throw new Error(message);
        console.log("PASS " + message);
    }

    Timer {
        interval: 60
        running: true
        repeat: true
        onTriggered: {
            if (checks.stepping) return;
            checks.stepping = true;
            try {
                if (++checks.attempts > 200) throw new Error("UI checks timed out");
                if (!checks.nativeWindow) {
                    let component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    checks.nativeWindow = component.createObject(null);
                    if (!checks.nativeWindow) throw new Error("native main window did not initialize");
                    checks.nativeWindow.benchmarkEngine.set_path(settings.place_path("") + "/large");
                    return;
                }
                let window = checks.nativeWindow;
                let engine = window.benchmarkEngine;
                let view = window.benchmarkView;
                if (engine.is_loading) return;
                if (checks.phase === 0) {
                    window.requestActivate();
                    checks.originalSize = window.gridItemSize;
                    checks.originalColumns = view.cols;
                    verify(window.visible && view.width > 0 && view.height > 0, "native window has a rendered viewport");
                    let card = view.itemAtIndex(0);
                    verify(card !== null, "zoom test targets a real file card rather than only the empty viewport");
                    events.mouseWheel(card, 20, 20, Qt.NoButton, Qt.ControlModifier, 0, 120, 1);
                    checks.phase = 1;
                } else if (checks.phase === 1) {
                    verify(window.gridItemSize > checks.originalSize, "actual Ctrl+wheel event increases the grid size");
                    verify(view.cols === checks.originalColumns - 1, "one zoom-in wheel step removes exactly one column");
                    verify(Math.abs(view.cellWidth * view.cols - view.width) < 0.01, "zoomed cards fill the available row width without a right-side gap");
                    verify(Number(engine.get_setting("gridItemSize")) === window.gridItemSize, "grid zoom preference is saved");
                    events.mouseWheel(view, 100, 100, Qt.NoButton, Qt.ControlModifier, 0, -120, 1);
                    checks.phase = 20;
                } else if (checks.phase === 20) {
                    verify(view.cols === checks.originalColumns, "one zoom-out wheel step adds exactly one column");
                    view.forceLayout();
                    var nextRow = view.itemAtIndex(view.cols);
                    var lastColumn = view.itemAtIndex(view.cols - 1);
                    verify(nextRow && Math.abs(nextRow.x) < 0.01 && nextRow.y >= view.cellHeight - 0.01
                           && lastColumn && Math.abs(lastColumn.x + lastColumn.width - view.width) < 0.01,
                           "actual GridView delegates wrap at the intended column and reach the right edge");
                    checks.originalSize = window.gridItemSize;
                    events.mouseWheel(view, 100, 100, Qt.NoButton, Qt.NoModifier, 0, -120, 1);
                    checks.phase = 2;
                } else if (checks.phase === 2) {
                    verify(window.gridItemSize === checks.originalSize && view.contentY > 0, "ordinary wheel scrolling does not zoom");
                    var exactSteps = true;
                    for (let index = 0; index < 40; index++) {
                        var previousColumns = view.cols;
                        events.mouseWheel(view, 100, 100, Qt.NoButton, Qt.ControlModifier, 0, 120, 0);
                        exactSteps = exactSteps && view.cols === Math.max(1, Math.floor(view.width / 420 + 0.000001), previousColumns - 1);
                    }
                    verify(exactSteps, "every zoom-in step removes one column until the maximum size is reached");
                    verify(window.gridItemSize === 420, "zoom maximum is enforced");
                    exactSteps = true;
                    var evenRows = true;
                    for (let index = 0; index < 40; index++) {
                        var previousColumns = view.cols;
                        events.mouseWheel(view, 100, 100, Qt.NoButton, Qt.ControlModifier, 0, -120, 0);
                        exactSteps = exactSteps && view.cols === Math.min(Math.max(1, Math.floor(view.width / 88 + 0.000001)), previousColumns + 1);
                        view.forceLayout();
                        var nextRow = view.itemAtIndex(view.cols);
                        var lastColumn = view.itemAtIndex(view.cols - 1);
                        evenRows = evenRows && nextRow && Math.abs(nextRow.x) < 0.01
                            && nextRow.y >= view.cellHeight - 0.01 && lastColumn
                            && Math.abs(lastColumn.x + lastColumn.width - view.width) < 0.01;
                    }
                    verify(exactSteps, "every zoom-out step adds one column until the minimum size is reached");
                    verify(evenRows, "native delegates fill and wrap correctly at every zoom level");
                    verify(window.gridItemSize === 88, "zoom minimum is enforced");
                    events.keyClick(Qt.Key_L, Qt.ControlModifier, 1);
                    checks.phase = 3;
                } else if (checks.phase === 3) {
                    verify(window.isEditingPath && window.benchmarkPath.activeFocus, "Ctrl+L focuses the path field");
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 1);
                    checks.phase = 4;
                } else if (checks.phase === 4) {
                    verify(!window.isEditingPath && !window.benchmarkPath.activeFocus, "Escape closes and unfocuses the path field");
                    let pictures = window.benchmarkNav.itemAt(4);
                    events.mouseClick(pictures, pictures.width / 2, pictures.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    checks.phase = 5;
                } else if (checks.phase === 5) {
                    verify(engine.current_path === settings.place_path("Pictures"), "actual Pictures sidebar click honors XDG user directories");
                    verify(window.currentNavIndex === 4, "sidebar active selection tracks the actual directory");
                    engine.set_path(settings.get_setting("outside_fixture"));
                    checks.phase = 6;
                } else if (checks.phase === 6) {
                    verify(engine.current_path === settings.get_setting("outside_fixture"), "navigation can leave the home directory");
                    let home = window.benchmarkNav.itemAt(1);
                    events.mouseClick(home, home.width / 2, home.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    checks.phase = 7;
                } else if (checks.phase === 7) {
                    verify(engine.current_path === settings.place_path(""), "actual Home sidebar click returns to the real home directory");
                    verify(window.favoriteItems.length === 1 && window.favoriteItems[0].label === "Saved folder ö", "favorites survive restarting the actual application");
                    let menu = window.benchmarkMenu;
                    menu.currentTargetItem = { name: "large", is_dir: true };
                    menu.buildItemModel().filter(function(item) { return item.text === "Pin to Favorites"; })[0].action();
                    verify(window.favoriteItems.length === 2 && window.benchmarkNav.count === 11, "folder context-menu pin action adds a real sidebar entry");
                    window.benchmarkNavScroll.contentY = Math.max(0, window.benchmarkNavScroll.contentHeight - window.benchmarkNavScroll.height);
                    checks.phase = 8;
                } else if (checks.phase === 8) {
                    window.benchmarkNavScroll.contentY = Math.max(0, window.benchmarkNavScroll.contentHeight - window.benchmarkNavScroll.height);
                    checks.phase = 81;
                } else if (checks.phase === 81) {
                    let favorite = window.benchmarkNav.itemAt(10);
                    events.mouseClick(favorite, favorite.width / 2, favorite.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    checks.phase = 9;
                } else if (checks.phase === 9) {
                    verify(engine.current_path === settings.place_path("") + "/large" && window.currentNavIndex === 10, "clicking a scrolled favorite navigates and selects the right sidebar entry");
                    let favorite = window.benchmarkNav.itemAt(10);
                    events.mouseClick(favorite, favorite.width / 2, favorite.height / 2, Qt.RightButton, Qt.NoModifier, 1);
                    verify(window.benchmarkFavoriteMenu.visible, "right-clicking a sidebar favorite opens its edit menu");
                    window.benchmarkFavoriteMenu.model[0].action();
                    window.benchmarkFavoriteMenu.close();
                    checks.phase = 10;
                } else if (checks.phase === 10) {
                    if (!window.activeFocusItem || window.activeFocusItem.text === undefined) return;
                    verify(window.benchmarkFavoritePrompt.visible, "favorite rename uses the native text prompt");
                    window.activeFocusItem.text = "My large folder";
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 1);
                    verify(window.favoriteItems[1].label === "My large folder", "editing a favorite changes its persisted label only");
                    checks.phase = 11;
                } else if (checks.phase === 11) {
                    verify(!window.activeFocusItem || window.activeFocusItem.text === undefined,
                           "closing the text prompt transfers focus away from its hidden input");
                    let menu = window.benchmarkFavoriteMenu;
                    menu.showFor(window.benchmarkNav.model[10], window.benchmarkNav.itemAt(10));
                    menu.model[1].action();
                    menu.close();
                    verify(window.favoriteItems.length === 1 && engine.current_path.endsWith("/large") && JSON.parse(engine.files_json).length === 1200, "removing a favorite does not delete or navigate away from its folder");
                    engine.view_mode = "list";
                    checks.originalSize = window.gridItemSize;
                    checks.phase = 12;
                } else if (checks.phase === 12) {
                    verify(window.gridItemSize === checks.originalSize, "list mode leaves the saved grid size intact");
                    checks.phase = 13;
                    console.log("UI_CHECKS_PASSED");
                    Qt.quit();
                }
            } catch (error) {
                console.error("UI_CHECKS_FAILED " + error);
                Qt.quit();
            } finally {
                checks.stepping = false;
            }
        }
    }
}
