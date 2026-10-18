import hashlib
import importlib.util
import io
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import warnings
import zipfile

spec = importlib.util.spec_from_file_location("archive_backend", Path(__file__).resolve().parents[1] / "src/archive_backend.py")
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="seabunny-archive-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.archive = self.root / "Sample # 日本語.zip"
        with zipfile.ZipFile(self.archive, "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("folder/inner/hello ö.txt", b"synthetic archive contents\n")
            archive.writestr("folder/second.txt", b"second file\n")
            archive.writestr("README.txt", b"readme\n")
            archive.writestr("empty/", b"")
            archive.writestr(".hidden", b"hidden\n")
        self.original = hashlib.sha256(self.archive.read_bytes()).digest()
        self.destination = self.root / "destination"
        self.destination.mkdir()

    def execute(self, action="extract", selection=None, **arguments):
        return backend.execute(dict(archive=str(self.archive), destination=str(self.destination),
                                    action=action, selection=selection or [], **arguments))

    def assertUnchanged(self):
        self.assertEqual(self.original, hashlib.sha256(self.archive.read_bytes()).digest())
        self.assertFalse(list(self.destination.glob(".seabunny-archive-*")))

    def test_zip_listing_synthesizes_folders_and_supports_unicode(self):
        entries = self.execute("list")["entries"]
        self.assertEqual({entry["name"] for entry in entries}, {"folder", "README.txt", "empty", ".hidden"})
        nested = self.execute("list", directory="folder/inner")["entries"]
        self.assertEqual(nested[0]["name"], "hello ö.txt")
        self.assertEqual(nested[0]["size"], len(b"synthetic archive contents\n"))
        self.assertTrue(nested[0]["modified_str"])
        self.assertFalse(list(self.destination.iterdir()))
        self.assertUnchanged()

    def test_whole_archive_extracts_under_archive_name(self):
        path = Path(self.execute()["paths"][0])
        self.assertEqual(path.name, "Sample # 日本語")
        self.assertEqual((path / "folder/inner/hello ö.txt").read_bytes(), b"synthetic archive contents\n")
        self.assertTrue((path / "empty").is_dir())
        self.assertTrue((path / ".hidden").is_file())
        self.assertUnchanged()

    def test_selected_nested_file_preserves_its_path_only(self):
        path = Path(self.execute(selection=["folder/inner/hello ö.txt"])["paths"][0])
        self.assertTrue((path / "folder/inner/hello ö.txt").is_file())
        self.assertFalse((path / "README.txt").exists())
        self.assertFalse((path / "folder/second.txt").exists())
        self.assertUnchanged()

    def test_selected_folder_includes_descendants_and_overlaps_are_deduplicated(self):
        path = Path(self.execute(selection=["folder", "folder/inner/hello ö.txt"])["paths"][0])
        self.assertTrue((path / "folder/inner/hello ö.txt").is_file())
        self.assertTrue((path / "folder/second.txt").is_file())
        self.assertFalse((path / "README.txt").exists())

    def test_copy_out_uses_selected_basename_not_archive_prefix(self):
        paths = self.execute("copy", ["folder/inner/hello ö.txt", "folder/second.txt"])["paths"]
        self.assertEqual({Path(path).name for path in paths}, {"hello ö.txt", "second.txt"})
        self.assertFalse((self.destination / "folder").exists())
        self.assertUnchanged()

    def test_copy_folder_out_is_recursive(self):
        path = Path(self.execute("copy", ["folder"])["paths"][0])
        self.assertEqual(path.name, "folder")
        self.assertTrue((path / "inner/hello ö.txt").is_file())

    def test_extract_here_publishes_top_level_entries(self):
        paths = self.execute("copy")["paths"]
        self.assertEqual({Path(path).name for path in paths}, {"folder", "README.txt", "empty", ".hidden"})

    def test_existing_extraction_folder_is_not_merged_or_overwritten(self):
        first = Path(self.execute()["paths"][0])
        (first / "README.txt").write_text("preserve existing data")
        second = Path(self.execute()["paths"][0])
        self.assertNotEqual(first, second)
        self.assertEqual((first / "README.txt").read_text(), "preserve existing data")
        self.assertEqual((second / "README.txt").read_text(), "readme\n")

    def test_existing_file_and_symlink_destinations_are_not_followed(self):
        protected = self.root / "protected"
        protected.mkdir()
        (self.destination / "Sample # 日本語").symlink_to(protected, target_is_directory=True)
        result = Path(self.execute()["paths"][0])
        self.assertEqual(result.name, "Sample # 日本語 (1)")
        self.assertFalse(list(protected.iterdir()))
        (self.destination / "README.txt").write_text("keep")
        result = Path(self.execute("copy", ["README.txt"])["paths"][0])
        self.assertEqual((self.destination / "README.txt").read_text(), "keep")
        self.assertNotEqual(result.name, "README.txt")

    def test_read_only_open_materializes_only_selected_regular_file(self):
        result = self.execute("open", ["README.txt"])
        path = Path(result["open_path"])
        self.assertEqual(path.read_bytes(), b"readme\n")
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o400)
        self.assertFalse((path.parent / "folder").exists())
        self.assertUnchanged()

    def test_open_cache_and_decompression_limits_fail_before_publication(self):
        with patch.object(backend, "OPEN_CACHE_BYTES", 1):
            with self.assertRaisesRegex(ValueError, "cache is full"):
                self.execute("open", ["README.txt"])
        with patch.object(backend, "MAX_BYTES", 1):
            with self.assertRaisesRegex(ValueError, "safety limit"):
                self.execute()
        self.assertFalse(list(self.destination.iterdir()))

    def test_tar_gzip_xz_and_bzip2_are_browsable_and_extractable(self):
        for suffix, mode in [(".tar", "w"), (".tar.gz", "w:gz"), (".tar.xz", "w:xz"), (".tar.bz2", "w:bz2")]:
            self.archive = self.root / ("sample" + suffix)
            with tarfile.open(self.archive, mode) as archive:
                entry = tarfile.TarInfo("./nested/file.txt")
                entry.size = 4
                archive.addfile(entry, io.BytesIO(b"test"))
            self.assertEqual(self.execute("list")["entries"][0]["name"], "nested")
            path = Path(self.execute()["paths"][0])
            self.assertEqual((path / "nested/file.txt").read_bytes(), b"test")

    @unittest.skipUnless(shutil.which("7z"), "7z fixture generator unavailable")
    def test_actual_seven_zip_archive(self):
        source = self.root / "fixture.txt"
        source.write_text("seven zip fixture")
        self.archive = self.root / "fixture.7z"
        subprocess.run(["7z", "a", str(self.archive), str(source)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.assertEqual(self.execute("list")["entries"][0]["name"], "fixture.txt")
        path = Path(self.execute()["paths"][0])
        self.assertEqual((path / "fixture.txt").read_text(), "seven zip fixture")

    def test_path_traversal_and_windows_paths_are_rejected(self):
        for name in ["../escape", "/absolute", "a/../../escape", "C:/escape", "folder\\..\\..\\escape"]:
            self.archive = self.root / "unsafe.zip"
            with zipfile.ZipFile(self.archive, "w") as archive:
                archive.writestr(name, "unsafe")
            with self.assertRaisesRegex(ValueError, "Unsafe archive member path"):
                self.execute()
        self.assertFalse(list(self.destination.iterdir()))
        self.assertFalse((self.root / "escape").exists())

    def test_libarchive_normalizes_benign_windows_separators_safely(self):
        self.archive = self.root / "windows.zip"
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr("folder\\file.txt", "safe")
        result = Path(self.execute()["paths"][0])
        self.assertEqual((result / "folder/file.txt").read_text(), "safe")

    def test_links_can_be_listed_but_never_followed_during_extraction(self):
        self.archive = self.root / "links.tar"
        with tarfile.open(self.archive, "w") as archive:
            entry = tarfile.TarInfo("link")
            entry.type = tarfile.SYMTYPE
            entry.linkname = "../../protected"
            archive.addfile(entry)
            entry = tarfile.TarInfo("plain.txt")
            entry.size = 4
            archive.addfile(entry, io.BytesIO(b"safe"))
        self.assertTrue(any(entry["blocked"] for entry in self.execute("list")["entries"]))
        with self.assertRaisesRegex(ValueError, "Links and special files"):
            self.execute()
        result = Path(self.execute(selection=["plain.txt"])["paths"][0])
        self.assertEqual((result / "plain.txt").read_bytes(), b"safe")

    def test_hardlinks_and_special_files_are_rejected(self):
        for kind in [tarfile.LNKTYPE, tarfile.FIFOTYPE]:
            self.archive = self.root / "special.tar"
            with tarfile.open(self.archive, "w") as archive:
                entry = tarfile.TarInfo("special")
                entry.type = kind
                entry.linkname = "elsewhere"
                archive.addfile(entry)
            with self.assertRaisesRegex(ValueError, "Links and special files"):
                self.execute()

    def test_duplicate_names_are_not_silently_overwritten(self):
        self.archive = self.root / "duplicates.zip"
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(self.archive, "w") as archive:
                archive.writestr("same.txt", "first")
                archive.writestr("same.txt", "second")
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            self.execute()

    def test_file_directory_conflicts_are_rejected(self):
        self.archive = self.root / "conflict.zip"
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr("parent", "file")
            archive.writestr("parent/child", "child")
        with self.assertRaisesRegex(ValueError, "non-directory ancestor"):
            self.execute()

    def test_corrupt_or_missing_members_do_not_publish_partial_output(self):
        with self.assertRaisesRegex(ValueError, "missing"):
            self.execute(selection=["missing.txt"])
        self.archive = self.root / "corrupt.zip"
        self.archive.write_bytes(b"not an archive")
        with self.assertRaises(ValueError):
            self.execute()
        self.assertFalse(list(self.destination.iterdir()))

    def test_publication_failure_cleans_staging_without_touching_existing_data(self):
        existing = self.destination / "keep.txt"
        existing.write_text("keep")
        with patch.object(backend, "publish", side_effect=OSError("synthetic publication failure")):
            with self.assertRaises(OSError):
                self.execute()
        self.assertEqual(list(self.destination.iterdir()), [existing])
        self.assertUnchanged()

    def test_unknown_archive_folder_reports_an_error(self):
        with self.assertRaisesRegex(ValueError, "unavailable"):
            self.execute("list", directory="missing")

    def test_crc_failure_does_not_publish_partial_files(self):
        self.archive = self.root / "bad-crc.zip"
        with zipfile.ZipFile(self.archive, "w", zipfile.ZIP_STORED) as archive:
            archive.writestr("file.txt", b"checksum fixture")
        data = bytearray(self.archive.read_bytes())
        data[30 + len("file.txt")] ^= 1
        self.archive.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "CRC"):
            self.execute()
        self.assertFalse(list(self.destination.iterdir()))

    def test_archive_change_during_extraction_aborts_publication(self):
        original_copy = backend.Reader.copy
        archive_path = self.archive
        def changed_copy(reader, output, size):
            original_copy(reader, output, size)
            current = archive_path.stat()
            os.utime(archive_path, ns=(current.st_atime_ns, current.st_mtime_ns + 2000000000))
        with patch.object(backend.Reader, "copy", changed_copy):
            with self.assertRaisesRegex(ValueError, "changed during extraction"):
                self.execute()
        self.assertFalse(list(self.destination.iterdir()))


if __name__ == "__main__":
    unittest.main()
