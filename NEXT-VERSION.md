# seabunny 0.2.0

new guts. same rabbit. considerably more fucking plumbing.

this development branch starts from [upstream Loaf](https://github.com/m-uvex/loaf-fm)
commit `7cbde575414723f330e866ceeacf31862f7835e0` (26 october 2026).
it keeps upstream's typed file model, asynchronous directory scans, file watcher,
background jobs, split panes, batch rename, recursive search and quick look.
we aren't making a second file browser just for the picker. both windows use the
same pane, sidebar and theme components.

## the stuff brought back

- Seabunny branding, icons, live Serpantinum colors and the compact save-name field
- the independent portal process, OpenFile / SaveFile / SaveFiles, filters,
  choices, overwrite confirmation, cancellation and parent-window integration
- separate saved sidebar width and open/closed state for explorer and picker
- sparse per-folder sorting, hidden files on by default, and existing favorites
- Open With, saved file-type defaults, direct executable/AppImage opening,
  and the Make executable switch in Properties
- folder merging with individual collision decisions, apply-to-all, cancellation,
  and grouped undo/redo, using the same background jobs as ordinary copies
- validated libarchive browsing, extraction and copying archive members

existing `folderTabs`, favorites, sidebar layout and sort state have compatibility
readers. normal 0.2 sessions use the newer pane-state format. the development
launcher doesn't import your installed settings, so trying this branch doesn't
silently migrate your everyday profile.

## try it without replacing anything

from this checkout:

```fish
cargo build --release --locked
fish ./run-development.fish
```

preferences live under `target/development-profile`, independently of the installed
app. it can browse and operate on your real files when you launch it, so the usual
file-manager rules still apply. the launcher doesn't install anything, claim the
normal running-instance service, or change default apps or portal configuration.
close the development window to go back to using the installed version.

building a package also doesn't install it:

```fish
python3 -B packaging/seabunny/package_user.py build --with-portal
```

installation and portal selection remain explicit steps. see the
[installation guide](packaging/seabunny/README.md) and
[portal guide](packaging/seabunny/PORTAL.md). keep the old versioned payload until
you've actually used this one. having a fallback is less exciting than needing one.

## bugs fixed during the port

upstream's copy cleanup could remove a destination created by another process
when exclusive creation failed. cleanup now checks that we created that entry;
moves use a no-replace rename. there are regression tests for files and folders.

a thumbnail provider used a global shutdown flag. closing one picker could disable
thumbnails in later pickers. shutdown now belongs to each provider, with a test
that destroys one provider and loads images through another.

folder merges keep an undo journal, including replaced destination files in trash.
cut clipboard entries aren't cleared before the background operation finishes;
skipped and failed sources remain available to paste again.

## checking the damn thing

`tests/next/run_rust.py` builds the Rust tests, then runs them with disposable
HOME/XDG directories. `tests/next/run_checks.py` drives the shared explorer and
chooser offscreen with synthetic files, keyboard events and a live palette fixture.
it also restarts both modes to verify sorting and independent sidebar persistence.
`tests/next/run_wayland.py` tests copy and cut between separate processes on a
private virtual KWin compositor. nothing needs your live clipboard or preferences.

build native tests in a canonical directory, not through a symlink:

```fish
cmake -S tests -B /tmp/seabunny-qt-tests
cmake --build /tmp/seabunny-qt-tests -j 2
python3 -B tests/next/run_native.py --build-dir /tmp/seabunny-qt-tests
env SEABUNNY_PORTAL_TESTS=/tmp/seabunny-qt-tests/portal-tests python3 -B tests/test_portal_bus.py
```

the portal integration check uses a private bus and temporary service definitions.
it checks activation, concurrent requests, cancellation, and routing through the
real portal frontend. it doesn't enable Seabunny for your desktop.
`--helium` additionally checks Save As with a disposable headless Helium profile;
it doesn't use your browser profile. desktop-visible dialogs still deserve a
manual test before switching the active backend.

`python3 -B tests/next/test_package.py --package /absolute/package/path` installs a
built package into a temporary home and checks portal enable/disable and removal
without touching your desktop.

## verification for this development snapshot

- release explorer and portal builds succeed
- 72 Rust tests, 24 archive-reader tests, and 5 portal-installer tests pass
- native Open With, portal controller/wire replies, and thumbnail lifecycle checks pass
- the shared UI passes keyboard copy/paste, merge decisions and undo/redo,
  executable permissions, Open With, archive copying, chooser filters and modes,
  live palette updates, and persistence across separate processes
- private Wayland clipboard transfers pass for copy and cut between two processes
- private-bus activation and the real portal frontend pass all three methods
- headless Helium Save As reaches the backend with its suggested filename
- package installation and portal rollback pass inside a disposable home

these checks don't replace trying the visible windows on your actual desktop.
the installed 0.1 payload and active portal routing haven't been switched.

## things that still need real-world testing

SMB, network sharing, removable-drive disconnects and privileged operations haven't
been validated on real devices or services during this port. they remain upstream
features rather than promises from a synthetic test. permissions on individual
files use Seabunny's checked file identity; recursive permission changes retain the
upstream implementation. archive previews remain read-only, with the existing
size limits. encrypted formats still depend on installed archive tools.

the gallery currently shows 0.1. new screenshots can wait until the layout is done
being poked. feedback is welcome; tell me what broke and how to make it happen.
