# Seabunny keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| F2 | Rename the single selected item |
| Delete | Move selected items to Trash |
| Ctrl+C / Ctrl+X / Ctrl+V | Copy / cut / paste |
| Ctrl+Z | Undo a file operation |
| Ctrl+Shift+Z / Ctrl+Y | Redo a file operation |
| Ctrl+A | Select all items |
| Ctrl+Shift+N | Create a folder |
| Ctrl+F | Focus search and select its text |
| Ctrl+L | Edit the location |
| F5 / Ctrl+R | Refresh the folder |
| Ctrl+H | Toggle hidden files |
| Alt+Enter | Show properties for the selected item, or the current folder with no selection |
| Alt+Left / Alt+Right | Back / forward |
| Alt+Up | Open the parent folder |
| Alt+Home | Open Home |
| Backspace | Back when navigating files |
| Ctrl+1 / Ctrl+2 | Grid / list view |
| F9 | Expand / collapse the sidebar |
| Arrow keys / Shift+arrows | Navigate / extend selection |
| Enter | Open the selected item |
| Ctrl+T / Ctrl+W | Open / close a tab |
| Ctrl+Tab / Ctrl+Shift+Tab | Next / previous tab |

File-operation shortcuts yield to focused text fields and modal dialogs. Delete in
a filename or search field edits text. File Undo/Redo does not intercept text Undo.
Rename selects a file's basename while leaving its extension visible; directory
names are selected in full. Rename from recursive search uses the actual parent
directory of the selected result.

Chooser windows support browsing shortcuts, but block file-operation shortcuts
such as rename, Trash, paste and filesystem Undo. Enter and Escape retain chooser
accept/cancel behavior. Archive browsing retains its read-only restrictions.
Delete is reversible through Trash and Undo; permanent deletion is not bound.

The reference for the familiar bindings is GNOME Files/Nautilus:
[view actions and key bindings](https://github.com/GNOME/nautilus/blob/main/src/nautilus-files-view.c).
Seabunny implements these actions through its existing Qt/QML components.
