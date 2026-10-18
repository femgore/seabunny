# Seabunny FileChooser portal (opt-in)

The standalone `xdg-desktop-portal-seabunny` process owns
`org.freedesktop.impl.portal.desktop.seabunny` and exports the FileChooser backend
at `/org/freedesktop/portal/desktop`. The normal file manager and its desktop
registration remain independent. Each request owns its controller, QML engine,
window, selection, and navigation. Closing one returns cancellation and leaves
other requests and normal Seabunny windows alone. The service exits when its bus
disconnects and otherwise stays available for later requests (maximum 32 pending).

`OpenFile`, `SaveFile`, and `SaveFiles` take `osssa{sv}` and return `ua{sv}`.
Requests have a caller-owned `org.freedesktop.impl.portal.Request.Close` method.
Responses are 0 for acceptance, 1 for cancellation, 2 for an unusable request/UI.
Complex filters and choices use their specified D-Bus structures, not JSON.

The existing QML browser is reused in chooser mode: sidebar, grid/list, navigation,
search, icons, thumbnails, animations and live palette watcher. Choosers do not
restore/persist explorer tabs or write general appearance preferences. Explorer
and chooser sidebars independently remember their expanded/collapsed state and
preferred width in `$XDG_STATE_HOME/seabunny/{explorer,chooser}-sidebar.json`
(default `~/.local/state/seabunny`). Writes are atomic; an existing explorer
`sidebarWidth` preference provides the initial width when no role-specific state
exists. Narrow windows clamp the displayed width without discarding the preferred
width. Malformed or future-version sidebar state is preserved rather than overwritten.
File-manager mutation actions,
archive opening, external file launching and settings UI are disabled in this mode.
Single/multiple selection and folder-only mode are supported. SaveFile offers
an editable suggested name, current directory/file, file filters and overwrite
confirmation. One unambiguous filter extension is appended to an extensionless
name and shown in the editable filename field; the initial selection covers the
basename so typing preserves the visible extension. Changing file type updates
an automatically suggested extension, while an explicitly typed extension is
preserved. SaveFiles selects a destination
and returns numbered alternatives for collisions, preserving input order. Neither
method creates files, truncates files, reserves names, or downloads data. The
calling application must handle races with other writers after the dialog closes.

Paths are absolute, percent-encoded local file URIs. Invalid UTF-8 byte paths cannot
round-trip through Qt and are not returned as replacement-character filenames.
Virtual/archive/remote URI selection is not supported. MIME filters use filename
MIME classification; they do not read file contents to identify a type.

Parenting uses KWindowSystem's XDG Foreign import on Wayland and native window IDs
on X11. The parent must be valid and the compositor must support the protocol.
`modal` is applied before showing the window. Missing/expired parents do not cause
another application's window to be used as parent. Real compositor focus, stacking,
and modality need visual review; offscreen tests cannot establish those behaviors.
The palette path follows the existing launcher: environment override, standard
Serpantinum state path, then the built-in theme when unavailable.

## Build and test without installation

Build dependencies: Rust/Cargo, Qt 6 Quick,
QML and DBus development files, KF6WindowSystem, pkg-config, CMake, and Python.
The private-bus integration test uses system Python's PyGObject. Its optional
Helium check also uses `websockets`. No installer downloads packages.

From the checkout, in Fish:

```fish
cargo build --release --locked
cmake -S tests -B target/seabunny-qt-tests
cmake --build target/seabunny-qt-tests -j 2
env QT_QPA_PLATFORM=offscreen SEABUNNY_PRIVATE_BUS_TEST=1 dbus-run-session -- target/seabunny-qt-tests/portal-tests
python3 -B tests/run_chooser_checks.py
python3 -B tests/run_sidebar_persistence.py
python3 -B tests/run_native_checks.py
python3 -B tests/test_portal_install.py
/usr/bin/python3 -B tests/test_portal_bus.py
/usr/bin/python3 -B tests/test_portal_bus.py --helium
```

The integration harness creates a private bus, disposable HOME/XDG directories,
synthetic files, its own activation entry and portal configuration. It uses the
real portal frontend and Seabunny backend with offscreen Qt windows. It does not
change the desktop session. The optional Helium check uses a disposable profile,
headless Ozone, Ctrl+S and a synthetic prompted download, then observes the actual backend SaveFile request. It
never disables Chromium's sandbox. This tests routing and filename suggestion;
it does not establish live Niri window behavior or completion of a browser download.

## Build an optional portal package

```fish
python3 -B packaging/seabunny/package_user.py build --with-portal
```

The existing package workflow adds the backend, descriptor, activation template,
this guide and `portal_user.py` only with `--with-portal`. A normal package build
has no portal payload. Portal installation is separate from the normal application's
installer, and retains an independent versioned backend payload.

## Register, then test before enabling

These commands modify user-local files and are intentionally manual. Substitute
the package path printed by the build command:

```fish
python3 -B packaging/seabunny/portal_user.py install --package /absolute/package/path
```

Registration writes only the user D-Bus activation file and
`$XDG_DATA_HOME/xdg-desktop-portal/portals/seabunny.portal`. It does not switch
preferences, restart services, or update the installed Seabunny application.
The descriptor advertises **only FileChooser**. It is discovered by recent XDG
Desktop Portal releases, with user-local descriptor discovery support. No existing backend is
removed. Save the printed **install receipt path** for uninstallation.

If live introspection initially reports `The name is not activatable`, ask the
session bus to rescan its activation registrations, then retry. This was necessary
when the user activation directory was newly created during the live test:

```fish
gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.ReloadConfig
gdbus introspect --session --dest org.freedesktop.impl.portal.desktop.seabunny --object-path /org/freedesktop/portal/desktop
```

This rescan does not restart D-Bus or the portal frontend. RealtimeKit warnings
with the same text in the private-session test log concern RealtimeKit, not
Seabunny activation; check which service the diagnostic identifies.

The checkout provides a five-dialog live test using disposable files, with no
portal routing change:

```fish
/usr/bin/python3 -u -B tests/manual_portal_test.py
```

Accept or cancel each dialog to advance through single-file, multiple-file,
folder, Save As and SaveFiles tests. During Save As, enter `existing.txt` to test
overwrite confirmation. Use `--case save` (or `open`, `multiple`, `folder`,
`savefiles`) to repeat one case. Output files are not created by these direct
backend tests. Test fixtures remain under `target/portal-live-test-*`.

The manual test does not add encoding menus or other sample choices. Any extra
options in a real chooser request are supplied by the calling application;
Seabunny returns the chosen values and does not convert file encoding itself.

For a live, directly addressed backend check, run the following from a terminal
and interact with the chooser that opens (this does not change routing):

```fish
gdbus call --session --dest org.freedesktop.impl.portal.desktop.seabunny --object-path /org/freedesktop/portal/desktop --method org.freedesktop.impl.portal.FileChooser.OpenFile /org/freedesktop/portal/desktop/request/manual/open '' '' 'Seabunny test' '{}'
```

Test Cancel, file selection, folders, spaces/Unicode, filters and overwrite handling
using disposable files. A direct gdbus call's process must stay alive for the request.
The private-bus test also verifies a portal-aware client before any live switch.

## Enable only FileChooser on Niri

First identify the **currently effective** portal configuration using the official
search order (desktop-specific files take precedence within each location). The
helper requires that file explicitly to avoid replacing other interface preferences
with guessed defaults. Do not use a one-line replacement configuration: portal
configuration files are selected, not merged across locations.

```fish
python3 -B packaging/seabunny/portal_user.py enable --base-config /absolute/path/to/effective/portals.conf
```

If `~/.config/xdg-desktop-portal/niri-portals.conf` exists, use that exact file as
`--base-config`. Otherwise use the effective generic/user/system file. The helper
copies it, preserving other keys and comments, and changes only this key under
`[preferred]`:

```ini
org.freedesktop.impl.portal.FileChooser=seabunny
```

It writes the Niri-specific user file, creates a receipt with the original bytes,
and prints the **enable receipt path**. ScreenCast, Screenshot, RemoteDesktop and
all unrelated interface entries remain as supplied in the effective base file.
No Niri compositor or Quickshell configuration is edited.

The running frontend needs to reread its configuration. At a time when no portal
operation (including screen sharing) is active, the manual command is:

```fish
systemctl --user restart xdg-desktop-portal.service
```

No script runs this command. It can interrupt portal operations, so do not run it
mid-session without considering those operations. No compositor reload is needed.

After the switch, use Helium's Ctrl+S on a synthetic local page and its upload
button for OpenFile. Confirm the native Seabunny dialog, suggested filename,
Cancel, overwrite prompt and actual application write result. Chromium's choice
of portal versus a toolkit dialog depends on the build and environment; a folder
MIME association or `xdg-open` change will not affect it. Keep the fallback below
ready and restore it if dialogs do not open. Do not test with personal downloads.

To test the active public portal directly with disposable files:

```fish
/usr/bin/python3 -u -B tests/manual_portal_test.py --frontend --case save
```

This uses `org.freedesktop.portal.FileChooser`, including the public request and
response lifecycle, rather than addressing the backend directly.

## Immediate fallback and uninstallation

Restore the exact previous configuration using the **enable receipt**, then reread
it with the same manual frontend restart at a safe time:

```fish
python3 -B packaging/seabunny/portal_user.py disable --receipt /absolute/enable/receipt.json
systemctl --user restart xdg-desktop-portal.service
```

To remove registration after disabling, use the **install receipt**:

```fish
python3 -B packaging/seabunny/portal_user.py uninstall --receipt /absolute/install/receipt.json
```

Rollback checks file hashes and refuses to overwrite edits made after installation.
It moves the installed version into the receipt directory and restores original
bytes/mode, or leaves a formerly absent file absent. Versioned payloads and backups
are retained; nothing is recursively deleted. Undo receipts in reverse order if
install/enable was performed more than once. A running backend may remain idle
until the session ends; removing registration does not terminate it.

## Troubleshooting

- Use `gdbus introspect --session --dest org.freedesktop.impl.portal.desktop.seabunny --object-path /org/freedesktop/portal/desktop` to check activation and method signatures.
- If activation fails, inspect the generated service's absolute Exec path and confirm
  Qt/KF6 libraries are available. Try the activation-registration rescan above.
  If routing was enabled and activation still fails, restore the enable receipt.
- Confirm `XDG_CURRENT_DESKTOP` includes Niri and that no higher-priority desktop
  configuration overrides the Niri file. A custom `XDG_DESKTOP_PORTAL_DIR` overrides
  normal discovery; do not overwrite it without understanding the existing setup.
- The backend intentionally avoids a synchronous Settings call to the portal frontend
  during startup, preventing a frontend/backend activation deadlock.
- Inspect service diagnostics with `journalctl --user -u xdg-desktop-portal.service -n 80` yourself; logs can contain private filenames and should not be shared blindly.
- Missing parent handles produce a standalone chooser; investigate compositor
  XDG Foreign support before changing desktop rules. Theme updates use Seabunny's
  existing palette watcher; no desktop theme is rewritten.

Authoritative references:
[FileChooser backend](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.impl.portal.FileChooser.html),
[Request cancellation](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.impl.portal.Request.html),
[portal configuration](https://flatpak.github.io/xdg-desktop-portal/docs/portals.conf.html),
[KWindowSystem parenting](https://api.kde.org/kwindowsystem.html).
