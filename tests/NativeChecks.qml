import QtQuick
import app.seabunny

Item {
    id: checks
    SeabunnyEngine { id: engine }
    SeabunnyEngine { id: otherEngine }
    Theme { id: theme }
    property int phase: 0
    property int attempts: 0
    property string home: engine.place_path("")

    function verify(condition, message) {
        if (!condition) throw new Error(message);
        console.log("PASS " + message);
    }

    Timer {
        interval: 20
        running: true
        repeat: true
        onTriggered: {
            try {
                if (++checks.attempts > 500) throw new Error("native regression timeout");
                if (checks.phase === 0) {
                    engine.set_path(checks.home + "/large");
                    engine.set_path(checks.home + "/small");
                    otherEngine.set_path(checks.home + "/large");
                    checks.phase = 1;
                } else if (checks.phase === 1 && !engine.is_loading && !otherEngine.is_loading) {
                    verify(JSON.parse(engine.files_json).length === 1, "stale large-directory work cannot overwrite the newer small folder");
                    verify(JSON.parse(otherEngine.files_json).length === 1200, "independent engine retains its own directory model");
                    engine.go_back();
                    checks.phase = 2;
                } else if (checks.phase === 2 && !engine.is_loading) {
                    verify(engine.current_path === checks.home + "/large", "back history returns to the previous directory");
                    engine.go_forward();
                    checks.phase = 3;
                } else if (checks.phase === 3 && !engine.is_loading) {
                    verify(engine.current_path === checks.home + "/small", "forward history survives asynchronous loading");
                    verify(otherEngine.current_path === checks.home + "/large" && otherEngine.can_go_back && !otherEngine.can_go_forward,
                           "one engine's navigation cannot overwrite another's history");
                    engine.set_path(checks.home + "/missing");
                    verify(engine.navigation_error.length > 0 && engine.current_path === checks.home + "/small",
                           "missing directory reports a useful error without changing the active path");
                    verify(engine.place_path("Pictures") === checks.home + "/Resimler ö",
                           "XDG Pictures location is independent of the current folder");
                    engine.search_everywhere("file");
                    engine.set_path(checks.home + "/small");
                    checks.phase = 4;
                } else if (checks.phase === 4 && !engine.is_loading) {
                    verify(!engine.is_searching_everywhere && JSON.parse(engine.files_json).length === 1,
                           "stale recursive search cannot replace a newer directory");
                    theme.accentName = "serpantinum";
                    theme.themeMode = "light";
                    verify(!theme.isDark && theme.background.r > 0.8 && theme.textMain.r < 0.2,
                           "forced light mode applies immediately with the Serpantinum source");
                    verify(engine.get_setting("themeMode") === "light", "theme-mode selection is persisted by the real Rust settings backend");
                    theme.themeMode = "dark";
                    verify(theme.isDark, "forced dark mode applies immediately");
                    theme.themeMode = "auto";
                    verify(theme.followsSerpantinum, "Auto retains Serpantinum palette synchronization");
                    verify(engine.update_favorite(checks.home + "/small", "Saved folder ö", false), "favorites can be pinned with Unicode labels");
                    verify(engine.update_favorite(checks.home + "/small/.", "Duplicate", false)
                           && JSON.parse(engine.favorites_json()).length === 1, "canonical folder aliases cannot create duplicate favorites");
                    verify(!engine.update_favorite(checks.home + "/missing", "Missing", false), "missing folders cannot be silently pinned");
                    verify(JSON.parse(otherEngine.favorites_json())[0].label === "Saved folder ö", "separate engines read the same durable favorites file");
                    console.log("NATIVE_CHECKS_PASSED");
                    Qt.quit();
                }
            } catch (error) {
                console.error("NATIVE_CHECKS_FAILED " + error);
                Qt.quit();
            }
        }
    }
}
