import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.seabunny

SeabunnyDialog {
    id: conflictModal
    title: resolvingMerge ? "File Already Exists" : "File Conflict"
    dialogWidth: canMerge || resolvingMerge ? Math.min(560, window.width - 32) : 420

    property var conflicts: []
    property var droppedPaths: []
    property string destDir: ""
    property bool isDrop: false
    property bool asCopy: false
    readonly property bool canMerge: conflicts.some(function(item) { return !!item.can_merge; })
    property bool resolvingMerge: false
    property var mergeConflicts: []
    property int mergeIndex: 0
    property var mergeChoices: ({})
    property string mergeError: ""

    property string transferMode: "copy"
    function showFor(list, paths, destination, mode, cut) {
        resolvingMerge = false; mergeError = ""; conflicts = list;
        droppedPaths = paths.slice(); destDir = destination; transferMode = mode; open();
    }
    function applyResolution(res) {
        if (res === "merge") {
            var scan = JSON.parse(core.check_merge_conflicts(JSON.stringify(droppedPaths), destDir));
            if (scan.error) { mergeError = scan.error; return; }
            mergeConflicts = scan.conflicts || [];
            mergeChoices = ({});
            mergeIndex = 0;
            applyToAllConflicts.checked = false;
            if (mergeConflicts.length) {
                resolvingMerge = true;
                conflicts = [mergeConflicts[0]];
                return;
            }
            res = JSON.stringify({mode: "merge", collisions: {}});
        }
        core.transfer(JSON.stringify(droppedPaths), destDir, transferMode, res);
        close();
    }

    function chooseMergeFile(choice) {
        var end = applyToAllConflicts.checked ? mergeConflicts.length : mergeIndex + 1;
        for (var index = mergeIndex; index < end; index++) mergeChoices[mergeConflicts[index].src_path] = choice;
        mergeIndex = end;
        if (mergeIndex < mergeConflicts.length) conflicts = [mergeConflicts[mergeIndex]];
        else applyResolution(JSON.stringify({mode: "merge", collisions: mergeChoices}));
    }

    Text {
        Layout.fillWidth: true
        text: conflictModal.resolvingMerge
            ? ("Conflict " + (conflictModal.mergeIndex + 1) + " of " + conflictModal.mergeConflicts.length + ". Choose which copy to keep.")
            : conflictModal.conflicts.length === 1
            ? ("\u201c" + conflictModal.conflicts[0].name + "\u201d already exists.")
            : (conflictModal.conflicts.length + " items already exist in this destination.")
        color: theme.textMuted
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }

    Rectangle {
        visible: conflictModal.conflicts.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: 60
        radius: theme.radiusM
        color: theme.surfaceContainer

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            SeabunnyIcon {
                name: (conflictModal.conflicts[0] && conflictModal.conflicts[0].is_dir) ? "folder" : "file"
                size: 20
                color: theme.textMuted
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: conflictModal.conflicts[0] ? conflictModal.conflicts[0].name : ""
                    color: theme.textMain
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
                Text {
                    text: conflictModal.conflicts[0] ? (conflictModal.resolvingMerge
                        ? "Incoming: " + conflictModal.conflicts[0].src_size + " · Existing: " + conflictModal.conflicts[0].dest_size
                        : "Destination size: " + conflictModal.conflicts[0].dest_size) : ""
                    color: theme.outline
                    font.pixelSize: 11
                }
            }
        }
    }

    Text {
        visible: conflictModal.canMerge
        text: "Merge combines matching folders. You can choose what to keep for any files with the same name."
        color: theme.textMuted
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    SeabunnySwitch {
        id: applyToAllConflicts
        objectName: "applyToAllConflictsSwitch"
        visible: conflictModal.resolvingMerge
        label: "Apply to all remaining conflicts"
    }

    Text {
        visible: text.length > 0
        text: conflictModal.mergeError
        color: theme.danger
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        SeabunnyButton {
            text: "Cancel"
            variant: "text"
            onClicked: conflictModal.close()
        }
        Item { Layout.fillWidth: true }
        SeabunnyButton {
            text: "Skip"
            visible: !conflictModal.resolvingMerge
            variant: "tonal"
            onClicked: conflictModal.applyResolution("skip")
        }
        SeabunnyButton {
            objectName: "keepBothMergeButton"
            text: "Keep Both"
            variant: "tonal"
            onClicked: conflictModal.resolvingMerge ? conflictModal.chooseMergeFile("keep_both") : conflictModal.applyResolution("rename")
        }
        SeabunnyButton {
            objectName: "keepExistingMergeButton"
            text: "Keep Existing"
            visible: conflictModal.resolvingMerge
            variant: "tonal"
            onClicked: conflictModal.chooseMergeFile("keep_existing")
        }
        SeabunnyButton {
            objectName: "replaceExistingMergeButton"
            text: conflictModal.resolvingMerge ? "Replace Existing" : "Replace"
            variant: "filled"
            onClicked: conflictModal.resolvingMerge ? conflictModal.chooseMergeFile("replace") : conflictModal.applyResolution("overwrite")
        }
        SeabunnyButton {
            objectName: "mergeFoldersButton"
            visible: conflictModal.canMerge
            text: "Merge"
            variant: "filled"
            onClicked: conflictModal.applyResolution("merge")
        }
    }
}
