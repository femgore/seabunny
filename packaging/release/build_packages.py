#!/usr/bin/env python3
"""Stage Seabunny and build native Linux packages using fpm."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]


def version():
    metadata = json.loads(subprocess.check_output(
        ["cargo", "metadata", "--no-deps", "--format-version", "1"], cwd=ROOT, text=True
    ))
    return next(package["version"] for package in metadata["packages"] if package["name"] == "seabunny")


def stage(destination, include_docs=True):
    files = {
        "usr/bin/seabunny": ROOT / "target/release/seabunny",
        "usr/bin/xdg-desktop-portal-seabunny": ROOT / "target/release/xdg-desktop-portal-seabunny",
        "usr/share/applications/org.femgore.Seabunny.desktop": ROOT / "packaging/seabunny/org.femgore.Seabunny.desktop",
        "usr/share/icons/hicolor/scalable/apps/org.femgore.Seabunny.svg": ROOT / "packaging/seabunny/org.femgore.Seabunny.svg",
        "usr/share/icons/hicolor/symbolic/apps/org.femgore.Seabunny-symbolic.svg": ROOT / "packaging/seabunny/org.femgore.Seabunny-symbolic.svg",
        "usr/share/xdg-desktop-portal/portals/seabunny.portal": ROOT / "packaging/seabunny/seabunny.portal",
        "usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.seabunny.service": ROOT / "packaging/seabunny/org.freedesktop.impl.portal.desktop.seabunny.service.in",
        "usr/share/licenses/seabunny/LICENSE": ROOT / "LICENSE",
        "usr/share/licenses/seabunny/NOTICE.md": ROOT / "NOTICE.md",
        "usr/share/licenses/seabunny/Phosphor-LICENSE.txt": ROOT / "assets/fonts/Phosphor-LICENSE.txt",
        "usr/share/licenses/seabunny/NerdFontsSymbolsOnly-LICENSE.txt": ROOT / "assets/fonts/NerdFontsSymbolsOnly-LICENSE.txt",
    }
    if include_docs:
        files.update({
            "usr/share/doc/seabunny/README.md": ROOT / "README.md",
            "usr/share/doc/seabunny/CHANGELOG.md": ROOT / "CHANGELOG.md",
            "usr/share/doc/seabunny/PORTAL.md": ROOT / "packaging/seabunny/PORTAL.md",
        })
    destination.mkdir(parents=True, exist_ok=True)
    for relative, source in files.items():
        if not source.is_file():
            raise FileNotFoundError(source)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        target.chmod(0o755 if relative.startswith("usr/bin/") else 0o644)
    service = destination / "usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.seabunny.service"
    service.write_text(service.read_text().replace("@EXEC@", "/usr/bin/xdg-desktop-portal-seabunny"))


def package(kind, output):
    ver = version()
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="seabunny-package-") as temporary:
        root = Path(temporary) / "root"
        stage(root)
        architecture = "amd64" if kind == "deb" else "x86_64"
        command = ["fpm", "-s", "dir", "-t", kind, "-n", "seabunny", "-v", ver,
                   "--iteration", "1", "--license", "MIT", "--description",
                   "Qt/QML file manager with an optional desktop file chooser",
                   "--url", "https://github.com/femgore/seabunny", "--architecture", architecture,
                   "--package", str(output / ("seabunny_" + ver + "_amd64.deb" if kind == "deb"
                                                else "seabunny-" + ver + "-1.x86_64.rpm"))]
        if kind == "rpm":
            dependencies = ["qt6-qtbase", "qt6-qtdeclarative", "qt6-qtsvg", "qt6-qtwayland",
                            "kf6-kwindowsystem", "glib2", "python3", "libarchive", "p7zip", "zip"]
        else:
            dependencies = ["libqt6core6", "libqt6gui6", "libqt6qml6", "libqt6quick6",
                            "qml6-module-qtquick", "qml6-module-qtquick-controls",
                            "qml6-module-qtquick-layouts", "qml6-module-qtquick-effects",
                            "qml6-module-qtquick-shapes", "libqt6svg6", "libqt6dbus6",
                            "libkf6windowsystem6", "libglib2.0-0", "python3", "libarchive13",
                            "7zip | p7zip-full", "zip"]
        for dependency in dependencies:
            command.extend(["--depends", dependency])
        command.extend(["-C", str(root), "usr"])
        subprocess.run(command, check=True, cwd=ROOT)


parser = argparse.ArgumentParser()
parser.add_argument("kind", choices=("deb", "rpm"))
parser.add_argument("--output", required=True, type=Path)
args = parser.parse_args()
package(args.kind, args.output)
