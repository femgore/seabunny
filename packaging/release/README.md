# Release builds

release builds are made from a version tag. the workflow checks that the tag
matches `Cargo.toml`, builds the app and picker, and publishes after all four
asset jobs succeed. releases contain exactly these downloads:

- a Debian package (`.deb`)
- an RPM package (`.rpm`)
- an AppImage
- a user-installable `.tar.gz` package with the optional picker

the release workflow does not attach a standalone binary, checksum file, or
Arch package. Arch packaging files remain available in the repository, but that
job is not run for these releases. the release job does not change portal
preferences or activate the picker.

to prepare a release, update the version in `Cargo.toml`, `Cargo.lock`,
`flake.nix`, `packaging/aur/PKGBUILD`, and `packaging/aur/.SRCINFO` together.
update the matching version checks and release notes, validate the packages,
then push a tag matching the version, such as `v0.2.2`.

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
