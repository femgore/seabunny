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
    property string defaultBefore: ""
    readonly property string work: settings.place_path("") + "/work/"
    readonly property string file: work + "First # 日本語.txt"
    function verify(value, message) {
        if (!value) throw new Error(message);
        console.log("PASS " + message);
    }
    function find(root, name) {
        if (root.objectName === name) return root;
        var children = root.children || [];
        for (var index = 0; index < children.length; index++) {
            var result = find(children[index], name); if (result) return result;
        }
        return null;
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                if (++attempts > 300) throw new Error("Open With timeout at " + phase);
                if (!window) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    window = component.createObject(null);
                    window.benchmarkTheme.reducedMotion = true;
                    window.benchmarkEngine.set_path(work); window.requestActivate(); return;
                }
                var engine = window.benchmarkEngine, popup = window.benchmarkOpenWith;
                if (engine.is_loading) return;
                switch (phase) {
                case 0:
                    var items = window.benchmarkContainer.displayedItems;
                    var index = items.findIndex(function(item) { return item.name === "First # 日本語.txt"; });
                    var card = window.benchmarkView.itemAtIndex(index);
                    events.mouseClick(card, card.width / 2, card.height / 2, Qt.RightButton, Qt.NoModifier, 1);
                    break;
                case 1:
                    verify(window.benchmarkContext.visible, "right-click opens the file context menu");
                    var entry = window.benchmarkContext.model.find(function(item) { return item.text === "Open With…"; });
                    verify(!!entry, "Open With is present in the context menu");
                    window.benchmarkContext.close(); entry.action(); break;
                case 2:
                    verify(popup.visible && window.anyModalOpen, "Open With opens a modal popup and suppresses file shortcuts");
                    verify(popup.applications.length === 2, "popup lists installed fixture applications");
                    verify(popup.details.mimeType === "text/plain", "default choice names the actual file type");
                    defaultBefore = JSON.stringify(popup.applications.filter(function(app) { return app.isDefault; }).map(function(app) { return app.id; }));
                    find(popup.contentItem, "applicationSearch").text = "two"; break;
                case 3:
                    verify(popup.filteredApps.length === 1 && popup.selectedApp === "two.desktop", "search filters apps and selects the first result for keyboard opening");
                    var control = find(popup.contentItem, "defaultApplicationSwitch");
                    events.mouseClick(control, control.width - 23, control.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    verify(control.checked, "default application switch can be enabled");
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 1); break;
                case 4:
                    verify(!popup.visible, "Escape cancels app selection");
                    var current = JSON.parse(engine.open_with_apps(JSON.stringify([file]))).apps;
                    verify(JSON.stringify(current.filter(function(app) { return app.isDefault; }).map(function(app) { return app.id; })) === defaultBefore,
                        "Cancel leaves file associations unchanged");
                    popup.showFor([file]); break;
                case 5:
                    verify(!find(popup.contentItem, "defaultApplicationSwitch").checked, "reopening resets the default switch");
                    var list = find(popup.contentItem, "applicationList");
                    find(popup.contentItem, "applicationSearch").forceActiveFocus();
                    events.keyClick(Qt.Key_Down, Qt.NoModifier, 1);
                    events.keyClick(Qt.Key_Down, Qt.NoModifier, 1);
                    verify(popup.selectedApp === "two.desktop", "arrow keys navigate the application list from the search field");
                    var second = list.itemAtIndex(1);
                    events.mouseClick(second, second.width / 2, second.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    verify(popup.selectedApp === "two.desktop", "clicking an application selects it");
                    var toggle = find(popup.contentItem, "defaultApplicationSwitch");
                    events.mouseClick(toggle, toggle.width - 23, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    phase = 50;
                    if (!popup.contentItem.grabToImage(function(image) {
                        if (!image.saveToFile(settings.get_setting("open_with_preview"))) { Qt.exit(1); return; }
                        phase = 51;
                    })) throw new Error("Could not capture popup");
                    return;
                case 50: return;
                case 51:
                    var button = find(popup.contentItem, "openWithButton");
                    events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    phase = 5; break;
                case 6:
                    verify(!popup.visible, "Open launches the chosen application and closes the popup");
                    var saved = JSON.parse(engine.open_with_apps(JSON.stringify([file]))).apps[0];
                    verify(saved.id === "two.desktop" && saved.isDefault, "selected application becomes the desktop default for that type");
                    engine.open_item(file);
                    verify(engine.navigation_error.length === 0, "normal opening uses the saved desktop association");
                    popup.showFor([file, work + "Other.pdf"]); break;
                case 7:
                    verify(!popup.details.canSetDefault && !find(popup.contentItem, "defaultApplicationSwitch").enabled, "mixed file types cannot silently change several defaults");
                    find(popup.contentItem, "applicationSearch").text = "no such application"; break;
                case 8:
                    verify(popup.filteredApps.length === 0 && !find(popup.contentItem, "openWithButton").enabled, "empty search results disable Open");
                    popup.close();
                    engine.open_item(work + "Run ö.AppImage");
                    verify(engine.navigation_error.includes("Make executable"), "non-executable AppImage reports a permission error instead of opening a browser");
                    var path = work + "Run ö.AppImage";
                    var info = JSON.parse(engine.get_item_info(path));
                    var update = JSON.parse(engine.set_item_permissions(path, info.permission_identity, info.permission_mode, 448));
                    verify(!update.error, "AppImage can be made executable through the permission backend");
                    engine.open_item(path);
                    verify(engine.navigation_error.length === 0, "executable AppImage starts directly without a document handler");
                    break;
                case 9:
                    console.log("OPEN_WITH_CHECKS_PASSED"); window.destroy(); Qt.quit(); return;
                }
                phase++;
            } catch (error) { console.error("OPEN_WITH_CHECKS_FAILED " + error); Qt.exit(1); }
        }
    }
}
