use serde::Serialize;
use std::fs::{self, Metadata, OpenOptions, Permissions};
use std::io;
use std::os::fd::AsRawFd;
use std::os::unix::fs::{MetadataExt, OpenOptionsExt, PermissionsExt};
use std::path::Path;

#[derive(Serialize)]
pub struct PermissionInfo {
    pub permission_mode: u32,
    pub permission_identity: String,
    pub can_edit_permissions: bool,
    pub is_regular: bool,
    pub is_symlink: bool,
    pub permissions_note: String,
}

fn identity(metadata: &Metadata) -> String {
    format!("{}:{}", metadata.dev(), metadata.ino())
}

pub fn inspect(path: &Path) -> io::Result<PermissionInfo> {
    let metadata = fs::symlink_metadata(path)?;
    let is_symlink = metadata.file_type().is_symlink();
    let supported = metadata.is_file() || metadata.is_dir();
    let owned = metadata.uid() == unsafe { libc::geteuid() };
    Ok(PermissionInfo {
        permission_mode: metadata.mode() & 0o7777,
        permission_identity: identity(&metadata),
        can_edit_permissions: supported && owned,
        is_regular: metadata.is_file(),
        is_symlink,
        permissions_note: if is_symlink {
            "Permissions belong to the link's target. Open its location to edit them."
        } else if !supported {
            "Permissions cannot be edited for this type of item."
        } else if !owned {
            "Only the owner can change these permissions."
        } else { "" }.into(),
    })
}

pub fn apply(path: &Path, expected_identity: &str, expected_mode: u32, mode: u32) -> Result<(), String> {
    if !path.is_absolute() || mode > 0o777 || expected_mode > 0o7777 {
        return Err("Invalid file permissions.".into());
    }
    // O_PATH pins the item without reading it, including when its read bit is off.
    // O_NOFOLLOW lets us reject links rather than change their targets.
    let item = OpenOptions::new().read(true)
        .custom_flags(libc::O_PATH | libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(path).map_err(|error| format!("Cannot open this item: {error}"))?;
    let metadata = item.metadata().map_err(|error| error.to_string())?;
    if !metadata.is_file() && !metadata.is_dir() {
        return Err("Only regular files and folders support permission editing.".into());
    }
    if metadata.uid() != unsafe { libc::geteuid() } {
        return Err("Only the owner can change these permissions.".into());
    }
    if identity(&metadata) != expected_identity || metadata.mode() & 0o7777 != expected_mode {
        return Err("This item or its permissions changed. Reopen Properties and try again.".into());
    }
    // chmod through our own pinned descriptor avoids a path-replacement race.
    // File::set_permissions uses fchmod, which cannot operate on an O_PATH fd.
    let descriptor = format!("/proc/self/fd/{}", item.as_raw_fd());
    let next = (metadata.mode() & 0o7000) | mode;
    fs::set_permissions(descriptor, Permissions::from_mode(next))
        .map_err(|error| format!("Cannot save permissions: {error}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::os::unix::fs::symlink;

    struct Fixture(PathBuf);
    impl Fixture {
        fn new() -> Self {
            let path = std::env::temp_dir().join(format!("seabunny-permissions-{}-{}", std::process::id(),
                std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()));
            fs::create_dir(&path).unwrap();
            Self(path)
        }
        fn file(&self) -> PathBuf {
            let path = self.0.join("App # 日本語.AppImage");
            fs::write(&path, "synthetic file; never executed\n").unwrap();
            fs::set_permissions(&path, Permissions::from_mode(0o640)).unwrap();
            path
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) { fs::remove_dir_all(&self.0).unwrap(); }
    }

    #[test]
    fn edits_regular_file_and_keeps_contents() {
        let fixture = Fixture::new(); let path = fixture.file();
        let info = inspect(&path).unwrap();
        assert!(info.can_edit_permissions && info.is_regular && !info.is_symlink);
        assert_eq!(info.permission_mode, 0o640);
        apply(&path, &info.permission_identity, info.permission_mode, 0o750).unwrap();
        assert_eq!(inspect(&path).unwrap().permission_mode, 0o750);
        assert_eq!(fs::read_to_string(path).unwrap(), "synthetic file; never executed\n");
    }

    #[test]
    fn restores_permissions_without_read_access_and_preserves_special_bits() {
        let fixture = Fixture::new(); let path = fixture.file();
        fs::set_permissions(&path, Permissions::from_mode(0)).unwrap();
        let info = inspect(&path).unwrap();
        apply(&path, &info.permission_identity, 0, 0o640).unwrap();
        fs::set_permissions(&path, Permissions::from_mode(0o4640)).unwrap();
        let info = inspect(&path).unwrap();
        apply(&path, &info.permission_identity, info.permission_mode, 0o750).unwrap();
        assert_eq!(inspect(&path).unwrap().permission_mode, 0o4750);
    }

    #[test]
    fn directory_changes_do_not_recurse() {
        let fixture = Fixture::new(); let path = fixture.file();
        let info = inspect(&fixture.0).unwrap();
        apply(&fixture.0, &info.permission_identity, info.permission_mode, 0o750).unwrap();
        assert_eq!(inspect(&fixture.0).unwrap().permission_mode, 0o750);
        assert_eq!(inspect(&path).unwrap().permission_mode, 0o640);
    }

    #[test]
    fn rejects_links_and_does_not_touch_targets() {
        let fixture = Fixture::new(); let path = fixture.file();
        let link = fixture.0.join("link"); symlink(&path, &link).unwrap();
        let info = inspect(&link).unwrap();
        assert!(info.is_symlink && !info.can_edit_permissions && !info.is_regular);
        assert!(apply(&link, &info.permission_identity, info.permission_mode, 0o777).is_err());
        assert_eq!(inspect(&path).unwrap().permission_mode, 0o640);
    }

    #[test]
    fn rejects_replaced_files_and_stale_permissions() {
        let fixture = Fixture::new(); let path = fixture.file();
        let info = inspect(&path).unwrap();
        fs::rename(&path, fixture.0.join("original")).unwrap();
        fs::write(&path, "replacement").unwrap();
        assert!(apply(&path, &info.permission_identity, info.permission_mode, 0o777).is_err());
        let info = inspect(&path).unwrap();
        fs::set_permissions(&path, Permissions::from_mode(0o600)).unwrap();
        assert!(apply(&path, &info.permission_identity, info.permission_mode, 0o777).is_err());
        assert_eq!(inspect(&path).unwrap().permission_mode, 0o600);
    }

    #[test]
    fn rejects_invalid_modes_paths_and_special_files() {
        let fixture = Fixture::new(); let path = fixture.file();
        let info = inspect(&path).unwrap();
        assert!(apply(&path, &info.permission_identity, info.permission_mode, 0o4777).is_err());
        assert!(apply(Path::new("relative"), "", 0, 0o777).is_err());
        let fifo = fixture.0.join("fifo");
        let cpath = std::ffi::CString::new(fifo.as_os_str().as_encoded_bytes()).unwrap();
        assert_eq!(unsafe { libc::mkfifo(cpath.as_ptr(), 0o600) }, 0);
        let info = inspect(&fifo).unwrap();
        assert!(!info.can_edit_permissions);
        assert!(apply(&fifo, &info.permission_identity, info.permission_mode, 0o777).is_err());
    }
}
