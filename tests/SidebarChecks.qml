import QtQuick
import QtTest
import app.seabunny
import "../qml/Sidebar.js" as Sidebar

Item {
    id: checks
    SeabunnyEngine { id: settings }
    TestEvent { id: events }
    property var nativeWindow: null
    property var fileDrag: null
    property int phase: 0
    property int ticks: 0
    property int attempts: 0
    property int expandedColumns: 0
    property bool stepping: false
    readonly property string home: settings.place_path("")

    function verify(value, message) {
        if (!value) throw new Error(message);
        console.log("PASS " + message);
    }
    function item(id) { return nativeWindow.benchmarkNav.model.filter(function(entry) { return entry.id === id; })[0]; }
    function row(id) { return nativeWindow.benchmarkNav.itemAt(nativeWindow.benchmarkNav.model.findIndex(function(entry) { return entry.id === id; })); }
    function find(root, name) {
        if (root.objectName === name) return root;
        for (var index = 0; index < root.children.length; index++) {
            var result = find(root.children[index], name);
            if (result) return result;
        }
        return null;
    }
    function uri(path) { return "file://" + path.split("/").map(encodeURIComponent).join("/"); }

    Component {
        id: fileDragComponent
        Item {
            id: fixtureDrag
            width: 2
            height: 2
            property string uri: ""
            property var sourceObject: fixtureDrag
            Drag.dragType: Drag.Internal
            Drag.source: sourceObject
            Drag.keys: ["text/uri-list"]
            Drag.mimeData: ({"text/uri-list": uri})
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        }
    }

    Timer {
        interval: 70
        running: true
        repeat: true
        onTriggered: {
            if (checks.stepping) return;
            checks.stepping = true;
            try {
                if (++checks.attempts > 250) throw new Error("sidebar checks timed out at phase " + checks.phase);
                if (!checks.nativeWindow) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    checks.nativeWindow = component.createObject(null);
                    checks.nativeWindow.gridItemSize = 260;
                    checks.nativeWindow.expandedSidebarWidth = 328;
                    checks.nativeWindow.sidebarExpanded = true;
                    checks.nativeWindow.benchmarkEngine.set_path(checks.home + "/previews");
                    return;
                }
                var window = checks.nativeWindow;
                var engine = window.benchmarkEngine;
                var view = window.benchmarkView;
                if (engine.is_loading) return;
                if (checks.phase === 0) {
                    if (++checks.ticks < 6) return;
                    var card = view.itemAtIndex(0);
                    var preview = find(card, "filePreview");
                    var label = find(card, "fileNameLabel");
                    verify(preview && preview.width >= card.width * 0.85 && preview.height >= card.width - 64,
                           "image previews use the space left inside square cards after the filename");
                    verify(Math.abs(card.height - card.width) < 0.01 && label
                           && label.mapToItem(card, 0, label.height).y <= card.height,
                           "the filename stays within the square card footprint");
                    verify(find(card, "fileThumbnail").fillMode === Image.PreserveAspectFit,
                           "large previews show the whole image without cropping away its content");
                    verify(engine.folder_position === "mixed", "folders default to the same sort order as files");
                    checks.expandedColumns = view.cols;
                    window.sidebarExpanded = false;
                    checks.ticks = 0;
                    checks.phase = 1;
                } else if (checks.phase === 1) {
                    if (++checks.ticks < 6) return;
                    verify(view.cols === checks.expandedColumns + 1, "collapsing the sidebar fits exactly one additional grid column");
                    var home = row("place:home");
                    events.mousePress(home, 34, 22, Qt.LeftButton, Qt.NoModifier, 1);
                    events.mouseMove(home, 34, 40, 5, Qt.LeftButton, Qt.NoModifier);
                    checks.phase = 2;
                } else if (checks.phase === 2) {
                    var pictures = row("place:Pictures");
                    events.mouseMove(pictures, 34, 35, 5, Qt.LeftButton, Qt.NoModifier);
                    events.mouseRelease(pictures, 34, 35, Qt.LeftButton, Qt.NoModifier, 1);
                    checks.phase = 3;
                } else if (checks.phase === 3) {
                    var ids = window.benchmarkNav.model.map(function(entry) { return entry.id; });
                    verify(ids.indexOf("place:home") === ids.indexOf("place:Pictures") + 1, "actual pointer dragging reorders built-in sidebar entries");
                    var pictures = item("place:Pictures");
                    window.benchmarkFavoriteMenu.showFor(pictures, row(pictures.id));
                    window.benchmarkFavoriteMenu.model[0].action();
                    window.benchmarkFavoriteMenu.close();
                    verify(!item("place:Pictures") && JSON.parse(engine.get_item_info(settings.place_path("Pictures"))).is_dir,
                           "removing a default place hides only its sidebar entry, not its folder");
                    var favorite = item("folder:" + checks.home + "/small");
                    verify(favorite.iconName === "folder", "new favorites default to a folder icon rather than a star");
                    window.benchmarkFavoriteMenu.showFor(favorite, row(favorite.id));
                    var icons = window.benchmarkFavoriteMenu.model.filter(function(entry) { return entry.text === "Folder Icon"; })[0].submenu;
                    icons.filter(function(entry) { return entry.text === "image"; })[0].action();
                    window.benchmarkFavoriteMenu.close();
                    verify(item(favorite.id).customIcon === "image", "sidebar icon selection is applied through the real context menu");
                    window.benchmarkNavScroll.contentY = Math.max(0, window.benchmarkNavScroll.contentHeight - window.benchmarkNavScroll.height);
                    checks.phase = 4;
                } else if (checks.phase === 4) {
                    window.benchmarkFileDragController.paths = [checks.home + "/pin # ö %"];
                    checks.fileDrag = fileDragComponent.createObject(window.contentItem, { x: 600, y: 100, sourceObject: window.benchmarkFileDrag });
                    checks.fileDrag.Drag.active = true;
                    var target = window.benchmarkPinDrop.mapToItem(window.contentItem, 20, 22);
                    checks.fileDrag.x = target.x;
                    checks.fileDrag.y = target.y;
                    checks.phase = 5;
                } else if (checks.phase === 5) {
                    verify(checks.fileDrag.Drag.drop() === Qt.CopyAction, "internal file drag onto the pin target is accepted as bookmarking, not moving");
                    checks.fileDrag.destroy();
                    verify(!!item("folder:" + checks.home + "/pin # ö %") && JSON.parse(engine.get_item_info(checks.home + "/pin # ö %")).is_dir,
                           "sidebar pin drops preserve special characters and leave the folder in place");
                    window.benchmarkNavScroll.contentY = Math.max(0, window.benchmarkNavScroll.contentHeight - window.benchmarkNavScroll.height);
                    checks.phase = 6;
                } else if (checks.phase === 6) {
                    window.benchmarkFileDragController.paths = [checks.home + "/move me # ö"];
                    checks.fileDrag = fileDragComponent.createObject(window.contentItem, { x: 600, y: 100, sourceObject: window.benchmarkFileDrag });
                    checks.fileDrag.Drag.active = true;
                    var target = row("folder:" + checks.home + "/small").mapToItem(window.contentItem, 34, 22);
                    checks.fileDrag.x = target.x;
                    checks.fileDrag.y = target.y;
                    checks.phase = 7;
                } else if (checks.phase === 7) {
                    verify(checks.fileDrag.Drag.drop() === Qt.MoveAction, "dropping onto a sidebar folder center requests a move rather than pinning");
                    checks.fileDrag.destroy();
                    verify(!JSON.parse(engine.get_item_info(checks.home + "/move me # ö")).is_dir
                        && JSON.parse(engine.get_item_info(checks.home + "/small/move me # ö")).is_dir,
                        "sidebar folder drop moves only the synthetic source into its chosen destination");
                    engine.undo();
                    verify(JSON.parse(engine.get_item_info(checks.home + "/move me # ö")).is_dir, "sidebar moves retain native undo support");
                    var drop = { source: null, urls: [uri(checks.home + "/copy me")], modifiers: Qt.ControlModifier,
                        accept: function(action) { this.action = action; } };
                    window.dropOnSidebar(drop, item("folder:" + checks.home + "/small"), "");
                    verify(drop.action === Qt.CopyAction && JSON.parse(engine.get_item_info(checks.home + "/copy me")).is_dir
                        && JSON.parse(engine.get_item_info(checks.home + "/small/copy me")).is_dir, "Ctrl-drop copies and preserves the original folder");
                    engine.drop_items(JSON.stringify([checks.home + "/small"]), checks.home + "/alias-small/inner", false);
                    verify(JSON.parse(engine.get_item_info(checks.home + "/small")).is_dir
                        && !JSON.parse(engine.get_item_info(checks.home + "/small/inner/small")).is_dir,
                        "canonical path checks reject moving a folder inside itself through a symlink");
                    verify(Sidebar.localPaths(["https://example.invalid/image", "file://remote/share", "file:///bad%ZZ"]).length === 0,
                           "non-local and malformed drop URLs cannot become filesystem paths");
                    verify(JSON.parse(engine.get_setting("sidebarLayout")).icons["folder:" + checks.home + "/small"] === "image",
                           "custom sidebar icons are persisted alongside stable sidebar identities");
                    window.gridItemSize = 300;
                    window.sidebarExpanded = true;
                    window.benchmarkNavScroll.contentY = 0;
                    checks.ticks = 0;
                    checks.phase = 8;
                } else if (checks.phase === 8) {
                    if (++checks.ticks < 8) return;
                    checks.phase = 9;
                    view.grabToImage(function(result) {
                        result.saveToFile(settings.get_setting("layout_preview"));
                        console.log("SIDEBAR_CHECKS_PASSED");
                        Qt.quit();
                    });
                }
            } catch (error) {
                console.error("SIDEBAR_CHECKS_FAILED " + error);
                Qt.quit();
            } finally { checks.stepping = false; }
        }
    }
}
