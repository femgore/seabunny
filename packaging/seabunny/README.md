# put seabunny on your computer

it's a file manager. installing it should involve fewer dramatic events than
using it to organize your downloads folder. here's the process.

first build it with `cargo build --release --locked`. then make a package and
install it from the path the packaging command prints:

```fish
python3 -B packaging/seabunny/package_user.py build
# Include the optional chooser backend:
python3 -B packaging/seabunny/package_user.py build --with-portal
fish packaging/seabunny/install-user.fish --package /absolute/package/path
```

use the normal build command if you just want the file manager. use
`--with-portal` if you want the picker included too. you only need one of those
package builds. running both is just making more packages for the hell of it.

## dependencies, because apparently there are always more

the package includes the executable, qml, fonts, icons, notices, and archive
adapter. it uses your system's qt 6, KDE WindowSystem, python 3, and libarchive.
it isn't a bundle of every library for every distro. ffmpeg handles video
thumbnails, and the launcher needs fish. the package doesn't summon missing
libraries out of thin air, so check those before blaming the executable.

## where it goes

the actual builds live in `~/.local/opt/seabunny/releases/`. a `current` symlink
picks which one runs. the launcher goes in `~/.local/bin/seabunny`, and the desktop
entry is `org.femgore.Seabunny.desktop`.

make sure `~/.local/bin` is on your PATH. a launcher your shell can't find is
mostly just decorative. the installer currently expects the usual
`~/.local/share` data directory.

it checks the package checksums and keeps receipts and backups in
`~/.local/opt/seabunny/installations/`. older builds stay around. to roll back,
point `current` at one of those retained releases. backups are useful when the
new thing decides to be a pain in the ass.

there isn't an automated uninstaller for the file-manager payload yet. that bit
still needs doing. the portal
has its own removal and rollback commands in [PORTAL.md](PORTAL.md).

## your defaults remain your business

installing doesn't make seabunny your default folder handler unless you pass
`--make-default`. `--no-register` skips desktop database updates and MIME queries.
the desktop identity stays `org.femgore.Seabunny`. installing a folder window
shouldn't quietly redecorate half your damn desktop.

preferences and favorites go in `$XDG_CONFIG_HOME/seabunny`, normally
`~/.config/seabunny`. the explorer and picker remember their sidebars separately
under `$XDG_STATE_HOME/seabunny`. sorting preferences are shared, and only folders
with non-default sorting get an entry.

installation doesn't import or overwrite existing settings. thumbnails and archive
previews use seabunny's own cache paths.

## the colors and the other window

live Serpantinum colors use `SEABUNNY_SERPANTINUM_COLORS`, `QS_COLORS_JSON`, or
`$XDG_STATE_HOME/serpantinum/qs_colors.json`. if there's no palette, the built-in
colors take over. none of this rewrites your compositor or theme config.

including the portal in a package, registering it, and enabling it are separate
steps. [the picker guide](PORTAL.md) walks through those and how to go back.

if installation fails, open an issue with the command, the error, and your distro.
if the instructions are confusing as hell, say which part. that counts as useful
feedback too.
