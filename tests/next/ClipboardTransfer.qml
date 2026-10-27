import QtQuick
import QtTest
import app.seabunny

Item {
    id: checks
    SeabunnyCore { id: settings }
    TestEvent { id: events }
    property var window: null
    property int phase: 0
    property int attempts: 0
    readonly property bool writer: settings.get_setting("role") === "writer"
    readonly property string base: settings.user_dir("HOME") + "/work"
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                if (++attempts > 200) throw new Error("transfer timeout");
                if (!window) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    window = component.createObject(null);
                    window.benchmarkTheme.reduceMotionSetting = true;
                    window.benchmarkEngine.set_path(writer ? base : base + "/destination");
                    window.requestActivate(); return;
                }
                if (window.benchmarkEngine.loading || !window.active) return;
                if (phase === 0) {
                    window.benchmarkKeys.forceActiveFocus();
                    if (writer) {
                        var grid = window.benchmarkContainer;
                        var index = -1;
                        for (var i = 0; i < window.engine.item_count; i++) if (JSON.parse(window.engine.item_json(i)).name === "a # 日本語.txt") { index = i; break; }
                        if (index < 0) throw new Error("missing transfer source");
                        grid.selectRow(index, false, false);
                        events.keyClick(settings.get_setting("cut") === "yes" ? Qt.Key_X : Qt.Key_C, Qt.ControlModifier, 1);
                        console.log("TRANSFER_READY");
                    } else events.keyClick(Qt.Key_V, Qt.ControlModifier, 1);
                    phase++;
                } else if (!writer) {
                    var info = JSON.parse(settings.get_item_info(base + "/destination/a # 日本語.txt"));
                    if (!info.exists) return;
                    console.log("TRANSFER_PASSED"); Qt.quit();
                }
            } catch (error) { console.error("TRANSFER_FAILED " + error); Qt.exit(1); }
        }
    }
}
