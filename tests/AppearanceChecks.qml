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
    property int choice: 0
    property bool stepping: false
    property real previousWidth: 0
    readonly property var choices: ["system", "adwaita", "serpantinum", "phosphor"]

    function verify(value, message) {
        if (!value) throw new Error(message);
        console.log("PASS " + message);
    }
    function find(root, name) {
        if (root.objectName === name) return root;
        for (var index = 0; index < root.children.length; index++) {
            var result = find(root.children[index], name);
            if (result) return result;
        }
        return null;
    }

    Timer {
        interval: 80
        running: true
        repeat: true
        onTriggered: {
            if (checks.stepping) return;
            checks.stepping = true;
            try {
                if (++checks.attempts > 250) throw new Error("appearance checks timed out at phase " + checks.phase);
                if (!checks.window) {
                    var component = Qt.createComponent("file://" + settings.get_setting("ui_source"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    checks.window = component.createObject(null);
                    checks.window.benchmarkTheme.reducedMotion = true;
                    checks.window.benchmarkTheme.showThumbnails = false;
                    checks.window.sidebarExpanded = true;
                    checks.window.benchmarkEngine.set_path(settings.place_path("") + "/previews");
                    return;
                }
                var window = checks.window;
                var theme = window.benchmarkTheme;
                var engine = window.benchmarkEngine;
                if (engine.is_loading) return;
                if (checks.phase === 0) {
                    theme.iconSource = checks.choices[checks.choice];
                    checks.phase = 1;
                } else if (checks.phase === 1) {
                    var card = window.benchmarkView.itemAtIndex(0);
                    var icon = find(card, theme.usesGlyphIcons ? "fileGlyphIcon" : "fileSystemIcon");
                    verify(icon && icon.visible && (theme.usesGlyphIcons ? icon.primaryGlyph.length > 0 : icon.status === Image.Ready),
                           checks.choices[checks.choice] + " icons render immediately in the actual file grid");
                    verify(engine.get_setting("iconSource") === checks.choices[checks.choice], "icon choice is saved: " + checks.choices[checks.choice]);
                    if (theme.iconSource === "serpantinum") verify(theme.symbolsFontFamily.length > 0 && icon.usesSymbols, "Serpantinum glyphs use the bundled Nerd Symbols font");
                    if (++checks.choice < checks.choices.length) { checks.phase = 0; return; }
                    checks.previousWidth = window.expandedSidebarWidth;
                    var handle = window.benchmarkResize;
                    var notch = find(handle, "sidebarResizeNotch");
                    verify(handle.parent.height === handle.height && handle.y === 0
                           && notch.height === 30 && Math.abs(notch.y + notch.height / 2 - handle.height / 2) < 1,
                           "resize indicator is a short notch centered inside the sidebar edge");
                    events.mousePress(handle, 4, 80, Qt.LeftButton, Qt.NoModifier, 1);
                    events.mouseMove(handle, 74, 80, 5, Qt.LeftButton, Qt.NoModifier);
                    events.mouseRelease(handle, 4, 80, Qt.LeftButton, Qt.NoModifier, 1);
                    checks.phase = 2;
                } else if (checks.phase === 2) {
                    verify(window.expandedSidebarWidth > checks.previousWidth + 40, "actual divider dragging resizes the sidebar");
                    verify(Number(engine.get_setting("sidebarWidth")) === window.expandedSidebarWidth, "dragged sidebar width is persisted");
                    window.resizeSidebar(1);
                    verify(window.expandedSidebarWidth === 180, "sidebar minimum width is enforced");
                    window.resizeSidebar(10000);
                    verify(window.expandedSidebarWidth === window.maximumSidebarWidth, "sidebar maximum preserves usable file space");
                    window.sidebarExpanded = false;
                    window.sidebarExpanded = true;
                    verify(window.expandedSidebarWidth === window.maximumSidebarWidth, "collapse and expand preserve the chosen width");
                    verify(theme.durationFast === 0 && theme.durationNormal === 0 && theme.motionDuration(250) === 0,
                           "reduced motion removes transition durations");
                    theme.reducedMotion = false;
                    window.sidebarExpanded = false;
                    theme.reducedMotion = true;
                    checks.phase = 3;
                } else if (checks.phase === 3) {
                    verify(engine.get_setting("reducedMotion") === "true", "reduced motion selection is persisted");
                    window.activeView = "settings";
                    window.benchmarkSettings.activeTab = 1;
                    checks.phase = 4;
                } else if (checks.phase === 4) {
                    var control = find(window.benchmarkSettings, "reducedMotionSwitch");
                    verify(control && control.checked, "Behavior settings exposes the active reduced-motion switch");
                    events.mouseClick(control, control.width - 18, control.height / 2, Qt.LeftButton, Qt.NoModifier, 1);
                    checks.phase = 5;
                } else if (checks.phase === 5) {
                    verify(!theme.reducedMotion && theme.durationFast > 0, "actual settings switch restores normal animations immediately");
                    checks.phase = 6;
                    console.log("APPEARANCE_CHECKS_PASSED");
                    Qt.quit();
                }
            } catch (error) {
                console.error("APPEARANCE_CHECKS_FAILED " + error);
                Qt.quit();
            } finally { checks.stepping = false; }
        }
    }
}
