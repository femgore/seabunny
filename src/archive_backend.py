import ctypes
import ctypes.util
import datetime
import errno
import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import stat
import sys
import tempfile

MAX_ENTRIES = 100000
MAX_NAMES = 8 * 1024 * 1024
MAX_BYTES = 4 * 1024**3
OPEN_CACHE_BYTES = 256 * 1024**2


def safe_name(value):
    if not value or "\x00" in value or "\\" in value or value.startswith("/"):
        raise ValueError("Unsafe archive member path")
    while value.startswith("./"):
        value = value[2:]
    value = value.rstrip("/")
    if value in ("", "."):
        return ""
    parts = value.split("/")
    if any(part in ("", ".", "..") for part in parts) or ":" in parts[0]:
        raise ValueError("Unsafe archive member path: " + value)
    return value


class Reader:
    def __init__(self, path):
        library = ctypes.util.find_library("archive")
        if not library:
            raise RuntimeError("libarchive is required for archive browsing")
        self.lib = ctypes.CDLL(library)
        signatures = {
            "archive_read_new": (ctypes.c_void_p, []),
            "archive_read_support_filter_all": (ctypes.c_int, [ctypes.c_void_p]),
            "archive_read_support_format_all": (ctypes.c_int, [ctypes.c_void_p]),
            "archive_read_open_filename": (ctypes.c_int, [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t]),
            "archive_read_next_header": (ctypes.c_int, [ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]),
            "archive_read_data": (ctypes.c_ssize_t, [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t]),
            "archive_read_free": (ctypes.c_int, [ctypes.c_void_p]),
            "archive_error_string": (ctypes.c_char_p, [ctypes.c_void_p]),
            "archive_entry_pathname_utf8": (ctypes.c_char_p, [ctypes.c_void_p]),
            "archive_entry_pathname": (ctypes.c_char_p, [ctypes.c_void_p]),
            "archive_entry_size": (ctypes.c_int64, [ctypes.c_void_p]),
            "archive_entry_mtime": (ctypes.c_int64, [ctypes.c_void_p]),
            "archive_entry_filetype": (ctypes.c_uint, [ctypes.c_void_p]),
            "archive_entry_symlink": (ctypes.c_char_p, [ctypes.c_void_p]),
            "archive_entry_hardlink": (ctypes.c_char_p, [ctypes.c_void_p]),
        }
        for name, (result, arguments) in signatures.items():
            function = getattr(self.lib, name)
            function.restype = result
            function.argtypes = arguments
        self.handle = self.lib.archive_read_new()
        if not self.handle:
            raise MemoryError("Cannot allocate archive reader")
        try:
            self.lib.archive_read_support_filter_all(self.handle)
            self.lib.archive_read_support_format_all(self.handle)
            if self.lib.archive_read_open_filename(self.handle, os.fsencode(path), 65536) < 0:
                raise ValueError(self.error())
        except BaseException:
            self.close()
            raise

    def error(self):
        return (self.lib.archive_error_string(self.handle) or b"Archive read failed").decode("utf-8", "replace")

    def close(self):
        if self.handle:
            self.lib.archive_read_free(self.handle)
            self.handle = None

    def __enter__(self):
        return self

    def __exit__(self, *unused):
        self.close()

    def entries(self):
        entry = ctypes.c_void_p()
        while True:
            result = self.lib.archive_read_next_header(self.handle, ctypes.byref(entry))
            if result == 1:
                return
            if result < 0:
                raise ValueError(self.error())
            raw = self.lib.archive_entry_pathname_utf8(entry) or self.lib.archive_entry_pathname(entry)
            if not raw:
                raise ValueError("Archive member has no readable name")
            name = safe_name(raw.decode("utf-8"))
            if not name:
                continue
            kind = self.lib.archive_entry_filetype(entry)
            linked = bool(self.lib.archive_entry_symlink(entry) or self.lib.archive_entry_hardlink(entry))
            yield {"name": name, "is_dir": stat.S_ISDIR(kind) and not linked,
                   "blocked": linked or not (stat.S_ISDIR(kind) or stat.S_ISREG(kind)),
                   "size": max(0, self.lib.archive_entry_size(entry)),
                   "modified": max(0, self.lib.archive_entry_mtime(entry))}

    def copy(self, output, expected_size):
        buffer = ctypes.create_string_buffer(65536)
        total = 0
        while True:
            count = self.lib.archive_read_data(self.handle, buffer, len(buffer))
            if count < 0:
                raise ValueError(self.error())
            if count == 0:
                break
            total += count
            if total > expected_size or total > MAX_BYTES:
                raise ValueError("Archive member exceeds its declared size")
            output.write(buffer.raw[:count])
        if total != expected_size:
            raise ValueError("Truncated archive member")


def fingerprint(path):
    value = path.stat()
    return value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns


def catalog(path):
    result = {}
    names_size = 0
    with Reader(path) as reader:
        for entry in reader.entries():
            name = entry["name"]
            names_size += len(name.encode("utf-8"))
            if len(result) >= MAX_ENTRIES or names_size > MAX_NAMES:
                raise ValueError("Archive index exceeds the safe browsing limit")
            if name in result:
                raise ValueError("Duplicate archive member: " + name)
            result[name] = entry
    for name in list(result):
        parent = Path(name).parent
        while str(parent) != ".":
            key = parent.as_posix()
            if key in result and not result[key]["is_dir"]:
                raise ValueError("Archive member has a non-directory ancestor: " + key)
            parent = parent.parent
    return result


def children(index, directory):
    directory = safe_name(directory) if directory else ""
    prefix = directory + "/" if directory else ""
    if directory and not (directory in index and index[directory]["is_dir"]) and not any(name.startswith(prefix) for name in index):
        raise ValueError("Archive folder is unavailable")
    result = {}
    for name, entry in index.items():
        if not name.startswith(prefix) or name == directory:
            continue
        tail = name[len(prefix):]
        child, separator, remainder = tail.partition("/")
        if separator:
            result.setdefault(child, {"name": child, "is_dir": True, "blocked": False,
                                      "size": 0, "modified": entry["modified"]})
        else:
            result[child] = dict(entry, name=child)
    for entry in result.values():
        try:
            entry["modified_str"] = datetime.datetime.fromtimestamp(entry["modified"]).strftime("%Y-%m-%d %H:%M")
        except (ValueError, OverflowError, OSError):
            entry["modified_str"] = "-"
    return list(result.values())


def archive_stem(path):
    for suffix in (".tar.gz", ".tar.xz", ".tar.bz2", ".tar.zst", ".tar.lz4", ".tar.lzma", ".tgz", ".txz", ".tbz2", ".zip", ".7z", ".rar", ".tar"):
        if path.name.lower().endswith(suffix):
            name = path.name[:-len(suffix)]
            return name if name not in ("", ".", "..") else "archive"
    return path.stem or "archive"


def publish(source, destination, label):
    library = ctypes.CDLL(None, use_errno=True)
    rename = getattr(library, "renameat2", None)
    if rename is None:
        raise RuntimeError("Atomic no-overwrite publishing is unavailable")
    rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    rename.restype = ctypes.c_int
    source_fd = os.open(source.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    destination_fd = os.open(destination, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for counter in range(10000):
            candidate = label if counter == 0 else label + " (" + str(counter) + ")"
            result = rename(source_fd, os.fsencode(source.name), destination_fd, os.fsencode(candidate), 1)
            if result == 0:
                return str(destination / candidate)
            error = ctypes.get_errno()
            if error != errno.EEXIST:
                raise OSError(error, os.strerror(error))
        raise ValueError("Too many conflicting extraction destinations")
    finally:
        os.close(source_fd)
        os.close(destination_fd)


def execute(request):
    if request.get("action") not in ("list", "copy", "extract", "open"):
        raise ValueError("Unknown archive operation")
    if request["action"] != "open":
        return execute_unlocked(request)
    descriptor = os.open(request["destination"], os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        return execute_unlocked(request)
    finally:
        os.close(descriptor)


def execute_unlocked(request):
    path = Path(request["archive"]).resolve(strict=True)
    identity = fingerprint(path)
    index = catalog(path)
    if fingerprint(path) != identity:
        raise ValueError("Archive changed while its index was being read")
    if request["action"] == "list":
        return {"entries": children(index, request.get("directory", ""))}
    selected = [safe_name(name) for name in request.get("selection", [])]
    if any(not name for name in selected):
        raise ValueError("Invalid archive selection")
    selected = list(dict.fromkeys(selected))
    if request["action"] == "copy" and not selected:
        selected = list(dict.fromkeys(name.split("/")[0] for name in index))
    selected = [name for name in selected if not any(name.startswith(parent + "/") for parent in selected if parent != name)]
    for name in selected:
        if name not in index and not any(value.startswith(name + "/") for value in index):
            raise ValueError("Selected archive member is missing: " + name)
    wanted = {name: entry for name, entry in index.items()
              if not selected or any(name == value or name.startswith(value + "/") for value in selected)}
    if any(entry["blocked"] for entry in wanted.values()):
        raise ValueError("Links and special files cannot be extracted; select regular files or folders instead")
    total = sum(entry["size"] for entry in wanted.values() if not entry["is_dir"])
    if total > MAX_BYTES:
        raise ValueError("Extraction exceeds the 4 GiB per-operation safety limit")
    destination = Path(request["destination"]).resolve(strict=True)
    if not destination.is_dir():
        raise ValueError("Extraction destination must be a real directory")
    if shutil.disk_usage(destination).free < total + 16 * 1024**2:
        raise ValueError("Not enough free disk space to extract safely")
    if request["action"] == "open":
        if len(selected) != 1 or selected[0] not in wanted or wanted[selected[0]]["is_dir"]:
            raise ValueError("Only a single regular archive file can be opened")
        used = 0
        for root, directories, files in os.walk(destination, followlinks=False):
            for name in files:
                value = Path(root, name).lstat()
                if stat.S_ISREG(value.st_mode):
                    used += value.st_size
        if used + total > OPEN_CACHE_BYTES:
            raise ValueError("Read-only preview cache is full (256 MiB); extract the file instead")
    with tempfile.TemporaryDirectory(prefix=".seabunny-archive-", dir=destination) as temporary:
        content = Path(temporary) / "content"
        content.mkdir(mode=0o700)
        seen = set()
        with Reader(path) as reader:
            for entry in reader.entries():
                name = entry["name"]
                if name not in index or entry != index[name] or name in seen:
                    raise ValueError("Archive changed during extraction")
                seen.add(name)
                if name not in wanted:
                    continue
                target = content / name
                target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                if entry["is_dir"]:
                    target.mkdir(exist_ok=True, mode=0o700)
                else:
                    with target.open("xb") as output:
                        os.chmod(target, 0o600)
                        reader.copy(output, entry["size"])
                    if request["action"] == "open":
                        os.chmod(target, 0o400)
        if seen != set(index) or fingerprint(path) != identity:
            raise ValueError("Archive changed during extraction")
        if request["action"] == "copy" and selected:
            paths = [publish(content / name, destination, Path(name).name) for name in selected]
        else:
            paths = [publish(content, destination, archive_stem(path))]
        result = {"paths": paths}
        if request["action"] == "open":
            result["open_path"] = str(Path(paths[0]) / selected[0])
        return result


if __name__ == "__main__":
    def interrupted(unused_signal, unused_frame):
        raise InterruptedError("Archive operation cancelled")
    signal.signal(signal.SIGTERM, interrupted)
    try:
        print(json.dumps(execute(json.load(sys.stdin)), ensure_ascii=True))
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
