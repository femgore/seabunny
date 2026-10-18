import QtQuick
import app.seabunny

Item {
    id: checks
    SeabunnyEngine { id: settings }
    property var window: null
    property int attempts: 0
    Timer {
        interval: 80
        running: true
        repeat: true
        onTriggered: {
            try {
                if (++checks.attempts > 150) throw new Error("startup checks timed out");
                if (!checks.window) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    checks.window = component.createObject(null);
                    return;
                }
                var tabs = checks.window.benchmarkTabs;
                if (tabs.entries.some(function(entry) { return entry.engine.is_loading; })) return;
                if (tabs.entries.length !== 2 || tabs.entries[0].engine.current_path !== settings.get_setting("outside_fixture"))
                    throw new Error("desktop folder URI did not override saved tabs");
                console.log("PASS Seabunny accepts desktop-entry file URIs and opens the intended folder");
                if (!tabs.entries[1].engine.archive_path.endsWith("Sample # 日本語.zip"))
                    throw new Error("archive URI did not create a browsing tab");
                console.log("PASS archive paths with spaces and Unicode open from command-line arguments");
                if (!checks.window.title.startsWith("Seabunny - ")) throw new Error("old window branding remains");
                console.log("PASS native window title uses Seabunny branding");
                running = false;
                console.log("STARTUP_CHECKS_PASSED");
                Qt.quit();
            } catch (error) {
                console.error("STARTUP_CHECKS_FAILED", error);
                Qt.exit(1);
            }
        }
    }
}
