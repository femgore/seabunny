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
    property int iconChoice: 0
    readonly property var iconChoices: ["phosphor", "serpantinum", "system", "adwaita"]
    readonly property string work: settings.place_path("") + "/work/"
    readonly property string application: work + "Example ö.AppImage"

    function verify(value, message) {
        if (!value) throw new Error(message);
        console.log("PASS " + message);
    }
    function find(root, name) {
        if (root.objectName === name) return root;
        var children = root.children || [];
        for (var index = 0; index < children.length; index++) {
            var result = find(children[index], name);
            if (result) return result;
        }
        return null;
    }
    function info(path) { return JSON.parse(window.benchmarkEngine.get_item_info(path)); }
    function click(item) { events.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, 1); }
    function toggle() {
        var control = find(window.benchmarkProperties.contentItem, "makeExecutableSwitch");
        events.mouseClick(control, control.width - 23, control.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
    }
    function save() { click(find(window.benchmarkProperties.contentItem, "savePermissionsButton")); }
    function setAccess(shift, last) {
        var control = find(window.benchmarkProperties.contentItem, "permissionAccess" + shift);
        control.forceActiveFocus();
        events.keyClick(last ? Qt.Key_End : Qt.Key_Home, Qt.NoModifier, 1);
    }

    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                if (++checks.attempts > 300) throw new Error("Properties timeout at phase " + phase);
                if (!window) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    window = component.createObject(null);
                    window.benchmarkTheme.reducedMotion = true;
                    window.benchmarkTheme.showThumbnails = false;
                    window.benchmarkEngine.set_path(work);
                    window.requestActivate();
                    return;
                }
                var engine = window.benchmarkEngine, properties = window.benchmarkProperties;
                if (engine.is_loading) return;
                switch (phase) {
                case 0:
                    window.benchmarkTheme.iconSource = iconChoices[iconChoice];
                    break;
                case 1:
                    var items = window.benchmarkContainer.displayedItems;
                    for (var pair of [["Archive.RAR", "file-archive", "package-x-generic"], ["Example ö.AppImage", "terminal", "application-x-executable"]]) {
                        var index = items.findIndex(function(item) { return item.name === pair[0]; });
                        verify(index >= 0, "fixture exists: " + pair[0]);
                        var card = window.benchmarkView.itemAtIndex(index);
                        var glyphs = window.benchmarkTheme.usesGlyphIcons;
                        var icon = find(card, glyphs ? "fileGlyphIcon" : "fileSystemIcon");
                        verify(icon && icon.visible && (glyphs ? icon.name === pair[1] : icon.status === Image.Ready && icon.source.toString().includes(pair[2])),
                            iconChoices[iconChoice] + " shows the correct icon for " + pair[0]);
                    }
                    if (++iconChoice < iconChoices.length) { phase = 0; return; }
                    window.benchmarkTheme.iconSource = "serpantinum";
                    properties.showInfo(application);
                    break;
                case 2:
                    verify(properties.visible && properties.permissionsEditable, "Properties allows editing an owned regular file");
                    verify(properties.info.permission_mode === 416, "Properties reads the actual 0640 mode");
                    verify(find(properties.contentItem, "permissionAccess6").currentText === "Read and write", "owner access uses Nautilus-style choices");
                    verify(find(properties.contentItem, "permissionAccess3").currentText === "Read-only", "group access reflects its existing read bit");
                    verify(!find(properties.contentItem, "makeExecutableSwitch").checked, "non-executable AppImage starts with the switch off");
                    toggle();
                    verify(properties.permissionMode === 488 && properties.permissionsChanged, "Make executable stages 0750 without granting write access");
                    verify(info(application).permission_mode === 416, "staged changes do not touch the file");
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 1);
                    break;
                case 3:
                    verify(!properties.visible && info(application).permission_mode === 416, "Escape cancels permission edits");
                    properties.showInfo(application);
                    break;
                case 4:
                    verify(!find(properties.contentItem, "makeExecutableSwitch").checked, "reopening restores the real switch state");
                    toggle();
                    setAccess(3, true);
                    verify(properties.permissionMode === 504, "changing group access preserves its execute bit");
                    save();
                    break;
                case 5:
                    verify(!properties.visible && info(application).permission_mode === 504, "Save applies 0770 on disk and closes Properties");
                    properties.showInfo(application);
                    break;
                case 6:
                    verify(find(properties.contentItem, "makeExecutableSwitch").checked, "saved executable state survives reopening");
                    phase = 60;
                    if (!properties.contentItem.grabToImage(function(result) {
                        if (!result.saveToFile(settings.get_setting("permissions_preview"))) {
                            console.error("PERMISSIONS_CHECKS_FAILED preview could not be saved"); Qt.exit(1); return;
                        }
                        phase = 61;
                    })) throw new Error("Properties preview could not be captured");
                    return;
                case 60:
                    return;
                case 61:
                    toggle();
                    verify(properties.permissionMode === 432, "turning off Make executable clears execute bits and keeps read/write bits");
                    save();
                    phase = 6;
                    break;
                case 7:
                    verify(info(application).permission_mode === 432, "execute bits are removed on disk");
                    properties.showInfo(work + "Folder");
                    break;
                case 8:
                    verify(!find(properties.contentItem, "makeExecutableSwitch").visible, "folders do not show a program execution switch");
                    verify(find(properties.contentItem, "permissionAccess3").currentText === "Access files", "folder permissions use folder-specific choices");
                    var group = find(properties.contentItem, "permissionAccess3");
                    group.forceActiveFocus(); events.keyClick(Qt.Key_Up, Qt.NoModifier, 1);
                    save();
                    break;
                case 9:
                    verify(info(work + "Folder").permission_mode === 480, "folder List files only saves 0740 without recursion");
                    properties.showInfo(work + "Link.AppImage");
                    break;
                case 10:
                    verify(properties.info.is_symlink && !properties.permissionsEditable, "symbolic links show read-only Properties");
                    verify(!find(properties.contentItem, "makeExecutableSwitch").visible, "link targets cannot be made executable accidentally");
                    verify(!find(properties.contentItem, "permissionAccess6").enabled, "link permission controls are disabled");
                    properties.close(); properties.showInfo(application);
                    break;
                case 11:
                    toggle();
                    var original = info(application);
                    var changed = JSON.parse(engine.set_item_permissions(application, original.permission_identity, original.permission_mode, 384));
                    verify(!changed.error && changed.permission_mode === 384, "backend can apply a separate concurrent permission change");
                    save();
                    break;
                case 12:
                    verify(properties.visible && properties.permissionError.includes("changed"), "stale Properties reports an error and stays open");
                    verify(info(application).permission_mode === 384, "stale Save cannot overwrite a concurrent permission change");
                    properties.close(); properties.showInfo(work + "missing.txt");
                    break;
                case 13:
                    verify(!properties.permissionsEditable, "missing items cannot be edited");
                    console.log("PERMISSIONS_CHECKS_PASSED"); window.destroy(); Qt.quit(); return;
                }
                phase++;
            } catch (error) {
                console.error("PERMISSIONS_CHECKS_FAILED " + error); Qt.exit(1);
            }
        }
    }
}
