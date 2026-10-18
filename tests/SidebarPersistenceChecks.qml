import QtQuick
import app.seabunny

Item {
    id: checks
    SeabunnyEngine { id: settings }
    property var browser: null
    property int attempts: 0
    QtObject {
        id: request
        readonly property var config: ({title: "Sidebar persistence fixture", folder: settings.place_path(""),
            save: false, directory: false, multiple: false, name: "", filters: [], filterIndex: -1,
            choices: [], acceptLabel: "Open"})
        function matches(path, filter) { return true; }
        function cancel() {}
    }
    function verify(value, message) {
        if (!value) throw new Error(message);
        console.log("PASS " + message);
    }
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            try {
                if (++checks.attempts > 100) throw new Error("sidebar persistence checks timed out");
                var role = settings.get_setting("sidebar_test_role");
                if (!checks.browser) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    checks.browser = component.createObject(null, role === "chooser" ? {chooser: request} : {});
                    return;
                }
                var w = checks.browser;
                if (w.engine.is_loading) return;
                var stage = settings.get_setting("sidebar_test_stage");
                verify(w.sidebarExpanded === (settings.get_setting("sidebar_expected_expanded") === "true"),
                    role + " restores its expanded/collapsed state in a fresh process (" + stage + ")");
                verify(w.expandedSidebarWidth === Number(settings.get_setting("sidebar_expected_width")),
                    role + " restores its preferred width in a fresh process (" + stage + ")");
                if (stage === "expand") {
                    w.sidebarExpanded = true;
                    w.resizeSidebar(role === "chooser" ? 350 : 410);
                    w.saveSidebarWidth();
                } else if (stage === "collapse") {
                    w.sidebarExpanded = false;
                }
                w.close();
                console.log("SIDEBAR_PERSISTENCE_PASSED");
                Qt.quit();
            } catch (error) {
                console.error("SIDEBAR_PERSISTENCE_FAILED", error);
                Qt.quit();
            }
        }
    }
}
