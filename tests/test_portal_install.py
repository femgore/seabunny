import importlib.util
from pathlib import Path
import os
import json
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("portal_user", Path(__file__).resolve().parents[1]/"packaging/seabunny/portal_user.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class InstallTests(unittest.TestCase):
    def test_preserve_other_interfaces(self):
        old = "# retained\n[preferred]\ndefault=gtk\norg.freedesktop.impl.portal.ScreenCast=wlr\norg.freedesktop.impl.portal.FileChooser=gtk;kde\n[other]\nkey=value\n"
        new = m.chooser_config(old)
        self.assertEqual(new, old.replace("FileChooser=gtk;kde", "FileChooser=seabunny"))
    def test_insert_at_section_end(self):
        old = "[preferred]\ndefault=gtk\n[other]\nkey=value\n"
        self.assertIn("FileChooser=seabunny\n[other]", m.chooser_config(old))
    def test_reversible_install(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            existing = root/"existing"
            existing.write_bytes(b"original")
            added = root/"new"
            receipt = m.transaction(root, [(existing,b"changed",0o644),(added,b"added",0o644)], "test")
            m.restore(receipt)
            self.assertEqual(existing.read_bytes(), b"original")
            self.assertFalse(added.exists())
    def test_preserve_later_edit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); path=root/"new"
            receipt=m.transaction(root,[(path,b"installed",0o644)],"test")
            path.write_bytes(b"user edit")
            with self.assertRaises(ValueError): m.restore(receipt)
            self.assertEqual(path.read_bytes(), b"user edit")
    def test_command_line_install_enable_and_rollback(self):
        with tempfile.TemporaryDirectory(prefix="seabunny-install-") as tmp:
            root = Path(tmp)
            package = root / "package"
            (package / "bin").mkdir(parents=True)
            (package / "bin/xdg-desktop-portal-seabunny").write_bytes(b"synthetic executable; never run\n")
            source = Path(m.__file__).parent
            names = ["bin/xdg-desktop-portal-seabunny", "seabunny.portal", m.BUS + ".service.in"]
            for name in names[1:]:
                (package / name).write_bytes((source / name).read_bytes())
            (package / "manifest.json").write_text(json.dumps({"application": "Seabunny",
                "files": {name: m.digest((package / name).read_bytes()) for name in names}}))
            home = root / "home"
            home.mkdir()
            data, config = home / "data", home / "config"
            env = dict(os.environ, HOME=str(home), XDG_DATA_HOME=str(data), XDG_CONFIG_HOME=str(config))
            def run(*args):
                return subprocess.check_output([sys.executable, "-B", m.__file__, *args], env=env, text=True)
            install_receipt = Path(run("install", "--package", str(package)).splitlines()[0])
            service = data / "dbus-1/services" / (m.BUS + ".service")
            descriptor = data / "xdg-desktop-portal/portals/seabunny.portal"
            self.assertTrue(service.is_file() and descriptor.is_file())
            self.assertFalse(config.exists(), "registration must not enable the backend")
            base = root / "base.conf"
            previous = "[preferred]\ndefault=gtk\norg.freedesktop.impl.portal.ScreenCast=wlr\norg.freedesktop.impl.portal.Screenshot=wlr\norg.freedesktop.impl.portal.RemoteDesktop=gnome\n"
            base.write_text(previous)
            enable_receipt = Path(run("enable", "--base-config", str(base)).splitlines()[0])
            destination = config / "xdg-desktop-portal/niri-portals.conf"
            self.assertEqual(destination.read_text(), previous + m.INTERFACE + "=seabunny\n")
            run("disable", "--receipt", str(enable_receipt))
            self.assertFalse(destination.exists())
            self.assertEqual(base.read_text(), previous)
            run("uninstall", "--receipt", str(install_receipt))
            self.assertFalse(service.exists() or descriptor.exists())
            self.assertTrue(list((data / "seabunny-portal/releases").iterdir()), "payload must be retained")

if __name__ == "__main__": unittest.main()
