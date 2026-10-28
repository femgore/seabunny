# Release builds

release builds are made from a version tag. the workflow checks that the tag
matches `Cargo.toml`, builds the app and picker, and publishes the release once
the Debian/RPM package and AppImage jobs succeed. The Arch package is attempted
separately and does not hold up the downloadable release.

the draft includes:

- Debian and RPM packages (`.deb` and `.rpm`)
- a standalone `seabunny` executable
- a user-installable `.tar.gz` package with the optional picker
- an AppImage
- `SHA256SUMS` for checking downloads

to prepare a release, update the version in `Cargo.toml`, `Cargo.lock`,
`flake.nix`, and `packaging/aur/PKGBUILD` together. check the changes, push a tag
in the form `v0.2.1`. the release job does not change package settings or
activate the picker.

the source build needs Rust, CMake, Ninja, Qt 6, KDE Window System, GLib, and
development headers for the libraries listed in the project build setup. Native
packages also expect those runtime libraries, plus Python, libarchive, a 7-Zip
implementation, and `zip` for archive and file operations.

the AppImage includes the Qt libraries and QML modules found by the bundler.
Host-provided tools used for archive operations may still need to be installed
separately. The Ubuntu 26.04 Qt packages currently omit the Wayland client
platform plugin, so this AppImage uses XCB and needs XWayland in Wayland sessions.
The native packages use the system Qt plugins and can run directly on Wayland.
Test the draft on a clean system before calling it done; package metadata and Qt
module names vary between distributions.

`build_packages.py` stages the system package files and uses `fpm` to create a
Debian or RPM package. It is intended for release automation and writes only to
the output directory you pass it.
