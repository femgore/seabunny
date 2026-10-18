# seabunny

a little file manager for linux, written in rust and qt/qml. i wanted something
that felt at home on my desktop and ended up spending a lot of time on it.

it has tabs, thumbnails, a sidebar you can rearrange, and a matching file picker.
i use it on cachyos with niri. other setups should be possible, but that's where
it's been getting actual use.

## gallery

| dark | light |
| --- | --- |
| ![Seabunny browsing files in dark mode](docs/gallery/image1.png) | ![Seabunny browsing files in light mode](docs/gallery/image2.png) |
| ![Seabunny storage overview](docs/gallery/image3.png) | ![Seabunny with a warm desktop palette](docs/gallery/image4.png) |

## what it does

- grid and list views, tabs, search, and normal keyboard shortcuts
- image and video thumbnails without starting a video every time you scroll
- a resizable sidebar with bookmarks and saved open/closed state
- per-folder sorting; only folders with custom sorting get saved
- hidden files shown by default. ctrl+h still toggles them
- trash, restore, copy/paste, drag and drop, and undo/redo
- read-only archive browsing and extraction
- built-in palettes, light/dark modes, reduced motion, and optional live Serpantinum colors
- an optional desktop portal for open, save, and folder dialogs

f2 renames, delete moves things to trash, ctrl+shift+n makes a folder, and f5
refreshes. the longer list is in [HOTKEYS.md](HOTKEYS.md).

## build it

you'll need rust/cargo, a c++ compiler, cmake, ninja, pkg-config, qt 6 (base,
declarative/quick, svg, and wayland), and KDE Frameworks 6 WindowSystem. python 3
and libarchive are used for archives. ffmpeg adds video thumbnails; zip and 7z
are used for the compression formats that need them.

```fish
cargo build --release --locked
./target/release/seabunny
```

the executable accepts folder paths, archives, and local file urls. there isn't a
published release or AUR package yet, so building from source is the current route.
the Nix recipe is included, but hasn't been verified for this snapshot.

## install for your user

there's a local installer. it keeps versioned copies, so an update doesn't remove
the previous build.

```fish
python3 -B packaging/seabunny/package_user.py build --with-portal
```

that prints a package directory. use that path here:

```fish
fish packaging/seabunny/install-user.fish --package /absolute/path/to/package
```

the launcher goes in `~/.local/bin`. add that directory to your PATH if it isn't
there already. installing doesn't change the default folder handler unless you
pass `--make-default`. it doesn't enable the portal either.

settings live in `~/.config/seabunny`, with sidebar and sorting state under
`~/.local/state/seabunny`. XDG directory overrides are supported where documented.
[installation details](packaging/seabunny/README.md)

## use the file picker

it's a separate `xdg-desktop-portal-seabunny` process. closing a picker doesn't
close the file manager, and apps still do their own reading and writing.

registration and enabling are separate steps. you can select it just for
FileChooser and keep the backends you already use for screen sharing and everything
else. [setup, testing, and rollback](packaging/seabunny/PORTAL.md)

## tests

```fish
cargo test --release --locked
python3 -B tests/test_archives.py
python3 -B tests/test_portal_install.py
python3 -B tests/run_folder_sort_checks.py
python3 -B tests/run_hotkey_checks.py
python3 -B tests/run_chooser_checks.py
python3 -B tests/run_native_checks.py
```

the UI checks run offscreen with temporary profiles. the portal integration tests
and native Qt tests are described in the portal guide.

still early, so there are rough edges. archive editing and remote file browsing
aren't supported, and some desktop-specific behavior needs testing outside my setup.

[third-party notices and license status](NOTICE.md)
