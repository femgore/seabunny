# naturally, there's a file picker

i made the file manager match my desktop and then the save dialog looked out of
place. so now there's this whole thing. excellent use of an afternoon.

the picker is optional. it lets apps use seabunny for open, save, and folder
dialogs through the desktop portal. you can use it just for FileChooser and leave
your screen sharing and other portal backends alone.

it's a separate `xdg-desktop-portal-seabunny` process. each request gets its own
window, selection, and navigation. closing one cancels that request; it doesn't
close another picker or your file-manager window. the backend stays around for
later requests, allows up to 32 pending requests, and exits if its session bus
disconnects. closing a save dialog shouldn't take your file manager down with it.
that would be a spectacularly stupid party trick.

## what the thing actually does

the picker uses the same browser, sidebar, icons, thumbnails, navigation,
animations, and live colors as the file manager. it supports single or multiple
files, folder selection, filters, suggested filenames, and overwrite confirmation.
file changes, archive opening, external file launching, and the settings view are
disabled here. it doesn't restore explorer tabs or save general appearance settings.
it's here to pick a file. it doesn't need to start rearranging your shit.

the explorer and picker remember their sidebar size and open/closed state
separately in `$XDG_STATE_HOME/seabunny/{explorer,chooser}-sidebar.json`, normally
under `~/.local/state/seabunny`. an existing `sidebarWidth` preference is the
starting point if there's no saved sidebar state yet. a narrow window can shrink
the visible sidebar without forgetting the size you picked. writes are atomic,
and malformed or newer-version state files are left alone.

when a filter gives one clear extension, an extensionless filename gets that
extension added in the text field. the initial selection covers the name, so
typing keeps the extension visible. changing file type updates an automatically
suggested extension, but keeps an extension you've entered yourself.

`SaveFiles` picks a folder for several output files and returns numbered names
where there are collisions, in the original order. the picker doesn't create,
truncate, reserve, or download files. the calling app does the actual writing and
still has to handle anything that changes after the dialog closes. the picker
can't reserve a filename through sheer confidence.

local paths come back as absolute, percent-encoded `file://` urls. remote paths,
archive members, and other virtual locations aren't supported. filenames with
invalid UTF-8 bytes can't round-trip through qt, so they aren't returned with
replacement characters. MIME filters use filename classification rather than
reading each file's contents.

## build it before making it everyone's problem

you need rust/cargo, qt 6 Quick/QML and D-Bus development files, KF6WindowSystem,
pkg-config, cmake, and python. the private-bus test uses system python's PyGObject;
the optional Helium test also needs `websockets`. the installers don't download
dependencies for you. check the list; there's always one damn library.

from the checkout, in fish:

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

the UI checks run offscreen. the integration test makes its own private bus,
temporary HOME/XDG directories, sample files, activation entry, and portal config.
it uses the real portal frontend and seabunny backend without changing your
desktop session.

the Helium test uses a temporary profile, headless Ozone, ctrl+s, and a sample
download prompt. it checks that `SaveFile` reaches seabunny with the suggested
filename. it keeps Chromium's sandbox enabled. this doesn't test actual Niri
window behavior or prove that a browser download finishes writing. headless tests
are useful, but they don't have a secret pair of eyes on your desktop.

## make a package

```fish
python3 -B packaging/seabunny/package_user.py build --with-portal
```

`--with-portal` adds the backend, descriptor, activation template, this guide, and
`portal_user.py`. a normal package build leaves those out. the portal has its own
versioned installation, separate from the file manager.

## register it and see if it opens a fucking window

use the package directory printed by the build command:

```fish
python3 -B packaging/seabunny/portal_user.py install --package /absolute/package/path
```

this writes the user D-Bus activation file and
`$XDG_DATA_HOME/xdg-desktop-portal/portals/seabunny.portal`. it doesn't enable the
picker, restart services, or update your installed file manager. the descriptor
only advertises FileChooser, and existing backends stay installed. you'll need an
XDG Desktop Portal version that discovers user-local descriptors.

keep the printed **install receipt path**. that's what you'll use to undo the
registration later. save the path somewhere you can actually find it.

if you get `The name is not activatable`, the session bus may need to rescan its
activation files. try this, then check the backend again:

```fish
gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.ReloadConfig
gdbus introspect --session --dest org.freedesktop.impl.portal.desktop.seabunny --object-path /org/freedesktop/portal/desktop
```

that rescan doesn't restart D-Bus or the portal frontend. if a private-test log
mentions RealtimeKit with the same error, check the service name: a RealtimeKit
warning isn't a seabunny activation failure. several services can complain in
the same log. very generous of them.

there's a live test that opens five dialogs using sample files, without changing
portal routing:

```fish
/usr/bin/python3 -u -B tests/manual_portal_test.py
```

accept or cancel each one to move through single-file, multiple-file, folder,
Save As, and SaveFiles tests. in Save As, enter `existing.txt` to check overwrite
confirmation. use `--case save`, `open`, `multiple`, `folder`, or `savefiles` to
repeat one case. these direct tests don't write the chosen output files. their
sample files stay under `target/portal-live-test-*`.

the manual test doesn't add an encoding menu. extra choices in a real dialog come
from the app that opened it. seabunny returns the choice; it doesn't convert file
encoding. an extra checkbox isn't a promise that seabunny secretly became a
text editor.

if you want to call the backend directly, this also opens a dialog without
changing routing:

```fish
gdbus call --session --dest org.freedesktop.impl.portal.desktop.seabunny --object-path /org/freedesktop/portal/desktop --method org.freedesktop.impl.portal.FileChooser.OpenFile /org/freedesktop/portal/desktop/request/manual/open '' '' 'Seabunny test' '{}'
```

keep that terminal process running while the request is open. try canceling,
selecting files and folders, spaces and Unicode in paths, filters, and overwrite
confirmation. use sample files for this. the private-bus integration test also
checks a portal-aware client before you change the live desktop's routing.

## give it the FileChooser job on niri

first find the portal config your session is actually using. desktop-specific
files take precedence within each search location. the helper asks for that file
explicitly so it can preserve your other preferences.

portal config files are selected, not merged across locations. don't replace your
existing config with a single FileChooser line. that's a great way to turn a
file-picker experiment into a screen-sharing troubleshooting session.

```fish
python3 -B packaging/seabunny/portal_user.py enable --base-config /absolute/path/to/effective/portals.conf
```

if `~/.config/xdg-desktop-portal/niri-portals.conf` exists, use that exact file for
`--base-config`. otherwise, use the effective generic, user, or system config. the
helper copies it, keeps the other keys and comments, and changes just this entry
under `[preferred]`:

```ini
org.freedesktop.impl.portal.FileChooser=seabunny
```

it writes the niri-specific user config and keeps the original bytes in a receipt.
keep the printed **enable receipt path** too. ScreenCast, Screenshot,
RemoteDesktop, and unrelated entries keep the preferences from your base config.
your Niri and Quickshell configs aren't edited. the scope is one damn chooser.

the running portal frontend needs to reread its config. wait until screen sharing
and other portal operations have stopped, then run:

```fish
systemctl --user restart xdg-desktop-portal.service
```

the scripts don't run that for you. surprise service restarts are bullshit. restarting the frontend can interrupt active
portal operations. you don't need to reload the compositor.

now try Helium's ctrl+s on a sample local page, and its upload button for OpenFile.
check that seabunny opens, the suggested name makes sense, cancel works, and the
app writes the file after you accept. try an overwrite too. whether Chromium uses
the portal depends on its build and environment; changing folder associations or
`xdg-open` won't switch its file chooser.

you can also test the active public portal with sample files:

```fish
/usr/bin/python3 -u -B tests/manual_portal_test.py --frontend --case save
```

this goes through `org.freedesktop.portal.FileChooser` and its public request and
response handling, rather than calling the backend directly. if dialogs stop
opening, use the rollback below.

## put it back if it acts up

to restore your previous routing, use the **enable receipt**, then restart the
frontend when it's safe to interrupt portal operations:

```fish
python3 -B packaging/seabunny/portal_user.py disable --receipt /absolute/enable/receipt.json
systemctl --user restart xdg-desktop-portal.service
```

to remove the registration after disabling it, use the **install receipt**:

```fish
python3 -B packaging/seabunny/portal_user.py uninstall --receipt /absolute/install/receipt.json
```

rollback checks file hashes and won't overwrite edits made after installation.
it moves the installed registration files into the receipt directory and restores
the old bytes and permissions, or leaves a previously absent file absent. payloads
and backups stay around; nothing is recursively deleted. rollback shouldn't
need its own recovery mission.

if you've installed or enabled it more than once, undo the receipts in reverse
order. removing registration doesn't stop an already-running backend, so it can
stay idle until the session ends.

## when the computer has other plans

- check activation and method signatures with `gdbus introspect --session --dest org.freedesktop.impl.portal.desktop.seabunny --object-path /org/freedesktop/portal/desktop`.
- if activation fails, check the generated service's absolute Exec path and make
  sure the qt/KF6 libraries are available. try the activation rescan above. if you
  already enabled it and dialogs won't open, restore the enable receipt.
- check that `XDG_CURRENT_DESKTOP` includes Niri and that a higher-priority config
  isn't overriding the niri file. `XDG_DESKTOP_PORTAL_DIR` can override normal
  discovery too, so don't change it without checking your setup.
- the backend avoids a synchronous Settings call to the frontend during startup.
  that keeps the two from waiting on each other during activation.
- you can inspect logs with `journalctl --user -u xdg-desktop-portal.service -n 80`.
  look through them before sharing them; they can contain private filenames.
- a missing or expired parent handle leaves the picker as a separate window. check
  compositor support for XDG Foreign before changing desktop rules. live colors
  use seabunny's palette watcher and don't rewrite your theme.

## the D-Bus shit, if you're here for that

if you need the interface details, the backend owns
`org.freedesktop.impl.portal.desktop.seabunny` and exports FileChooser at
`/org/freedesktop/portal/desktop`. `OpenFile`, `SaveFile`, and `SaveFiles` take
`osssa{sv}` and return `ua{sv}`. response 0 means accepted, 1 means canceled, and
2 means the request or UI couldn't be used. filters and choices use the specified
D-Bus structures, not JSON. the caller owns its
`org.freedesktop.impl.portal.Request.Close` method for cancellation.

parent windows use KWindowSystem's XDG Foreign import on Wayland and native window
IDs on X11. `modal` is applied before showing the picker. the parent handle has to
be valid, and the compositor has to support the protocol. an expired handle doesn't
make some other app's window the parent. focus, stacking, and modality still need
a real desktop check; offscreen tests can't establish those.

colors use an environment override or the standard Serpantinum state path, with
the built-in theme as fallback.

if something still goes sideways, open an issue with your desktop, portal
versions, the command you tried, and a relevant error. check logs for private
filenames before sharing them. suggestions and clearer ways to explain this mess
are welcome too.

the official references, if you need to dig further:
[FileChooser backend](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.impl.portal.FileChooser.html),
[request cancellation](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.impl.portal.Request.html),
[portal config](https://flatpak.github.io/xdg-desktop-portal/docs/portals.conf.html),
[KWindowSystem parenting](https://api.kde.org/kwindowsystem.html).
