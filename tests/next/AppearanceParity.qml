import QtQuick
import QtTest
import app.seabunny
Item {
    id: checks
    SeabunnyCore { id: settings }
    TestEvent { id: events }
    TestResult { id: pixels }
    property var window: null
    property bool stepping: false
    property int phase: 0
    property int attempts: 0
    property int initialColumns: 0
    property real initialWidth: 0
    property bool captured: false
    readonly property string base: settings.user_dir("HOME")
    function check(ok, message) { if (!ok) throw new Error(message); console.log("PASS " + message); }
    function find(root, predicate) {
        if (predicate(root)) return root;
        var children = root.children || [];
        for (var i=0;i<children.length;i++) { var found=find(children[i],predicate); if (found) return found; }
        return null;
    }
    function named(root, name) { return find(root,function(item){return item.objectName === name;}); }
    function card(name) { return find(window.activePane,function(item){return item.objectName === "fileCard" && item.path === base + "/work/" + name;}); }
    function capture(name, target) {
        var directory=settings.get_setting("capture_dir");
        if (directory) (target || window.activePane).grabToImage(function(result) {
            if (!result.saveToFile(directory+"/"+name+".png")) console.error("Could not save synthetic screenshot");
        });
    }
    function menuIndex() {
        for (var i=0;i<window.testMenu.model.length;i++) if (window.testMenu.model[i].itemKey === "open_with") return i;
        return -1;
    }
    Timer {
        id: timer
        interval:60;repeat:true;running:true
        onTriggered: {
            if (checks.stepping) return;
            checks.stepping=true;
            try {
                if (++attempts > 500) throw new Error("appearance timeout at phase " + phase);
                if (!window) {
                    var component=Qt.createComponent("file://"+settings.get_setting("test_ui"));
                    if (component.status !== Component.Ready) throw new Error(component.errorString());
                    window=component.createObject(null,{chooser:null}); window.requestActivate();
                    window.engine.set_path(base+"/work"); return;
                }
                var w=window, pane=w.activePane, theme=w.testTheme;
                if (w.engine.loading || w.testCore.busy) return;
                var grid=find(pane,function(item){return item.cellWidth !== undefined && typeof item.positionViewAtIndex === "function";});
                switch (phase) {
                case 0:
                    check(theme.accentName === "auto" && theme.followsSerpantinum && theme.primary.toString() === "#abcdef", "fresh profiles automatically follow the desktop palette");
                    theme.reduceMotionSetting=false; theme.lowPowerSetting="off";
                    w.testSidebar.expanded=true; w.testSidebar.expandedWidth=300; break;
                case 1:
                    if (Math.abs(w.testSidebar.width-300)>1) return;
                    check(theme.animate,"sidebar drag is tested with animations enabled");
                    var handle=named(w.testSidebar,"sidebarResizeHandle");
                    initialWidth=w.testSidebar.width;
                    events.mousePress(handle,4,80,Qt.LeftButton,Qt.NoModifier,1);
                    events.mouseMove(handle,74,80,5,Qt.LeftButton,Qt.NoModifier); break;
                case 2:
                    check(w.testSidebar.resizing && w.testSidebar.expandedWidth>initialWidth+60,"actual sidebar drag updates the requested width");
                    check(Math.abs(w.testSidebar.width-w.testSidebar.expandedWidth)<2,"sidebar follows the pointer within one frame interval without trailing animations");
                    events.mouseRelease(named(w.testSidebar,"sidebarResizeHandle"),4,80,Qt.LeftButton,Qt.NoModifier,1);
                    theme.reduceMotionSetting=true; w.testSidebar.expandedWidth=300; break;
                case 3:
                    var photo=card("image.png"), thumb=photo ? named(photo,"fileThumbnail") : null;
                    if (!thumb || thumb.status !== Image.Ready) return;
                    var rendered=pixels.grabImage(window.contentItem);
                    var center=thumb.mapToItem(window.contentItem,thumb.width/2,thumb.height/2);
                    var px=Math.floor(center.x), py=Math.floor(center.y);
                    check(rendered.red(px,py)>240 && rendered.green(px,py)<20 && rendered.blue(px,py)<20,
                        "thumbnail pixels remain visible on the software renderer even with low-power mode disabled");
                    if (!captured && settings.get_setting("capture_dir")) { captured=true; capture("grid"); return; }
                    check(grid && grid.cellWidth >= 220 && grid.cellHeight === grid.cellWidth,"default file grid uses large square cells");
                    check(thumb.width>150 && thumb.height>140 && thumb.sourceSize.width>=256,"image previews fill the card and request enough pixels");
                    initialColumns=pane.gridColumns;
                    events.mouseWheel(photo,20,20,Qt.NoButton,Qt.ControlModifier,0,120,1); break;
                case 4:
                    check(pane.gridColumns === initialColumns-1,"Ctrl+wheel over a file removes exactly one column");
                    check(Math.abs(grid.cellWidth*pane.gridColumns-grid.width)<0.01,"zoomed cells fill the row without unused space");
                    events.mouseWheel(grid,100,100,Qt.NoButton,Qt.ControlModifier,0,-120,1); break;
                case 5:
                    check(pane.gridColumns === initialColumns,"reverse Ctrl+wheel restores one column");
                    for (var i=0;i<12;i++) events.mouseWheel(grid,100,100,Qt.NoButton,Qt.ControlModifier,0,120,0);
                    check(theme.gridItemSize === 420,"zoom reaches the 0.1 maximum preview size");
                    for (var j=0;j<12;j++) events.mouseWheel(grid,100,100,Qt.NoButton,Qt.ControlModifier,0,-120,0);
                    check(theme.gridItemSize === 88,"zoom retains the compact end of the 0.1 range");
                    theme.resetZoom();
                    w.testKeys.forceActiveFocus(); events.keyClick(Qt.Key_Equal,Qt.ControlModifier,1); break;
                case 6:
                    check(pane.gridColumns === initialColumns-1,"keyboard zoom uses the same grid sizing");
                    events.keyClick(Qt.Key_0,Qt.ControlModifier,1); break;
                case 7:
                    check(theme.gridItemSize === 220,"Ctrl+0 restores the 0.1 default size");
                    var file=card("a.txt"); check(!!file,"file card exists for context-menu testing");
                    events.mouseClick(file,20,20,Qt.RightButton,Qt.NoModifier,1); break;
                case 8:
                    check(w.testMenu.visible && menuIndex()>=0,"right-clicking a file exposes Open With");
                    w.testMenu.activate(menuIndex()); break;
                case 9:
                    check(w.testOpenWith.visible && w.testOpenWith.applications.length>0,"the context-menu action opens the application chooser");
                    w.testOpenWith.close(); break;
                case 10:
                    if (w.testOpenWith.visible) return;
                    events.mouseClick(card("destination"),20,20,Qt.RightButton,Qt.NoModifier,1); break;
                case 11:
                    check(w.testMenu.visible && menuIndex()>=0,"folders also expose Open With");
                    w.testMenu.close(); w.openSettings(); w.testSettings.searchQuery="icon style"; break;
                case 12:
                    if (w.testMenu.visible) return;
                    for (var name of ["phosphor","serpantinum","system","adwaita"])
                        check(!!named(w.testSettings,"iconStyle_"+name) && named(w.testSettings,"iconStyle_"+name).visible,"settings exposes icon style: "+name);
                    var button=named(w.testSettings,"iconStyle_serpantinum");
                    events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,1); break;
                case 13:
                    check(theme.iconSource === "serpantinum" && theme.usesGlyphIcons,"the real settings control selects Serpantinum Symbols");
                    capture("settings", w.testSettings);
                    var about=named(w.testSettings,"settingsTab_about");
                    check(!!about && !!named(about,"seabunnyLogoImage"),"the About navigation entry uses Seabunny's logo");
                    theme.iconSource="adwaita";
                    check(w.systemIcon("folder").indexOf("theme=Adwaita")>=0,"Adwaita uses an explicit icon-theme request");
                    theme.iconSource="system";
                    check(w.systemIcon("folder").indexOf("theme=Adwaita")<0,"System resolves the desktop icon theme independently");
                    theme.iconSource="serpantinum"; w.showFiles(); break;
                case 14:
                    var glyph=named(card("a.txt"),"fileGlyphIcon");
                    check(glyph && glyph.visible && glyph.usesSymbols && glyph.fontFamily === theme.symbolsFontFamily,"file icons actually render using the bundled Symbols font");
                    theme.iconSource="phosphor"; theme.resetZoom(); theme.lowPowerSetting="auto";
                    timer.stop(); console.log("APPEARANCE_PARITY_PASSED"); Qt.quit(); return;
                }
                phase++;
            } catch (error) { timer.stop(); console.error("APPEARANCE_PARITY_FAILED " + error); Qt.exit(1); }
            finally { checks.stepping=false; }
        }
    }
}
