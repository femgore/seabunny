use super::*;

struct Fixture(PathBuf);

impl Fixture {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!("seabunny-rust-test-{}-{}", std::process::id(),
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()));
        fs::create_dir(&path).unwrap();
        Self(path)
    }
}

impl Drop for Fixture {
    fn drop(&mut self) { fs::remove_dir_all(&self.0).unwrap(); }
}

#[test]
fn sidebar_uses_home_and_xdg_not_current_directory() {
    let fixture = Fixture::new();
    fs::write(fixture.0.join("user-dirs.dirs"), "XDG_PICTURES_DIR=\"$HOME/Resimler ö\"\nXDG_DOWNLOAD_DIR=\"/mnt/My Downloads\"\n").unwrap();
    let config = fixture.0.to_str().unwrap();
    assert_eq!(user_directory("", "/home/fixture", config), "/home/fixture");
    assert_eq!(user_directory("Pictures", "/home/fixture", config), "/home/fixture/Resimler ö");
    assert_eq!(user_directory("Downloads", "/home/fixture", config), "/mnt/My Downloads");
    assert_eq!(user_directory("Projects", "/home/fixture", config), "/home/fixture/Projects");
    assert_eq!(user_directory("Videos", "/home/fixture", config), "/home/fixture/Videos");
}

#[test]
fn directory_sort_hidden_and_cancellation() {
    let fixture = Fixture::new();
    fs::write(fixture.0.join("a.txt"), "a").unwrap();
    fs::write(fixture.0.join("Z.txt"), "z").unwrap();
    fs::write(fixture.0.join(".hidden"), "h").unwrap();
    fs::create_dir(fixture.0.join("folder")).unwrap();
    let items = scan_directory(&fixture.0, false, "name", true, "first", || false);
    assert_eq!(items.iter().map(|item| item.name.as_str()).collect::<Vec<_>>(), ["folder", "a.txt", "Z.txt"]);
    assert_eq!(scan_directory(&fixture.0, true, "name", true, "first", || false).len(), 4);
    assert!(scan_directory(&fixture.0, true, "name", true, "first", || true).is_empty());
    let folder = fs::File::open(fixture.0.join("folder")).unwrap();
    folder.set_times(fs::FileTimes::new().set_modified(std::time::UNIX_EPOCH + std::time::Duration::from_secs(100))).unwrap();
    let file = fs::File::open(fixture.0.join("a.txt")).unwrap();
    file.set_times(fs::FileTimes::new().set_modified(std::time::UNIX_EPOCH + std::time::Duration::from_secs(200))).unwrap();
    let items = scan_directory(&fixture.0, false, "modified", false, "mixed", || false);
    assert_eq!(items.last().unwrap().name, "folder");
    let items = scan_directory(&fixture.0, false, "name", true, "mixed", || false);
    assert_eq!(items[0].name, "a.txt");
}

#[test]
fn thumbnail_request_is_nonblocking_and_supports_video_and_special_paths() {
    let image = resolve_thumbnail_path(Path::new("/fixture/picture # ö.tiff"));
    assert!(image.starts_with("image://seabunnythumb/"));
    assert!(image.contains("%23") && image.contains("%20"));
    assert!(resolve_thumbnail_path(Path::new("/fixture/video.mp4")).starts_with("image://seabunnythumb/"));
    assert!(resolve_thumbnail_path(Path::new("/fixture/file.txt")).is_empty());
}
