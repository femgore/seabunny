import QtQuick
import app.seabunny

Item {
    SeabunnyEngine { id: engine }
    SeabunnyEngine { id: other }
    property string home: engine.place_path("")
    property string stage: engine.get_setting("sort_test_stage")
    Timer {
      interval: 30; running: true; repeat: false
      onTriggered: {
        try {
            function verify(ok, message) {
                if (!ok) throw new Error(message);
                console.log("PASS " + message);
            }
            verify(engine.show_hidden && other.show_hidden, "hidden files are visible by default");
            engine.set_path(home + "/Pictures ö");
            if (stage === "seed") {
                verify(engine.sort_by === "name" && engine.sort_ascending && engine.folder_position === "mixed", "new folders use default sorting");
                engine.set_sort("modified", false);
                engine.change_folder_position("first");
                engine.set_path(home + "/Default");
                verify(engine.sort_by === "name" && engine.sort_ascending && engine.folder_position === "mixed", "custom sorting does not leak into another folder");
                engine.go_back();
                verify(engine.sort_by === "modified" && !engine.sort_ascending && engine.folder_position === "first", "Back restores all sorting preferences");
                engine.go_forward();
                verify(engine.sort_by === "name" && engine.sort_ascending, "Forward restores default sorting");
                other.set_path(home + "/alias");
                verify(other.sort_by === "modified" && !other.sort_ascending, "another engine and symlink alias share folder preferences");
                other.set_sort("size", true);
                engine.set_path(home + "/Pictures ö");
                verify(engine.sort_by === "size" && engine.sort_ascending, "existing engines see preferences saved by another engine");
                other.toggle_sort_order();
                engine.refresh();
                verify(engine.sort_by === "size" && !engine.sort_ascending, "toggling sort direction is remembered on refresh");
                other.toggle_sort_order();
                engine.refresh();
                verify(engine.sort_ascending, "toggling back restores ascending order");
            } else if (stage === "reset") {
                verify(engine.sort_by === "size" && engine.sort_ascending && engine.folder_position === "first", "sorting survives process relaunch");
                engine.set_sort("name", true);
                engine.change_folder_position("mixed");
                engine.refresh();
                verify(engine.sort_by === "name" && engine.sort_ascending && engine.folder_position === "mixed", "returning to defaults clears the override");
            } else {
                verify(engine.sort_by === "name" && engine.sort_ascending && engine.folder_position === "mixed", "defaults survive relaunch after removing an override");
            }
            finish.start();
        } catch (error) {
            console.error("FOLDER_SORT_FAILED " + error);
            Qt.quit();
        }
      }
    }
    Timer {
        id: finish
        interval: 20; repeat: true
        property int attempts: 0
        onTriggered: {
            if (engine.is_loading && ++attempts < 500) return;
            if (!engine.is_loading && JSON.parse(engine.files_json).some(function(file) { return file.name === ".visible-by-default"; }))
                console.log("FOLDER_SORT_PASSED");
            else console.error("FOLDER_SORT_FAILED hidden entry missing or scan timed out");
            Qt.quit();
        }
    }
}
