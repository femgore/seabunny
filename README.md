# seabunny

a file manager. for managing files. groundbreaking stuff.

i wanted my folders to look nice and stuff so that became a rust + qt/qml project.
there are tabs. there are thumbnails. the sidebar remembers where i left it.
i've spent an unreasonable amount of time looking at little rectangles.

fuck it. the rectangles look good.

anyway. i use it on cachyos with niri. that's the setup getting actual use, so
keep that in mind if you're bringing it somewhere else.

## look at her

yeah theres 4 of them. i really wanted you to see that it changes colors.
yes, the spacing is deliberate. i have been incredibly annoying about it.

| dark | light |
| --- | --- |
| ![Seabunny browsing files in dark mode](docs/gallery/image1.png) | ![Seabunny browsing files in light mode](docs/gallery/image2.png) |
| ![Seabunny storage overview](docs/gallery/image3.png) | ![Seabunny with a warm desktop palette](docs/gallery/image4.png) |

## things i put in here

- grid and list views, tabs, search, and the keyboard shortcuts your hands already know
- image and video thumbnails. the videos don't start playing every time you scroll past them
- a sidebar you can resize and rearrange, with bookmarks and saved open/closed state
- per-folder sorting. only folders with custom sorting need a saved entry
- hidden files shown by default. ctrl+h if you'd rather pretend `.config` doesn't exist
- trash, restore, copy/paste, drag and drop, and undo/redo for when you do some stupid shit
- read-only archive browsing and extraction
- file permissions in properties, including a make executable switch. no terminal detour
- built-in palettes, light/dark modes, reduced motion, and optional live Serpantinum colors
- a matching file picker for apps using desktop portals. yes, i got distracted by that too

f2 renames. delete sends things to trash. ctrl+shift+n makes a folder. f5 refreshes.
the rest are in [HOTKEYS.md](HOTKEYS.md). there's a table. very official.

## okay, build it

the dependency list got a little long. you'll need rust/cargo, a c++ compiler,
cmake, ninja, pkg-config, qt 6 (base, declarative/quick, svg, and wayland), and
KDE Frameworks 6 WindowSystem.

python 3 and libarchive handle archives. ffmpeg adds video thumbnails. zip and 7z
are used for the compression formats that need them.

run these from the repo root:

```fish
cargo build --release --locked
./target/release/seabunny
```

folder paths, archives, and local file urls all work as arguments.

there isn't a published release or AUR package yet, so you'll need to build from
source. the Nix recipe is here too, but it hasn't been verified for this snapshot.
its presence in the repo is not a spiritual guarantee that it works.
if you try it and it falls on its ass, the details would actually be useful.

## put it on your computer

the local installer keeps versioned copies. your previous build gets to stay
around when you update. occasionally the old thing working is useful information.

```fish
python3 -B packaging/seabunny/package_user.py build --with-portal
```

it prints a package directory. put that path here:

```fish
fish packaging/seabunny/install-user.fish --package /absolute/path/to/package
```

the launcher lives in `~/.local/bin`. add that to your PATH if it isn't there.
you have to pass `--make-default` to change the default folder handler, and the
portal still needs enabling separately. installing a file manager shouldn't become
a surprise desktop renovation.

settings go in `~/.config/seabunny`. sidebar and sorting state go under
`~/.local/state/seabunny`. the documented XDG directory overrides work too.
[the installation guide has the details](packaging/seabunny/README.md).

## naturally, there's a file picker

it's a separate `xdg-desktop-portal-seabunny` process. you can close a picker and
your file-manager window stays right where it was. the app opening the dialog
still does its own reading and writing.

registration and enabling are separate steps. you can pick seabunny just for
FileChooser and keep your existing backends for screen sharing and everything
else. keep the rollback instructions handy the first time. optimism is not a
recovery procedure.

[setup, testing, and how to go back](packaging/seabunny/PORTAL.md).

## yes, there are tests

moving files around is the entire fucking job, so there are checks for that.

```fish
cargo test --release --locked
python3 -B tests/test_archives.py
python3 -B tests/test_portal_install.py
python3 -B tests/run_folder_sort_checks.py
python3 -B tests/run_hotkey_checks.py
python3 -B tests/run_chooser_checks.py
python3 -B tests/run_native_checks.py
```

the UI checks run offscreen with temporary profiles. the portal guide covers the
portal integration tests and native Qt tests.

it's still early. archive editing and remote file browsing aren't supported,
and some desktop-specific behavior needs checking outside my setup.

bugs, suggestions, weird screenshots: all welcome. open an issue and tell me
what you did, what happened, and what you expected. include your distro and desktop
setup if it seems relevant. i use this thing too, so i'd quite like to fix it. suggestions are welcome too.
there's a decent chance the thing annoying you also annoys the shit out of me.

[third-party notices and license status](NOTICE.md).

anyway. that's seabunny. it opens folders and i have opinions about the spacing.
