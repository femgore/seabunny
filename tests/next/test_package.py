"""Check a built package and reversible registration inside a disposable home."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--package", required=True)
args = parser.parse_args()
package = Path(args.package).resolve(strict=True)
manifest = json.loads((package / "manifest.json").read_text())
assert manifest["version"] == "0.2.0"
with tempfile.TemporaryDirectory(prefix="seabunny-next-package-") as tmp:
    home = Path(tmp) / "home"
    home.mkdir(mode=0o700)
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
        XDG_DATA_HOME=str(home / ".local/share"), XDG_STATE_HOME=str(home / ".local/state"),
        XDG_CACHE_HOME=str(home / ".cache"), DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent")
    def run(*arguments):
        completed = subprocess.run([str(arg) for arg in arguments], env=env, check=True,
            text=True, capture_output=True, timeout=60)
        print(completed.stdout, end="")
        return completed.stdout
    run("python3", "-B", package / "package_user.py", "install", "--package", package, "--no-register")
    binary = home / ".local/opt/seabunny/current/bin/seabunny"
    assert run(binary, "--version").strip() == "seabunny 0.2.0"
    desktop = home / ".local/share/applications/org.femgore.Seabunny.desktop"
    assert desktop.exists() and "org.femgore.Seabunny" in desktop.read_text()
    portal = package / "portal_user.py"
    registration = run("python3", "-B", portal, "install", "--package", package)
    install_receipt = Path(registration.splitlines()[0])
    service = home / ".local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.seabunny.service"
    descriptor = home / ".local/share/xdg-desktop-portal/portals/seabunny.portal"
    assert service.exists() and descriptor.exists()
    assert not (home / ".config/xdg-desktop-portal/niri-portals.conf").exists()
    base = home / "base-portals.conf"
    base.write_text("[preferred]\ndefault=gtk\norg.freedesktop.impl.portal.ScreenCast=wlr\n")
    enabled = run("python3", "-B", portal, "enable", "--base-config", base)
    enable_receipt = Path(enabled.splitlines()[0])
    active = home / ".config/xdg-desktop-portal/niri-portals.conf"
    assert "org.freedesktop.impl.portal.FileChooser=seabunny" in active.read_text()
    assert "org.freedesktop.impl.portal.ScreenCast=wlr" in active.read_text()
    run("python3", "-B", portal, "disable", "--receipt", enable_receipt)
    assert not active.exists()
    run("python3", "-B", portal, "uninstall", "--receipt", install_receipt)
    assert not service.exists() and not descriptor.exists()
    assert binary.exists(), "removing portal registration must retain the explorer"
    print("PASS packaged 0.2 install, separate portal registration and reversible routing in a disposable home")
