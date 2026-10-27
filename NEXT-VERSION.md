# seabunny 0.2.1 release notes

new file plumbing, familiar rabbit. this is the version to try if you want the
file manager and its portal picker to behave like one app instead of distant
cousins who only meet at holidays.

## what's in the release

the explorer and file picker use the same directory pane, navigation, sidebar,
icons, thumbnails, and theme. the picker runs as its own portal backend, so
closing a dialog doesn't close an explorer window. the calling app still handles
reading or writing the selected files.

the chooser supports Open File, Save File, Save Multiple, and Select Folder.
filters, suggested filenames, current directories, multiple selection,
overwrite confirmation, cancellation, choices, and parent-window information are
handled by the portal request. picker state is kept separate from explorer state.

the explorer brings tabs, split view, search, Quick Look, batch rename, large
thumbnails, aspect-ratio-aware previews, and Ctrl+scroll zoom. file operations
run in background jobs with progress, cancellation, and undo where supported.
folder merges ask what to do with clashing files and can apply one choice to the
remaining conflicts.

Open With can remember an app by file type. executable files and AppImages launch
as applications. Properties includes a Make executable switch. network bookmarks
use the desktop URI handler, while local folders stay in Seabunny.

Serpantinum palettes update live. System icons follow the desktop icon theme.
Sorting preferences are stored only for folders that differ from the default;
hidden files are shown by default. Explorer and picker each remember their own
sidebar width and open or closed state.

## trying the build before installing it

build and run a separate development window from this checkout:

```fish
cargo build --release --locked
fish ./run-development.fish
```

the development profile stays under `target/development-profile`. it can still
change real files if you ask it to, so point it at test data when you're checking
destructive operations.

to test portal dialogs without changing your active picker:

```fish
fish ./test-file-picker.fish
fish ./test-file-picker.fish --case save
```

the helper uses a private bus and disposable profile. selected paths are returned
to the test app; the chooser doesn't write the outputs.

## building and release downloads

the release workflow checks that the pushed tag matches `Cargo.toml`, then builds
the Arch package, Debian package, RPM, AppImage, standalone executable, and
user-installable archive. it attaches SHA-256 checksums and publishes the release
when all package jobs pass. the AppImage is the explorer build; use a native package or
the archive with the optional backend when you want portal integration.

the user archive is built locally with:

```fish
cargo build --release --locked
python3 -B packaging/seabunny/package_user.py build --with-portal
```

installing the application, registering the portal, and selecting it for
FileChooser are separate actions. see [the install guide](packaging/seabunny/README.md)
and [the portal guide](packaging/seabunny/PORTAL.md) before changing the active
portal preference.

## verification and limits

the disposable UI checks cover keyboard navigation, copying, merging, undo/redo,
permissions, Open With, archives, chooser filters and modes, live palettes, and
state across relaunches. Rust, archive, portal-bus, native Qt, and Wayland
clipboard checks use test-owned profiles or private sessions.

network shares, removable-drive disconnects, and privileged operations still
need testing against real devices and services. archive previews are read-only;
encrypted formats need the relevant system archive tools. the AppImage bundles
Qt and QML resources, but archive helper programs may still need to be installed
on the host.
