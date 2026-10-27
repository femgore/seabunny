import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import app.seabunny
import "Sidebar.js" as Sidebar

ApplicationWindow {
    id: window
    readonly property var chooser: typeof portalRequest !== "undefined" ? portalRequest : null
    readonly property bool chooserMode: chooser !== null
    property string chooserError: ""
    property var chooserChoices: ({})
    property int chooserFilter: chooserMode ? chooser.config.filterIndex : -1
    property string chooserNameBase: ""
    property string chooserGeneratedName: ""
    onChooserFilterChanged: {
        gridContainer.clearSelection(); gridContainer.reloadItems();
        if (chooserMode) Qt.callLater(window.updateChooserName);
    }

    function updateChooserName() {
        if (!chooserMode || !chooser.config.save) return;
        var base = chooserName.text === chooserGeneratedName ? chooserNameBase : chooserName.text;
        chooserNameBase = base;
        chooserGeneratedName = chooser.saveName(base, chooserFilter);
        chooserName.text = chooserGeneratedName;
    }

    function chooserPaths() {
        return gridContainer.getSelectedItems().map(function(item) {
            return engine.is_searching_everywhere ? item.path : engine.current_path + "/" + item.name;
        });
    }
    function acceptChooser(overwrite) {
        if (!chooserMode) return;
        updateChooserName();
        var result = chooser.accept(engine.current_path, chooserPaths(), chooserName.text,
                                    chooserFilter, chooserChoices, !!overwrite);
        chooserError = result.error || "";
        if (result.overwrite) { overwritePath.text = result.path; chooserOverwrite.open(); }
    }
    function activateFile(path) {
        if (!chooserMode) { engine.open_item(path); return; }
        if (chooser.config.save) chooserName.text = path.split("/").pop();
        acceptChooser(false);
    }
    component ChooserComboBox: ComboBox {
        palette.buttonText: theme.textMain
        palette.base: theme.surfaceContainerHigh
        palette.text: theme.textMain
        palette.window: theme.surfaceContainer
        palette.windowText: theme.textMain
        palette.highlight: theme.primary
        palette.highlightedText: theme.primaryFg
        background: Rectangle {
            implicitWidth: 140
            implicitHeight: 34
            radius: theme.radiusM
            color: theme.surfaceContainerHigh
            border.color: parent.activeFocus ? theme.primary : theme.outline
        }
    }
    footer: Rectangle {
        visible: window.chooserMode
        height: visible ? chooserFooter.implicitHeight + 24 : 0
        color: theme.surfaceContainer
        ColumnLayout {
            id: chooserFooter
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8
            Text {
                visible: window.chooserError.length > 0
                text: window.chooserError
                color: theme.danger
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Repeater {
                model: window.chooserMode ? chooser.config.choices : []
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Text { text: modelData.label; color: theme.textMain }
                    ChooserComboBox {
                        Layout.fillWidth: true
                        model: modelData.options
                        textRole: "label"
                        valueRole: "id"
                        Component.onCompleted: currentIndex = modelData.options.findIndex(function(p) { return p.id === modelData.selected; })
                        onActivated: {
                            var values = Object.assign({}, window.chooserChoices);
                            values[modelData.id] = currentValue;
                            window.chooserChoices = values;
                        }
                    }
                }
            }
            Item {
                id: chooserActionsRow
                Layout.fillWidth: true
                Layout.preferredHeight: chooserName.visible ? 44 : 34
                TextField {
                    id: chooserName
                    objectName: "chooserFilename"
                    visible: window.chooserMode && chooser.config.save
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(160, Math.min(440, parent.width
                        - 2 * Math.max(chooserFilterControl.visible ? chooserFilterControl.width : 0,
                                       chooserActionButtons.width) - 24))
                    height: 44
                    leftPadding: 16
                    rightPadding: 16
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: "Filename"
                    text: window.chooserMode ? chooser.config.name : ""
                    color: theme.textMain
                    selectionColor: theme.primary
                    background: Rectangle { radius: theme.radiusM; color: theme.surfaceContainerHigh; border.color: theme.outline }
                    onAccepted: window.acceptChooser(false)
                    onEditingFinished: window.updateChooserName()
                }
                ChooserComboBox {
                    id: chooserFilterControl
                    objectName: "chooserFilter"
                    visible: count > 0
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(240, Math.max(140, parent.width * 0.18))
                    model: window.chooserMode ? chooser.config.filters : []
                    currentIndex: window.chooserFilter
                    onActivated: window.chooserFilter = currentIndex
                }
                RowLayout {
                    id: chooserActionButtons
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    SeabunnyButton {
                        objectName: "chooserCancel"
                        text: "Cancel"
                        activeFocusOnTab: true
                        onClicked: chooser.cancel()
                        Keys.onReturnPressed: chooser.cancel()
                        Keys.onSpacePressed: chooser.cancel()
                    }
                    SeabunnyButton {
                        objectName: "chooserAccept"
                        text: window.chooserMode ? chooser.config.acceptLabel : "Open"
                        variant: "filled"
                        activeFocusOnTab: true
                        onClicked: window.acceptChooser(false)
                        Keys.onReturnPressed: window.acceptChooser(false)
                        Keys.onSpacePressed: window.acceptChooser(false)
                    }
                }
            }
        }
    }
    SeabunnyDialog {
        id: chooserOverwrite
        objectName: "chooserOverwrite"
        title: "Replace existing file?"
        Text { id: overwritePath; color: theme.textMain; wrapMode: Text.Wrap; Layout.fillWidth: true }
        RowLayout {
            SeabunnyButton { text: "Cancel"; onClicked: chooserOverwrite.close() }
            SeabunnyButton {
                objectName: "chooserReplace"
                text: "Replace"; variant: "danger"; activeFocusOnTab: true
                onClicked: { chooserOverwrite.close(); window.acceptChooser(true); }
                Keys.onReturnPressed: { chooserOverwrite.close(); window.acceptChooser(true); }
            }
        }
    }
    Shortcut {
        sequence: window.chooserMode ? (chooser.config.acceptKey || "") : ""
        enabled: window.chooserMode && !window.anyModalOpen && !!chooser.config.acceptKey
        onActivated: window.acceptChooser(false)
    }
    Shortcut {
        sequence: "Escape"
        enabled: window.chooserMode && !window.anyModalOpen
        onActivated: chooser.cancel()
    }
    width: 1080
    height: 720
    minimumWidth: 760
    minimumHeight: 500
    visible: !chooserMode
    title: chooserMode ? chooser.config.title : "Seabunny - " + (activeView === "settings"
        ? ("Settings - " + (settingsView ? (settingsView.activeTab === 0 ? "Interface" : (settingsView.activeTab === 1 ? "Behavior" : (settingsView.activeTab === 2 ? "Experimental" : "About Seabunny"))) : "Settings"))
        : activeView === "pc" ? (engine.hostname || "This PC")
        : (engine.is_searching_everywhere ? "Searching Everywhere" : engine.current_dir_name))
    color: theme.background
    font.family: theme.fontFamily

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressedChanged: {
            if (!pressed || !searchInput.activeFocus) return;
            var position = searchInput.mapFromItem(parent, point.position.x, point.position.y);
            if (position.x < 0 || position.y < 0 || position.x > searchInput.width || position.y > searchInput.height)
                globalKeyHandler.forceActiveFocus();
        }
    }

    readonly property var initialSidebarState: JSON.parse(preferencesEngine.sidebar_state(chooserMode) || "{}")
    property bool sidebarReady: false
    property bool sidebarExpanded: initialSidebarState.expanded === true
    property real expandedSidebarWidth: Math.max(180, Math.min(520,
        Number(initialSidebarState.width) || Number(preferencesEngine.get_setting("sidebarWidth")) || 300))
    property bool resizingSidebar: false
    readonly property real maximumSidebarWidth: Math.max(180, Math.min(520, width - 380))
    onSidebarExpandedChanged: saveSidebarState()

    function saveSidebarState() {
        if (sidebarReady)
            preferencesEngine.save_sidebar_state(chooserMode, sidebarExpanded, expandedSidebarWidth);
    }

    function resizeSidebar(value) {
        expandedSidebarWidth = Math.max(180, Math.min(maximumSidebarWidth, value));
    }
    function saveSidebarWidth() {
        if (!chooserMode) preferencesEngine.set_setting("sidebarWidth", String(expandedSidebarWidth));
        saveSidebarState();
    }

    MouseArea {
        id: sidebarResizeHandle
        objectName: "sidebarResizeHandle"
        parent: navRailRect
        x: parent.width - width
        y: 0
        width: 8
        height: navRailRect.height
        z: 100
        visible: window.sidebarExpanded
        hoverEnabled: true
        cursorShape: Qt.SplitHCursor
        property real startX: 0
        property real startWidth: 0
        onPressed: function(mouse) {
            startX = mapToItem(window.contentItem, mouse.x, mouse.y).x;
            startWidth = navRailRect.width;
            window.resizingSidebar = true;
            theme.finishAnimations(navRailRect);
        }
        onPositionChanged: function(mouse) {
            if (pressed) window.resizeSidebar(startWidth + mapToItem(window.contentItem, mouse.x, mouse.y).x - startX);
        }
        onReleased: { window.saveSidebarWidth(); window.resizingSidebar = false; }
        onCanceled: { window.saveSidebarWidth(); window.resizingSidebar = false; }
        onDoubleClicked: { window.resizeSidebar(300); window.saveSidebarWidth(); }
        Rectangle {
            objectName: "sidebarResizeNotch"
            anchors.centerIn: parent
            width: 3
            height: 30
            radius: 1.5
            color: parent.containsMouse || parent.pressed ? theme.primary : theme.outline
            opacity: parent.containsMouse || parent.pressed ? 1 : 0.5
        }
    }
    property string activeView: "files" // "files", "settings", or "pc"
    property int currentNavIndex: 1      // nav rows: 0 = PC, 1 = Home, ...
    property int currentPlaceIndex: 1    // last clicked place row (pill position when in files view)
    property real gridItemSize: Math.max(88, Math.min(420, Number(engine.get_setting("gridItemSize")) || 220))
    onGridItemSizeChanged: engine.set_setting("gridItemSize", String(gridItemSize))
    readonly property var cutPaths: JSON.parse(engine.clipboard_cut_paths_json || "[]")
    property var favoriteItems: JSON.parse(engine.favorites_json())
    property var sidebarLayout: Sidebar.layout(engine.get_setting("sidebarLayout"))

    function saveSidebarLayout(value) {
        sidebarLayout = value;
        engine.set_setting("sidebarLayout", JSON.stringify(value));
        Qt.callLater(window.syncPlaces);
    }

    function reorderSidebar(source, target, before) {
        if (chooserMode) return;
        saveSidebarLayout(Sidebar.move(sidebarLayout, navRepeater.model, source, target, before));
    }

    function removeSidebar(item) {
        if (chooserMode) return;
        if (item.favorite) { saveFavorite(item.path, "", true); return; }
        var value = Sidebar.layout(JSON.stringify(sidebarLayout));
        if (value.hidden.indexOf(item.id) < 0) value.hidden.push(item.id);
        saveSidebarLayout(value);
    }

    function sidebarPath(item) {
        if (item.view === "pc" || item.trashRoot) return "";
        return item.path || engine.place_path(item.pathSuffix || "");
    }

    function pinSidebarPaths(paths, target, before) {
        var pinned = false;
        paths.forEach(function(path) {
            if (!JSON.parse(engine.get_item_info(path)).is_dir) return;
            if (window.saveFavorite(path, path.split("/").filter(Boolean).pop() || "Home", false)) {
                pinned = true;
                var favorite = window.favoriteItems.filter(function(item) { return item.path === path; })[0];
                if (favorite && target) window.reorderSidebar("folder:" + favorite.path, target, before);
            }
        });
        return pinned;
    }

    function dropOnSidebar(drop, item, edge) {
        if (chooserMode) return;
        drop.accepted = false;
        if (drop.source === sidebarDragProxy) {
            var source = sidebarDragProxy.sidebarId;
            Qt.callLater(function() { window.reorderSidebar(source, item ? item.id : "", edge !== "after"); });
            drop.accept(Qt.MoveAction);
            return;
        }
        var paths = drop.source === dragProxy ? dragManager.paths.slice() : Sidebar.localPaths(drop.urls || []);
        if (!paths.length) return;
        dragManager.hoverTarget = "";
        if (!item || edge) {
            if (pinSidebarPaths(paths, item ? item.id : "", edge !== "after")) drop.accept(Qt.CopyAction);
            return;
        }
        var target = sidebarPath(item);
        if (!target || !JSON.parse(engine.get_item_info(target)).is_dir) return;
        var asCopy = drop.source === dragProxy ? dragManager.asCopy
            : !!(drop.modifiers & Qt.ControlModifier) || !(drop.supportedActions & Qt.MoveAction);
        drop.accept(asCopy ? Qt.CopyAction : Qt.MoveAction);
        handleDrop(paths, target, asCopy);
    }

    function saveFavorite(path, label, remove) {
        if (!engine.update_favorite(path, label, remove)) return false;
        favoriteItems = JSON.parse(engine.favorites_json());
        syncPlaces();
        return true;
    }

    function isFavorite(path) {
        return favoriteItems.some(function(item) { return item.path === path; });
    }

    function zoomGrid(event) {
        if (!(event.modifiers & Qt.ControlModifier)) return false;
        var delta = event.angleDelta.y || event.pixelDelta.y;
        if (!delta) return false;
        var availableWidth = filesGridView.width;
        if (availableWidth <= 0 || engine.view_mode !== "grid") return false;
        cancelTabRestore();
        var minimumColumns = Math.max(1, Math.floor(availableWidth / 420 + 0.000001));
        var maximumColumns = Math.max(1, Math.floor(availableWidth / 88 + 0.000001));
        var columns = Math.max(minimumColumns, Math.min(maximumColumns, filesGridView.cols + (delta > 0 ? -1 : 1)));
        gridItemSize = delta > 0 && columns === minimumColumns ? 420
            : delta < 0 && columns === maximumColumns ? 88
            : Math.max(88, Math.min(420, availableWidth / columns));
        event.accepted = true;
        return true;
    }

    function syncPlaces() {
        if (!navRepeater.model) return;
        if (window.activeView === "pc") {
            window.currentNavIndex = navRepeater.model.findIndex(function(item) { return item.view === "pc"; });
        }
        var best = -1;
        var longest = -1;
        for (var index = 0; index < navRepeater.model.length; index++) {
            var place = navRepeater.model[index];
            if (place.view === "pc") continue;
            var target = place.path || (place.trashRoot ? engine.trash_root : engine.place_path(place.pathSuffix || ""));
            if ((engine.current_path === target || engine.current_path.indexOf(target + "/") === 0) && target.length > longest) {
                best = index;
                longest = target.length;
            }
        }
        window.currentPlaceIndex = best;
        if (window.activeView === "files") window.currentNavIndex = best;
    }
    property bool isEditingPath: false

    // Views that show the back button and aren't the file grid (back returns to files)
    readonly property bool isAuxView: activeView === "settings" || activeView === "pc"

    // Return to the file grid, restoring the nav pill to the last place row.
    // placeIdx >= 0 also updates which place is considered active (e.g. PCView jumps).
    function showFiles(placeIdx) {
        activeView = "files";
        if (placeIdx !== undefined && placeIdx >= 0) {
            currentPlaceIndex = placeIdx;
        }
        currentNavIndex = currentPlaceIndex;
    }

    function startEditingPath() {
        if (activeView !== "files") return;
        pathInput.text = engine.current_path;
        isEditingPath = true;
        pathInput.forceActiveFocus();
        pathInput.selectAll();
    }

    function commitPathEdit() {
        var raw = pathInput.text.trim();
        if (raw.length > 0) {
            engine.set_path(raw);
        }
        endPathEdit();
    }

    function endPathEdit() {
        globalKeyHandler.forceActiveFocus();
        isEditingPath = false;
    }

    function copySelected(isCut) {
        if (chooserMode) return;
        if (activeView !== "files") return;
        var items = gridContainer.getSelectedItems();
        if (items.length === 0) return;
        var paths = items.map(function(it) {
            return engine.is_searching_everywhere ? it.path : (engine.current_path + "/" + it.name);
        });
        engine.copy_items(JSON.stringify(paths), isCut);
    }

    function extractArchiveSelection() {
        if (chooserMode) return;
        var paths = gridContainer.getSelectedItems().map(function(item) { return engine.current_path + "/" + item.name; });
        engine.extract_current_archive(JSON.stringify(paths));
    }

    function triggerPaste() {
        if (chooserMode) return;
        if (activeView !== "files") return;
        var conflictsJson = engine.check_clipboard_conflicts(engine.current_path);
        var conflicts = JSON.parse(conflictsJson || "[]");
        if (conflicts.length > 0) {
            conflictModal.showForClipboard(conflicts, engine.current_path);
        } else {
            engine.paste_items(engine.current_path);
        }
    }

    function handleDrop(paths, destDir, asCopy) {
        if (chooserMode) return;
        var conflictsJson = engine.check_paste_conflicts(JSON.stringify(paths), destDir);
        var conflicts = JSON.parse(conflictsJson || "[]");
        if (conflicts.length > 0) {
            conflictModal.showForDrop(conflicts, paths, destDir, asCopy);
        } else {
            engine.drop_items(JSON.stringify(paths), destDir, asCopy);
        }
    }

    function renameSelected() {
        if (chooserMode) return;
        if (engine.archive_path.length) return;
        if (activeView !== "files") return;
        var items = gridContainer.getSelectedItems();
        if (items.length === 1) {
            var item = items[0];
            var directory = engine.is_searching_everywhere
                ? item.path.substring(0, item.path.lastIndexOf("/")) || "/" : engine.current_path;
            inputModal.showRename(item.name, directory, item.is_dir);
        }
    }

    function trashSelected() {
        if (chooserMode) return;
        if (engine.archive_path.length) return;
        if (activeView !== "files") return;
        var items = gridContainer.getSelectedItems();
        if (items.length === 0) return;
        var paths = items.map(function(it) {
            return engine.is_searching_everywhere ? it.path : (engine.current_path + "/" + it.name);
        });
        engine.trash_items(JSON.stringify(paths));
        gridContainer.clearSelection();
    }

    function showSelectedProperties() {
        var items = gridContainer.getSelectedItems();
        if (items.length > 1) return;
        var path = items.length === 0 ? engine.current_path
            : engine.is_searching_everywhere ? items[0].path : engine.current_path + "/" + items[0].name;
        propsModal.showInfo(path);
    }

    // True while the user is navigating the file grid/list from the keyboard,
    // used to draw a visible focus ring.
    property bool keyboardNavActive: false

    // Responsive list-column visibility: fixed columns drop out as the window
    // narrows so nothing overlaps at 760px.
    readonly property bool listShowDate: width >= 820
    readonly property bool listShowSize: width >= 900
    readonly property bool listShowType: width >= 980

    // True while any modal dialog is open (arrow keys / shortcuts must not fire).
    readonly property bool anyModalOpen: inputModal.visible || favoritePrompt.visible || propsModal.visible || openWithModal.visible
        || conflictModal.visible || passwordModal.visible || chooserOverwrite.visible || window.isEditingPath

    // True when a plain keystroke should be routed to the grid/list (no input
    // field focused, files view visible, no modal open).
    readonly property bool textInputFocused: !!window.activeFocusItem
        && window.activeFocusItem.text !== undefined
        && typeof window.activeFocusItem.selectAll === "function"
    readonly property bool gridKeyboardReady: window.activeView === "files"
        && !window.textInputFocused && !window.anyModalOpen
    readonly property bool fileActionsReady: window.gridKeyboardReady && !window.chooserMode
        && !engine.archive_path.length && engine.current_path !== engine.trash_root

    // Global Keyboard Shortcuts. Each is *enabled* only when it should apply so
    // that a disabled shortcut never swallows the key from a focused text field.
    Shortcut { sequence: "Ctrl+Z"; enabled: !window.chooserMode && window.gridKeyboardReady && engine.can_undo; onActivated: engine.undo() }
    Shortcut { sequences: ["Ctrl+Y", "Ctrl+Shift+Z"]; enabled: !window.chooserMode && window.gridKeyboardReady && engine.can_redo; onActivated: engine.redo() }
    Shortcut { sequence: "Ctrl+C"; enabled: !window.chooserMode && window.gridKeyboardReady; onActivated: window.copySelected(false) }
    Shortcut { sequence: "Ctrl+X"; enabled: window.fileActionsReady; onActivated: window.copySelected(true) }
    Shortcut { sequence: "Ctrl+V"; enabled: window.fileActionsReady; onActivated: window.triggerPaste() }
    Shortcut { sequence: "Ctrl+A"; enabled: window.gridKeyboardReady; onActivated: gridContainer.selectAll() }
    Shortcut { sequence: "Ctrl+H"; enabled: window.activeView === "files" && !window.anyModalOpen; onActivated: engine.toggle_show_hidden() }
    Shortcut { sequence: "Ctrl+L"; enabled: !window.anyModalOpen || window.isEditingPath; onActivated: window.startEditingPath() }
    Shortcut { sequence: "Ctrl+F"; enabled: window.activeView === "files" && !window.anyModalOpen; onActivated: { searchInput.forceActiveFocus(); searchInput.selectAll(); } }
    Shortcut { sequences: ["F5", "Ctrl+R"]; enabled: window.gridKeyboardReady; onActivated: engine.refresh() }
    Shortcut { sequence: "Ctrl+Shift+N"; enabled: window.fileActionsReady && !engine.is_searching_everywhere; onActivated: inputModal.showNewFolder() }
    Shortcut { sequence: "F2"; autoRepeat: false; enabled: window.fileActionsReady; onActivated: window.renameSelected() }
    Shortcut { sequence: "Delete"; autoRepeat: false; enabled: window.fileActionsReady; onActivated: window.trashSelected() }
    Shortcut { sequence: "Alt+Return"; enabled: !window.chooserMode && window.gridKeyboardReady && !engine.archive_path.length; onActivated: window.showSelectedProperties() }
    Shortcut { sequence: "Ctrl+1"; enabled: window.gridKeyboardReady; onActivated: engine.view_mode = "grid" }
    Shortcut { sequence: "Ctrl+2"; enabled: window.gridKeyboardReady; onActivated: engine.view_mode = "list" }
    Shortcut { sequence: "F9"; enabled: !window.anyModalOpen; onActivated: window.sidebarExpanded = !window.sidebarExpanded }
    Shortcut { sequence: "Alt+Home"; enabled: window.gridKeyboardReady; onActivated: engine.set_path(engine.place_path("")) }
    Shortcut { sequence: "Alt+Left"; enabled: window.gridKeyboardReady && engine.can_go_back; onActivated: engine.go_back() }
    Shortcut { sequence: "Alt+Right"; enabled: window.gridKeyboardReady && engine.can_go_forward; onActivated: engine.go_forward() }
    Shortcut { sequence: "Alt+Up"; enabled: window.gridKeyboardReady; onActivated: engine.navigate_up() }
    Shortcut { sequence: "Backspace"; enabled: window.gridKeyboardReady && engine.can_go_back; onActivated: engine.go_back() }
    // NOTE: Return / Enter are handled in globalKeyHandler below (not as a
    // Shortcut) so they are never swallowed from a focused text field.

    // Full-window catcher for mouse back / forward side buttons. It sits below
    // the shell (z: 0) and only accepts the two extra buttons, so ordinary
    // clicks are untouched while the side buttons always navigate history.
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onPressed: function(mouse) {
            if (mouse.button === Qt.BackButton) {
                if (engine.can_go_back) engine.go_back();
            } else if (mouse.button === Qt.ForwardButton) {
                if (engine.can_go_forward) engine.go_forward();
            }
        }
    }

    Item {
        id: globalKeyHandler
        anchors.fill: parent
        focus: true
        z: -100

        Keys.onPressed: function(event) {
            if (window.anyModalOpen) {
                return;
            }

            // Always-on arrow navigation + open, for both grid and list views.
            if (window.gridKeyboardReady) {
                switch (event.key) {
                case Qt.Key_Up:
                    window.keyboardNavActive = true;
                    gridContainer.moveSelection(0, -1, !!(event.modifiers & Qt.ShiftModifier));
                    event.accepted = true;
                    return;
                case Qt.Key_Down:
                    window.keyboardNavActive = true;
                    gridContainer.moveSelection(0, 1, !!(event.modifiers & Qt.ShiftModifier));
                    event.accepted = true;
                    return;
                case Qt.Key_Left:
                    if (engine.view_mode !== "list") {
                        window.keyboardNavActive = true;
                        gridContainer.moveSelection(-1, 0, !!(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                        return;
                    }
                    break;
                case Qt.Key_Right:
                    if (engine.view_mode !== "list") {
                        window.keyboardNavActive = true;
                        gridContainer.moveSelection(1, 0, !!(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                        return;
                    }
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    gridContainer.openSelected();
                    event.accepted = true;
                    return;
                }
            }

            // Type-to-search: any printable key pulls focus into the search bar.
            if (!searchInput.activeFocus && window.activeView === "files") {
                if (!(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    if (event.text.length > 0 && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backspace && event.key !== Qt.Key_Delete) {
                        searchInput.forceActiveFocus();
                        searchInput.text = event.text;
                        searchInput.cursorPosition = 1;
                        event.accepted = true;
                    }
                }
            }
        }
    }

    readonly property var engine: folderTabs.activeEngine || preferencesEngine
    property bool switchingTab: false
    property var pendingTabState: null
    property int tabRestoreRevision: 0

    function cancelTabRestore() {
        restoreScrollTimer.stop();
        pendingTabState = null;
        tabRestoreRevision++;
    }

    function captureTabState() {
        if (pendingTabState) return pendingTabState;
        var last = gridContainer.displayedItems[gridContainer.lastSelectedIndex];
        var anchor = gridContainer.displayedItems[gridContainer.anchorIndex];
        return {query: searchInput.text, view: activeView,
            paths: gridContainer.getSelectedItems().map(function(item) { return item.path || engine.current_path + "/" + item.name; }), gridY: filesGridView.contentY,
            listY: filesListView.contentY,
            last: last ? last.path || engine.current_path + "/" + last.name : "",
            anchor: anchor ? anchor.path || engine.current_path + "/" + anchor.name : ""};
    }

    function restoreTabState() {
        if (!pendingTabState || engine.is_loading) return;
        var state = pendingTabState;
        gridContainer.reloadItems();
        var indices = {};
        gridContainer.displayedItems.forEach(function(item, index) {
            var path = item.path || engine.current_path + "/" + item.name;
            if (state.paths.indexOf(path) >= 0) indices[index] = true;
        });
        gridContainer.selectedIndices = indices;
        gridContainer.lastSelectedIndex = gridContainer.displayedItems.findIndex(function(item) { return (item.path || engine.current_path + "/" + item.name) === state.last; });
        gridContainer.anchorIndex = gridContainer.displayedItems.findIndex(function(item) { return (item.path || engine.current_path + "/" + item.name) === state.anchor; });
        restoreScrollTimer.backend = engine;
        restoreScrollTimer.revision = ++tabRestoreRevision;
        restoreScrollTimer.restart();
    }

    Timer {
        id: restoreScrollTimer
        interval: 16
        property var backend: null
        property int revision: 0
        onTriggered: {
            if (window.engine !== backend || window.tabRestoreRevision !== revision || !window.pendingTabState) return;
            var state = window.pendingTabState;
            filesGridView.forceLayout();
            filesListView.forceLayout();
            filesGridView.contentY = Math.max(0, Math.min(state.gridY, Math.max(0, filesGridView.contentHeight - filesGridView.height)));
            filesListView.contentY = Math.max(0, Math.min(state.listY, Math.max(0, filesListView.contentHeight - filesListView.height)));
            window.pendingTabState = null;
        }
    }

    function openFolderTab(path, background) {
        if (chooserMode) { engine.set_path(path); return true; }
        return folderTabs.open(path, !!background);
    }

    SeabunnyEngine { id: preferencesEngine; objectName: "settingsEngine" }
    FolderTabs {
        id: folderTabs
        settingsEngine: preferencesEngine
        persistent: !window.chooserMode
        captureState: window.captureTabState
        onActivated: function(entry) {
            window.tabRestoreRevision++;
            window.switchingTab = true;
            var state = entry.state || {query: "", view: "files", paths: [], gridY: 0, listY: 0, last: "", anchor: ""};
            window.activeView = state.view;
            searchInput.text = state.query;
            filterTimer.stop();
            gridContainer.clearSelection();
            gridContainer.reloadItems();
            window.pendingTabState = state;
            window.switchingTab = false;
            window.restoreTabState();
            window.endPathEdit();
            window.syncPlaces();
            globalKeyHandler.forceActiveFocus();
        }
        onNavigated: {
            window.tabRestoreRevision++;
            searchInput.text = "";
            filterTimer.stop();
            if (window.isEditingPath) window.endPathEdit();
            Qt.callLater(window.syncPlaces);
            window.pendingTabState = null;
            gridContainer.clearSelection();
            window.keyboardNavActive = false;
            dirTransitionAnim.restart();
        }
    }

    Component.onCompleted: {
        sidebarReady = true;
        if (chooserMode) {
            folderTabs.open(chooser.config.folder, false);
            if (chooser.config.save) Qt.callLater(function() {
                window.updateChooserName();
                chooserName.forceActiveFocus();
                var extension = chooserName.text.lastIndexOf(".");
                chooserName.select(0, extension > 0 ? extension : chooserName.text.length);
            });
        } else folderTabs.restore();
    }
    onClosing: {
        saveSidebarState();
        if (chooserMode) chooser.cancel(); else folderTabs.persist();
    }
    Shortcut { sequence: "Ctrl+T"; enabled: !window.anyModalOpen; onActivated: window.openFolderTab(engine.current_path, false) }
    Shortcut { sequence: "Ctrl+W"; enabled: !window.anyModalOpen; onActivated: { if (chooserMode) chooser.cancel(); else folderTabs.close(folderTabs.currentIndex); } }
    Shortcut { sequence: "Ctrl+Tab"; enabled: !window.anyModalOpen; onActivated: folderTabs.cycle(1) }
    Shortcut { sequence: "Ctrl+Shift+Tab"; enabled: !window.anyModalOpen; onActivated: folderTabs.cycle(-1) }

    ParallelAnimation {
        id: dirTransitionAnim

        NumberAnimation {
            target: mainStageContent
            property: "opacity"
            from: 0.2
            to: 1.0
            duration: theme.motionDuration(170)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: stageTranslate
            property: "y"
            from: 10
            to: 0
            duration: theme.motionDuration(190)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: stageScale
            property: "xScale"
            from: 0.985
            to: 1.0
            duration: theme.motionDuration(190)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: stageScale
            property: "yScale"
            from: 0.985
            to: 1.0
            duration: theme.motionDuration(190)
            easing.type: Easing.OutCubic
        }
    }

    Theme {
        id: theme
        onReducedMotionChanged: {
            if (theme.reducedMotion) Qt.callLater(function() { theme.finishAnimations(window); });
        }
    }

    FontLoader {
        id: phosphorFontRegular
        source: "qrc:/seabunny/fonts/Phosphor.ttf"
    }

    FontLoader {
        id: phosphorFontBold
        source: "qrc:/seabunny/fonts/Phosphor-Bold.ttf"
    }

    // ==========================================
    // ORGANIC BACKGROUND SHAPES
    // ==========================================
    Item {
        anchors.fill: parent
        z: 0

        Rectangle {
            width: 420
            height: 220
            radius: 200
            x: -40
            y: -50
            color: theme.primaryContainer
            opacity: theme.isDark ? 0.22 : 0.35
        }

        Rectangle {
            width: 380
            height: 380
            radius: 190
            x: parent.width - 280
            y: parent.height - 300
            color: theme.secondaryContainer
            opacity: theme.isDark ? 0.18 : 0.28
        }
    }

    // ==========================================
    // APP SHELL
    // ==========================================
    ColumnLayout {
        id: appShell
        anchors.fill: parent
        spacing: 12
        z: 1

        // Top Navigation Bar
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 14
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            spacing: 10

            // Brand Pill (width + opacity animate on show/hide)
            Rectangle {
                id: brandBadge
                property real badgeWidth: theme.showBrandBadge ? (brandRow.implicitWidth + 24) : 0
                Layout.preferredWidth: badgeWidth
                Layout.minimumWidth: 0
                height: 42
                opacity: theme.showBrandBadge ? 1.0 : 0.0
                visible: opacity > 0.001
                radius: theme.radiusFull
                color: theme.surfaceContainer

                Behavior on badgeWidth { enabled: !theme.reducedMotion; SpringAnimation { spring: 3.8; damping: 0.35 } }
                Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.durationFast; easing.type: Easing.OutCubic } }

                RowLayout {
                    id: brandRow
                    anchors.centerIn: parent
                    spacing: 8
                    clip: true

                    SeabunnyLogo {
                        size: 24
                        color: theme.primary
                    }
                    Text {
                        text: "Seabunny"
                        color: theme.textMain
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
            }

            // Navigation History Chip (Back & Forward)
            Rectangle {
                id: navHistoryChip
                height: 42
                radius: theme.radiusFull
                color: theme.surfaceContainer
                clip: true

                readonly property bool canBack: engine.can_go_back || window.isAuxView || engine.is_searching_everywhere
                readonly property bool canForward: engine.can_go_forward && !window.isAuxView && !engine.is_searching_everywhere

                opacity: (canBack || canForward) ? 1.0 : 0.0
                property real chipWidth: (canBack || canForward)
                    ? ((canBack && canForward) ? 82 : 44)
                    : 0
                Layout.preferredWidth: chipWidth

                Behavior on chipWidth { enabled: !theme.reducedMotion; SpringAnimation { spring: 3.8; damping: 0.32 } }
                Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.durationFast } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    // Back Button
                    Item {
                        visible: navHistoryChip.canBack
                        width: 36
                        height: 36

                        Rectangle {
                            anchors.fill: parent
                            radius: 18
                            color: backBtnMouse.containsMouse ? theme.hoverOverlay : "transparent"

                            SeabunnyIcon {
                                visible: theme.usesGlyphIcons
                                anchors.centerIn: parent
                                name: "caret-left"
                                size: 18
                                color: theme.textMain
                            }

                            Image {
                                visible: !theme.usesGlyphIcons
                                anchors.centerIn: parent
                                source: theme.resolveIcon("go-previous-symbolic")
                                width: 18
                                height: 18
                                sourceSize.width: 36
                                sourceSize.height: 36
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                id: backBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (engine.is_searching_everywhere) {
                                        engine.clear_search_everywhere();
                                        searchInput.text = "";
                                    } else if (window.activeView === "settings") {
                                        if (searchInput.text.length > 0) {
                                            searchInput.text = "";
                                        } else if (settingsView && settingsView.activeTab > 0) {
                                            settingsView.activeTab = 0;
                                        } else {
                                            window.showFiles();
                                        }
                                    } else if (window.activeView === "pc") {
                                        window.showFiles();
                                    } else {
                                        engine.go_back();
                                    }
                                }
                            }
                        }
                    }

                    // Divider if both can be pressed
                    Rectangle {
                        visible: navHistoryChip.canBack && navHistoryChip.canForward
                        width: 1
                        height: 18
                        color: theme.outlineVariant
                    }

                    // Forward Button
                    Item {
                        visible: navHistoryChip.canForward
                        width: 36
                        height: 36

                        Rectangle {
                            anchors.fill: parent
                            radius: 18
                            color: fwdBtnMouse.containsMouse ? theme.hoverOverlay : "transparent"

                            SeabunnyIcon {
                                visible: theme.usesGlyphIcons
                                anchors.centerIn: parent
                                name: "caret-right"
                                size: 18
                                color: theme.textMain
                            }

                            Image {
                                visible: !theme.usesGlyphIcons
                                anchors.centerIn: parent
                                source: theme.resolveIcon("go-next-symbolic")
                                width: 18
                                height: 18
                                sourceSize.width: 36
                                sourceSize.height: 36
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                id: fwdBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: engine.go_forward()
                            }
                        }
                    }
                }
            }

            // Path Bar in Center
            Rectangle {
                id: pathBarContainer
                objectName: "pathBar"
                visible: window.activeView !== "pc"
                Layout.fillWidth: true
                Layout.minimumWidth: 140
                Layout.preferredHeight: 42
                radius: theme.radiusFull
                color: window.isEditingPath ? theme.surfaceContainerHighest : theme.surfaceContainer
                clip: true

                Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }

                // Direct Path Input (Active when isEditingPath is true)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 8
                    visible: window.isEditingPath && window.activeView === "files"

                    SeabunnyIcon {
                        name: "folder"
                        size: 16
                        color: theme.primary
                    }

                    TextInput {
                        id: pathInput
                        Layout.fillWidth: true
                        color: theme.textMain
                        font.pixelSize: 13
                        font.family: "monospace"
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true

                        Keys.onReturnPressed: function(event) {
                            window.commitPathEdit();
                            event.accepted = true;
                        }
                        Keys.onEnterPressed: function(event) {
                            window.commitPathEdit();
                            event.accepted = true;
                        }
                        Keys.onEscapePressed: function(event) {
                            window.endPathEdit();
                            event.accepted = true;
                        }
                    }

                    // Checkmark commit button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: pathCommitMouse.containsMouse ? theme.primaryContainer : "transparent"
                        Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }

                        SeabunnyIcon {
                            anchors.centerIn: parent
                            name: "check"
                            size: 14
                            color: theme.primary
                        }

                        MouseArea {
                            id: pathCommitMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.commitPathEdit()
                        }
                    }
                }

                TapHandler {
                    enabled: !window.isEditingPath && window.activeView === "files"
                    onTapped: {
                        var position = breadcrumbs.mapFromItem(parent, point.position.x, point.position.y);
                        if (!breadcrumbs.visible || breadcrumbs.indexAt(position.x + breadcrumbs.contentX, position.y + breadcrumbs.contentY) < 0)
                            window.startEditingPath();
                    }
                }

                // Files Breadcrumbs
                ListView {
                    id: breadcrumbs
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    orientation: ListView.Horizontal
                    spacing: 4
                    clip: true
                    visible: !window.isEditingPath && window.activeView === "files" && !engine.is_searching_everywhere

                    model: JSON.parse(engine.breadcrumbs_json || "[]")

                    populate: Transition {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: theme.motionDuration(160); easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.85; to: 1.0; duration: theme.motionDuration(170); easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                    }
                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: theme.motionDuration(160); easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.85; to: 1.0; duration: theme.motionDuration(170); easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                    }

                    delegate: RowLayout {
                        height: breadcrumbs.height
                        spacing: 4

                        Item {
                            id: chipContainer
                            height: 32
                            width: chipRow.implicitWidth + 22

                            readonly property bool isHoverDropTarget: dragManager.active && dragManager.hoverTarget === modelData.path

                            Rectangle {
                                anchors.fill: parent
                                radius: theme.radiusFull
                                color: chipContainer.isHoverDropTarget
                                    ? theme.primaryContainer
                                    : (modelData.is_forward
                                        ? "transparent"
                                        : ((index === breadcrumbs.count - 1 && !modelData.is_forward) ? theme.secondaryContainer : theme.hoverOverlay))
                                border.color: chipContainer.isHoverDropTarget ? theme.primary : (modelData.is_forward ? theme.outline : "transparent")
                                border.width: (chipContainer.isHoverDropTarget || modelData.is_forward) ? 1 : 0
                                opacity: (chipContainer.isHoverDropTarget || index === breadcrumbs.count - 1 || modelData.is_forward || cMouse.containsMouse) ? 1.0 : 0.0

                                Behavior on opacity { enabled: !theme.reducedMotion;
                                    NumberAnimation { duration: theme.durationFast }
                                }
                                Behavior on color { enabled: !theme.reducedMotion;
                                    ColorAnimation { duration: theme.durationFast }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                keys: ["text/uri-list"]
                                onEntered: {
                                    dragManager.hoverTarget = modelData.path;
                                }
                                onExited: {
                                    if (dragManager.hoverTarget === modelData.path) {
                                        dragManager.hoverTarget = "";
                                    }
                                }
                                onDropped: function(drop) {
                                    if (!drop.hasUrls) return;
                                    var dest = modelData.path;
                                    dragManager.hoverTarget = "";
                                    var paths = [];
                                    for (var i = 0; i < drop.urls.length; ++i) {
                                        var u = drop.urls[i].toString();
                                        if (u.startsWith("file://")) u = u.slice(7);
                                        if (u === dest) continue;
                                        paths.push(u);
                                    }
                                    if (paths.length === 0) return;
                                    var asCopy = (drop.source === dragProxy) ? dragManager.asCopy : (drop.proposedAction === Qt.CopyAction);
                                    drop.accept(asCopy ? Qt.CopyAction : Qt.MoveAction);
                                    if (dragManager.isRmb) {
                                        var pt = mapToItem(window.contentItem, cMouse.mouseX, cMouse.mouseY);
                                        rmbDropMenu.showAt(pt.x, pt.y, paths, dest);
                                    } else {
                                        window.handleDrop(paths, dest, asCopy);
                                    }
                                }
                            }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6

                                // Iconic root place icon
                                Item {
                                    width: 16
                                    height: 16
                                    visible: modelData.is_root_place

                                    SeabunnyIcon {
                                        visible: theme.usesGlyphIcons
                                        anchors.centerIn: parent
                                        name: modelData.icon || "folder"
                                        size: 15
                                        color: (index === breadcrumbs.count - 1) ? theme.secondaryContainerFg : theme.textMain
                                    }

                                    Image {
                                        visible: !theme.usesGlyphIcons
                                        anchors.centerIn: parent
                                        source: theme.resolveIcon(modelData.system_icon || "folder")
                                        width: 15
                                        height: 15
                                        sourceSize.width: 32
                                        sourceSize.height: 32
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }

                                Text {
                                    id: chipTxt
                                    text: modelData.name
                                    color: modelData.is_forward
                                        ? theme.textMuted
                                        : ((index === breadcrumbs.count - 1) ? theme.secondaryContainerFg : (cMouse.containsMouse ? theme.textMain : theme.textMuted))
                                    font.pixelSize: 12
                                    font.bold: index === breadcrumbs.count - 1 && !modelData.is_forward

                                    Behavior on color { enabled: !theme.reducedMotion;
                                        ColorAnimation { duration: theme.durationFast }
                                    }
                                }
                            }

                            scale: cMouse.pressed ? 0.94 : (cMouse.containsMouse ? 1.04 : 1.0)
                            Behavior on scale { enabled: !theme.reducedMotion; SpringAnimation { spring: 3.8; damping: 0.3 } }

                            MouseArea {
                                id: cMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.path === engine.current_path) window.startEditingPath();
                                    else engine.set_path(modelData.path);
                                }
                            }
                        }

                        SeabunnyIcon {
                            visible: index < breadcrumbs.count - 1
                            name: "caret-right"
                            size: 11
                            color: theme.outline
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // PC Breadcrumb Chip
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 6
                    visible: window.activeView === "pc"

                    Item {
                        height: 32
                        width: pcChipRow.implicitWidth + 22

                        Rectangle {
                            anchors.fill: parent
                            radius: theme.radiusFull
                            color: theme.secondaryContainer
                        }

                        RowLayout {
                            id: pcChipRow
                            anchors.centerIn: parent
                            spacing: 6

                            SeabunnyIcon {
                                visible: theme.usesGlyphIcons
                                name: "desktop"
                                size: 15
                                color: theme.secondaryContainerFg
                            }
                            Image {
                                visible: !theme.usesGlyphIcons
                                source: theme.resolveIcon("computer-symbolic")
                                width: 15
                                height: 15
                                sourceSize.width: 32
                                sourceSize.height: 32
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                text: engine.hostname || "This PC"
                                color: theme.secondaryContainerFg
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }
                }

                // Settings Path Bar Header: <Settings icon> Settings > Behavior
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 6
                    visible: window.activeView === "settings"

                    // Chip 1: <Settings icon> Settings
                    Item {
                        id: settingsRootChip
                        height: 32
                        width: settingsChipRow.implicitWidth + 22

                        Rectangle {
                            anchors.fill: parent
                            radius: theme.radiusFull
                            color: (settingsView.searchQuery.length === 0 && settingsView.activeTab === 0)
                                ? theme.secondaryContainer
                                : (settingsChipMouse.containsMouse ? theme.surfaceContainerHigh : "transparent")

                            Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }
                        }

                        RowLayout {
                            id: settingsChipRow
                            anchors.centerIn: parent
                            spacing: 6

                            SeabunnyIcon {
                                visible: theme.usesGlyphIcons
                                name: "gear"
                                size: 15
                                color: (settingsView.searchQuery.length === 0 && settingsView.activeTab === 0)
                                    ? theme.secondaryContainerFg
                                    : (settingsChipMouse.containsMouse ? theme.textMain : theme.textMuted)
                            }

                            Image {
                                visible: !theme.usesGlyphIcons
                                source: theme.resolveIcon("preferences-system-symbolic")
                                width: 14
                                height: 14
                                sourceSize.width: 28
                                sourceSize.height: 28
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: "Settings"
                                color: (settingsView.searchQuery.length === 0 && settingsView.activeTab === 0)
                                    ? theme.secondaryContainerFg
                                    : (settingsChipMouse.containsMouse ? theme.textMain : theme.textMuted)
                                font.pixelSize: 12
                                font.bold: (settingsView.searchQuery.length === 0 && settingsView.activeTab === 0)
                            }
                        }

                        scale: settingsChipMouse.pressed ? 0.94 : (settingsChipMouse.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { enabled: !theme.reducedMotion; SpringAnimation { spring: 3.8; damping: 0.3 } }

                        MouseArea {
                            id: settingsChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                settingsView.activeTab = 0;
                            }
                        }
                    }

                    // Separator Caret
                    SeabunnyIcon {
                        name: "caret-right"
                        size: 11
                        color: theme.outline
                        Layout.alignment: Qt.AlignVCenter
                        visible: settingsView.searchQuery.length > 0 || settingsView.activeTab > 0
                    }

                    // Chip 2: Active Tab or Search Query
                    Item {
                        visible: settingsView.searchQuery.length > 0 || settingsView.activeTab > 0
                        height: 32
                        width: subTabTxt.implicitWidth + 22

                        Rectangle {
                            anchors.fill: parent
                            radius: theme.radiusFull
                            color: theme.secondaryContainer
                        }

                        Text {
                            id: subTabTxt
                            anchors.centerIn: parent
                            text: settingsView.searchQuery.length > 0
                                ? ("Search: \"" + searchInput.text + "\"")
                                : (settingsView.activeTab === 0 ? "Interface" : (settingsView.activeTab === 1 ? "Behavior" : (settingsView.activeTab === 2 ? "Experimental" : "About Seabunny")))
                            color: theme.secondaryContainerFg
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Search Everywhere Breadcrumb: <Globe icon> Search Everywhere > [Query]
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 6
                    visible: engine.is_searching_everywhere

                    // Centring spacers fill the bar so the chips sit mid-bar
                    // instead of leaving a large empty gap on one side.
                    Item { Layout.fillWidth: true }

                    // Chip 1: <Globe icon> Search Everywhere (Click to exit)
                    Item {
                        height: 32
                        width: seChipRow.implicitWidth + 22

                        Rectangle {
                            anchors.fill: parent
                            radius: theme.radiusFull
                            color: (searchInput.text.trim().length === 0)
                                ? theme.secondaryContainer
                                : (seChipMouse.containsMouse ? theme.surfaceContainerHigh : "transparent")

                            Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }
                        }

                        RowLayout {
                            id: seChipRow
                            anchors.centerIn: parent
                            spacing: 6

                            SeabunnyIcon {
                                name: "globe"
                                size: 14
                                color: (searchInput.text.trim().length === 0)
                                    ? theme.secondaryContainerFg
                                    : (seChipMouse.containsMouse ? theme.textMain : theme.textMuted)
                            }

                            Text {
                                text: "Search Everywhere"
                                color: (searchInput.text.trim().length === 0)
                                    ? theme.secondaryContainerFg
                                    : (seChipMouse.containsMouse ? theme.textMain : theme.textMuted)
                                font.pixelSize: 12
                                font.bold: searchInput.text.trim().length === 0
                            }
                        }

                        scale: seChipMouse.pressed ? 0.94 : (seChipMouse.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { enabled: !theme.reducedMotion; SpringAnimation { spring: 3.8; damping: 0.3 } }

                        MouseArea {
                            id: seChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                engine.clear_search_everywhere();
                                searchInput.text = "";
                            }
                        }
                    }

                    // Separator Caret
                    SeabunnyIcon {
                        visible: searchInput.text.trim().length > 0
                        name: "caret-right"
                        size: 11
                        color: theme.outline
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Chip 2: Query Chip
                    Item {
                        visible: searchInput.text.trim().length > 0
                        height: 32
                        width: seQueryTxt.implicitWidth + 22

                        Rectangle {
                            anchors.fill: parent
                            radius: theme.radiusFull
                            color: theme.secondaryContainer
                        }

                        Text {
                            id: seQueryTxt
                            anchors.centerIn: parent
                            text: "\"" + searchInput.text.trim() + "\""
                            color: theme.secondaryContainerFg
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            // Expanding Search Bar (Smoothly expands to the left when focused)
            Rectangle {
                id: searchBarRect
                visible: window.activeView !== "pc"
                Layout.preferredHeight: 42
                radius: theme.radiusFull
                color: searchInput.activeFocus ? theme.surfaceContainerHighest : theme.surfaceContainer
                border.width: searchInput.activeFocus ? 1.5 : 0
                border.color: theme.primary

                Behavior on border.width { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.durationFast } }

                property real barWidth: engine.is_searching_everywhere
                    ? (window.width < 900 ? 240 : 320)
                    : (searchInput.activeFocus ? (window.width < 900 ? 260 : 460) : 260)
                Layout.preferredWidth: barWidth
                Layout.minimumWidth: 120

                Behavior on barWidth { enabled: !theme.reducedMotion;
                    SpringAnimation { spring: 3.8; damping: 0.32 }
                }

                Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 10
                    spacing: 10

                    Item {
                        width: 16
                        height: 16
                        SeabunnyIcon {
                            visible: theme.usesGlyphIcons
                            anchors.centerIn: parent
                            name: "magnifying-glass"
                            size: 16
                            color: searchInput.activeFocus ? theme.primary : theme.outline
                        }
                        Image {
                            visible: !theme.usesGlyphIcons
                            anchors.centerIn: parent
                            source: theme.resolveIcon("system-search")
                            width: 16
                            height: 16
                            sourceSize.width: 32
                            sourceSize.height: 32
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    TextInput {
                        id: searchInput
                        onActiveFocusChanged: if (!activeFocus) deselect()
                        Layout.fillWidth: true
                        color: theme.textMain
                        font.pixelSize: 13
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        Text {
                            text: window.activeView === "settings"
                                ? "Search settings..."
                                : (engine.is_searching_everywhere ? "Search across entire filesystem..." : "Search files...")
                            color: theme.outline
                            font.pixelSize: 13
                            visible: !searchInput.text && !searchInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: {
                            if (window.switchingTab) return;
                            window.cancelTabRestore();
                            if (window.activeView === "pc") {
                                // Typing search from PC pulls back to the file grid
                                window.showFiles();
                            }
                            if (window.activeView === "files") {
                                if (engine.is_searching_everywhere) {
                                    engine.search_everywhere(searchInput.text);
                                }
                                if (searchInput.text.trim().length > 0) {
                                    filesGridView.selectItem(0, false, false);
                                }
                            }
                        }

                        Keys.onEscapePressed: function(event) {
                            if (searchInput.text.length > 0) {
                                searchInput.text = "";
                                event.accepted = true;
                            } else if (window.isAuxView) {
                                window.showFiles();
                                event.accepted = true;
                            }
                        }

                        Keys.onDownPressed: function(event) {
                            if (window.activeView === "files") {
                                gridContainer.moveSelection(0, 1, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                        }

                        Keys.onUpPressed: function(event) {
                            if (window.activeView === "files") {
                                gridContainer.moveSelection(0, -1, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                        }

                        Keys.onLeftPressed: function(event) {
                            if (window.activeView === "files" && engine.view_mode === "grid") {
                                gridContainer.moveSelection(-1, 0, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                        }

                        Keys.onRightPressed: function(event) {
                            if (window.activeView === "files" && engine.view_mode === "grid") {
                                gridContainer.moveSelection(1, 0, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                        }

                        Keys.onReturnPressed: function(event) {
                            if (window.activeView === "files") {
                                gridContainer.openSelected();
                                event.accepted = true;
                            }
                        }

                        Keys.onEnterPressed: function(event) {
                            if (window.activeView === "files") {
                                gridContainer.openSelected();
                                event.accepted = true;
                            }
                        }
                    }

                    // "Search everywhere" Pop-up Pill Button (Visible when focused)
                    Rectangle {
                        id: everywhereBtn
                        visible: (window.activeView === "files") && (searchInput.activeFocus || engine.is_searching_everywhere) && !engine.is_searching_everywhere
                        height: 30
                        width: everywhereRow.implicitWidth + 18
                        radius: theme.radiusFull
                        color: everywhereMouse.containsMouse ? theme.primary : theme.surfaceContainerLow

                        Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }

                        RowLayout {
                            id: everywhereRow
                            anchors.centerIn: parent
                            spacing: 6

                            SeabunnyIcon {
                                name: "globe"
                                size: 13
                                color: everywhereMouse.containsMouse ? theme.primaryFg : theme.textMain
                            }

                            Text {
                                text: "Search everywhere"
                                color: everywhereMouse.containsMouse ? theme.primaryFg : theme.textMain
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: everywhereMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                engine.search_everywhere(searchInput.text || "a");
                            }
                        }
                    }

                    // Exit Search Everywhere Button (When search everywhere is active)
                    Rectangle {
                        visible: engine.is_searching_everywhere
                        height: 30
                        width: closeSearchTxt.implicitWidth + 18
                        radius: theme.radiusFull
                        color: closeSearchMouse.containsMouse ? theme.surfaceContainerHighest : theme.surfaceContainerLow

                        Text {
                            id: closeSearchTxt
                            anchors.centerIn: parent
                            text: "Back to Files"
                            color: theme.textMain
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            id: closeSearchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                engine.clear_search_everywhere();
                                searchInput.text = "";
                            }
                        }
                    }
                }
            }

            // Unified View & Sort Options Button
            Rectangle {
                id: viewDropdownBtn
                visible: window.activeView === "files" && !engine.is_searching_everywhere
                Layout.preferredHeight: 42
                Layout.preferredWidth: viewDropdownRow.implicitWidth + (window.width < 900 ? 16 : 24)
                radius: theme.radiusFull
                color: viewDropdownMouse.containsMouse ? theme.surfaceContainerHighest : theme.surfaceContainer
                Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }
                scale: viewDropdownMouse.pressed ? 0.95 : 1.0
                Behavior on scale { enabled: !theme.reducedMotion; SpringAnimation { spring: 4.0; damping: 0.3 } }

                RowLayout {
                    id: viewDropdownRow
                    anchors.centerIn: parent
                    spacing: 7

                    SeabunnyIcon {
                        name: engine.view_mode === "list" ? "list" : "squares-four"
                        size: 16
                        color: theme.primary
                    }

                    Text {
                        visible: window.width >= 900
                        text: "View"
                        color: theme.textMain
                        font.pixelSize: 12
                        font.bold: true
                    }

                    SeabunnyIcon {
                        name: "caret-down"
                        size: 11
                        color: theme.outline
                    }
                }

                MouseArea {
                    id: viewDropdownMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var pt = mapToItem(window.contentItem, 0, height + 6);
                        viewMenuPopup.openAt(pt.x, pt.y);
                    }
                }
            }

            // Empty Trash: shown only while browsing the trash root.
            SeabunnyButton {
                id: emptyTrashBtn
                visible: window.activeView === "files"
                    && engine.trash_root.length > 0
                    && engine.current_path === engine.trash_root
                text: window.width < 900 ? "" : "Empty Trash"
                icon: "trash"
                variant: "danger"
                onClicked: engine.empty_trash()
            }
        }

        RowLayout {
            visible: folderTabs.entries.length >= 2
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            spacing: 6

            ListView {
                id: tabBar
                objectName: "folderTabBar"
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                orientation: ListView.Horizontal
                spacing: 6
                clip: true
                model: folderTabs.entries
                currentIndex: folderTabs.currentIndex
                highlightMoveDuration: 0
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: tabCard
                    required property var modelData
                    required property int index
                    width: Math.max(120, Math.min(210, tabBar.width / Math.min(4, tabBar.count) - 6))
                    height: 38
                    radius: theme.radiusFull
                    color: index === folderTabs.currentIndex ? theme.primaryContainer : theme.surfaceContainer
                    border.width: tabMouse.containsMouse ? 1 : 0
                    border.color: theme.outline
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 6
                        spacing: 6
                        SeabunnyIcon { name: "folder"; size: 16; color: index === folderTabs.currentIndex ? theme.primaryContainerFg : theme.textMuted }
                        Text {
                            Layout.fillWidth: true
                            text: tabCard.modelData.engine.current_dir_name || "/"
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: tabCard.index === folderTabs.currentIndex ? theme.primaryContainerFg : theme.textMain
                        }
                        Item { Layout.preferredWidth: 26; Layout.preferredHeight: 26 }
                    }
                    MouseArea {
                        id: tabMouse
                        objectName: "folderTabDrag"
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        property real pressX: 0
                        property bool reordered: false
                        onPressed: function(mouse) { reordered = false; pressX = mapToItem(tabBar, mouse.x, mouse.y).x; }
                        onClicked: function(mouse) {
                            if (reordered) return;
                            if (mouse.button === Qt.MiddleButton) folderTabs.close(tabCard.index);
                            else folderTabs.activate(tabCard.index);
                        }
                        onReleased: function(mouse) {
                            if (mouse.button !== Qt.LeftButton) return;
                            var delta = mapToItem(tabBar, mouse.x, mouse.y).x - pressX;
                            if (Math.abs(delta) > tabCard.width / 2) {
                                reordered = true;
                                folderTabs.move(tabCard.index, Math.max(0, Math.min(folderTabs.entries.length - 1, tabCard.index + Math.round(delta / (tabCard.width + tabBar.spacing)))));
                            }
                        }
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 600
                        ToolTip.text: tabCard.modelData.engine.current_path
                    }
                    MouseArea {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: folderTabs.close(tabCard.index)
                        SeabunnyIcon { anchors.centerIn: parent; name: "x"; size: 13; color: theme.textMuted }
                    }
                }
            }
            SeabunnyButton {
                text: ""
                icon: "plus"
                enabled: folderTabs.entries.length < folderTabs.limit
                onClicked: window.openFolderTab(engine.current_path, false)
            }
        }

        // ==========================================
        // MAIN BODY (Expandable Rail + Stage)
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.bottomMargin: 20
            spacing: 16

            // Expandable Navigation Rail
            Rectangle {
                id: navRailRect
                Layout.fillHeight: true
                property real railWidth: window.sidebarExpanded ? Math.min(window.expandedSidebarWidth, window.maximumSidebarWidth) : 68
                Layout.preferredWidth: railWidth
                radius: theme.radiusXl
                color: theme.surfaceContainer
                clip: true

                Behavior on railWidth {
                    enabled: !window.resizingSidebar && !theme.reducedMotion
                    NumberAnimation {
                        duration: theme.motionDuration(230)
                        easing.type: Easing.OutCubic
                    }
                }

                // Sliding Active Pill Indicator (glides between Places and Settings)
                Rectangle {
                    id: navIndicator
                    height: 44
                    radius: 22
                    x: 12
                    width: window.sidebarExpanded ? (navRailRect.width - 24) : 44
                    color: theme.primaryContainer
                    opacity: window.activeView !== "settings" && (window.currentNavIndex < 0
                        || window.currentNavIndex * 52 < navRailArea.contentY
                        || window.currentNavIndex * 52 + 44 > navRailArea.contentY + navRailArea.height)
                        ? 0 : (engine.is_searching_everywhere ? 0.35 : 1.0)
                    Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.durationFast } }
                    z: 0

                    y: {
                        if (window.activeView === "settings") {
                            return navRailCol.y + settingsBtnItem.y;
                        } else {
                            return navRailCol.y + navRailArea.y + window.currentNavIndex * 52 - navRailArea.contentY;
                        }
                    }

                    Behavior on y { enabled: !theme.reducedMotion;
                        SpringAnimation {
                            spring: 3.5
                            damping: 0.35
                            epsilon: 0.25
                        }
                    }
                    Behavior on width { enabled: !theme.reducedMotion;
                        SpringAnimation {
                            spring: 3.5
                            damping: 0.35
                        }
                    }
                    Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationNormal } }

                    ParallelAnimation {
                        id: indicatorExpandAnim
                        SequentialAnimation {
                            PauseAnimation { duration: theme.motionDuration(60 + window.currentNavIndex * 40)}
                            NumberAnimation {
                                target: navIndicator
                                property: "width"
                                from: 44
                                to: navRailRect.width - 24
                                duration: theme.motionDuration(210)
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.25
                            }
                        }
                    }

                    ParallelAnimation {
                        id: indicatorCollapseAnim
                        SequentialAnimation {
                            PauseAnimation { duration: theme.motionDuration(Math.max(0, (navRepeater.count - 1 - window.currentNavIndex)) * 22)}
                            NumberAnimation {
                                target: navIndicator
                                property: "width"
                                from: navIndicator.width
                                to: 44
                                duration: theme.motionDuration(130)
                                easing.type: Easing.InCubic
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: navRailCol
                    anchors.fill: parent
                    anchors.topMargin: 14
                    anchors.bottomMargin: 14
                    spacing: 8
                    z: 1

                    // Sidebar Expand Toggle Button
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44

                        Rectangle {
                            width: 44
                            height: 44
                            radius: 22
                            x: 12
                            color: toggleMouse.containsMouse ? theme.surfaceContainerHigh : "transparent"

                            Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }

                            SeabunnyIcon {
                                anchors.centerIn: parent
                                name: window.sidebarExpanded ? "sidebar" : "sidebar-simple"
                                size: 20
                                color: theme.textMain
                            }

                            MouseArea {
                                id: toggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    window.sidebarExpanded = !window.sidebarExpanded;
                                    if (window.sidebarExpanded) {
                                        indicatorCollapseAnim.stop();
                                        indicatorExpandAnim.restart();
                                        for (var i = 0; i < navRepeater.count; i++) {
                                            var it = navRepeater.itemAt(i);
                                            if (it && typeof it.playExpand === "function") {
                                                it.playExpand(i);
                                            }
                                        }
                                        if (settingsBtnItem && typeof settingsBtnItem.playExpand === "function") {
                                            settingsBtnItem.playExpand(navRepeater.count);
                                        }
                                    } else {
                                        indicatorExpandAnim.stop();
                                        indicatorCollapseAnim.restart();
                                        if (settingsBtnItem && typeof settingsBtnItem.playCollapse === "function") {
                                            settingsBtnItem.playCollapse(0);
                                        }
                                        for (var j = 0; j < navRepeater.count; j++) {
                                            var btn = navRepeater.itemAt(j);
                                            if (btn && typeof btn.playCollapse === "function") {
                                                var revIdx = (navRepeater.count - j);
                                                btn.playCollapse(revIdx);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Places Navigation List
                    Flickable {
                        id: navRailArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: navColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        property real dragY: -1
                        function trackDrag(drag, item) { dragY = item.mapToItem(navRailArea, drag.x, drag.y).y; }

                        Timer {
                            interval: 30
                            running: navRailArea.dragY >= 0
                            repeat: true
                            onTriggered: {
                                var delta = navRailArea.dragY < 28 ? -12 : navRailArea.dragY > navRailArea.height - 28 ? 12 : 0;
                                navRailArea.contentY = Math.max(0, Math.min(Math.max(0, navRailArea.contentHeight - navRailArea.height), navRailArea.contentY + delta));
                            }
                        }

                        DropArea {
                            id: sidebarBackgroundDrop
                            parent: navRailArea
                            anchors.fill: parent
                            z: -1
                            onEntered: function(drag) {
                                drag.accepted = drag.source === sidebarDragProxy || drag.source === dragProxy || drag.hasUrls;
                                if (drag.accepted) navRailArea.trackDrag(drag, sidebarBackgroundDrop);
                            }
                            onPositionChanged: function(drag) { navRailArea.trackDrag(drag, sidebarBackgroundDrop); }
                            onExited: { navRailArea.dragY = -1; }
                            onDropped: function(drop) {
                                navRailArea.dragY = -1;
                                window.dropOnSidebar(drop, null, "after");
                            }
                        }

                        Column {
                            id: navColumn
                            width: navRailArea.width
                            spacing: 8

                            Repeater {
                                id: navRepeater
                                model: Sidebar.arrange([
                                    { name: engine.hostname || "PC", iconName: engine.device_type === "laptop" ? "laptop" : "desktop", systemIcon: "computer-symbolic", view: "pc" },
                                    { name: "Home", iconName: "house", systemIcon: "user-home-symbolic", pathSuffix: "", view: "files" },
                                    { name: "Documents", iconName: "file-text", systemIcon: "x-office-document-symbolic", pathSuffix: "Documents", view: "files" },
                                    { name: "Downloads", iconName: "download", systemIcon: "folder-download-symbolic", pathSuffix: "Downloads", view: "files" },
                                    { name: "Pictures", iconName: "image", systemIcon: "image-x-generic-symbolic", pathSuffix: "Pictures", view: "files" },
                                    { name: "Music", iconName: "music", systemIcon: "audio-x-generic-symbolic", pathSuffix: "Music", view: "files" },
                                    { name: "Videos", iconName: "video", systemIcon: "video-x-generic-symbolic", pathSuffix: "Videos", view: "files" },
                                    { name: "Projects", iconName: "code", systemIcon: "utilities-terminal-symbolic", pathSuffix: "Projects", view: "files" },
                                    { name: "Trash", iconName: "trash", systemIcon: "user-trash-symbolic", view: "files", trashRoot: true }
                                ], window.favoriteItems, window.sidebarLayout).filter(function(item) { return !window.chooserMode || (item.view !== "pc" && !item.trashRoot); })

                                delegate: Item {
                                    id: navBtn
                                    width: navRailArea.width
                                    height: 44

                                    readonly property bool isSelected: window.activeView === modelData.view && window.currentNavIndex === index
                                    readonly property bool isHovered: btnMouse.containsMouse

                                    DropArea {
                                        id: sidebarRowDrop
                                        anchors.fill: parent
                                        property string edge: ""
                                        function updatePosition(drag) {
                                            navRailArea.trackDrag(drag, sidebarRowDrop);
                                            edge = drag.y < 12 ? "before" : drag.y > height - 12 ? "after" : "";
                                            if (drag.source === sidebarDragProxy) edge = drag.y < height / 2 ? "before" : "after";
                                            dragManager.hoverTarget = edge ? "" : window.sidebarPath(modelData);
                                        }
                                        onEntered: function(drag) {
                                            drag.accepted = drag.source === sidebarDragProxy || drag.source === dragProxy || drag.hasUrls;
                                            if (drag.accepted) updatePosition(drag);
                                        }
                                        onPositionChanged: function(drag) { updatePosition(drag); }
                                        onExited: { dragManager.hoverTarget = ""; navRailArea.dragY = -1; }
                                        onDropped: function(drop) {
                                            navRailArea.dragY = -1;
                                            window.dropOnSidebar(drop, modelData, edge);
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        radius: 16
                                        color: theme.primaryContainer
                                        opacity: 0.65
                                        visible: sidebarRowDrop.containsDrag && !sidebarRowDrop.edge
                                    }
                                    Rectangle {
                                        x: 8
                                        y: sidebarRowDrop.edge === "after" ? parent.height - 2 : 0
                                        width: parent.width - 16
                                        height: 3
                                        radius: 1.5
                                        color: theme.primary
                                        visible: sidebarRowDrop.containsDrag && sidebarRowDrop.edge.length > 0
                                    }

                                    Rectangle {
                                        width: window.sidebarExpanded ? (parent.width - 24) : 44
                                        height: 44
                                        radius: 22
                                        x: 12
                                        color: theme.hoverOverlay
                                        opacity: (!navBtn.isSelected && navBtn.isHovered) ? 1.0 : 0.0

                                        Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.durationFast } }
                                        Behavior on width { enabled: !theme.reducedMotion; SpringAnimation { spring: 3.5; damping: 0.35 } }
                                    }

                                    Item {
                                        id: iconBox
                                        width: 44
                                        height: 44
                                        x: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        transformOrigin: Item.Center

                                        NumberAnimation {
                                            id: iconBounceAnim
                                            target: iconBox
                                            property: "scale"
                                            from: 1.0
                                            to: 1.25
                                            duration: theme.motionDuration(120)
                                            easing.type: Easing.OutBack
                                            onFinished: iconSettleAnim.start()
                                        }
                                        NumberAnimation {
                                            id: iconSettleAnim
                                            target: iconBox
                                            property: "scale"
                                            from: 1.25
                                            to: 1.0
                                            duration: theme.motionDuration(120)
                                            easing.type: Easing.OutCubic
                                        }

                                        SeabunnyIcon {
                                            visible: theme.usesGlyphIcons || !!modelData.customIcon
                                            anchors.centerIn: parent
                                            name: modelData.iconName
                                            size: 20
                                            color: navBtn.isSelected ? theme.primaryContainerFg : (navBtn.isHovered ? theme.textMain : theme.textMuted)

                                            Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }
                                        }

                                        Image {
                                            visible: !theme.usesGlyphIcons && !modelData.customIcon
                                            anchors.centerIn: parent
                                            source: theme.resolveIcon(modelData.systemIcon)
                                            width: 20
                                            height: 20
                                            sourceSize.width: 40
                                            sourceSize.height: 40
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                    Item {
                                        id: labelContainer
                                        anchors.left: iconBox.right
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24

                                        clip: true
                                        opacity: window.sidebarExpanded ? 1.0 : 0.0
                                        scale: window.sidebarExpanded ? 1.0 : 0.3
                                        transformOrigin: Item.Left

                                        transform: Translate {
                                            id: labelTranslate
                                            x: window.sidebarExpanded ? 0 : -16
                                        }

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: modelData.name
                                            color: navBtn.isSelected ? theme.primaryContainerFg : (navBtn.isHovered ? theme.textMain : theme.textMuted)
                                            font.pixelSize: 13
                                            font.bold: navBtn.isSelected
                                            elide: Text.ElideRight

                                            Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }
                                        }
                                    }

                                    ParallelAnimation {
                                        id: labelExpandAnim
                                        property int delayMs: 0

                                        SequentialAnimation {
                                            PauseAnimation { duration: theme.motionDuration(labelExpandAnim.delayMs)}
                                            ParallelAnimation {
                                                ScriptAction { script: iconBounceAnim.restart() }
                                                NumberAnimation {
                                                    target: labelContainer
                                                    property: "opacity"
                                                    from: 0.0
                                                    to: 1.0
                                                    duration: theme.motionDuration(180)
                                                    easing.type: Easing.OutCubic
                                                }
                                                NumberAnimation {
                                                    target: labelContainer
                                                    property: "scale"
                                                    from: 0.3
                                                    to: 1.0
                                                    duration: theme.motionDuration(230)
                                                    easing.type: Easing.OutBack
                                                    easing.overshoot: 1.5
                                                }
                                                NumberAnimation {
                                                    target: labelTranslate
                                                    property: "x"
                                                    from: -16
                                                    to: 0
                                                    duration: theme.motionDuration(210)
                                                    easing.type: Easing.OutBack
                                                    easing.overshoot: 1.2
                                                }
                                            }
                                        }
                                    }

                                    ParallelAnimation {
                                        id: labelCollapseAnim
                                        property int delayMs: 0

                                        SequentialAnimation {
                                            PauseAnimation { duration: theme.motionDuration(labelCollapseAnim.delayMs)}
                                            ParallelAnimation {
                                                NumberAnimation {
                                                    target: labelContainer
                                                    property: "opacity"
                                                    from: labelContainer.opacity
                                                    to: 0.0
                                                    duration: theme.motionDuration(110)
                                                    easing.type: Easing.InCubic
                                                }
                                                NumberAnimation {
                                                    target: labelContainer
                                                    property: "scale"
                                                    from: labelContainer.scale
                                                    to: 0.3
                                                    duration: theme.motionDuration(130)
                                                    easing.type: Easing.InBack
                                                    easing.overshoot: 1.2
                                                }
                                                NumberAnimation {
                                                    target: labelTranslate
                                                    property: "x"
                                                    from: labelTranslate.x
                                                    to: -16
                                                    duration: theme.motionDuration(130)
                                                    easing.type: Easing.InCubic
                                                }
                                            }
                                        }
                                    }

                                    function playExpand(idx) {
                                        labelCollapseAnim.stop();
                                        labelExpandAnim.stop();
                                        labelContainer.opacity = 0.0;
                                        labelContainer.scale = 0.3;
                                        labelTranslate.x = -16;
                                        labelExpandAnim.delayMs = 60 + idx * 35;
                                        labelExpandAnim.start();
                                    }

                                    function playCollapse(reverseIdx) {
                                        labelExpandAnim.stop();
                                        labelCollapseAnim.stop();
                                        labelCollapseAnim.delayMs = reverseIdx * 20;
                                        labelCollapseAnim.start();
                                    }

                                    MouseArea {
                                        id: btnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        preventStealing: true
                                        drag.target: sidebarDragProxy
                                        drag.smoothed: false
                                        property bool dragged: false
                                        ToolTip.visible: containsMouse
                                        ToolTip.text: (modelData.path || modelData.name) + "\nDrag to reorder; drop on center to move, edges to pin"
                                        onPressed: function(mouse) {
                                            dragged = false;
                                            if (mouse.button !== Qt.LeftButton) return;
                                            sidebarDragProxy.sidebarId = modelData.id;
                                            sidebarDragProxy.label = modelData.name;
                                            var position = mapToItem(window.contentItem, mouse.x, mouse.y);
                                            sidebarDragProxy.x = position.x - 16;
                                            sidebarDragProxy.y = position.y - 16;
                                        }
                                        drag.onActiveChanged: { if (drag.active && (pressedButtons & Qt.LeftButton)) sidebarDragProxy.Drag.active = true; }
                                        onPositionChanged: function(mouse) {
                                            if (drag.active && (pressedButtons & Qt.LeftButton)) {
                                                dragged = true;
                                                var position = mapToItem(window.contentItem, mouse.x, mouse.y);
                                                sidebarDragProxy.x = position.x - 16;
                                                sidebarDragProxy.y = position.y - 16;
                                                sidebarDragProxy.Drag.active = true;
                                            }
                                        }
                                        onReleased: {
                                            if (sidebarDragProxy.Drag.active) sidebarDragProxy.Drag.drop();
                                            sidebarDragProxy.Drag.active = false;
                                        }
                                        onCanceled: { sidebarDragProxy.Drag.cancel(); }
                                        onClicked: function(mouse) {
                                            if (dragged) return;
                                            if (mouse.button === Qt.RightButton) {
                                                favoriteMenu.showFor(modelData, navBtn);
                                                return;
                                            }
                                            engine.clear_search_everywhere();
                                            window.currentNavIndex = index;
                                            if (modelData.view === "pc") {
                                                window.activeView = "pc";
                                                engine.load_drives();
                                                engine.refresh_frequent_dirs();
                                            } else if (modelData.trashRoot) {
                                                window.currentPlaceIndex = index;
                                                window.activeView = "files";
                                                engine.set_path(engine.trash_root);
                                            } else {
                                                window.currentPlaceIndex = index;
                                                window.activeView = "files";
                                                engine.set_path(modelData.path || engine.place_path(modelData.pathSuffix || ""));
                                                window.syncPlaces();
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                width: navRailArea.width
                                height: 8
                                objectName: "sidebarPinTarget"
                                DropArea {
                                    id: sidebarPinDrop
                                    anchors.fill: parent
                                    onEntered: function(drag) {
                                        drag.accepted = drag.source === sidebarDragProxy || drag.source === dragProxy || drag.hasUrls;
                                        if (drag.accepted) navRailArea.trackDrag(drag, sidebarPinDrop);
                                    }
                                    onPositionChanged: function(drag) { navRailArea.trackDrag(drag, sidebarPinDrop); }
                                    onExited: { navRailArea.dragY = -1; }
                                    onDropped: function(drop) {
                                        navRailArea.dragY = -1;
                                        window.dropOnSidebar(drop, null, "after");
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.RightButton
                                    onClicked: { favoriteMenu.showRestore(parent); }
                                    ToolTip.visible: containsMouse
                                    hoverEnabled: true
                                    ToolTip.text: "Drop folders here to pin. Right-click to restore hidden places."
                                }
                            }
                        }
                    }

                    // Settings Button
                    Item {
                        id: settingsBtnItem
                        visible: !window.chooserMode
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44

                        readonly property bool isSettingsActive: window.activeView === "settings"

                        Rectangle {
                            width: window.sidebarExpanded ? (parent.width - 24) : 44
                            height: 44
                            radius: 22
                            x: 12
                            color: theme.hoverOverlay
                            opacity: settingsMouse.containsMouse ? 1.0 : 0.0

                            Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.durationFast } }
                            Behavior on width { enabled: !theme.reducedMotion; SpringAnimation { spring: 3.5; damping: 0.35 } }
                        }

                        Item {
                            id: settingsIconBox
                            width: 44
                            height: 44
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            transformOrigin: Item.Center

                            NumberAnimation {
                                id: settingsBounceAnim
                                target: settingsIconBox
                                property: "scale"
                                from: 1.0
                                to: 1.25
                                duration: theme.motionDuration(120)
                                easing.type: Easing.OutBack
                                onFinished: settingsSettleAnim.start()
                            }
                            NumberAnimation {
                                id: settingsSettleAnim
                                target: settingsIconBox
                                property: "scale"
                                from: 1.25
                                to: 1.0
                                duration: theme.motionDuration(120)
                                easing.type: Easing.OutCubic
                            }

                            SeabunnyIcon {
                                visible: theme.usesGlyphIcons
                                anchors.centerIn: parent
                                name: "gear"
                                size: 20
                                color: settingsBtnItem.isSettingsActive ? theme.primaryContainerFg : (settingsMouse.containsMouse ? theme.textMain : theme.textMuted)

                                Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }
                            }

                            Image {
                                visible: !theme.usesGlyphIcons
                                anchors.centerIn: parent
                                source: theme.resolveIcon("preferences-system-symbolic")
                                width: 20
                                height: 20
                                sourceSize.width: 40
                                sourceSize.height: 40
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        Item {
                            id: settingsLabelContainer
                            anchors.left: settingsIconBox.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            height: 24

                            clip: true
                            opacity: window.sidebarExpanded ? 1.0 : 0.0
                            scale: window.sidebarExpanded ? 1.0 : 0.3
                            transformOrigin: Item.Left

                            transform: Translate {
                                id: settingsLabelTranslate
                                x: window.sidebarExpanded ? 0 : -16
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Settings"
                                color: settingsBtnItem.isSettingsActive ? theme.primaryContainerFg : (settingsMouse.containsMouse ? theme.textMain : theme.textMuted)
                                font.pixelSize: 13
                                font.bold: settingsBtnItem.isSettingsActive
                                elide: Text.ElideRight

                                Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }
                            }
                        }

                        ParallelAnimation {
                            id: settingsExpandAnim
                            property int delayMs: 0

                            SequentialAnimation {
                                PauseAnimation { duration: theme.motionDuration(settingsExpandAnim.delayMs)}
                                ParallelAnimation {
                                    ScriptAction { script: settingsBounceAnim.restart() }
                                    NumberAnimation {
                                        target: settingsLabelContainer
                                        property: "opacity"
                                        from: 0.0
                                        to: 1.0
                                        duration: theme.motionDuration(180)
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        target: settingsLabelContainer
                                        property: "scale"
                                        from: 0.3
                                        to: 1.0
                                        duration: theme.motionDuration(230)
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.5
                                    }
                                    NumberAnimation {
                                        target: settingsLabelTranslate
                                        property: "x"
                                        from: -16
                                        to: 0
                                        duration: theme.motionDuration(210)
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.2
                                    }
                                }
                            }
                        }

                        ParallelAnimation {
                            id: settingsCollapseAnim
                            property int delayMs: 0

                            SequentialAnimation {
                                PauseAnimation { duration: theme.motionDuration(settingsCollapseAnim.delayMs)}
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: settingsLabelContainer
                                        property: "opacity"
                                        from: settingsLabelContainer.opacity
                                        to: 0.0
                                        duration: theme.motionDuration(110)
                                        easing.type: Easing.InCubic
                                    }
                                    NumberAnimation {
                                        target: settingsLabelContainer
                                        property: "scale"
                                        from: settingsLabelContainer.scale
                                        to: 0.3
                                        duration: theme.motionDuration(130)
                                        easing.type: Easing.InBack
                                        easing.overshoot: 1.2
                                    }
                                    NumberAnimation {
                                        target: settingsLabelTranslate
                                        property: "x"
                                        from: settingsLabelTranslate.x
                                        to: -16
                                        duration: theme.motionDuration(130)
                                        easing.type: Easing.InCubic
                                    }
                                }
                            }
                        }

                        function playExpand(idx) {
                            settingsCollapseAnim.stop();
                            settingsExpandAnim.stop();
                            settingsLabelContainer.opacity = 0.0;
                            settingsLabelContainer.scale = 0.3;
                            settingsLabelTranslate.x = -16;
                            settingsExpandAnim.delayMs = 60 + idx * 35;
                            settingsExpandAnim.start();
                        }

                        function playCollapse(reverseIdx) {
                            settingsExpandAnim.stop();
                            settingsCollapseAnim.stop();
                            settingsCollapseAnim.delayMs = reverseIdx * 20;
                            settingsCollapseAnim.start();
                        }

                        MouseArea {
                            id: settingsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                engine.clear_search_everywhere();
                                if (window.activeView === "settings") {
                                    window.showFiles();
                                } else {
                                    if (!window.chooserMode) window.activeView = "settings";
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // MAIN CONTENT STAGE
            // ==========================================
            Rectangle {
                id: mainStage
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: theme.radiusXl
                color: theme.surfaceContainerLow
                clip: true
                // Visible focus ring while the grid/list is driven by the keyboard.
                border.width: window.keyboardNavActive ? 2 : 0
                border.color: theme.primary
                Behavior on border.width { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.motionDuration(140); easing.type: Easing.OutCubic } }

                // Shared content wrapper for dir/settings transition animation
                Item {
                    id: mainStageContent
                    anchors.fill: parent

                    transform: [
                        Translate {
                            id: stageTranslate
                            y: 0
                        },
                        Scale {
                            id: stageScale
                            origin.x: mainStageContent.width / 2
                            origin.y: 0
                            xScale: 1.0
                            yScale: 1.0
                        }
                    ]

                // VIEW 1: FILES BROWSER
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 14
                    visible: window.activeView === "files"

                    // Directory Hero Header & Item/Selection Count
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            id: dirHeroTitle
                            text: engine.is_searching_everywhere ? "Searching Everywhere" : engine.current_dir_name
                            color: theme.textMain
                            font.pixelSize: 26
                            font.bold: true
                            font.letterSpacing: -0.5
                            elide: Text.ElideRight
                            Layout.maximumWidth: Math.max(120, mainStage.width - 220)

                            transform: Translate { id: dirHeroTrans; x: 0 }

                            onTextChanged: dirHeroAnim.restart()

                            SequentialAnimation {
                                id: dirHeroAnim
                                ParallelAnimation {
                                    NumberAnimation { target: dirHeroTitle; property: "opacity"; from: 0.2; to: 1.0; duration: theme.motionDuration(160); easing.type: Easing.OutCubic }
                                    NumberAnimation { target: dirHeroTrans; property: "x"; from: -8; to: 0; duration: theme.motionDuration(180); easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Selection Count Badge
                        Rectangle {
                            visible: filesGridView.selectedCount > 0
                            height: 28
                            width: selLabel.implicitWidth + 20
                            radius: theme.radiusFull
                            color: theme.primaryContainer

                            Text {
                                id: selLabel
                                anchors.centerIn: parent
                                text: filesGridView.selectedCount + " selected"
                                color: theme.primaryContainerFg
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        SeabunnyButton {
                            objectName: "archiveExtractButton"
                            visible: engine.archive_path.length > 0
                            text: engine.archive_busy ? "Extracting…" : "Extract"
                            icon: "archive"
                            enabled: !engine.archive_busy && !engine.is_loading
                            onClicked: window.extractArchiveSelection()
                        }

                        // Total Items Badge
                        Rectangle {
                            height: 28
                            width: countLabel.implicitWidth + 18
                            radius: theme.radiusFull
                            color: theme.surfaceContainerHigh

                            Text {
                                id: countLabel
                                anchors.centerIn: parent
                                text: {
                                    var count = gridContainer.allTargetItems ? gridContainer.allTargetItems.length : 0;
                                    if (engine.is_searching_everywhere) {
                                        return count + " results";
                                    }
                                    return count + " items";
                                }
                                color: theme.textMuted
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: engine.navigation_error.length > 0 || engine.is_loading || engine.archive_status.length > 0
                        text: engine.navigation_error || (engine.is_loading ? "Loading folder…" : engine.archive_status)
                        color: engine.navigation_error ? theme.danger : theme.textMuted
                        wrapMode: Text.Wrap
                    }

                    // File Grid Stage
                    Item {
                        id: gridContainer
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        property var selectedIndices: ({})
                        property int selectedCount: Object.keys(selectedIndices).length
                        property int lastSelectedIndex: -1
                        property int anchorIndex: -1

                        property var allTargetItems: []
                        property var displayedItems: []
                        property int loadedCount: 0

                        readonly property var rawItems: JSON.parse(engine.files_json || "[]")
                        readonly property var searchItems: JSON.parse(engine.search_everywhere_json || "[]")

                        function reloadItems() {
                            var full = engine.is_searching_everywhere ? searchItems : rawItems;
                            var query = searchInput.text.toLowerCase().trim();
                            if (!engine.is_searching_everywhere && query.length > 0)
                                full = full.filter(item => item.name.toLowerCase().indexOf(query) !== -1);
                            if (window.chooserMode) full = full.filter(function(item) {
                                return chooser.matches(item.path || engine.current_path + "/" + item.name, window.chooserFilter);
                            });
                            allTargetItems = full;
                            displayedItems = full;
                            loadedCount = full.length;
                        }

                        function refreshItems() {
                            if (!window.pendingTabState && !window.switchingTab) window.pendingTabState = window.captureTabState();
                            reloadItems();
                            window.restoreTabState();
                        }

                        Timer {
                            id: filterTimer
                            interval: 80
                            onTriggered: gridContainer.reloadItems()
                        }

                        Connections {
                            target: engine
                            function onFiles_jsonChanged() { gridContainer.refreshItems(); }
                            function onSearch_everywhere_jsonChanged() { gridContainer.refreshItems(); }
                            function onIs_loadingChanged() { window.restoreTabState(); }
                            function onIs_searching_everywhereChanged() { gridContainer.clearSelection(); gridContainer.reloadItems(); }
                        }

                        Connections {
                            target: searchInput
                            function onTextChanged() { if (!window.switchingTab) { gridContainer.clearSelection(); filterTimer.restart(); } }
                        }

                        Component.onCompleted: gridContainer.reloadItems()

                        function getFilteredItems() {
                            return allTargetItems;
                        }

                        function getSelectedItems() {
                            var raw = allTargetItems;
                            var res = [];
                            for (var k in selectedIndices) {
                                var idx = parseInt(k);
                                if (raw[idx]) res.push(raw[idx]);
                            }
                            return res;
                        }

                        function selectItem(idx, isCtrl, isShift) {
                            if (window.chooserMode && !chooser.config.multiple) { isCtrl = false; isShift = false; }
                            if (window.chooserMode && chooser.config.save && allTargetItems[idx] && !allTargetItems[idx].is_dir)
                                chooserName.text = allTargetItems[idx].name;
                            window.cancelTabRestore();
                            var copy = {};
                            if (isShift) {
                                var anchor = anchorIndex !== -1 ? anchorIndex : (lastSelectedIndex !== -1 ? lastSelectedIndex : 0);
                                var start = Math.min(anchor, idx);
                                var end = Math.max(anchor, idx);
                                for (var i = start; i <= end; ++i) {
                                    copy[i] = true;
                                }
                                lastSelectedIndex = idx;
                            } else if (isCtrl) {
                                copy = Object.assign({}, selectedIndices);
                                if (copy[idx]) {
                                    delete copy[idx];
                                } else {
                                    copy[idx] = true;
                                }
                                lastSelectedIndex = idx;
                                anchorIndex = idx;
                            } else {
                                copy[idx] = true;
                                lastSelectedIndex = idx;
                                anchorIndex = idx;
                            }
                            selectedIndices = copy;
                        }

                        function selectAll() {
                            if (window.chooserMode && !chooser.config.multiple) return;
                            window.cancelTabRestore();
                            var raw = getFilteredItems();
                            var copy = {};
                            for (var i = 0; i < raw.length; ++i) {
                                copy[i] = true;
                            }
                            selectedIndices = copy;
                        }

                        function clearSelection() {
                            selectedIndices = {};
                            lastSelectedIndex = -1;
                            anchorIndex = -1;
                        }

                        function moveSelection(dx, dy, isShift) {
                            var raw = getFilteredItems();
                            if (raw.length === 0) return;

                            var isList = engine.view_mode === "list";
                            var effectiveCols = isList ? 1 : (filesGridView.cols || 1);

                            var cur = lastSelectedIndex !== -1 ? lastSelectedIndex : 0;
                            var target;
                            if (isList) {
                                var delta = (dy !== 0) ? dy : dx;
                                target = cur + delta;
                            } else {
                                target = cur + dx + dy * effectiveCols;
                            }

                            if (target < 0) target = 0;
                            if (target >= raw.length) target = raw.length - 1;

                            selectItem(target, false, isShift);
                            if (isList) {
                                filesListView.positionViewAtIndex(target, ListView.Visible);
                            } else {
                                filesGridView.positionViewAtIndex(target, GridView.Visible);
                            }
                        }

                        function openSelected() {
                            var items = getSelectedItems();
                            if (window.chooserMode && !items.length && chooser.config.directory) { window.acceptChooser(false); return; }
                            if (items.length > 0) {
                                var it = items[0];
                                var targetPath = engine.is_searching_everywhere
                                    ? it.path
                                    : (engine.current_path + "/" + it.name);

                                if (it.is_dir) {
                                    clearSelection();
                                    engine.set_path(targetPath);
                                    if (engine.is_searching_everywhere) {
                                        engine.clear_search_everywhere();
                                        searchInput.text = "";
                                    }
                                } else {
                                    window.activateFile(targetPath);
                                }
                            }
                        }

                        // Drop target: current directory (for external drops onto empty space)
                        DropArea {
                            id: gridDropArea
                            anchors.fill: parent
                            keys: ["text/uri-list"]

                            // Only handle drops that didn't land on a folder card.
                            // Folder cards have their own DropArea which takes priority.
                            property bool gridIsTarget: containsDrag && dragManager.hoverTarget.length === 0

                            onDropped: function(drop) {
                                if (!drop.hasUrls) return;
                                // If hovering a folder, that folder's DropArea owns the drop.
                                if (dragManager.hoverTarget.length > 0) return;

                                var destPath = engine.current_path;
                                var paths = [];
                                for (var i = 0; i < drop.urls.length; ++i) {
                                    var u = drop.urls[i].toString();
                                    if (u.startsWith("file://")) u = u.slice(7);
                                    if (u === destPath) continue;
                                    paths.push(u);
                                }
                                if (paths.length === 0) return;

                                var asCopy;
                                if (drop.source === dragProxy) {
                                    asCopy = dragManager.asCopy;
                                } else {
                                    asCopy = (drop.proposedAction === Qt.CopyAction) || !(drop.supportedActions & Qt.MoveAction);
                                }

                                drop.accept(asCopy ? Qt.CopyAction : Qt.MoveAction);
                                window.handleDrop(paths, destPath, asCopy);
                            }
                        }

                        // Right-click on empty background or left-click deselect
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            z: 0

                            onPressed: {
                                if (searchInput.activeFocus)
                                    globalKeyHandler.forceActiveFocus();
                            }

                            onClicked: function(mouse) {
                                if (selectionManager.justFinishedDrag) return;
                                if (mouse.button === Qt.RightButton && !engine.is_searching_everywhere) {
                                    contextMenu.showEmptyMenu(mouse.x + gridContainer.x, mouse.y + gridContainer.y);
                                } else {
                                    filesGridView.clearSelection();
                                    contextMenu.close();
                                }
                            }
                        }

                        GridView {
                            id: filesGridView
                            TapHandler {
                                onTapped: {
                                    if (filesGridView.indexAt(point.position.x + filesGridView.contentX, point.position.y + filesGridView.contentY) < 0) {
                                        gridContainer.clearSelection();
                                        globalKeyHandler.forceActiveFocus();
                                        contextMenu.close();
                                    }
                                }
                            }
                            anchors.fill: parent
                            cellWidth: Math.max(1, width / cols)
                            cellHeight: cellWidth
                            reuseItems: true
                            cacheBuffer: cellHeight * 2
                            clip: true
                            z: engine.view_mode === "grid" ? 2 : 1
                            // Cross-fade grid <-> list instead of an instant swap.
                            opacity: engine.view_mode === "grid" ? 1.0 : 0.0
                            visible: opacity > 0.001
                            enabled: engine.view_mode === "grid"
                            Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.motionDuration(170); easing.type: Easing.OutCubic } }
                            interactive: true
                            onMovementStarted: window.cancelTabRestore()
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {
                                id: gridScrollBar
                                policy: ScrollBar.AsNeeded
                                width: 12
                                padding: 2
                                contentItem: Rectangle {
                                    implicitWidth: 6
                                    radius: 3
                                    color: gridScrollBar.pressed ? theme.primary : (gridScrollBar.hovered ? theme.outline : theme.outlineVariant)
                                    opacity: gridScrollBar.active ? 1.0 : 0.0
                                    Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.motionDuration(200)} }
                                }
                            }

                            readonly property int rows: Math.ceil(count / cols)
                            contentWidth: Math.max(width, cols * cellWidth)
                            contentHeight: Math.max(height, rows * cellHeight)

                            property alias selectedIndices: gridContainer.selectedIndices
                            property alias selectedCount: gridContainer.selectedCount
                            property alias lastSelectedIndex: gridContainer.lastSelectedIndex

                            function selectItem(idx, isCtrl, isShift) { gridContainer.selectItem(idx, isCtrl, isShift); }
                            function selectAll() { gridContainer.selectAll(); }
                            function clearSelection() { gridContainer.clearSelection(); }
                            function getFilteredItems() { return gridContainer.getFilteredItems(); }
                            function getSelectedItems() { return gridContainer.getSelectedItems(); }
                            function openSelected() { gridContainer.openSelected(); }

                            readonly property int cols: Math.max(1, Math.floor(width / window.gridItemSize + 0.000001))

                            // Per-card staggered enter is implemented on the delegate
                            // itself (capped) instead of populate/add transitions, so
                            // large folders and search results never hitch.

                            // Wheel handler ensures smooth wheel scrolling in both select and scroll modes
                            WheelHandler {
                                id: gridWheelHandler
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                acceptedModifiers: Qt.KeyboardModifierMask
                                target: null
                                onWheel: function(event) {
                                    var delta = event.angleDelta.y || event.pixelDelta.y;
                                    if (delta === 0) { event.accepted = false; return; }
                                    if (window.zoomGrid(event)) return;
                                    window.cancelTabRestore();
                                    var step = 80;
                                    var newY = filesGridView.contentY - (delta > 0 ? step : -step);
                                    var maxY = Math.max(0, filesGridView.contentHeight - filesGridView.height);
                                    filesGridView.contentY = Math.max(0, Math.min(maxY, newY));
                                }
                            }

                            MouseArea {
                                objectName: "gridZoomInput"
                                parent: filesGridView
                                anchors.fill: parent
                                z: 200
                                acceptedButtons: Qt.NoButton
                                onWheel: function(event) {
                                    event.accepted = window.zoomGrid(event);
                                }
                            }

                            // ==========================================
                            // RUBBERBAND SELECTION BOX & CONTROLLER
                            // ==========================================
                            Rectangle {
                                id: selectionBox
                                parent: filesGridView.contentItem
                                z: 100
                                visible: false
                                color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, theme.isDark ? 0.22 : 0.16)
                                border.color: theme.primary
                                border.width: 1.5
                                radius: theme.radiusM

                                Behavior on color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }
                                Behavior on border.color { enabled: !theme.reducedMotion; ColorAnimation { duration: theme.durationFast } }
                            }

                            ParallelAnimation {
                                id: contractAnim
                                NumberAnimation { target: selectionBox; property: "x"; to: selectionManager.startX; duration: theme.motionDuration(160); easing.type: Easing.OutCubic }
                                NumberAnimation { target: selectionBox; property: "y"; to: selectionManager.startY; duration: theme.motionDuration(160); easing.type: Easing.OutCubic }
                                NumberAnimation { target: selectionBox; property: "width"; to: 0; duration: theme.motionDuration(160); easing.type: Easing.OutCubic }
                                NumberAnimation { target: selectionBox; property: "height"; to: 0; duration: theme.motionDuration(160); easing.type: Easing.OutCubic }
                                NumberAnimation { target: selectionBox; property: "opacity"; to: 0.0; duration: theme.motionDuration(150); easing.type: Easing.OutQuad }

                                onFinished: {
                                    selectionBox.visible = false;
                                    selectionBox.opacity = 1.0;
                                }
                            }

                            Item {
                                id: selectionManager

                                property real startX: 0
                                property real startY: 0
                                property real curX: 0
                                property real curY: 0
                                property bool active: false
                                property bool justFinishedDrag: false
                                property var baseSelection: ({})
                                property bool isCtrl: false

                                function start(x, y, ctrl) {
                                    if (window.chooserMode && !chooser.config.multiple) return;
                                    contractAnim.stop();
                                    selectionBox.opacity = 1.0;
                                    selectionBox.visible = false;
                                    resetJustFinishedDragTimer.stop();
                                    justFinishedDrag = false;

                                    startX = x;
                                    startY = y;
                                    curX = x;
                                    curY = y;
                                    isCtrl = ctrl;
                                    baseSelection = ctrl ? Object.assign({}, filesGridView.selectedIndices) : {};
                                    active = false;
                                }

                                function update(x, y) {
                                    if (window.chooserMode && !chooser.config.multiple) return;
                                    if (theme.dragAction !== "select") return;

                                    curX = x;
                                    curY = y;
                                    var dx = curX - startX;
                                    var dy = curY - startY;

                                    if (!active && (dx * dx + dy * dy >= 25)) {
                                        active = true;
                                        contractAnim.stop();
                                        selectionBox.opacity = 1.0;
                                        selectionBox.visible = true;
                                    }

                                    if (active) {
                                        var boxX = Math.min(startX, curX);
                                        var boxY = Math.min(startY, curY);
                                        var boxW = Math.abs(curX - startX);
                                        var boxH = Math.abs(curY - startY);

                                        selectionBox.x = boxX;
                                        selectionBox.y = boxY;
                                        selectionBox.width = boxW;
                                        selectionBox.height = boxH;

                                        var totalCount = filesGridView.count;
                                        var cols = filesGridView.cols;
                                        var cellW = filesGridView.cellWidth;
                                        var cellH = filesGridView.cellHeight;

                                        var newSelection = Object.assign({}, baseSelection);

                                        for (var i = 0; i < totalCount; ++i) {
                                            var col = i % cols;
                                            var row = Math.floor(i / cols);
                                            var itemL = col * cellW + 4;
                                            var itemT = row * cellH + 4;
                                            var itemR = itemL + cellW - 8;
                                            var itemB = itemT + cellH - 8;

                                            var intersects = (boxX < itemR && (boxX + boxW) > itemL &&
                                                              boxY < itemB && (boxY + boxH) > itemT);

                                            if (intersects) {
                                                newSelection[i] = true;
                                            } else if (!isCtrl) {
                                                delete newSelection[i];
                                            }
                                        }

                                        filesGridView.selectedIndices = newSelection;
                                    }
                                }

                                function end() {
                                    if (active) {
                                        active = false;
                                        justFinishedDrag = true;
                                        contractAnim.start();
                                        resetJustFinishedDragTimer.restart();
                                    }
                                }
                            }

                            Timer {
                                id: resetJustFinishedDragTimer
                                interval: 60
                                repeat: false
                                onTriggered: selectionManager.justFinishedDrag = false
                            }

                            Timer {
                                id: autoScrollTimer
                                interval: 20
                                repeat: true
                                running: selectionManager.active

                                onTriggered: {
                                    var viewTop = filesGridView.contentY;
                                    var viewBottom = viewTop + filesGridView.height;
                                    var scrollMargin = 32;
                                    var step = 10;

                                    if (selectionManager.curY < viewTop + scrollMargin && filesGridView.contentY > 0) {
                                        filesGridView.contentY = Math.max(0, filesGridView.contentY - step);
                                        selectionManager.update(selectionManager.curX, selectionManager.curY);
                                    } else if (selectionManager.curY > viewBottom - scrollMargin && filesGridView.contentY < filesGridView.contentHeight - filesGridView.height) {
                                        filesGridView.contentY = Math.min(filesGridView.contentHeight - filesGridView.height, filesGridView.contentY + step);
                                        selectionManager.update(selectionManager.curX, selectionManager.curY);
                                    }
                                }
                            }

                            // Background click & rubberband selection area
                            MouseArea {
                                id: bgMouseArea
                                parent: filesGridView.contentItem
                                x: 0
                                y: 0
                                width: Math.max(filesGridView.width, filesGridView.contentWidth)
                                height: Math.max(filesGridView.height + filesGridView.contentY, filesGridView.contentHeight)
                                z: 0
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                preventStealing: theme.dragAction === "select"

                                property point pressPt: Qt.point(0, 0)

                                onPressed: function(mouse) {
                                    globalKeyHandler.forceActiveFocus();
                                    if (mouse.button === Qt.LeftButton) {
                                        pressPt = Qt.point(mouse.x, mouse.y);
                                        if (theme.dragAction === "select") {
                                            selectionManager.start(mouse.x, mouse.y, !!(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)));
                                        }
                                    }
                                }

                                onPositionChanged: function(mouse) {
                                    if (theme.dragAction !== "select") return;
                                    if (mouse.buttons & Qt.LeftButton) {
                                        selectionManager.update(mouse.x, mouse.y);
                                    }
                                }

                                onReleased: function(mouse) {
                                    if (selectionManager.active) {
                                        selectionManager.end();
                                    }
                                }

                                onCanceled: {
                                    if (selectionManager.active) {
                                        selectionManager.end();
                                    }
                                }

                                onClicked: function(mouse) {
                                    if (selectionManager.justFinishedDrag) return;
                                    if (mouse.button === Qt.RightButton && !engine.is_searching_everywhere) {
                                        var pt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                        contextMenu.showEmptyMenu(pt.x, pt.y);
                                    } else {
                                        filesGridView.clearSelection();
                                        contextMenu.close();
                                    }
                                }
                            }

                            function moveSelection(dx, dy, isShift) {
                                gridContainer.moveSelection(dx, dy, isShift);
                            }

                            focus: true
                            Keys.onLeftPressed: function(event) {
                                moveSelection(-1, 0, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                            Keys.onRightPressed: function(event) {
                                moveSelection(1, 0, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                            Keys.onUpPressed: function(event) {
                                moveSelection(0, -1, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                            Keys.onDownPressed: function(event) {
                                moveSelection(0, 1, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: function(event) {
                                openSelected();
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: function(event) {
                                openSelected();
                                event.accepted = true;
                            }

                            model: engine.view_mode === "grid" ? gridContainer.displayedItems : []

                            delegate: Item {
                                id: fileCardDelegate
                                property bool entered: false
                                property bool pooled: false
                                Component.onCompleted: entered = true
                                GridView.onPooled: pooled = true
                                GridView.onReused: pooled = false
                                width: filesGridView.cellWidth
                                height: filesGridView.cellHeight

                                readonly property var item: modelData
                                readonly property bool isSelected: !!filesGridView.selectedIndices[index]

                                readonly property bool isCutItem: {
                                    if (!engine.has_clipboard) return false;
                                    try {
                                        var cutList = window.cutPaths;
                                        var myPath = engine.is_searching_everywhere ? item.path : (engine.current_path + "/" + item.name);
                                        return cutList.indexOf(myPath) !== -1;
                                    } catch (e) {
                                        return false;
                                    }
                                }

                                opacity: isCutItem ? 0.52 : 1.0

                                readonly property int col: index % filesGridView.cols
                                readonly property bool hasLeft: isSelected && (col > 0) && !!filesGridView.selectedIndices[index - 1]
                                readonly property bool hasRight: isSelected && (col < filesGridView.cols - 1) && !!filesGridView.selectedIndices[index + 1]

                                readonly property string thumbSource: {
                                    if (pooled || !filesGridView.visible || !theme.showThumbnails || fileCardDelegate.item.is_dir) return "";
                                    return fileCardDelegate.item.thumbnail || "";
                                }
                                readonly property bool hasThumbnail: theme.showThumbnails && thumbSource.length > 0
                                    && (thumbImg.status === Image.Ready)

                                readonly property bool isDropTarget: fileCardDelegate.item.is_dir && folderDropArea.containsDrag

                                // Drop target for folders: accept drops + hover-to-open
                                DropArea {
                                    id: folderDropArea
                                    anchors.fill: parent
                                    enabled: fileCardDelegate.item.is_dir
                                    keys: ["text/uri-list"]

                                    property string folderPath: engine.is_searching_everywhere
                                        ? fileCardDelegate.item.path
                                        : (engine.current_path + "/" + fileCardDelegate.item.name)

                                    onEntered: function(drag) {
                                        dragManager.hoverTarget = folderPath;
                                    }
                                    onExited: {
                                        if (dragManager.hoverTarget === folderPath) {
                                            dragManager.hoverTarget = "";
                                        }
                                    }
                                    onPositionChanged: function(drag) {
                                        dragManager.hoverTarget = folderPath;
                                    }
                                    onDropped: function(drop) {
                                        dragManager.hoverTarget = "";
                                        if (!drop.hasUrls) return;

                                        var destPath = folderPath;
                                        var paths = [];
                                        for (var i = 0; i < drop.urls.length; ++i) {
                                            var u = drop.urls[i].toString();
                                            if (u.startsWith("file://")) u = u.slice(7);
                                            // Ignore dropping a folder into itself
                                            if (u === destPath) continue;
                                            paths.push(u);
                                        }
                                        if (paths.length === 0) return;

                                        // Internal drag: honor Ctrl (copy) vs default (move).
                                        // External drag from another app: copy is the safe default.
                                        var asCopy;
                                        if (drop.source === dragProxy) {
                                            asCopy = dragManager.asCopy;
                                        } else {
                                            asCopy = (drop.proposedAction === Qt.CopyAction) || !(drop.supportedActions & Qt.MoveAction);
                                        }

                                        drop.accept(asCopy ? Qt.CopyAction : Qt.MoveAction);
                                        if (dragManager.isRmb) {
                                            var pt = mapToItem(window.contentItem, cardMouseArea.mouseX, cardMouseArea.mouseY);
                                            rmbDropMenu.showAt(pt.x, pt.y, paths, destPath);
                                        } else {
                                            window.handleDrop(paths, destPath, asCopy);
                                        }
                                    }
                                }

                                // Connected Selection Background with FULL Matching Outer Curvature
                                Rectangle {
                                    id: cardHighlight
                                    anchors.fill: parent
                                    anchors.topMargin: 4
                                    anchors.bottomMargin: 4
                                    anchors.leftMargin: fileCardDelegate.hasLeft ? -4 : 4
                                    anchors.rightMargin: fileCardDelegate.hasRight ? -4 : 4

                                    radius: theme.radiusL
                                    color: fileCardDelegate.isDropTarget
                                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, theme.isDark ? 0.20 : 0.14)
                                        : (fileCardDelegate.isSelected
                                            ? theme.secondaryContainer
                                            : (cardMouseArea.pressed ? theme.activeOverlay : theme.hoverOverlay))
                                    opacity: (fileCardDelegate.isSelected || cardMouseArea.containsMouse || fileCardDelegate.isDropTarget) ? 1.0 : 0.0
                                    border.color: fileCardDelegate.isDropTarget ? theme.primary : Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0)
                                    border.width: fileCardDelegate.isDropTarget ? 2 : 0

                                    Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.durationFast } }
                                    scale: fileCardDelegate.isDropTarget ? 1.06 : 1.0
                                    Behavior on scale { enabled: !theme.reducedMotion; SpringAnimation { spring: 4.0; damping: 0.3 } }

                                    // Square off right half if connected right (leaves left outer corners curved)
                                    Rectangle {
                                        visible: fileCardDelegate.hasRight
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width / 2
                                        color: parent.color
                                        radius: 0
                                    }

                                    // Square off left half if connected left (leaves right outer corners curved)
                                    Rectangle {
                                        visible: fileCardDelegate.hasLeft
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width / 2
                                        color: parent.color
                                        radius: 0
                                    }
                                }

                                scale: !entered ? 0.82
                                    : (cardMouseArea.pressed ? 0.94 : ((cardMouseArea.containsMouse && !fileCardDelegate.hasLeft && !fileCardDelegate.hasRight) ? 1.03 : 1.0))
                                Behavior on scale { enabled: !theme.reducedMotion; SpringAnimation { spring: 3.5; damping: 0.3 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6
                                    z: 1

                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: 0
                                        Layout.preferredHeight: Math.max(0, fileCardDelegate.height - 62)
                                        objectName: "filePreview"

                                        SeabunnyIcon {
                                            visible: !fileCardDelegate.hasThumbnail && (theme.usesGlyphIcons)
                                            objectName: "fileGlyphIcon"
                                            anchors.centerIn: parent
                                            name: fileCardDelegate.isCutItem
                                                ? (fileCardDelegate.item.is_dir ? "folder-dashed" : "file-dashed")
                                                : (fileCardDelegate.item.icon || (fileCardDelegate.item.is_dir ? "folder" : "file"))
                                            size: Math.round(Math.min(parent.width, parent.height) * 0.9)
                                            color: fileCardDelegate.isSelected
                                                ? theme.secondaryContainerFg
                                                : (fileCardDelegate.item.is_dir ? theme.primary : theme.textMain)
                                        }

                                        // Symlink badge indicator
                                        Rectangle {
                                            visible: !!fileCardDelegate.item.is_symlink
                                            width: 14
                                            height: 14
                                            radius: 7
                                            color: theme.surfaceContainer
                                            border.color: theme.outlineVariant
                                            border.width: 1
                                            anchors.bottom: parent.bottom
                                            anchors.right: parent.right
                                            z: 2

                                            SeabunnyIcon {
                                                anchors.centerIn: parent
                                                name: "arrow-square-out"
                                                size: 9
                                                color: theme.primary
                                            }
                                        }

                                        Image {
                                            visible: !fileCardDelegate.hasThumbnail && (!theme.usesGlyphIcons)
                                            objectName: "fileSystemIcon"
                                            anchors.centerIn: parent
                                            source: theme.iconUrl(fileCardDelegate.item.icon_path)
                                            width: Math.round(Math.min(parent.width, parent.height) * 0.9)
                                            height: width
                                            sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
                                            sourceSize.height: Math.ceil(width * Screen.devicePixelRatio)
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            mipmap: true
                                        }

                                        Item {
                                            id: thumbSlot
                                            anchors.fill: parent
                                            visible: fileCardDelegate.hasThumbnail

                                            // Rounded mask. layer.enabled gives it a texture
                                            // so it can be used as a MultiEffect maskSource
                                            // while staying invisible.
                                            Rectangle {
                                                id: thumbMask
                                                anchors.fill: parent
                                                radius: theme.radiusM
                                                color: "white"
                                                visible: false
                                                layer.enabled: true
                                            }

                                            // Thumbnail. MultiEffect cannot sample an invisible
                                            // item, so the *visible* image is masked via
                                            // layer.effect instead of feeding a hidden source
                                            // into a separate MultiEffect.
                                            Image {
                                                id: thumbImg
                                                objectName: "fileThumbnail"
                                                anchors.fill: parent
                                                source: fileCardDelegate.thumbSource
                                                fillMode: Image.PreserveAspectFit
                                                sourceSize.width: 512
                                                sourceSize.height: 512
                                                asynchronous: true
                                                cache: true
                                                retainWhileLoading: true
                                                smooth: true
                                                mipmap: true
                                                visible: fileCardDelegate.hasThumbnail
                                                layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                                                layer.effect: MultiEffect {
                                                    maskEnabled: true
                                                    maskSource: thumbMask
                                                }
                                            }

                                        }
                                    }

                                    Text {
                                        objectName: "fileNameLabel"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                        Layout.minimumHeight: 32
                                        Layout.maximumHeight: 32
                                        // If search everywhere, show disambiguated display_name (e.g. Projects/Pictures)
                                        text: engine.is_searching_everywhere
                                            ? (fileCardDelegate.item.display_name || fileCardDelegate.item.name)
                                            : fileCardDelegate.item.name
                                        color: fileCardDelegate.isSelected ? theme.secondaryContainerFg : theme.textMain
                                        font.pixelSize: 11
                                        font.bold: fileCardDelegate.item.is_dir || fileCardDelegate.isSelected
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignTop
                                        wrapMode: Text.WrapAnywhere
                                        maximumLineCount: 2
                                        elide: Text.ElideMiddle
                                    }

                                }

                                MouseArea {
                                    id: cardMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    preventStealing: true

                                    onWheel: function(wheel) {
                                        wheel.accepted = window.zoomGrid(wheel);
                                    }

                                    property point pressPt: Qt.point(0, 0)
                                    property bool dragStarted: false

                                    onPressed: function(mouse) {
                                        if (mouse.button === Qt.LeftButton) {
                                            pressPt = Qt.point(mouse.x, mouse.y);
                                            dragStarted = false;
                                            if (!fileCardDelegate.isSelected && !(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) {
                                                filesGridView.selectItem(index, false, false);
                                            }
                                        }
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (!(mouse.buttons & (Qt.LeftButton | Qt.RightButton))) return;
                                        if (engine.is_searching_everywhere) return;
                                        if (dragStarted) return;

                                        var dx = mouse.x - pressPt.x;
                                        var dy = mouse.y - pressPt.y;
                                        if (dx * dx + dy * dy >= 36) {
                                            dragStarted = true;
                                            dragManager.isRmb = !!(mouse.buttons & Qt.RightButton);
                                            var gpt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                            dragManager.cursorPos = gpt;
                                            dragManager.begin(fileCardDelegate.item, index, mouse);
                                        }
                                    }

                                    onReleased: function(mouse) {
                                        if (dragStarted) {
                                            dragManager.end();
                                            dragStarted = false;
                                        }
                                    }

                                    onCanceled: {
                                        if (dragStarted) {
                                            dragManager.end();
                                            dragStarted = false;
                                        }
                                    }

                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.MiddleButton) {
                                            if (fileCardDelegate.item.is_dir) window.openFolderTab(fileCardDelegate.item.path || engine.current_path + "/" + fileCardDelegate.item.name, true);
                                            return;
                                        }
                                        if (searchInput.activeFocus)
                                            globalKeyHandler.forceActiveFocus();
                                        if (mouse.button === Qt.RightButton) {
                                            if (!fileCardDelegate.isSelected) {
                                                filesGridView.selectItem(index, false, false);
                                            }
                                            var pt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                            contextMenu.showItemMenu(fileCardDelegate.item, pt.x, pt.y);
                                        } else {
                                            contextMenu.close();
                                            var isCtrl = !!(mouse.modifiers & Qt.ControlModifier);
                                            var isShift = !!(mouse.modifiers & Qt.ShiftModifier);
                                            filesGridView.selectItem(index, isCtrl, isShift);
                                        }
                                    }

                                    onDoubleClicked: function(mouse) {
                                        if (mouse.button === Qt.LeftButton) {
                                            var targetPath = engine.is_searching_everywhere
                                                ? fileCardDelegate.item.path
                                                : (engine.current_path + "/" + fileCardDelegate.item.name);

                                            if (fileCardDelegate.item.is_dir) {
                                                gridContainer.clearSelection();
                                                engine.set_path(targetPath);
                                                if (engine.is_searching_everywhere) {
                                                    engine.clear_search_everywhere();
                                                    searchInput.text = "";
                                                }
                                            } else {
                                                window.activateFile(targetPath);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // List View Column Headers
                        Rectangle {
                            id: listHeaderRow
                            readonly property bool shown: engine.view_mode === "list" && !engine.is_searching_everywhere
                            visible: opacity > 0.001
                            opacity: shown ? 1.0 : 0.0
                            Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.motionDuration(170); easing.type: Easing.OutCubic } }
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 32
                            radius: theme.radiusM
                            color: theme.surfaceContainer
                            z: 2

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                // Name Column
                                Item {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 100
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Text {
                                            text: "Name"
                                            color: engine.sort_by === "name" ? theme.primary : theme.textMuted
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        SeabunnyIcon {
                                            visible: engine.sort_by === "name"
                                            name: engine.sort_ascending ? "sort-ascending" : "sort-descending"
                                            size: 13
                                            color: theme.primary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (engine.sort_by === "name") {
                                                engine.toggle_sort_order();
                                            } else {
                                                engine.set_sort("name", true);
                                            }
                                        }
                                    }
                                }

                                // Date Modified Column
                                Item {
                                    visible: window.listShowDate
                                    Layout.preferredWidth: 150
                                    Layout.minimumWidth: 96
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Text {
                                            text: "Date Modified"
                                            color: engine.sort_by === "modified" ? theme.primary : theme.textMuted
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        SeabunnyIcon {
                                            visible: engine.sort_by === "modified"
                                            name: engine.sort_ascending ? "sort-ascending" : "sort-descending"
                                            size: 13
                                            color: theme.primary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (engine.sort_by === "modified") {
                                                engine.toggle_sort_order();
                                            } else {
                                                engine.set_sort("modified", false);
                                            }
                                        }
                                    }
                                }

                                // Type Column
                                Item {
                                    visible: window.listShowType
                                    Layout.preferredWidth: 100
                                    Layout.minimumWidth: 70
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Text {
                                            text: "Type"
                                            color: engine.sort_by === "type" ? theme.primary : theme.textMuted
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        SeabunnyIcon {
                                            visible: engine.sort_by === "type"
                                            name: engine.sort_ascending ? "sort-ascending" : "sort-descending"
                                            size: 13
                                            color: theme.primary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (engine.sort_by === "type") {
                                                engine.toggle_sort_order();
                                            } else {
                                                engine.set_sort("type", true);
                                            }
                                        }
                                    }
                                }

                                // Size Column
                                Item {
                                    visible: window.listShowSize
                                    Layout.preferredWidth: 80
                                    Layout.minimumWidth: 60
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Text {
                                            text: "Size"
                                            color: engine.sort_by === "size" ? theme.primary : theme.textMuted
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        SeabunnyIcon {
                                            visible: engine.sort_by === "size"
                                            name: engine.sort_ascending ? "sort-ascending" : "sort-descending"
                                            size: 13
                                            color: theme.primary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (engine.sort_by === "size") {
                                                engine.toggle_sort_order();
                                            } else {
                                                engine.set_sort("size", false);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Detailed List View
                        ListView {
                            id: filesListView
                            TapHandler {
                                onTapped: {
                                    if (filesListView.indexAt(point.position.x + filesListView.contentX, point.position.y + filesListView.contentY) < 0) {
                                        gridContainer.clearSelection();
                                        globalKeyHandler.forceActiveFocus();
                                        contextMenu.close();
                                    }
                                }
                            }
                            reuseItems: true
                            cacheBuffer: 160
                            anchors.top: listHeaderRow.shown ? listHeaderRow.bottom : parent.top
                            anchors.topMargin: listHeaderRow.shown ? 6 : 0
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            spacing: 3
                            clip: true
                            z: engine.view_mode === "list" ? 2 : 1
                            // Cross-fade grid <-> list instead of an instant swap.
                            opacity: engine.view_mode === "list" ? 1.0 : 0.0
                            visible: opacity > 0.001
                            enabled: engine.view_mode === "list"
                            Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.motionDuration(170); easing.type: Easing.OutCubic } }
                            interactive: true
                            boundsBehavior: Flickable.StopAtBounds

                            MouseArea {
                                parent: filesListView.contentItem
                                width: Math.max(filesListView.width, filesListView.contentWidth)
                                height: Math.max(filesListView.height + filesListView.contentY, filesListView.contentHeight)
                                z: 0
                                onPressed: globalKeyHandler.forceActiveFocus()
                                onClicked: {
                                    gridContainer.clearSelection();
                                    contextMenu.close();
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                id: listScrollBar
                                policy: ScrollBar.AsNeeded
                                width: 12
                                padding: 2
                                contentItem: Rectangle {
                                    implicitWidth: 6
                                    radius: 3
                                    color: listScrollBar.pressed ? theme.primary : (listScrollBar.hovered ? theme.outline : theme.outlineVariant)
                                    opacity: listScrollBar.active ? 1.0 : 0.0
                                    Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.motionDuration(200)} }
                                }
                            }

                            WheelHandler {
                                id: listWheelHandler
                                target: null
                                onWheel: function(event) {
                                    window.cancelTabRestore();
                                    var delta = event.angleDelta.y;
                                    var step = 80;
                                    var newY = filesListView.contentY - (delta > 0 ? step : -step);
                                    var maxY = Math.max(0, filesListView.contentHeight - filesListView.height);
                                    filesListView.contentY = Math.max(0, Math.min(maxY, newY));
                                }
                            }

                            // Keyboard navigation (arrow keys + open), mirroring the grid.
                            focus: false
                            Keys.onUpPressed: function(event) {
                                gridContainer.moveSelection(0, -1, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                            Keys.onDownPressed: function(event) {
                                gridContainer.moveSelection(0, 1, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: function(event) {
                                gridContainer.openSelected();
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: function(event) {
                                gridContainer.openSelected();
                                event.accepted = true;
                            }

                            model: engine.view_mode === "list" ? gridContainer.displayedItems : []

                            delegate: Item {
                                id: listRowDelegate
                                property bool pooled: false
                                ListView.onPooled: pooled = true
                                ListView.onReused: pooled = false
                                width: filesListView.width
                                height: 38

                                readonly property var item: modelData
                                readonly property bool isSelected: !engine.is_searching_everywhere && !!gridContainer.selectedIndices[index]
                                readonly property bool isHovered: listRowMouse.containsMouse
                                readonly property bool isDropTarget: listFolderDropArea.containsDrag

                                readonly property bool isCutItem: {
                                    if (!engine.has_clipboard) return false;
                                    try {
                                        var cutList = window.cutPaths;
                                        var myPath = engine.is_searching_everywhere ? item.path : (engine.current_path + "/" + item.name);
                                        return cutList.indexOf(myPath) !== -1;
                                    } catch (e) {
                                        return false;
                                    }
                                }

                                readonly property string fullPath: engine.is_searching_everywhere
                                    ? item.path : (engine.current_path + "/" + item.name)
                                readonly property string thumbSource: {
                                    if (pooled || !filesListView.visible || !theme.showThumbnails || item.is_dir) return "";
                                    return item.thumbnail || "";
                                }
                                readonly property bool hasThumbnail: theme.showThumbnails && thumbSource.length > 0
                                    && (listThumbImg.status === Image.Ready)

                                opacity: isCutItem ? 0.52 : 1.0
                                Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.durationFast } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: theme.radiusM
                                    color: listRowDelegate.isSelected
                                        ? theme.secondaryContainer
                                        : (listRowDelegate.isDropTarget ? theme.primaryContainer : theme.hoverOverlay)
                                    opacity: (listRowDelegate.isSelected || listRowDelegate.isHovered || listRowDelegate.isDropTarget) ? 1.0 : 0.0
                                    Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.durationFast } }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    // Name Column
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Item {
                                            width: 22
                                            height: 22
                                            Layout.alignment: Qt.AlignVCenter

                                            SeabunnyIcon {
                                                visible: !listRowDelegate.hasThumbnail && theme.usesGlyphIcons
                                                anchors.centerIn: parent
                                                name: listRowDelegate.isCutItem
                                                    ? (listRowDelegate.item.is_dir ? "folder-dashed" : "file-dashed")
                                                    : (listRowDelegate.item.icon || (listRowDelegate.item.is_dir ? "folder" : "file"))
                                                size: 18
                                                color: listRowDelegate.isSelected ? theme.secondaryContainerFg : (listRowDelegate.item.is_dir ? theme.primary : theme.textMain)
                                            }

                                            // Small symlink badge indicator
                                            Rectangle {
                                                visible: !!listRowDelegate.item.is_symlink
                                                width: 10
                                                height: 10
                                                radius: 5
                                                color: theme.surfaceContainer
                                                border.color: theme.outlineVariant
                                                border.width: 1
                                                anchors.bottom: parent.bottom
                                                anchors.right: parent.right

                                                SeabunnyIcon {
                                                    anchors.centerIn: parent
                                                    name: "arrow-square-out"
                                                    size: 7
                                                    color: theme.primary
                                                }
                                            }

                                            Image {
                                                visible: !listRowDelegate.hasThumbnail && !theme.usesGlyphIcons
                                                anchors.centerIn: parent
                                                source: theme.iconUrl(listRowDelegate.item.icon_path)
                                                width: 18
                                                height: 18
                                                sourceSize.width: 36
                                                sourceSize.height: 36
                                                fillMode: Image.PreserveAspectFit
                                            }

                                            // Inline image thumbnail (replaces the icon).
                                            Rectangle {
                                                anchors.fill: parent
                                                visible: listRowDelegate.hasThumbnail
                                                radius: 6
                                                color: theme.surfaceContainerHigh
                                                clip: true

                                                Image {
                                                    id: listThumbImg
                                                    anchors.fill: parent
                                                    source: listRowDelegate.thumbSource
                                                    fillMode: Image.PreserveAspectCrop
                                                    sourceSize.width: 512
                                                    sourceSize.height: 512
                                                    asynchronous: true
                                                    cache: true
                                                    retainWhileLoading: true
                                                    smooth: true
                                                    mipmap: true
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 6
                                                    color: "transparent"
                                                    border.color: theme.outlineVariant
                                                    border.width: 1
                                                    opacity: 0.4
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: listRowDelegate.item.name
                                            color: listRowDelegate.isSelected ? theme.secondaryContainerFg : theme.textMain
                                            font.pixelSize: 13
                                            font.bold: listRowDelegate.item.is_dir || listRowDelegate.isSelected
                                            elide: Text.ElideMiddle
                                        }
                                    }

                                    // Date Column
                                    Text {
                                        visible: window.listShowDate
                                        Layout.preferredWidth: 150
                                        Layout.minimumWidth: 96
                                        text: listRowDelegate.item.modified_str || "-"
                                        color: listRowDelegate.isSelected ? theme.secondaryContainerFg : theme.textMuted
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }

                                    // Type Column
                                    Text {
                                        visible: window.listShowType
                                        Layout.preferredWidth: 100
                                        Layout.minimumWidth: 70
                                        text: listRowDelegate.item.category || "-"
                                        color: listRowDelegate.isSelected ? theme.secondaryContainerFg : theme.outline
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }

                                    // Size Column
                                    Text {
                                        visible: window.listShowSize
                                        Layout.preferredWidth: 80
                                        Layout.minimumWidth: 60
                                        text: listRowDelegate.item.size_str || "-"
                                        color: listRowDelegate.isSelected ? theme.secondaryContainerFg : theme.textMuted
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }

                                DropArea {
                                    id: listFolderDropArea
                                    anchors.fill: parent
                                    enabled: listRowDelegate.item.is_dir
                                    keys: ["text/uri-list"]

                                    onEntered: function(drag) {
                                        dragManager.hoverTarget = engine.current_path + "/" + listRowDelegate.item.name;
                                    }
                                    onExited: {
                                        if (dragManager.hoverTarget === (engine.current_path + "/" + listRowDelegate.item.name)) {
                                            dragManager.hoverTarget = "";
                                        }
                                    }
                                    onDropped: function(drop) {
                                        if (!drop.hasUrls) return;
                                        var folderPath = engine.current_path + "/" + listRowDelegate.item.name;
                                        dragManager.hoverTarget = "";
                                        var paths = [];
                                        for (var i = 0; i < drop.urls.length; ++i) {
                                            var u = drop.urls[i].toString();
                                            if (u.startsWith("file://")) u = u.slice(7);
                                            if (u === folderPath) continue;
                                            paths.push(u);
                                        }
                                        if (paths.length === 0) return;

                                        var asCopy;
                                        if (drop.source === dragProxy) {
                                            asCopy = dragManager.asCopy;
                                        } else {
                                            asCopy = (drop.proposedAction === Qt.CopyAction) || !(drop.supportedActions & Qt.MoveAction);
                                        }
                                        drop.accept(asCopy ? Qt.CopyAction : Qt.MoveAction);
                                        if (dragManager.isRmb) {
                                            var pt = mapToItem(window.contentItem, listRowMouse.mouseX, listRowMouse.mouseY);
                                            rmbDropMenu.showAt(pt.x, pt.y, paths, folderPath);
                                        } else {
                                            window.handleDrop(paths, folderPath, asCopy);
                                        }
                                    }
                                }

                                MouseArea {
                                    id: listRowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true

                                    onWheel: function(wheel) {
                                        wheel.accepted = false;
                                    }

                                    property point pressPos: Qt.point(0, 0)
                                    property bool isDragging: false

                                    onPressed: function(mouse) {
                                        pressPos = Qt.point(mouse.x, mouse.y);
                                        isDragging = false;
                                        var isCtrl = !!(mouse.modifiers & Qt.ControlModifier);
                                        var isShift = !!(mouse.modifiers & Qt.ShiftModifier);
                                        if (mouse.button === Qt.LeftButton) {
                                            if (!gridContainer.selectedIndices[index] && !isCtrl && !isShift) {
                                                gridContainer.selectItem(index, false, false);
                                            }
                                        }
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (mouse.buttons & (Qt.LeftButton | Qt.RightButton)) {
                                            var dx = mouse.x - pressPos.x;
                                            var dy = mouse.y - pressPos.y;
                                            if (!isDragging && (dx*dx + dy*dy >= 36)) {
                                                isDragging = true;
                                                dragManager.isRmb = !!(mouse.buttons & Qt.RightButton);
                                                var gpt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                                dragManager.cursorPos = gpt;
                                                dragManager.begin(listRowDelegate.item, index, mouse);
                                            }
                                        }
                                    }

                                    onReleased: function(mouse) {
                                        if (isDragging) {
                                            isDragging = false;
                                            dragManager.end();
                                        }
                                    }

                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.MiddleButton) {
                                            if (listRowDelegate.item.is_dir) window.openFolderTab(listRowDelegate.item.path || engine.current_path + "/" + listRowDelegate.item.name, true);
                                            return;
                                        }
                                        if (isDragging) return;
                                        if (searchInput.activeFocus)
                                            globalKeyHandler.forceActiveFocus();
                                        var isCtrl = !!(mouse.modifiers & Qt.ControlModifier);
                                        var isShift = !!(mouse.modifiers & Qt.ShiftModifier);
                                        if (mouse.button === Qt.LeftButton) {
                                            gridContainer.selectItem(index, isCtrl, isShift);
                                        } else if (mouse.button === Qt.RightButton) {
                                            if (!gridContainer.selectedIndices[index]) {
                                                gridContainer.selectItem(index, false, false);
                                            }
                                            var pt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                            contextMenu.showItemMenu(listRowDelegate.item, pt.x, pt.y);
                                        }
                                    }

                                    onDoubleClicked: function(mouse) {
                                        if (mouse.button === Qt.LeftButton) {
                                            var fullPath = engine.is_searching_everywhere
                                                ? listRowDelegate.item.path
                                                : (engine.current_path + "/" + listRowDelegate.item.name);
                                            if (listRowDelegate.item.is_dir) {
                                                gridContainer.clearSelection();
                                                engine.set_path(fullPath);
                                                if (engine.is_searching_everywhere) {
                                                    engine.clear_search_everywhere();
                                                    searchInput.text = "";
                                                }
                                            } else {
                                                window.activateFile(fullPath);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // VIEW 2: INTEGRATED SETTINGS VIEW
                SettingsView {
                    id: settingsView
                    anchors.fill: parent
                    anchors.margins: 22
                    searchQuery: window.activeView === "settings" ? searchInput.text : ""
                    visible: opacity > 0.001
                    opacity: window.activeView === "settings" ? 1.0 : 0.0
                    enabled: window.activeView === "settings"

                    Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.motionDuration(200); easing.type: Easing.OutCubic } }
                    transform: Translate {
                        y: window.activeView === "settings" ? 0 : 8
                        Behavior on y { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.motionDuration(200); easing.type: Easing.OutCubic } }
                    }
                }

                // VIEW 3: PC DASHBOARD
                PCView {
                    id: pcView
                    anchors.fill: parent
                    anchors.margins: 22
                    visible: opacity > 0.001
                    opacity: window.activeView === "pc" ? 1.0 : 0.0
                    enabled: window.activeView === "pc"

                    Behavior on opacity { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.motionDuration(200); easing.type: Easing.OutCubic } }
                    transform: Translate {
                        y: window.activeView === "pc" ? 0 : 8
                        Behavior on y { enabled: !theme.reducedMotion; NumberAnimation { duration: theme.motionDuration(200); easing.type: Easing.OutCubic } }
                    }
                }

                // VIEW 4: TRASH is now a normal directory (navigated via the nav
                // rail -> engine.trash_root); no dedicated view exists anymore.
                } // end mainStageContent
            }
        }
    }

    Rectangle {
        id: sidebarDragProxy
        parent: window.contentItem
        width: 120
        height: 36
        radius: 12
        color: theme.primaryContainer
        z: 10000
        visible: Drag.active
        property string sidebarId: ""
        property string label: ""
        Drag.dragType: Drag.Internal
        Drag.source: sidebarDragProxy
        Drag.keys: ["seabunny/sidebar"]
        Drag.supportedActions: Qt.MoveAction
        Drag.hotSpot.x: 16
        Drag.hotSpot.y: 16
        Text {
            anchors.fill: parent
            anchors.margins: 8
            text: sidebarDragProxy.label
            elide: Text.ElideRight
            color: theme.primaryContainerFg
        }
    }

    // ==========================================
    // FILE DRAG & DROP SYSTEM
    // ==========================================
    QtObject {
        id: dragManager
        property bool active: false
        property bool asCopy: false
        property bool isRmb: false
        property var paths: []          // absolute paths being dragged
        property string hoverTarget: "" // dir path currently hovered (for auto-open)
        property point cursorPos: Qt.point(0, 0)

        function begin(item, index, mouse) {
            if (window.chooserMode) return;
            if (engine.archive_path.length) return;
            // Drag the whole selection if the pressed card is part of it,
            // otherwise just the pressed card.
            var idxs = [];
            if (filesGridView.selectedIndices[index]) {
                for (var k in filesGridView.selectedIndices) idxs.push(parseInt(k));
            } else {
                filesGridView.selectItem(index, false, false);
                idxs = [index];
            }

            var items = gridContainer.allTargetItems;
            var list = [];
            for (var i = 0; i < idxs.length; ++i) {
                var it = items[idxs[i]];
                if (!it) continue;
                list.push(engine.is_searching_everywhere ? it.path
                    : (engine.current_path + "/" + it.name));
            }
            if (list.length === 0) return;

            paths = list;
            isRmb = (mouse.button === Qt.RightButton || !!(mouse.buttons & Qt.RightButton));
            asCopy = !!(mouse.modifiers & Qt.ControlModifier);
            active = true;
            hoverTarget = "";
            dragProxy.x = cursorPos.x;
            dragProxy.y = cursorPos.y;

            // Grab the ghost for the drag pixmap, then start once it's ready.
            dragGhost.visible = true;
            dragGhost.grabToImage(function(result) {
                dragProxy.ghostImageSource = result.url;
                dragGhost.visible = false;
                if (dragManager.active) {
                    dragProxy.Drag.active = true;
                }
            });
        }

        function end() {
            active = false;
            hoverTarget = "";
            hoverOpenTimer.stop();
            dragProxy.Drag.active = false;
        }
    }

    // Invisible proxy that carries the platform drag (external apps read its mimeData)
    Item {
        id: dragProxy
        visible: false
        width: 1
        height: 1

        Drag.active: false
        Drag.dragType: Drag.Automatic
        Drag.keys: ["text/uri-list"]
        Drag.source: dragProxy
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: dragManager.asCopy ? Qt.CopyAction : Qt.MoveAction
        Drag.hotSpot.x: dragGhost.width / 2
        Drag.hotSpot.y: dragGhost.height / 2
        Drag.imageSource: ghostImageSource

        // Build a file:// uri list from the dragged paths.
        // Qt splits text/uri-list on CRLF per RFC 2483, so join with \r\n.
        property string uriList: {
            var uris = [];
            for (var i = 0; i < dragManager.paths.length; ++i) {
                uris.push("file://" + dragManager.paths[i]);
            }
            return uris.join("\r\n");
        }
        property url ghostImageSource: ""

        Drag.mimeData: ({
            "text/uri-list": uriList,
            "text/plain": dragManager.paths.join("\n")
        })

        // dragFinished is a signal of the Drag attached type, not the Item
        Drag.onDragFinished: function(dropAction) {
            // Internal drops handle their own fs work via DropArea.onDropped.
            // Only clean up state here; the DropArea path already refreshed.
            dragManager.end();
        }
    }

    // Visible ghost shown while dragging inside the app (also source of the drag image)
    Rectangle {
        id: dragGhost
        visible: false
        z: 9999
        width: Math.max(120, ghostRow.implicitWidth + 28)
        height: 52
        radius: theme.radiusL
        color: theme.surfaceContainerHighest
        border.color: theme.primary
        border.width: 1.5
        opacity: 0.96

        Row {
            id: ghostRow
            anchors.centerIn: parent
            spacing: 10

            SeabunnyIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "file"
                size: 22
                color: theme.primary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dragManager.paths.length > 1
                    ? (dragManager.paths.length + " files")
                    : (dragManager.paths.length === 1
                        ? dragManager.paths[0].split("/").pop()
                        : "")
                color: theme.textMain
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
                width: Math.min(implicitWidth, 180)
            }
        }

        // "copy" badge when Ctrl is held
        Rectangle {
            visible: dragManager.asCopy
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: -4
            width: 20
            height: 20
            radius: 10
            color: theme.primary

            SeabunnyIcon {
                anchors.centerIn: parent
                name: "copy"
                size: 12
                color: theme.primaryFg
            }
        }
    }

    // Hover-to-open timer: if a drag stays over a folder, navigate into it
    Timer {
        id: hoverOpenTimer
        interval: 750
        repeat: false
        running: dragManager.active && dragManager.hoverTarget.length > 0
        onTriggered: {
            if (dragManager.active && dragManager.hoverTarget.length > 0) {
                var target = dragManager.hoverTarget;
                dragManager.hoverTarget = "";
                filesGridView.clearSelection();
                engine.set_path(target);
            }
        }
    }

    // ==========================================
    // CONTEXT MENUS -- built on the shared SeabunnyMenu library
    // ==========================================
    SeabunnyMenu {
        id: contextMenu

        property var currentTargetItem: null
        property bool isItemMenu: false

        menuMinWidth: 230
        menuMaxWidth: 340

        readonly property bool insideTrash: engine.trash_root.length > 0
            && engine.current_path === engine.trash_root

        function targetPath() {
            if (!currentTargetItem)
                return "";
            if (engine.is_searching_everywhere)
                return currentTargetItem.path || "";
            return engine.current_path + "/" + currentTargetItem.name;
        }

        function selectedPaths() {
            var items = gridContainer.getSelectedItems();
            var out = [];
            for (var i = 0; i < items.length; ++i) {
                var it = items[i];
                out.push(engine.is_searching_everywhere
                    ? it.path
                    : (engine.current_path + "/" + it.name));
            }
            return out;
        }

        function compressSubmenu(paths) {
            function doCompress(fmt) {
                contextMenu.close();
                engine.compress_items_with_options(JSON.stringify(paths), fmt, "");
            }
            var sub = [
                { text: ".zip Archive", icon: "file-zip", action: function() { doCompress("zip"); } },
                { text: "Encrypted .zip…", icon: "lock", action: function() {
                    contextMenu.close();
                    passwordModal.openFor(paths, "zip_encrypted");
                } },
                { text: ".tar.gz Archive", icon: "archive", separatorBefore: true, action: function() { doCompress("tar.gz"); } },
                { text: ".7z Archive", icon: "file-archive", action: function() { doCompress("7z"); } }
            ];
            if (theme.showAdvancedArchives) {
                sub.push({ text: ".tar.xz Archive", icon: "archive", separatorBefore: true, action: function() { doCompress("tar.xz"); } });
                sub.push({ text: ".tar.zst Archive", icon: "archive", action: function() { doCompress("tar.zst"); } });
                sub.push({ text: ".tar.bz2 Archive", icon: "archive", action: function() { doCompress("tar.bz2"); } });
                sub.push({ text: ".cpio Archive", icon: "package", action: function() { doCompress("cpio"); } });
            }
            return sub;
        }

        function buildItemModel() {
            var it = currentTargetItem;
            if (!it)
                return [];
            var isSearching = engine.is_searching_everywhere;
            var itemPath = targetPath();
            var paths = selectedPaths();
            if (paths.length === 0)
                paths = [itemPath];
            var parentPath = it.parent_path || "";
            var inTrash = contextMenu.insideTrash;
            var m = [];

            if (engine.archive_path.length) {
                m.push({text: "Open", icon: "arrow-square-out", action: function() {
                    if (it.is_dir) engine.set_path(itemPath); else engine.open_item(itemPath);
                }});
                if (it.is_dir) m.push({text: "Open in New Tab", icon: "folder-open", action: function() { window.openFolderTab(itemPath, false); }});
                m.push({text: "Copy", icon: "copy", shortcut: "Ctrl+C", action: function() { engine.copy_items(JSON.stringify(paths), false); }});
                m.push({text: "Extract Selected", icon: "archive", enabled: !engine.archive_busy, action: function() { engine.extract_current_archive(JSON.stringify(paths)); }});
                return m;
            }

            m.push({ text: "Open", icon: "arrow-square-out", action: function() {
                if (it.is_dir) {
                    engine.set_path(itemPath);
                    if (engine.is_searching_everywhere) {
                        engine.clear_search_everywhere();
                        searchInput.text = "";
                    }
                } else {
                    engine.open_item(itemPath);
                }
            } });

            if (!inTrash) m.push({ text: "Open With…", icon: "squares-four", action: function() {
                openWithModal.showFor(paths);
            } });

            if ((it.is_dir || engine.is_archive_file(itemPath)) && !inTrash) m.push({text: "Open in New Tab", icon: "folder-open", action: function() { window.openFolderTab(itemPath, false); }});

            // Hide "Open Containing Folder" when the item already lives in the
            // folder we are browsing.
            var showContaining = isSearching
                || (parentPath.length > 0 && parentPath !== engine.current_path);
            if (showContaining) {
                m.push({ text: "Open Containing Folder", icon: "folder-open", action: function() {
                    if (parentPath.length > 0) {
                        engine.clear_search_everywhere();
                        searchInput.text = "";
                        engine.set_path(parentPath);
                    }
                } });
            }

            m.push({ text: "Open in Terminal", icon: "terminal", action: function() {
                var dir = it.is_dir ? itemPath : (parentPath.length > 0 ? parentPath : engine.current_path);
                engine.open_terminal(dir);
            } });

            if (it.is_dir && !inTrash) {
                m.push({ text: window.isFavorite(itemPath) ? "Unpin from Favorites" : "Pin to Favorites", icon: "star", action: function() {
                    window.saveFavorite(itemPath, it.name, window.isFavorite(itemPath));
                } });
            }

            m.push({ text: "Cut", icon: "scissors", shortcut: "Ctrl+X", separatorBefore: true, action: function() {
                engine.copy_items(JSON.stringify(paths), true);
            } });
            m.push({ text: "Copy", icon: "copy", shortcut: "Ctrl+C", action: function() {
                engine.copy_items(JSON.stringify(paths), false);
            } });
            m.push({ text: "Rename", icon: "pencil-simple", shortcut: "F2", enabled: !inTrash, action: function() {
                inputModal.showRename(it.name, parentPath || "/", it.is_dir);
            } });

            var isArchive = !isSearching && it.is_dir === false
                && engine.is_archive_file(itemPath);
            if (isArchive) {
                m.push({ text: "Extract Here", icon: "archive", action: function() {
                    engine.extract_archive(itemPath, false);
                } });
                m.push({ text: "Extract to Folder", icon: "folder-open", action: function() {
                    engine.extract_archive(itemPath, true);
                } });
            }

            m.push({ text: "Compress", icon: "file-archive", submenu: compressSubmenu(paths) });

            if (inTrash) {
                m.push({ text: "Restore", icon: "arrow-counter-clockwise", separatorBefore: true, action: function() {
                    engine.restore_trash_item(itemPath);
                } });
            } else {
                m.push({ text: "Move to Trash", icon: "trash", shortcut: "Del", danger: true, separatorBefore: true, action: function() {
                    engine.trash_items(JSON.stringify(paths));
                    gridContainer.clearSelection();
                } });
            }

            m.push({ text: "Properties", icon: "info", shortcut: "Alt+Enter", action: function() {
                propsModal.showInfo(itemPath);
            } });

            return m;
        }

        function buildEmptyModel() {
            var m = [];
            if (engine.archive_path.length) {
                return [{text: "Extract Entire Archive", icon: "archive", enabled: !engine.archive_busy,
                         action: function() { engine.extract_current_archive("[]"); }},
                        {text: "Select All", icon: "check-square", shortcut: "Ctrl+A", action: function() { gridContainer.selectAll(); }}];
            }
            m.push({ text: window.isFavorite(engine.current_path) ? "Unpin This Folder" : "Pin This Folder", icon: "star", action: function() {
                window.saveFavorite(engine.current_path, engine.current_dir_name || "Home", window.isFavorite(engine.current_path));
            } });
            m.push({ text: "New Folder", icon: "folder-plus", shortcut: "Ctrl+Shift+N", action: function() {
                inputModal.showNewFolder();
            } });
            m.push({ text: "New Text File", icon: "file-plus", action: function() {
                inputModal.showNewFile();
            } });
            m.push({ text: "Open Terminal Here", icon: "terminal", action: function() {
                engine.open_terminal(engine.current_path);
            } });
            if (engine.has_clipboard) {
                m.push({ text: "Paste", icon: "clipboard", shortcut: "Ctrl+V", action: function() {
                    window.triggerPaste();
                } });
            }
            m.push({ text: "Select All", icon: "check-square", shortcut: "Ctrl+A", separatorBefore: true, action: function() {
                gridContainer.selectAll();
            } });
            return m;
        }

        function showItemMenu(item, mx, my) {
            if (window.chooserMode) return;
            currentTargetItem = item;
            isItemMenu = true;
            model = buildItemModel();
            openAt(mx, my);
        }

        function showEmptyMenu(mx, my) {
            if (window.chooserMode) return;
            currentTargetItem = null;
            isItemMenu = false;
            model = buildEmptyModel();
            openAt(mx, my);
        }
    }

    SeabunnyMenu {
        id: favoriteMenu
        function showRestore(anchor) {
            if (window.chooserMode) return;
            model = [{ text: "Restore Default Places", icon: "arrow-counter-clockwise", action: function() {
                var value = Sidebar.layout(JSON.stringify(window.sidebarLayout));
                value.hidden = [];
                window.saveSidebarLayout(value);
            } }];
            openRightOf(anchor);
        }
        function showFor(item, anchor) {
            if (window.chooserMode) return;
            var entries = [];
            if (item.favorite) entries.push({ text: "Rename Favorite", icon: "pencil-simple", action: function() { favoritePrompt.edit(item); } });
            entries.push({ text: item.favorite ? "Remove Favorite" : "Remove from Sidebar", icon: "minus", action: function() { window.removeSidebar(item); } });
            entries.push({ text: "Folder Icon", icon: "folder", submenu: ["folder", "folder-open", "image", "music", "video", "code", "camera", "star"].map(function(icon) {
                return { text: icon, icon: icon, action: function() {
                    var value = Sidebar.layout(JSON.stringify(window.sidebarLayout));
                    value.icons[item.id] = icon;
                    window.saveSidebarLayout(value);
                } };
            }) });
            entries.push({ text: "Restore Default Places", icon: "arrow-counter-clockwise", action: function() {
                var value = Sidebar.layout(JSON.stringify(window.sidebarLayout));
                value.hidden = [];
                window.saveSidebarLayout(value);
            } });
            model = entries;
            openRightOf(anchor);
        }
    }

    SeabunnyTextPrompt {
        id: favoritePrompt
        property string folderPath: ""
        title: "Rename Favorite"
        label: "Changes only the sidebar label, not the folder"
        confirmText: "Save"
        function edit(item) {
            folderPath = item.path;
            initialText = item.name;
            open();
        }
        onAccepted: function(text) { window.saveFavorite(folderPath, text, false); }
    }

    // ==========================================
    // INPUT MODAL (New Folder, New File, Rename)
    // ==========================================
    SeabunnyTextPrompt {
        id: inputModal

        property string mode: "new_folder"
        property string targetItemName: ""
        property string targetDirectory: ""

        function showNewFolder() {
            if (window.chooserMode) return;
            mode = "new_folder";
            title = "New Folder";
            label = "Enter a name for the new folder";
            placeholder = "Folder name";
            initialText = "New Folder";
            confirmText = "Save";
            selectBasename = false;
            open();
        }

        function showNewFile() {
            if (window.chooserMode) return;
            mode = "new_file";
            title = "New File";
            label = "Enter a name for the new file";
            placeholder = "File name";
            initialText = "Untitled.txt";
            confirmText = "Save";
            selectBasename = false;
            open();
        }

        function showRename(oldName, directory, isDirectory) {
            if (window.chooserMode) return;
            mode = "rename";
            targetItemName = oldName;
            targetDirectory = directory || engine.current_path;
            title = "Rename";
            label = "Enter a new name";
            initialText = oldName;
            confirmText = "Rename";
            selectBasename = !isDirectory;
            open();
        }

        onAccepted: function(text) {
            var val = (text || "").trim();
            if (val.length === 0)
                return;
            if (mode === "new_folder") {
                engine.create_folder(engine.current_path, val);
            } else if (mode === "new_file") {
                engine.create_file(engine.current_path, val);
            } else if (mode === "rename") {
                engine.rename_item(targetDirectory, targetItemName, val);
            }
        }
    }

    // ==========================================
    // OPEN WITH
    // ==========================================
    SeabunnyDialog {
        id: openWithModal
        title: "Open With"
        dialogWidth: Math.min(460, window.width - 32)
        property var paths: []
        property var applications: []
        property var details: ({})
        property string selectedApp: ""
        property string error: ""
        readonly property var filteredApps: applications.filter(function(app) {
            return app.name.toLowerCase().includes(applicationSearch.text.toLowerCase());
        })

        function showFor(items) {
            if (window.chooserMode || !items.length) return;
            paths = items.slice();
            details = JSON.parse(engine.open_with_apps(JSON.stringify(paths)) || "{}");
            applications = details.apps || [];
            error = details.error || "";
            applicationSearch.text = "";
            defaultApplication.checked = false;
            selectedApp = applications.length ? applications[0].id : "";
            open();
            applicationSearch.forceActiveFocus();
        }

        function launch() {
            if (!selectedApp.length) return;
            error = engine.open_with(JSON.stringify(paths), selectedApp,
                                     details.canSetDefault && defaultApplication.checked);
            if (!error.length) close();
        }

        Text {
            text: openWithModal.paths.length === 1 ? openWithModal.paths[0].split("/").pop()
                : openWithModal.paths.length + " selected items"
            color: theme.textMuted
            font.pixelSize: 12
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }
        TextField {
            id: applicationSearch
            objectName: "applicationSearch"
            Layout.fillWidth: true
            placeholderText: "Search applications"
            color: theme.textMain
            placeholderTextColor: theme.textMuted
            selectByMouse: true
            onTextChanged: {
                var needle = text.toLowerCase();
                var matches = openWithModal.applications.filter(function(app) { return app.name.toLowerCase().includes(needle); });
                openWithModal.selectedApp = matches.length ? matches[0].id : "";
            }
            Keys.onDownPressed: {
                if (applicationList.count) {
                    applicationList.currentIndex = 0;
                    openWithModal.selectedApp = openWithModal.filteredApps[0].id;
                    applicationList.forceActiveFocus();
                }
            }
            onAccepted: openWithModal.launch()
            background: Rectangle {
                implicitHeight: 36
                color: theme.surfaceContainer
                radius: theme.radiusM
                border.color: applicationSearch.activeFocus ? theme.primary : theme.outline
            }
        }
        ListView {
            id: applicationList
            objectName: "applicationList"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(260, window.height * 0.36)
            clip: true
            spacing: 2
            model: openWithModal.filteredApps
            onCurrentIndexChanged: {
                if (activeFocus && currentIndex >= 0 && currentIndex < count)
                    openWithModal.selectedApp = openWithModal.filteredApps[currentIndex].id;
            }
            Keys.onReturnPressed: openWithModal.launch()
            Keys.onEnterPressed: openWithModal.launch()
            ScrollBar.vertical: ScrollBar {}
            delegate: ItemDelegate {
                required property var modelData
                width: ListView.view.width
                height: 50
                onClicked: openWithModal.selectedApp = modelData.id
                contentItem: RowLayout {
                    spacing: 12
                    Image {
                        source: modelData.icon.startsWith("file:") ? modelData.icon : theme.resolveIcon(modelData.icon)
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        sourceSize: Qt.size(28, 28)
                        fillMode: Image.PreserveAspectFit
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: modelData.name
                            color: theme.textMain
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: modelData.isDefault || modelData.recommended
                            text: modelData.isDefault ? "Default application" : "Recommended"
                            color: theme.textMuted
                            font.pixelSize: 10
                        }
                    }
                    SeabunnyIcon {
                        name: "check"
                        visible: openWithModal.selectedApp === modelData.id
                        color: theme.primary
                        size: 18
                    }
                }
                background: Rectangle {
                    radius: theme.radiusM
                    color: openWithModal.selectedApp === parent.modelData.id ? theme.primaryContainer
                        : parent.hovered || parent.activeFocus ? theme.surfaceContainerHighest : "transparent"
                }
            }
            Text {
                anchors.centerIn: parent
                visible: applicationList.count === 0
                text: "No applications found"
                color: theme.textMuted
                font.pixelSize: 12
            }
        }
        SeabunnySwitch {
            id: defaultApplication
            objectName: "defaultApplicationSwitch"
            enabled: !!openWithModal.details.canSetDefault
            opacity: enabled ? 1 : 0.5
            label: "Use by default for this file type"
        }
        Text {
            text: openWithModal.details.canSetDefault
                ? "File type: " + (openWithModal.details.typeName || openWithModal.details.mimeType)
                : openWithModal.details.defaultNote || "Select items of one file type to set a default."
            color: theme.textMuted
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Text {
            visible: text.length > 0
            text: openWithModal.error
            color: theme.danger
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            SeabunnyButton { text: "Cancel"; onClicked: openWithModal.close() }
            SeabunnyButton {
                objectName: "openWithButton"
                text: "Open"
                variant: "filled"
                enabled: openWithModal.selectedApp.length > 0
                onClicked: openWithModal.launch()
            }
        }
    }

    // ==========================================
    // PROPERTIES MODAL
    // ==========================================
    SeabunnyDialog {
        id: propsModal
        title: "Properties"
        dialogWidth: 380

        property var info: ({})
        property int permissionMode: 0
        property string permissionError: ""
        readonly property bool permissionsEditable: !window.chooserMode && !!info.can_edit_permissions
        readonly property bool permissionsChanged: permissionMode !== ((info.permission_mode || 0) & 0o777)

        function showInfo(path) {
            info = JSON.parse(engine.get_item_info(path) || "{}");
            permissionMode = (info.permission_mode || 0) & 0o777;
            permissionError = "";
            open();
        }

        function setAccess(shift, access) {
            if (!permissionsEditable) return;
            var mask = (info.is_dir ? 7 : 6) << shift;
            permissionMode = (permissionMode & ~mask) | (access << shift);
            permissionError = "";
        }

        function setExecutable(checked) {
            if (!permissionsEditable || !info.is_regular) return;
            permissionMode = checked ? permissionMode | 0o100 | ((permissionMode & 0o444) >> 2)
                                     : permissionMode & ~0o111;
            permissionError = "";
        }

        function savePermissions() {
            if (!permissionsEditable || !permissionsChanged) return;
            var result = JSON.parse(engine.set_item_permissions(info.path, info.permission_identity,
                info.permission_mode, permissionMode) || "{}");
            if (result.error) { permissionError = result.error; return; }
            info = result;
            close();
        }

        component PermissionRow: RowLayout {
            property string label: ""
            property int shift: 0
            id: permissionRow
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: permissionRow.label
                color: theme.textMain
                font.pixelSize: 12
                Layout.preferredWidth: 80
            }
            ChooserComboBox {
                objectName: "permissionAccess" + permissionRow.shift
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                enabled: propsModal.permissionsEditable
                opacity: enabled ? 1 : 0.5
                Accessible.name: permissionRow.label + " access"
                readonly property int access: (propsModal.permissionMode >> permissionRow.shift) & (propsModal.info.is_dir ? 7 : 6)
                model: {
                    var options = propsModal.info.is_dir
                        ? [{label: "None", value: 0}, {label: "List files only", value: 4},
                           {label: "Access files", value: 5}, {label: "Create and delete files", value: 7}]
                        : [{label: "None", value: 0}, {label: "Read-only", value: 4},
                           {label: "Write-only", value: 2}, {label: "Read and write", value: 6}];
                    if (!options.some(function(option) { return option.value === access; }))
                        options.push({label: "Custom access (" + access.toString(8) + ")", value: access});
                    return options;
                }
                textRole: "label"
                currentIndex: model.findIndex(function(option) { return option.value === access; })
                onActivated: function(index) { propsModal.setAccess(permissionRow.shift, model[index].value); }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            SeabunnyIcon {
                visible: theme.usesGlyphIcons
                name: propsModal.info.icon || "file"
                size: 32
                color: theme.primary
            }
            Image {
                visible: !theme.usesGlyphIcons
                source: theme.iconUrl(propsModal.info.icon_path || "")
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                sourceSize: Qt.size(32, 32)
                fillMode: Image.PreserveAspectFit
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: propsModal.info.name || "-"
                    color: theme.textMain
                    font.pixelSize: 16
                    font.bold: true
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
                Text {
                    text: propsModal.info.is_symlink ? "Symbolic link" : propsModal.info.is_dir ? "Folder" : "File"
                    color: theme.textMuted
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: theme.separator
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Path: " + (propsModal.info.path || "-")
                color: theme.textMuted
                font.pixelSize: 11
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
            }
            Text {
                text: "Size: " + (propsModal.info.size || "-")
                color: theme.textMuted
                font.pixelSize: 11
            }
            Text {
                text: "Modified: " + (propsModal.info.modified || "-")
                color: theme.textMuted
                font.pixelSize: 11
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: "Permissions"
                color: theme.textMain
                font.pixelSize: 13
                font.bold: true
            }
            PermissionRow { label: "Owner"; shift: 6 }
            PermissionRow { label: "Group"; shift: 3 }
            PermissionRow { label: "Others"; shift: 0 }
            SeabunnySwitch {
                id: executableSwitch
                objectName: "makeExecutableSwitch"
                visible: !!propsModal.info.is_regular
                enabled: propsModal.permissionsEditable
                label: "Make executable"
                checked: (propsModal.permissionMode & 0o111) !== 0
                onToggled: function(checked) {
                    propsModal.setExecutable(checked);
                    executableSwitch.checked = Qt.binding(function() { return (propsModal.permissionMode & 0o111) !== 0; });
                }
            }
            Text {
                visible: !!propsModal.info.is_regular
                text: "Allow the owner and users with read access to run this file as a program."
                color: theme.textMuted
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Text {
                visible: text.length > 0
                text: propsModal.info.permissions_note || (!propsModal.info.permission_identity ? "Permissions are unavailable." : "")
                color: theme.textMuted
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Text {
                objectName: "permissionError"
                visible: text.length > 0
                text: propsModal.permissionError
                color: theme.danger
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            SeabunnyButton {
                text: propsModal.permissionsChanged ? "Cancel" : "Close"
                onClicked: propsModal.close()
            }
            SeabunnyButton {
                objectName: "savePermissionsButton"
                text: "Save"
                variant: "filled"
                enabled: propsModal.permissionsEditable && propsModal.permissionsChanged
                onClicked: propsModal.savePermissions()
            }
        }
    }

    // ==========================================
    // UNIFIED VIEW DROPDOWN
    // ==========================================
    SeabunnyMenu {
        id: viewMenuPopup
        menuMinWidth: 288
        menuMaxWidth: 360
        model: []

        Text {
            Layout.leftMargin: 6
            text: "VIEW"
            color: theme.textMuted
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.8
        }

        SeabunnySegmented {
            Layout.leftMargin: 2
            options: [
                { value: "grid", label: "Grid", icon: "squares-four" },
                { value: "list", label: "List", icon: "list" }
            ]
            value: engine.view_mode
            onSelected: function(v) { engine.view_mode = v; viewMenuPopup.close(); }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            color: theme.separator
        }

        Text {
            Layout.leftMargin: 6
            text: "SORT BY"
            color: theme.textMuted
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.8
        }

        SeabunnyMenuItem {
            text: "Name"
            checkable: true
            checked: engine.sort_by === "name"
            onTriggered: { engine.set_sort("name", engine.sort_ascending); viewMenuPopup.close(); }
        }
        SeabunnyMenuItem {
            text: "Date Modified"
            checkable: true
            checked: engine.sort_by === "modified"
            onTriggered: { engine.set_sort("modified", engine.sort_ascending); viewMenuPopup.close(); }
        }
        SeabunnyMenuItem {
            text: "Size"
            checkable: true
            checked: engine.sort_by === "size"
            onTriggered: { engine.set_sort("size", engine.sort_ascending); viewMenuPopup.close(); }
        }
        SeabunnyMenuItem {
            text: "Type"
            checkable: true
            checked: engine.sort_by === "type"
            onTriggered: { engine.set_sort("type", engine.sort_ascending); viewMenuPopup.close(); }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            color: theme.separator
        }

        Text {
            Layout.leftMargin: 6
            text: "ORDER"
            color: theme.textMuted
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.8
        }

        SeabunnySegmented {
            Layout.leftMargin: 2
            options: [
                { value: "asc", label: "Ascending", icon: "sort-ascending" },
                { value: "desc", label: "Descending", icon: "sort-descending" }
            ]
            value: engine.sort_ascending ? "asc" : "desc"
            onSelected: function(v) { engine.set_sort(engine.sort_by, v === "asc"); }
        }

        Text {
            Layout.leftMargin: 6
            Layout.topMargin: 4
            text: "FOLDERS"
            color: theme.textMuted
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.8
        }

        SeabunnySegmented {
            Layout.leftMargin: 2
            options: [
                { value: "first", label: "First" },
                { value: "last", label: "Last" },
                { value: "mixed", label: "Mixed" }
            ]
            value: engine.folder_position
            onSelected: function(v) { engine.change_folder_position(v); }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            color: theme.separator
        }

        SeabunnySwitch {
            Layout.topMargin: 2
            label: "Show Hidden Files"
            checked: engine.show_hidden
            onToggled: engine.toggle_show_hidden()
        }
    }

    // ==========================================
    // PASSWORD PROMPT FOR ENCRYPTED ARCHIVES
    // ==========================================
    SeabunnyTextPrompt {
        id: passwordModal

        property var paths: []
        property string format: "zip_encrypted"

        title: "Encrypted Archive"
        label: "Set a password to protect the archive"
        placeholder: "Password"
        confirmText: "Create"

        function openFor(targetPaths, fmt) {
            paths = targetPaths;
            format = fmt;
            initialText = "";
            open();
        }

        onAccepted: function(text) {
            if (!text || text.length === 0)
                return;
            engine.compress_items_with_options(JSON.stringify(paths), format, text);
        }
    }

    // ==========================================
    // RIGHT-MOUSE DRAG DROP MENU
    // ==========================================
    SeabunnyMenu {
        id: rmbDropMenu
        menuMinWidth: 200
        menuMaxWidth: 280

        property var dropPaths: []
        property string dropDest: ""

        function showAt(px, py, paths, dest) {
            // A same-directory drop is a silent no-op.
            var sameDir = paths.length > 0;
            for (var i = 0; i < paths.length; ++i) {
                var p = paths[i];
                var slash = p.lastIndexOf("/");
                var parent = slash > 0 ? p.substring(0, slash) : "/";
                if (parent !== dest) {
                    sameDir = false;
                    break;
                }
            }
            if (sameDir) {
                dragManager.end();
                return;
            }
            dropPaths = paths;
            dropDest = dest;
            model = [
                { text: "Copy Here", icon: "copy", action: function() {
                    window.handleDrop(rmbDropMenu.dropPaths, rmbDropMenu.dropDest, true);
                } },
                { text: "Move Here", icon: "arrows-out-cardinal", action: function() {
                    window.handleDrop(rmbDropMenu.dropPaths, rmbDropMenu.dropDest, false);
                } },
                { text: "Link Here", icon: "link", action: function() {
                    engine.create_symlinks(JSON.stringify(rmbDropMenu.dropPaths), rmbDropMenu.dropDest);
                } },
                { text: "Cancel", icon: "x", danger: true, separatorBefore: true, action: function() {
                    dragManager.end();
                } }
            ];
            openAt(px, py);
        }
    }

    // ==========================================
    // CONFLICT RESOLUTION MODAL
    // ==========================================
    SeabunnyDialog {
        id: conflictModal
        title: resolvingMerge ? "File Already Exists" : "File Conflict"
        dialogWidth: canMerge || resolvingMerge ? Math.min(560, window.width - 32) : 420

        property var conflicts: []
        property var droppedPaths: []
        property string destDir: ""
        property bool isDrop: false
        property bool asCopy: false
        readonly property bool canMerge: conflicts.some(function(item) { return !!item.can_merge; })
        property bool resolvingMerge: false
        property var mergeConflicts: []
        property int mergeIndex: 0
        property var mergeChoices: ({})
        property string mergeError: ""

        function showForClipboard(confList, dest) {
            resolvingMerge = false;
            mergeError = "";
            conflicts = confList;
            destDir = dest;
            isDrop = false;
            open();
        }

        function showForDrop(confList, paths, dest, copy) {
            resolvingMerge = false;
            mergeError = "";
            conflicts = confList;
            droppedPaths = paths;
            destDir = dest;
            isDrop = true;
            asCopy = copy;
            open();
        }

        function applyResolution(res) {
            if (res === "merge") {
                var scan = JSON.parse(isDrop ? engine.check_merge_conflicts(JSON.stringify(droppedPaths), destDir)
                                            : engine.check_clipboard_merge_conflicts(destDir));
                if (scan.error) { mergeError = scan.error; return; }
                mergeConflicts = scan.conflicts || [];
                mergeChoices = ({});
                mergeIndex = 0;
                applyToAllConflicts.checked = false;
                if (mergeConflicts.length) {
                    resolvingMerge = true;
                    conflicts = [mergeConflicts[0]];
                    return;
                }
                res = JSON.stringify({mode: "merge", collisions: {}});
            }
            if (isDrop) {
                engine.drop_items_resolved(JSON.stringify(droppedPaths), destDir, asCopy, res);
            } else {
                engine.paste_items_resolved(destDir, res);
            }
            close();
        }

        function chooseMergeFile(choice) {
            var end = applyToAllConflicts.checked ? mergeConflicts.length : mergeIndex + 1;
            for (var index = mergeIndex; index < end; index++) mergeChoices[mergeConflicts[index].src_path] = choice;
            mergeIndex = end;
            if (mergeIndex < mergeConflicts.length) conflicts = [mergeConflicts[mergeIndex]];
            else applyResolution(JSON.stringify({mode: "merge", collisions: mergeChoices}));
        }

        Text {
            Layout.fillWidth: true
            text: conflictModal.resolvingMerge
                ? ("Conflict " + (conflictModal.mergeIndex + 1) + " of " + conflictModal.mergeConflicts.length + ". Choose which copy to keep.")
                : conflictModal.conflicts.length === 1
                ? ("\u201c" + conflictModal.conflicts[0].name + "\u201d already exists.")
                : (conflictModal.conflicts.length + " items already exist in this destination.")
            color: theme.textMuted
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Rectangle {
            visible: conflictModal.conflicts.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: theme.radiusM
            color: theme.surfaceContainer

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                SeabunnyIcon {
                    name: (conflictModal.conflicts[0] && conflictModal.conflicts[0].is_dir) ? "folder" : "file"
                    size: 20
                    color: theme.textMuted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: conflictModal.conflicts[0] ? conflictModal.conflicts[0].name : ""
                        color: theme.textMain
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                    Text {
                        text: conflictModal.conflicts[0] ? (conflictModal.resolvingMerge
                            ? "Incoming: " + conflictModal.conflicts[0].src_size + " · Existing: " + conflictModal.conflicts[0].dest_size
                            : "Destination size: " + conflictModal.conflicts[0].dest_size) : ""
                        color: theme.outline
                        font.pixelSize: 11
                    }
                }
            }
        }

        Text {
            visible: conflictModal.canMerge
            text: "Merge combines matching folders. You can choose what to keep for any files with the same name."
            color: theme.textMuted
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        SeabunnySwitch {
            id: applyToAllConflicts
            objectName: "applyToAllConflictsSwitch"
            visible: conflictModal.resolvingMerge
            label: "Apply to all remaining conflicts"
        }

        Text {
            visible: text.length > 0
            text: conflictModal.mergeError
            color: theme.danger
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            SeabunnyButton {
                text: "Cancel"
                variant: "text"
                onClicked: conflictModal.close()
            }
            Item { Layout.fillWidth: true }
            SeabunnyButton {
                text: "Skip"
                visible: !conflictModal.resolvingMerge
                variant: "tonal"
                onClicked: conflictModal.applyResolution("skip")
            }
            SeabunnyButton {
                objectName: "keepBothMergeButton"
                text: "Keep Both"
                variant: "tonal"
                onClicked: conflictModal.resolvingMerge ? conflictModal.chooseMergeFile("keep_both") : conflictModal.applyResolution("rename")
            }
            SeabunnyButton {
                objectName: "keepExistingMergeButton"
                text: "Keep Existing"
                visible: conflictModal.resolvingMerge
                variant: "tonal"
                onClicked: conflictModal.chooseMergeFile("keep_existing")
            }
            SeabunnyButton {
                objectName: "replaceExistingMergeButton"
                text: conflictModal.resolvingMerge ? "Replace Existing" : "Replace"
                variant: "filled"
                onClicked: conflictModal.resolvingMerge ? conflictModal.chooseMergeFile("replace") : conflictModal.applyResolution("overwrite")
            }
            SeabunnyButton {
                objectName: "mergeFoldersButton"
                visible: conflictModal.canMerge
                text: "Merge"
                variant: "filled"
                onClicked: conflictModal.applyResolution("merge")
            }
        }
    }
}
