use super::*;

fn merge_fixture(fixture: &Fixture) -> (PathBuf, PathBuf) {
    let source = fixture.0.join("incoming/Folder ö");
    let target = fixture.0.join("destination/Folder ö");
    fs::create_dir_all(source.join("nested")).unwrap();
    fs::create_dir_all(target.join("nested")).unwrap();
    fs::write(source.join("new.txt"), "new").unwrap();
    fs::write(source.join("nested/same.txt"), "incoming").unwrap();
    fs::write(target.join("nested/same.txt"), "existing").unwrap();
    fs::write(target.join("untouched.txt"), "untouched").unwrap();
    (source, target)
}

#[test]
fn folder_merge_copy_combines_nested_folders_and_undo_preserves_existing() {
    let fixture = Fixture::new();
    let (source, target) = merge_fixture(&fixture);
    let choices = HashMap::from([(source.join("nested/same.txt").to_string_lossy().into_owned(), "keep_both".into())]);
    let mut actions = Vec::new();
    merge_folders(&source, &target, false, &choices, &mut actions).unwrap();
    assert_eq!(fs::read_to_string(target.join("nested/same.txt")).unwrap(), "existing");
    assert_eq!(fs::read_to_string(target.join("nested/same (1).txt")).unwrap(), "incoming");
    assert!(target.join("new.txt").exists());
    assert!(source.join("new.txt").exists());
    assert!(!target.join("Folder ö").exists());
    let redo = apply_inverse(&UndoAction::Merge { actions }).unwrap();
    assert!(target.join("untouched.txt").exists());
    assert!(target.join("nested/same.txt").exists());
    assert!(!target.join("nested/same (1).txt").exists());
    assert!(!target.join("new.txt").exists());
    apply_action(&redo).unwrap();
    assert!(target.join("nested/same (1).txt").exists());
}

#[test]
fn folder_merge_cut_undo_redo_restores_source_tree() {
    let fixture = Fixture::new();
    let (source, target) = merge_fixture(&fixture);
    fs::create_dir(source.join("empty")).unwrap();
    let choices = HashMap::from([(source.join("nested/same.txt").to_string_lossy().into_owned(), "keep_both".into())]);
    let mut actions = Vec::new();
    merge_folders(&source, &target, true, &choices, &mut actions).unwrap();
    assert!(!source.exists());
    assert!(target.join("empty").is_dir());
    let redo = apply_inverse(&UndoAction::Merge { actions }).unwrap();
    assert!(source.join("empty").is_dir());
    assert!(source.join("nested/same.txt").exists());
    assert!(target.join("nested/same.txt").exists());
    assert!(target.join("untouched.txt").exists());
    assert!(!target.join("empty").exists());
    apply_action(&redo).unwrap();
    assert!(!source.exists());
    assert!(target.join("nested/same (1).txt").exists());
}

#[test]
fn folder_merge_keep_existing_leaves_skipped_cut_files_at_source() {
    let fixture = Fixture::new();
    let (source, target) = merge_fixture(&fixture);
    let choices = HashMap::from([(source.join("nested/same.txt").to_string_lossy().into_owned(), "keep_existing".into())]);
    let mut actions = Vec::new();
    merge_folders(&source, &target, true, &choices, &mut actions).unwrap();
    assert_eq!(fs::read_to_string(source.join("nested/same.txt")).unwrap(), "incoming");
    assert_eq!(fs::read_to_string(target.join("nested/same.txt")).unwrap(), "existing");
    assert!(!source.join("new.txt").exists());
    assert!(target.join("new.txt").exists());
}

#[test]
fn folder_merge_preflight_and_symlinks_do_not_touch_external_targets() {
    use std::os::unix::fs::symlink;
    let fixture = Fixture::new();
    let (source, target) = merge_fixture(&fixture);
    let outside = fixture.0.join("outside"); fs::create_dir(&outside).unwrap();
    fs::write(outside.join("sentinel"), "preserve").unwrap();
    fs::create_dir(source.join("linked")).unwrap();
    fs::write(source.join("linked/new.txt"), "incoming").unwrap();
    symlink(&outside, target.join("linked")).unwrap();
    symlink(&outside, source.join("only-link")).unwrap();
    symlink("missing", source.join("broken")).unwrap();
    symlink("other-missing", target.join("broken")).unwrap();
    let mut conflicts = Vec::new();
    collect_merge_conflicts(&source, &target, source.parent().unwrap(), &mut conflicts).unwrap();
    assert_eq!(conflicts.len(), 3);
    let choices = conflicts.into_iter().map(|conflict| (conflict.src_path, "keep_both".into())).collect();
    let mut actions = Vec::new();
    merge_folders(&source, &target, false, &choices, &mut actions).unwrap();
    assert!(target.join("linked (1)/new.txt").exists());
    assert_eq!(fs::read_link(target.join("linked")).unwrap(), outside);
    assert_eq!(fs::read_link(target.join("broken (1)")).unwrap(), PathBuf::from("missing"));
    assert!(!outside.join("new.txt").exists());
    assert_eq!(fs::read_to_string(outside.join("sentinel")).unwrap(), "preserve");
    let redo = apply_inverse(&UndoAction::Merge { actions }).unwrap();
    assert!(!entry_exists(&target.join("broken (1)")));
    apply_action(&redo).unwrap();
    assert_eq!(fs::read_link(target.join("broken (1)")).unwrap(), PathBuf::from("missing"));
    assert_eq!(fs::read_link(target.join("only-link")).unwrap(), outside);
    assert_eq!(fs::read_to_string(outside.join("sentinel")).unwrap(), "preserve");
}

#[test]
fn folder_merge_rejects_overlapping_paths_and_unresolved_collisions() {
    let fixture = Fixture::new();
    let (source, target) = merge_fixture(&fixture);
    let mut actions = Vec::new();
    assert!(merge_folders(&source, &source, false, &HashMap::new(), &mut actions).is_err());
    assert!(merge_folders(&source, &source.join("nested"), false, &HashMap::new(), &mut actions).is_err());
    assert!(actions.is_empty());
    assert!(merge_folders(&source, &target, false, &HashMap::new(), &mut actions).is_err());
    assert_eq!(fs::read_to_string(target.join("nested/same.txt")).unwrap(), "existing");
    assert_eq!(fs::read_to_string(source.join("nested/same.txt")).unwrap(), "incoming");
}

#[test]
fn archive_and_application_icons_agree_across_icon_sources() {
    for name in ["a.rar", "a.RAR", "a.7z", "a.tar.gz", "a.tgz", "a.cab", "a.iso", "a.zip"] {
        let path = Path::new(name);
        assert_eq!(icon_for_file(path, false).1, "archive", "{name}");
        assert_eq!(system_icon_for_file(path, false), "package-x-generic", "{name}");
    }
    for name in ["a.AppImage", "a.appimage", "a.RUN", "a.exe"] {
        assert_eq!(icon_for_file(Path::new(name), false), ("terminal", "application"));
        assert_eq!(system_icon_for_file(Path::new(name), false), "application-x-executable");
    }
    for name in ["a.deb", "a.rpm", "a.flatpak"] {
        assert_eq!(icon_for_file(Path::new(name), false), ("package", "application"));
        assert_eq!(system_icon_for_file(Path::new(name), false), "package-x-generic");
    }
    let fixture = Fixture::new();
    let path = fixture.0.join("program");
    fs::write(&path, "synthetic").unwrap();
    use std::os::unix::fs::PermissionsExt;
    fs::set_permissions(&path, fs::Permissions::from_mode(0o700)).unwrap();
    assert_eq!(system_icon_for_file(&path, false), "application-x-executable");
    assert_eq!(icon_for_file(&path, false), ("terminal", "application"));
    fs::set_permissions(&path, fs::Permissions::from_mode(0o600)).unwrap();
    assert_eq!(icon_for_file(&path, false), ("file", "file"));
    assert_eq!(icon_for_file(Path::new("folder.AppImage"), true), ("folder", "folder"));
}

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
