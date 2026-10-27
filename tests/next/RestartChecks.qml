import QtQuick
import app.seabunny
Item {
    id: test
    SeabunnyCore { id: settings }
    property var explorer: null
    property var picker: null
    property int phase: 0
    property int attempts: 0
    readonly property bool saving: settings.get_setting("restart_role") === "save"
    readonly property string base: settings.user_dir("HOME")
    QtObject {
        id: request
        property var config: ({title:"Restart test",save:false,directory:false,multiple:false,
            folder:base + "/work",name:"",filters:[],filterIndex:-1,choices:[],acceptLabel:"Open",acceptKey:""})
        function filterRules(index) { return "[]"; }
        function cancel() {}
        function saveName(name, index) { return name; }
        function accept() { return {}; }
    }
    function create(chooser) {
        var component = Qt.createComponent("file://" + settings.get_setting("test_ui"));
        if (component.status !== Component.Ready) throw new Error(component.errorString());
        return component.createObject(null, {chooser:chooser});
    }
    function check(value, message) { if (!value) throw new Error(message); console.log("PASS " + message); }
    Timer {
        id: timer
        interval:100; repeat:true; running:true
        onTriggered: {
            try {
                if (++attempts > 100) throw new Error("restart test timed out");
                if (!explorer) { explorer = create(null); explorer.engine.set_path(base + "/work"); return; }
                if (explorer.engine.loading) return;
                if (phase === 0) {
                    if (saving) {
                        explorer.testSidebar.expanded = false; explorer.testSidebar.expandedWidth = 376;
                        explorer.engine.set_sort("size", false);
                        explorer.testTheme.gridItemSize = 320;
                    } else {
                        check(!explorer.testSidebar.expanded && explorer.testSidebar.expandedWidth === 376, "explorer restores collapsed state and width after process relaunch");
                        check(explorer.testTheme.gridItemSize === 320, "grid zoom survives process relaunch");
                        check(explorer.engine.sort_by === "size" && !explorer.engine.sort_ascending, "folder sorting survives process relaunch");
                    }
                    picker = create(request); phase++; return;
                }
                if (picker.engine.loading) return;
                if (phase === 1) {
                    if (saving) {
                        picker.testSidebar.expanded = false; picker.testSidebar.expandedWidth = 244;
                        explorer.close(); picker.close();
                        timer.stop(); console.log("RESTART_CHECKS_PASSED"); Qt.quit(); return;
                    }
                    else check(!picker.testSidebar.expanded && picker.testSidebar.expandedWidth === 244, "picker restores independent collapsed state and width after process relaunch");
                    phase++; return;
                }
                if (phase < 5) { phase++; return; } // Let the atomic persistence timer finish.
                timer.stop(); console.log("RESTART_CHECKS_PASSED"); Qt.quit();
            } catch (error) { console.error("RESTART_CHECKS_FAILED " + error); Qt.exit(1); }
        }
    }
}
