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
    property string stage: settings.get_setting("sort_ui_stage")
    property string home: settings.place_path("")

    function verify(ok, message) {
        if (!ok) throw new Error(message);
        console.log("PASS " + message);
    }
    function verifySort(ascending, folders, message) {
        var engine = window.engine;
        verify(engine.sort_by === "name" && engine.sort_ascending === ascending
               && engine.folder_position === folders, message + " backend");
        verify(window.benchmarkOrder.value === (ascending ? "asc" : "desc")
               && window.benchmarkFolders.value === folders, message + " menu indicators");
        var files = JSON.parse(engine.files_json);
        var names = files.filter(function(item) { return !item.is_dir; }).map(function(item) { return item.name; });
        verify(names.join(",") === (ascending ? "alpha.txt,zulu.txt" : "zulu.txt,alpha.txt"), message + " visible file order");
        if (folders === "first") verify(files[0].is_dir, message + " folders first");
    }
    function clickOption(control, index, count) {
        events.mouseClick(control, control.width * (index + 0.5) / count,
                          control.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (checks.stepping) return;
            checks.stepping = true;
            try {
                if (++checks.attempts > 250) throw new Error("sort UI timeout at " + checks.phase);
                if (!checks.window) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    checks.window = component.createObject(null);
                    window.benchmarkTheme.reducedMotion = true;
                    window.engine.set_path(checks.home + "/Sort A");
                    window.requestActivate();
                    return;
                }
                var w = checks.window;
                if (w.engine.is_loading) return;
                switch (checks.phase) {
                case 0:
                    w.benchmarkMenu.open(); break;
                case 1:
                    verifySort(stage === "seed", stage === "seed" ? "mixed" : "first", "initial folder after relaunch");
                    if (stage === "seed") clickOption(w.benchmarkOrder, 1, 2);
                    else if (stage === "reset") clickOption(w.benchmarkOrder, 0, 2);
                    break;
                case 2:
                    if (stage === "seed") {
                        verify(!w.engine.sort_ascending, "actual descending-menu click updates the backend");
                        clickOption(w.benchmarkFolders, 0, 3);
                    } else if (stage === "reset") clickOption(w.benchmarkFolders, 2, 3);
                    break;
                case 3:
                    verifySort(stage === "reset", stage === "reset" ? "mixed" : "first", "chosen folder preferences");
                    w.benchmarkMenu.close(); w.engine.set_path(checks.home + "/Sort B"); break;
                case 4:
                    w.benchmarkMenu.open(); break;
                case 5:
                    verifySort(true, "mixed", "another folder keeps its defaults");
                    w.benchmarkMenu.close(); w.engine.go_back(); break;
                case 6:
                    w.benchmarkMenu.open(); break;
                case 7:
                    verifySort(stage === "reset", stage === "reset" ? "mixed" : "first", "Back restores folder preferences");
                    w.benchmarkMenu.close(); w.engine.go_forward(); break;
                case 8:
                    w.benchmarkMenu.open(); break;
                case 9:
                    verifySort(true, "mixed", "Forward restores the other folder's defaults");
                    w.benchmarkMenu.close();
                    verify(w.openFolderTab(checks.home + "/Sort A", false), "open the custom-sorted folder in another tab");
                    break;
                case 10:
                    w.benchmarkMenu.open(); break;
                case 11:
                    verifySort(stage === "reset", stage === "reset" ? "mixed" : "first", "new tab restores folder preferences");
                    w.benchmarkMenu.close(); w.benchmarkTabs.cycle(-1); break;
                case 12:
                    w.benchmarkMenu.open(); break;
                case 13:
                    verifySort(true, "mixed", "switching tabs restores the other folder's defaults");
                    console.log("FOLDER_SORT_UI_PASSED"); Qt.quit(); break;
                }
                checks.phase++;
            } catch (error) {
                console.error("FOLDER_SORT_UI_FAILED " + error); Qt.exit(1);
            } finally { checks.stepping = false; }
        }
    }
}
