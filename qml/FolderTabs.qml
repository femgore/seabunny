import QtQuick
import app.seabunny

Item {
    id: tabs
    visible: false
    required property var settingsEngine
    property var entries: []
    property int currentIndex: -1
    property var activeEngine: null
    readonly property int limit: 24
    property bool persistent: true
    property bool restoring: false
    property var dirtySearches: []
    required property var captureState
    signal activated(var entry)
    signal navigated()

    Component {
        id: engineFactory
        SeabunnyEngine {
            onCurrent_pathChanged: tabs.pathChanged(this)
            onFile_operation_finished: tabs.refreshOtherTabs(this)
        }
    }

    Timer {
        id: saveTimer
        interval: 200
        onTriggered: tabs.persist()
    }

    function persist() {
        if (!persistent || restoring || !entries.length) return;
        settingsEngine.set_setting("folderTabs", JSON.stringify({version: 1,
            paths: entries.map(function(entry) { return entry.engine.current_path; }), active: currentIndex}));
    }

    function restore() {
        restoring = true;
        var saved = null;
        try { saved = JSON.parse(settingsEngine.get_setting("folderTabs")); } catch (error) {}
        var paths = saved && saved.version === 1 && Array.isArray(saved.paths) ? saved.paths.slice(0, limit) : [];
        var requested = JSON.parse(settingsEngine.startup_locations());
        if (requested.length) { paths = requested.slice(0, limit); saved = {active: 0}; }
        var selected = 0;
        paths.forEach(function(path, index) {
            if (typeof path !== "string" || !settingsEngine.valid_location(path)) return;
            if (index === saved.active) selected = entries.length;
            open(path, true);
        });
        if (!entries.length) open(settingsEngine.place_path(""), true);
        restoring = false;
        activate(selected);
    }

    function open(path, background) {
        if (entries.length >= limit || !settingsEngine.valid_location(path)) return false;
        var backend = engineFactory.createObject(tabs);
        if (!backend) return false;
        backend.set_path(path);
        var previousState = currentIndex >= 0 ? captureState() : null;
        var next = entries.slice();
        if (currentIndex >= 0) next[currentIndex] = {engine: activeEngine, state: previousState};
        entries = next.concat([{engine: backend, state: null}]);
        if (!background) activate(entries.length - 1, previousState);
        else if (currentIndex >= 0) activated(entries[currentIndex]);
        saveTimer.restart();
        return true;
    }

    function activate(index, previousState) {
        if (index < 0 || index >= entries.length || index === currentIndex) return;
        if (currentIndex >= 0) {
            var next = entries.slice();
            next[currentIndex] = {engine: activeEngine, state: previousState === undefined ? captureState() : previousState};
            entries = next;
        }
        currentIndex = index;
        activeEngine = entries[index].engine;
        activeEngine.sync_shared_state();
        activated(entries[index]);
        if (dirtySearches.indexOf(activeEngine) >= 0) {
            dirtySearches = dirtySearches.filter(function(backend) { return backend !== tabs.activeEngine; });
            activeEngine.search_everywhere(entries[index].state ? entries[index].state.query : "");
        }
        saveTimer.restart();
    }

    function close(index) {
        if (index < 0 || index >= entries.length) return;
        if (entries.length === 1) { persist(); Qt.quit(); return; }
        if (index === currentIndex) activate(index > 0 ? index - 1 : 1);
        var state = captureState();
        var backend = entries[index].engine;
        var next = entries.slice();
        next.splice(index, 1);
        var active = currentIndex > index ? currentIndex - 1 : currentIndex;
        next[active] = {engine: activeEngine, state: state};
        entries = next;
        currentIndex = active;
        activated(entries[active]);
        dirtySearches = dirtySearches.filter(function(item) { return item !== backend; });
        backend.destroy();
        saveTimer.restart();
    }

    function move(index, destination) {
        if (index < 0 || destination < 0 || index >= entries.length || destination >= entries.length || index === destination) return;
        var active = entries[currentIndex];
        var next = entries.slice();
        next.splice(destination, 0, next.splice(index, 1)[0]);
        entries = next;
        currentIndex = next.indexOf(active);
        saveTimer.restart();
    }

    function cycle(delta) {
        if (entries.length) activate((currentIndex + delta + entries.length) % entries.length);
    }

    function pathChanged(backend) {
        if (backend === activeEngine) navigated();
        if (!restoring) saveTimer.restart();
    }

    function refreshOtherTabs(source) {
        entries.forEach(function(entry) {
            if (entry.engine === source) return;
            if (!entry.engine.is_searching_everywhere) entry.engine.refresh();
            else if (dirtySearches.indexOf(entry.engine) < 0) dirtySearches = dirtySearches.concat([entry.engine]);
        });
    }
}
