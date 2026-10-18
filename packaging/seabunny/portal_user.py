"""Opt-in user portal registration. Never restarts services or changes the manager payload.
Each operation records previous bytes before replacement; rollback checks for later edits.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import tempfile

INTERFACE = "org.freedesktop.impl.portal.FileChooser"
BUS = "org.freedesktop.impl.portal.desktop.seabunny"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def atomic(path, data, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".seabunny-portal-", delete=False) as f:
        f.write(data)
        os.fchmod(f.fileno(), mode)
        os.fsync(f.fileno())
        temp = Path(f.name)
    os.replace(temp, path)


def transaction(root, changes, kind):
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    journal = root / "transactions" / (stamp + "-" + kind)
    journal.mkdir(parents=True, exist_ok=False)
    receipt = {"kind": kind, "changes": []}
    receipt_path = journal / "receipt.json"
    for i, (path, data, mode) in enumerate(changes):
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise ValueError("Refusing to replace non-regular path: " + str(path))
        old = path.read_bytes() if path.exists() else None
        if old is not None:
            (journal / str(i)).write_bytes(old)
        receipt["changes"].append({"path": str(path), "backup": str(i) if old is not None else None,
            "old_mode": path.stat().st_mode & 0o777 if old is not None else None, "sha256": digest(data)})
        # Record intent before replacing, so interrupted operations remain reversible.
        atomic(receipt_path, (json.dumps(receipt, indent=2)+"\n").encode(), 0o600)
        atomic(path, data, mode)
    print(receipt_path)
    return receipt_path


def restore(receipt_path):
    receipt_path = Path(receipt_path).resolve(strict=True)
    receipt = json.loads(receipt_path.read_text())
    for item in receipt["changes"]:
        path = Path(item["path"])
        if path.is_symlink() or not path.is_file() or digest(path.read_bytes()) != item["sha256"]:
            raise ValueError("File changed since this operation; refusing to overwrite: " + str(path))
    for i, item in reversed(list(enumerate(receipt["changes"]))):
        path = Path(item["path"])
        # Retain the installed/edited version too. No recursive deletion.
        shutil.move(str(path), str(receipt_path.parent / (str(i)+".disabled")))
        if item["backup"] is not None:
            atomic(path, (receipt_path.parent/item["backup"]).read_bytes(), item["old_mode"])
    print("Restored previous files; retained payload and transaction backups. No service restarted.")


def chooser_config(text):
    lines = text.splitlines(keepends=True)
    section = ""
    found_section = False
    inserted = False
    result = []
    for line in lines:
        match = re.match(r"\s*\[([^]]+)\]", line)
        if match:
            if section == "preferred" and not inserted:
                result.append(INTERFACE+"=seabunny\n"); inserted = True
            section = match[1]
            found_section |= section == "preferred"
        if section == "preferred" and re.match(r"\s*"+re.escape(INTERFACE)+r"\s*=", line):
            if inserted:
                raise ValueError("Duplicate FileChooser key in source configuration")
            result.append(INTERFACE+"=seabunny\n"); inserted = True
        else:
            result.append(line if line.endswith("\n") else line+"\n")
    if not found_section:
        raise ValueError("The effective base configuration must contain [preferred]")
    if not inserted:
        result.append(INTERFACE+"=seabunny\n")
    return "".join(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    install = sub.add_parser("install")
    install.add_argument("--package", required=True)
    enable = sub.add_parser("enable")
    enable.add_argument("--base-config", required=True, help="The currently effective portals.conf; copied intact except FileChooser")
    for name in ("disable", "uninstall"):
        sub.add_parser(name).add_argument("--receipt", required=True)
    args = parser.parse_args()
    home = Path.home()
    data = Path(os.environ.get("XDG_DATA_HOME", str(home/".local/share"))).absolute()
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(home/".config"))).absolute()
    root = data / "seabunny-portal"
    if args.command in ("disable", "uninstall"):
        restore(args.receipt)
    elif args.command == "enable":
        base = Path(args.base_config).resolve(strict=True)
        destination = config/"xdg-desktop-portal/niri-portals.conf"
        if destination.exists() and base != destination.resolve():
            raise ValueError("An existing user niri-portals.conf must be used as --base-config")
        transaction(root, [(destination, chooser_config(base.read_text()).encode(), 0o644)], "enable")
        print("Only FileChooser changed. Use disable --receipt with the printed receipt to restore it.")
    else:
        package = Path(args.package).resolve(strict=True)
        manifest = json.loads((package/"manifest.json").read_text())
        if manifest.get("application") != "Seabunny":
            raise ValueError("Not a Seabunny package")
        names = ["bin/xdg-desktop-portal-seabunny", "seabunny.portal", BUS+".service.in"]
        for name in names:
            path = package/name
            if path.is_symlink() or not path.resolve().is_relative_to(package) or digest(path.read_bytes()) != manifest["files"].get(name):
                raise ValueError("Missing or changed portal package file: "+name)
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        payload = root/"releases"/stamp
        payload.mkdir(parents=True, exist_ok=False)
        executable = payload/"xdg-desktop-portal-seabunny"
        shutil.copy2(package/names[0], executable); executable.chmod(0o755)
        # D-Bus Exec quoting is not shell syntax; no shell interpolation occurs.
        quoted = '"'+str(executable).replace('\\', '\\\\').replace('"', '\\"')+'"'
        service = (package/names[2]).read_text().replace("@EXEC@", quoted).encode()
        transaction(root, [(data/"dbus-1/services"/(BUS+".service"), service, 0o644),
                           (data/"xdg-desktop-portal/portals/seabunny.portal", (package/names[1]).read_bytes(), 0o644)], "install")
        print("Registered backend only; preferences unchanged. Payload: "+str(payload))


if __name__ == "__main__":
    main()
