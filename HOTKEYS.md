# keyboard shortcuts

most of these are probably already in your muscle memory. here's the list anyway.

| shortcut | what it does |
| --- | --- |
| F2 | rename the one selected item |
| Delete | move selected items to trash |
| Ctrl+C / Ctrl+X / Ctrl+V | copy / cut / paste |
| Ctrl+Z | undo a file operation |
| Ctrl+Shift+Z / Ctrl+Y | redo a file operation |
| Ctrl+A | select everything in the current view |
| Ctrl+Shift+N | make a folder |
| Ctrl+F | focus search and select its text |
| Ctrl+L | edit the location |
| F5 / Ctrl+R | refresh the folder |
| Ctrl+H | show or hide hidden files |
| Alt+Enter | properties for the selected item, or the current folder if nothing is selected |
| Alt+Left / Alt+Right | back / forward |
| Alt+Up | open the parent folder |
| Alt+Home | go home |
| Backspace | go back while browsing files |
| Ctrl+1 / Ctrl+2 | grid / list view |
| F9 | expand / collapse the sidebar |
| Arrow keys / Shift+arrows | move through files / extend the selection |
| Enter | open the selected item |
| Ctrl+T / Ctrl+W | open / close a tab |
| Ctrl+Tab / Ctrl+Shift+Tab | next / previous tab |

if you're typing in a filename or search box, the keys stay with that box. delete
edits the text, and undo edits the text too. file actions also wait while a dialog
is open.

rename selects the filename without its extension, so you can just type a new name
without losing `.txt` or whatever was there. folders get their whole name selected.
renaming a search result changes the file in its actual folder.

the file picker keeps the browsing shortcuts, but blocks things like rename,
trash, paste, and file undo. enter accepts or opens things as appropriate, and
escape cancels. archives stay read-only.

delete goes through trash and can be undone. there's no permanent-delete shortcut.

the familiar bindings take their cue from GNOME Files/Nautilus:
[view actions and key bindings](https://github.com/GNOME/nautilus/blob/main/src/nautilus-files-view.c).
the actual actions use seabunny's own qt/qml components.
