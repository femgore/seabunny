# Seabunny user-local installation

Build with `cargo build --release --locked`, then create a package:

```fish
python3 -B packaging/seabunny/package_user.py build
# Include the optional chooser backend:
python3 -B packaging/seabunny/package_user.py build --with-portal
fish packaging/seabunny/install-user.fish --package /absolute/package/path
```

The package includes the native executable, embedded QML, fonts, icons, notices,
and archive adapter. It uses system Qt 6, KDE WindowSystem, Python 3 and libarchive;
it is not a self-contained bundle for every Linux distribution. Video thumbnails
use FFmpeg. The launcher requires Fish.

Files are installed under `~/.local/opt/seabunny/releases/`, with a `current`
symlink selecting the active release, a launcher at `~/.local/bin/seabunny`, and
an `org.femgore.Seabunny.desktop` entry. Installation currently requires the standard
`~/.local/share` data directory. Ensure `~/.local/bin` is on PATH.

The installer verifies package checksums and keeps deployment receipts and backups
under `~/.local/opt/seabunny/installations/`. Older releases remain available.
To roll back, repoint `current` to a retained release. There is not yet an automated
uninstaller for the file-manager payload; portal registration has its own removal
and rollback commands described in [PORTAL.md](PORTAL.md).

The default directory handler changes only when `--make-default` is explicitly
passed. `--no-register` skips desktop database updates and MIME queries. The app's
desktop identity remains `org.femgore.Seabunny`.

Preferences/favorites are under `$XDG_CONFIG_HOME/seabunny` (default
`~/.config/seabunny`). Each explorer and chooser has independent sidebar state in
`$XDG_STATE_HOME/seabunny/`; sorting overrides are shared and contain only folders
with non-default sorting. Existing settings are not imported or overwritten by
installation. Thumbnail and archive caches use Seabunny-owned cache paths.

Live Serpantinum colors use `SEABUNNY_SERPANTINUM_COLORS`, `QS_COLORS_JSON`, or
`$XDG_STATE_HOME/serpantinum/qs_colors.json`, with built-in colors as fallback.
No compositor or theme configuration is rewritten.

Portal packaging, registration and activation are separate, opt-in operations.
See [PORTAL.md](PORTAL.md) before switching a desktop's FileChooser backend.
