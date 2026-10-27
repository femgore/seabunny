import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tarfile
import tempfile


def checksum(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(with_portal=False):
    repository = Path(__file__).resolve().parents[2]
    source = repository / "packaging/seabunny"
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    output = repository / "target/seabunny-dist" / stamp
    output.mkdir(parents=True, exist_ok=False)
    files = {
        "bin/seabunny": repository / "target/release/seabunny",
        "seabunny.fish": source / "seabunny.fish",
        "install-user.fish": source / "install-user.fish",
        "package_user.py": source / "package_user.py",
        "org.femgore.Seabunny.desktop": source / "org.femgore.Seabunny.desktop",
        "org.femgore.Seabunny.svg": source / "org.femgore.Seabunny.svg",
        "README.md": source / "README.md",
        "ABOUT.md": repository / "README.md",
        "NEXT-VERSION.md": repository / "NEXT-VERSION.md",
        "NOTICE.md": repository / "NOTICE.md",
    }
    if with_portal:
        files.update({"bin/xdg-desktop-portal-seabunny": repository / "target/release/xdg-desktop-portal-seabunny"})
        for name in ("portal_user.py", "seabunny.portal", "org.freedesktop.impl.portal.desktop.seabunny.service.in", "PORTAL.md"):
            files[name] = source / name
    for license_path in (repository / "assets/fonts").glob("*LICENSE*"):
        files["licenses/" + license_path.name] = license_path
    for relative, original in files.items():
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, destination)
        destination.chmod(0o755 if relative in ("bin/seabunny", "bin/xdg-desktop-portal-seabunny", "seabunny.fish", "install-user.fish") else 0o644)
    manifest = {"application": "Seabunny", "version": "0.2.0", "release": stamp,
                "files": {relative: checksum(output / relative) for relative in files}}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    archive_path = output.parent / ("seabunny-0.2.0-linux-x86_64-" + stamp + ".tar.gz")
    with tarfile.open(archive_path, "x:gz") as archive:
        archive.add(output, arcname="seabunny-" + stamp)
    (archive_path.parent / (archive_path.name + ".sha256")).write_text(checksum(archive_path) + "  " + archive_path.name + "\n")
    print(json.dumps({"package": str(output), "archive": str(archive_path)}))


def replace_file(destination, data, mode, backups, prefix):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() or destination.is_symlink():
        backup = backups / destination.relative_to(prefix)
        backup.parent.mkdir(parents=True, exist_ok=True)
        if destination.is_symlink():
            backup.symlink_to(os.readlink(destination))
        else:
            shutil.copy2(destination, backup)
    with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=".seabunny-", delete=False) as temporary:
        temporary.write(data)
        os.fchmod(temporary.fileno(), mode)
        os.fsync(temporary.fileno())
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, destination)


def install(package, make_default, no_register):
    package = Path(package).resolve(strict=True)
    manifest = json.loads((package / "manifest.json").read_text())
    if manifest.get("application") != "Seabunny" or not re.fullmatch(r"[0-9A-Za-z._-]+", manifest["release"]):
        raise ValueError("Not a Seabunny package")
    for name, expected in manifest["files"].items():
        relative = PurePosixPath(name)
        path = package / name
        if relative.is_absolute() or ".." in relative.parts or path.is_symlink() or not path.resolve().is_relative_to(package):
            raise ValueError("Unsafe package path")
        if checksum(path) != expected:
            raise ValueError("Package checksum mismatch: " + name)
    home = Path.home()
    prefix = home / ".local"
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(prefix / "share")))
    if data_home != prefix / "share":
        raise ValueError("This reviewed installer requires the standard ~/.local/share data directory")
    root = prefix / "opt/seabunny"
    if (root / "current").exists() and not (root / "current").is_symlink():
        raise ValueError("Refusing to replace a non-symlink current installation")
    root.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(root).free < sum((package / name).stat().st_size for name in manifest["files"]) * 2 + 32 * 1024**2:
        raise ValueError("Insufficient free space for a reversible installation")
    release = root / "releases" / manifest["release"]
    if release.exists():
        raise FileExistsError("This release is already installed: " + str(release))
    receipt_directory = root / "installations" / manifest["release"]
    receipt_directory.mkdir(parents=True, exist_ok=False)
    previous_default = None
    if not no_register:
        previous_default = subprocess.check_output(["xdg-mime", "query", "default", "inode/directory"], text=True).strip()
    receipt = {"application": "Seabunny", "release": str(release), "previous_default": previous_default,
               "backup_directory": str(receipt_directory / "backups"), "files": [], "make_default": make_default,
               "previous_current": os.readlink(root / "current") if (root / "current").is_symlink() else None}
    receipt_path = receipt_directory / "receipt.json"
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
    if make_default:
        mimeapps = Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config"))) / "mimeapps.list"
        if mimeapps.is_file():
            shutil.copy2(mimeapps, receipt_directory / "mimeapps.list.before")
    shutil.copytree(package, release)
    launcher = prefix / "bin/seabunny"
    desktop = data_home / "applications/org.femgore.Seabunny.desktop"
    icon = data_home / "icons/hicolor/scalable/apps/org.femgore.Seabunny.svg"
    quoted_launcher = str(launcher).replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("`", "\\`")
    desktop_data = (package / "org.femgore.Seabunny.desktop").read_text().replace("Exec=seabunny %U", 'Exec="' + quoted_launcher + '" %U').replace("TryExec=seabunny", "TryExec=" + str(launcher))
    for target, content, mode in [(launcher, (package / "seabunny.fish").read_bytes(), 0o755),
                                  (desktop, desktop_data.encode(), 0o644),
                                  (icon, (package / "org.femgore.Seabunny.svg").read_bytes(), 0o644)]:
        replace_file(target, content, mode, receipt_directory / "backups", prefix)
        receipt["files"].append({"path": str(target), "sha256": checksum(target)})
        receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
    temporary_link = root / (".current-" + manifest["release"])
    temporary_link.symlink_to("releases/" + manifest["release"])
    os.replace(temporary_link, root / "current")
    if not no_register:
        subprocess.run(["desktop-file-validate", str(desktop)], check=True)
        subprocess.run(["update-desktop-database", str(desktop.parent)], check=True)
        if make_default:
            subprocess.run(["xdg-mime", "default", desktop.name, "inode/directory"], check=True)
            current = subprocess.check_output(["xdg-mime", "query", "default", "inode/directory"], text=True).strip()
            if current != desktop.name:
                raise ValueError("Default folder association could not be verified")
    receipt["status"] = "installed"
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"receipt": str(receipt_path), "command": str(launcher), "release": str(release)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build or install the user-local Seabunny application")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("build").add_argument("--with-portal", action="store_true")
    installer = commands.add_parser("install")
    installer.add_argument("--package", required=True)
    installer.add_argument("--make-default", action="store_true")
    installer.add_argument("--no-register", action="store_true")
    arguments = parser.parse_args()
    if arguments.command == "build":
        build(arguments.with_portal)
    else:
        install(arguments.package, arguments.make_default, arguments.no_register)
