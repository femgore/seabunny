#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("cxx-qt-lib/qqmlapplicationengine.h");
        type QQmlApplicationEngine = cxx_qt_lib::QQmlApplicationEngine;
        include!("seabunny/src/thumbnail_provider.h");
        fn install_thumbnail_provider(engine: Pin<&mut QQmlApplicationEngine>);
        fn thumbnail_statistics() -> QString;
        include!("seabunny/src/app_integration.h");
        fn configure_seabunny();
        include!("seabunny/src/open_with.h");
        fn seabunny_open_with_apps(paths: &QString) -> QString;
        fn seabunny_open_with(paths: &QString, desktop_id: &QString, make_default: bool) -> QString;
        fn seabunny_open_file(path: &QString) -> QString;
        include!("seabunny/src/portal_backend.h");
        fn start_seabunny_portal() -> bool;
        fn seabunny_portal_mode() -> bool;
        fn seabunny_startup_arguments() -> QString;
        fn seabunny_sidebar_state(chooser: bool) -> QString;
        fn seabunny_save_sidebar_state(chooser: bool, expanded: bool, width: f64) -> bool;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, current_path)]
        #[qproperty(QString, current_dir_name)]
        #[qproperty(QString, files_json)]
        #[qproperty(bool, is_loading)]
        #[qproperty(QString, navigation_error)]
        #[qproperty(QString, archive_path)]
        #[qproperty(bool, archive_busy)]
        #[qproperty(QString, archive_status)]
        #[qproperty(QString, breadcrumbs_json)]
        #[qproperty(bool, is_dark)]
        #[qproperty(bool, has_clipboard)]
        #[qproperty(bool, show_hidden)]
        #[qproperty(bool, disambiguate_duplicates)]
        #[qproperty(QString, wallpaper_colors_json)]
        #[qproperty(bool, is_searching_everywhere)]
        #[qproperty(QString, search_everywhere_json)]
        #[qproperty(bool, can_go_back)]
        #[qproperty(bool, can_go_forward)]
        #[qproperty(QString, hostname)]
        #[qproperty(QString, drives_json)]
        #[qproperty(QString, trash_json)]
        #[qproperty(QString, frequent_dirs_json)]
        #[qproperty(QString, sort_by)]
        #[qproperty(bool, sort_ascending)]
        #[qproperty(bool, dirs_first)]
        #[qproperty(QString, folder_position)]
        #[qproperty(QString, view_mode)]
        #[qproperty(QString, clipboard_cut_paths_json)]
        #[qproperty(QString, device_type)]
        #[qproperty(bool, can_undo)]
        #[qproperty(bool, can_redo)]
        #[qproperty(QString, trash_root)]
        type SeabunnyEngine = super::SeabunnyEngineRust;

        #[qinvokable]
        fn set_path(self: Pin<&mut SeabunnyEngine>, path: &QString);

        #[qinvokable]
        fn navigate_up(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn go_back(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn go_forward(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn refresh(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn sync_shared_state(self: Pin<&mut SeabunnyEngine>);

        #[qsignal]
        fn file_operation_finished(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn toggle_show_hidden(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn toggle_disambiguate_duplicates(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn resolve_icon(self: &SeabunnyEngine, name: &QString) -> QString;

        #[qinvokable]
        fn get_thumbnail(self: &SeabunnyEngine, path: &QString) -> QString;

        #[qinvokable]
        fn place_path(&self, place: &QString) -> QString;

        #[qinvokable]
        fn favorites_json(&self) -> QString;

        #[qinvokable]
        fn update_favorite(self: Pin<&mut SeabunnyEngine>, path: &QString, label: &QString, remove: bool) -> bool;

        #[qinvokable]
        fn thumbnail_stats(&self) -> QString;

        #[qinvokable]
        fn search_everywhere(self: Pin<&mut SeabunnyEngine>, query: &QString);

        #[qinvokable]
        fn clear_search_everywhere(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn load_drives(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn refresh_frequent_dirs(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn load_trash(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn empty_trash(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn open_item(self: Pin<&mut SeabunnyEngine>, path: &QString);

        #[qinvokable]
        fn open_with_apps(&self, paths: &QString) -> QString;

        #[qinvokable]
        fn open_with(self: Pin<&mut SeabunnyEngine>, paths: &QString, desktop_id: &QString, make_default: bool) -> QString;

        #[qinvokable]
        fn valid_location(self: &SeabunnyEngine, path: &QString) -> bool;

        #[qinvokable]
        fn startup_locations(self: &SeabunnyEngine) -> QString;

        #[qinvokable]
        fn extract_current_archive(self: Pin<&mut SeabunnyEngine>, selected_json: &QString);

        #[qinvokable]
        fn open_terminal(self: &SeabunnyEngine, dir_path: &QString);

        #[qinvokable]
        fn create_folder(self: Pin<&mut SeabunnyEngine>, dir: &QString, name: &QString);

        #[qinvokable]
        fn create_file(self: Pin<&mut SeabunnyEngine>, dir: &QString, name: &QString);

        #[qinvokable]
        fn rename_item(self: Pin<&mut SeabunnyEngine>, dir: &QString, old_name: &QString, new_name: &QString);

        #[qinvokable]
        fn trash_items(self: Pin<&mut SeabunnyEngine>, paths_json: &QString);

        #[qinvokable]
        fn copy_items(self: Pin<&mut SeabunnyEngine>, paths_json: &QString, is_cut: bool);

        #[qinvokable]
        fn paste_items(self: Pin<&mut SeabunnyEngine>, dest_dir: &QString);

        #[qinvokable]
        fn drop_items(self: Pin<&mut SeabunnyEngine>, paths_json: &QString, dest_dir: &QString, as_copy: bool);

        #[qinvokable]
        fn get_item_info(self: &SeabunnyEngine, path: &QString) -> QString;

        #[qinvokable]
        fn set_item_permissions(self: Pin<&mut SeabunnyEngine>, path: &QString, identity: &QString, expected_mode: u32, mode: u32) -> QString;

        #[qinvokable]
        fn set_sort(self: Pin<&mut SeabunnyEngine>, sort_by: &QString, ascending: bool);

        #[qinvokable]
        fn toggle_sort_order(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn toggle_view_mode(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn check_paste_conflicts(self: &SeabunnyEngine, paths_json: &QString, dest_dir: &QString) -> QString;

        #[qinvokable]
        fn check_clipboard_conflicts(self: &SeabunnyEngine, dest_dir: &QString) -> QString;

        #[qinvokable]
        fn check_merge_conflicts(self: &SeabunnyEngine, paths_json: &QString, dest_dir: &QString) -> QString;

        #[qinvokable]
        fn check_clipboard_merge_conflicts(self: &SeabunnyEngine, dest_dir: &QString) -> QString;

        #[qinvokable]
        fn paste_items_resolved(self: Pin<&mut SeabunnyEngine>, dest_dir: &QString, resolution: &QString);

        #[qinvokable]
        fn drop_items_resolved(self: Pin<&mut SeabunnyEngine>, paths_json: &QString, dest_dir: &QString, as_copy: bool, resolution: &QString);

        #[qinvokable]
        fn change_folder_position(self: Pin<&mut SeabunnyEngine>, position: &QString);

        #[qinvokable]
        fn compress_items_with_options(self: Pin<&mut SeabunnyEngine>, paths_json: &QString, format: &QString, password: &QString);

        #[qinvokable]
        fn create_symlinks(self: Pin<&mut SeabunnyEngine>, paths_json: &QString, dest_dir: &QString);

        #[qinvokable]
        fn compress_items(self: Pin<&mut SeabunnyEngine>, paths_json: &QString, format: &QString);

        #[qinvokable]
        fn extract_archive(self: Pin<&mut SeabunnyEngine>, archive_path: &QString, into_subfolder: bool);

        #[qinvokable]
        fn is_archive_file(self: &SeabunnyEngine, path: &QString) -> bool;

        #[qinvokable]
        fn mount_drive(self: Pin<&mut SeabunnyEngine>, device: &QString);

        #[qinvokable]
        fn unmount_drive(self: Pin<&mut SeabunnyEngine>, device: &QString);

        #[qinvokable]
        fn rename_drive(self: Pin<&mut SeabunnyEngine>, device: &QString, new_name: &QString);

        #[qinvokable]
        fn undo(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn redo(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn refresh_system_theme(self: Pin<&mut SeabunnyEngine>);

        #[qinvokable]
        fn restore_trash_item(self: Pin<&mut SeabunnyEngine>, path: &QString);

        #[qinvokable]
        fn get_setting(&self, key: &QString) -> QString;

        #[qinvokable]
        fn set_setting(self: Pin<&mut SeabunnyEngine>, key: &QString, value: &QString);

        #[qinvokable]
        fn sidebar_state(self: &SeabunnyEngine, chooser: bool) -> QString;

        #[qinvokable]
        fn save_sidebar_state(self: &SeabunnyEngine, chooser: bool, expanded: bool, width: f64) -> bool;

        #[qinvokable]
        fn reload_wallpaper_colors(self: Pin<&mut SeabunnyEngine>) -> bool;
    }
    impl cxx_qt::Threading for SeabunnyEngine {}
}

use core::pin::Pin;
use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::QString;
use serde::Serialize;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, Arc, Condvar};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};

#[cfg(test)]
#[path = "bridge_tests.rs"]
mod regression_tests;

static CLIPBOARD: Mutex<(Vec<String>, bool)> = Mutex::new((Vec::new(), false));
static VISIT_COUNTS: Mutex<Option<HashMap<String, usize>>> = Mutex::new(None);
static SETTINGS_STORE: Mutex<Option<HashMap<String, String>>> = Mutex::new(None);
static BIN_CACHE: Mutex<Option<HashMap<String, Option<String>>>> = Mutex::new(None);

pub fn resolve_system_icon(name: &str) -> String {
    format!("image://seabunnyicon/{}", percent_encode_path(name))
}

fn run_cmd_stdout(cmd: &str, args: &[&str]) -> Option<String> {
    let output = std::process::Command::new(cmd).args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn dark_from_gsettings() -> Option<bool> {
    let out = run_cmd_stdout("gsettings", &["get", "org.gnome.desktop.interface", "color-scheme"])?;
    let s = out.to_lowercase();
    if s.contains("prefer-dark") {
        Some(true)
    } else if s.contains("prefer-light") {
        Some(false)
    } else {
        // "default"/unset means "no preference": try the next source.
        None
    }
}

fn dark_from_portal() -> Option<bool> {
    let out = run_cmd_stdout(
        "gdbus",
        &[
            "call",
            "--session",
            "--dest",
            "org.freedesktop.portal.Desktop",
            "--object-path",
            "/org/freedesktop/portal/desktop",
            "--method",
            "org.freedesktop.portal.Settings.Read",
            "org.freedesktop.appearance",
            "color-scheme",
        ],
    )?;
    // Reply shape: (<uint32 1>,) where 0 = no preference, 1 = prefer dark, 2 = prefer light.
    if out.contains("uint32 1") {
        Some(true)
    } else if out.contains("uint32 2") {
        Some(false)
    } else {
        None
    }
}

fn dark_from_gtk_settings() -> Option<bool> {
    let home = std::env::var("HOME").unwrap_or_default();
    let candidates = [
        std::env::var("XDG_CONFIG_HOME").ok().map(|c| PathBuf::from(c).join("gtk-3.0/settings.ini")),
        std::env::var("XDG_CONFIG_HOME").ok().map(|c| PathBuf::from(c).join("gtk-4.0/settings.ini")),
        Some(PathBuf::from(&home).join(".config/gtk-3.0/settings.ini")),
        Some(PathBuf::from(&home).join(".config/gtk-4.0/settings.ini")),
    ];

    for candidate in candidates.into_iter().flatten() {
        let Ok(content) = fs::read_to_string(&candidate) else { continue };
        for line in content.lines() {
            let line = line.trim();
            let Some((key, value)) = line.split_once('=') else { continue };
            if key.trim() != "gtk-application-prefer-dark-theme" {
                continue;
            }
            let v = value.trim().to_lowercase();
            if v == "1" || v == "true" || v == "yes" || v == "on" {
                return Some(true);
            }
            if v == "0" || v == "false" || v == "no" || v == "off" {
                return Some(false);
            }
        }
    }
    None
}

/// Detection order: gsettings -> XDG desktop portal -> GTK settings.ini -> dark.
fn detect_system_dark_mode() -> bool {
    if let Some(dark) = dark_from_gsettings() {
        return dark;
    }
    // A portal backend must not synchronously call the frontend that is activating it.
    if !qobject::seabunny_portal_mode() {
        if let Some(dark) = dark_from_portal() { return dark; }
    }
    if let Some(dark) = dark_from_gtk_settings() {
        return dark;
    }
    true
}

fn read_system_hostname() -> String {
    if let Ok(s) = fs::read_to_string("/proc/sys/kernel/hostname") {
        let trimmed = s.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }
    "PC".to_string()
}

/// Returns (source_path, content, mtime_secs) for the first readable color source.
fn read_wallpaper_colors_source() -> Option<(String, String, u64)> {
    let home = std::env::var("HOME").unwrap_or_default();
    let candidates = [
        format!("{}/.local/state/quickshell/user/generated/colors.json", home),
        format!("{}/.cache/wal/colors.json", home),
        format!("{}/.cache/matugen/colors.json", home),
    ];

    for path_str in candidates {
        let path = Path::new(&path_str);
        let Ok(content) = fs::read_to_string(path) else { continue };
        let is_object = serde_json::from_str::<serde_json::Value>(&content)
            .ok()
            .map(|v| v.is_object() && v.as_object().map(|o| !o.is_empty()).unwrap_or(false))
            .unwrap_or(false);
        if !is_object {
            continue;
        }
        let mtime = fs::metadata(path)
            .and_then(|m| m.modified())
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs())
            .unwrap_or(0);
        return Some((path_str, content, mtime));
    }
    None
}

fn read_wallpaper_colors() -> String {
    read_wallpaper_colors_source()
        .map(|(_, content, _)| content)
        .unwrap_or_else(|| "{}".to_string())
}

#[derive(Serialize, Clone)]
pub struct FileItem {
    pub name: String,
    pub is_dir: bool,
    pub is_symlink: bool,
    pub icon: String,
    pub icon_path: String,
    pub thumbnail: String,
    pub category: String,
    pub size: u64,
    pub size_str: String,
    pub modified: u64,
    pub modified_str: String,
}

#[derive(Serialize, Clone)]
pub struct ConflictItem {
    pub name: String,
    pub src_path: String,
    pub dest_path: String,
    pub src_size: String,
    pub dest_size: String,
    pub is_dir: bool,
    pub can_merge: bool,
}

#[derive(Serialize)]
pub struct Breadcrumb {
    pub name: String,
    pub path: String,
    pub icon: String,
    pub system_icon: String,
    pub is_root_place: bool,
    pub is_forward: bool,
}

#[derive(Serialize, Clone)]
pub struct SearchResultItem {
    pub name: String,
    pub display_name: String,
    pub path: String,
    pub parent_path: String,
    pub is_dir: bool,
    pub icon: String,
    pub icon_path: String,
    pub thumbnail: String,
    pub category: String,
}

#[derive(Serialize, Clone)]
pub struct DriveItem {
    pub name: String,
    pub device: String,
    pub mount_point: String,
    pub is_mounted: bool,
    pub is_external: bool,
    pub fs_type: String,
    pub total_str: String,
    pub used_str: String,
    pub free_str: String,
    pub total_bytes: u64,
    pub used_bytes: u64,
    pub free_bytes: u64,
    pub percent: f64,
    pub model: String,
}

#[derive(Serialize, Clone)]
pub struct FrequentDirItem {
    pub name: String,
    pub path: String,
    pub icon: String,
}

#[derive(Serialize)]
pub struct ItemInfo {
    pub name: String,
    pub path: String,
    pub size: String,
    pub is_dir: bool,
    pub modified: String,
    pub icon: String,
    pub icon_path: String,
    #[serde(flatten)]
    pub permissions: Option<crate::permissions::PermissionInfo>,
}

pub struct SeabunnyEngineRust {
    current_path: QString,
    current_dir_name: QString,
    files_json: QString,
    is_loading: bool,
    navigation_error: QString,
    archive_path: QString,
    archive_busy: bool,
    archive_status: QString,
    archive_generation: Arc<AtomicU64>,
    breadcrumbs_json: QString,
    is_dark: bool,
    has_clipboard: bool,
    show_hidden: bool,
    disambiguate_duplicates: bool,
    wallpaper_colors_json: QString,
    is_searching_everywhere: bool,
    search_everywhere_json: QString,
    can_go_back: bool,
    can_go_forward: bool,
    hostname: QString,
    drives_json: QString,
    trash_json: QString,
    frequent_dirs_json: QString,
    sort_by: QString,
    sort_ascending: bool,
    dirs_first: bool,
    folder_position: QString,
    view_mode: QString,
    clipboard_cut_paths_json: QString,
    device_type: QString,
    can_undo: bool,
    can_redo: bool,
    trash_root: QString,
    history_stack: Vec<String>,
    forward_stack: Vec<String>,
    scan_generation: Arc<AtomicU64>,
    scan_requests: Option<Arc<DirectoryInbox>>,
}

struct DirectoryRequest {
    generation: u64,
    path: String,
    hidden: bool,
    sort: String,
    ascending: bool,
    folders: String,
    search: Option<(String, bool)>,
}

struct DirectoryInbox {
    request: Mutex<Option<DirectoryRequest>>,
    ready: Condvar,
    closed: AtomicBool,
}

impl Drop for SeabunnyEngineRust {
    fn drop(&mut self) {
        self.scan_generation.fetch_add(1, Ordering::Relaxed);
        self.archive_generation.fetch_add(1, Ordering::Relaxed);
        if let Some(inbox) = &self.scan_requests {
            let mut request = inbox.request.lock().unwrap();
            inbox.closed.store(true, Ordering::Relaxed);
            *request = None;
            inbox.ready.notify_one();
        }
    }
}

fn detect_device_type() -> &'static str {
    if let Ok(chassis) = fs::read_to_string("/sys/class/dmi/id/chassis_type") {
        match chassis.trim() {
            "8" | "9" | "10" | "11" | "14" | "30" | "31" | "32" => return "laptop",
            _ => {}
        }
    }
    if Path::new("/sys/class/power_supply/BAT0").exists() || Path::new("/sys/class/power_supply/BAT1").exists() {
        return "laptop";
    }
    "desktop"
}

#[derive(Clone)]
struct TrashItem {
    /// Absolute path the file had before it was trashed.
    original: String,
    /// Absolute path inside the trash `files/` directory.
    trashed: String,
    /// Absolute path to the matching `info/<name>.trashinfo` file.
    info: String,
}

#[derive(Clone)]
enum UndoAction {
    Rename { dir: String, old_name: String, new_name: String },
    Create { path: String, is_dir: bool },
    /// Pairs are (from, to) as performed by the move.
    Move { pairs: Vec<(String, String)> },
    /// Pairs are (source, created_copy).
    Copy { pairs: Vec<(String, String)> },
    Trash { items: Vec<TrashItem> },
    Merge { actions: Vec<UndoAction> },
    RemovedDirectory { path: String, mode: u32 },
    CreatedMergeDirectory { path: String, mode: u32 },
}

static UNDO_STACK: Mutex<Option<Vec<UndoAction>>> = Mutex::new(None);
static REDO_STACK: Mutex<Option<Vec<UndoAction>>> = Mutex::new(None);

fn stack_len(stack: &Mutex<Option<Vec<UndoAction>>>) -> usize {
    stack.lock().unwrap().as_ref().map(|s| s.len()).unwrap_or(0)
}

fn clear_stack(stack: &Mutex<Option<Vec<UndoAction>>>) {
    if let Some(s) = stack.lock().unwrap().as_mut() {
        s.clear();
    }
}

/// Pushes an undo entry and invalidates the redo stack, keeping both bounded.
fn push_undo(action: UndoAction) {
    {
        let mut guard = UNDO_STACK.lock().unwrap();
        let stack = guard.get_or_insert_with(Vec::new);
        stack.push(action);
        if stack.len() > 200 {
            stack.remove(0);
        }
    }
    clear_stack(&REDO_STACK);
}

fn percent_encode_path(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        let keep = b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~' | b'/');
        if keep {
            out.push(b as char);
        } else {
            out.push_str(&format!("%{:02X}", b));
        }
    }
    out
}

fn user_directory(place: &str, home: &str, config: &str) -> String {
    let key = match place {
        "Documents" => "XDG_DOCUMENTS_DIR", "Downloads" => "XDG_DOWNLOAD_DIR",
        "Pictures" => "XDG_PICTURES_DIR", "Music" => "XDG_MUSIC_DIR",
        "Videos" => "XDG_VIDEOS_DIR", "Desktop" => "XDG_DESKTOP_DIR",
        "" | "Home" => return home.to_string(),
        _ => return format!("{}/{}", home, place),
    };
    if let Ok(content) = fs::read_to_string(Path::new(config).join("user-dirs.dirs")) {
        for line in content.lines() {
            if let Some((name, value)) = line.trim().split_once('=') {
                if name.trim() == key {
                    let value = value.trim().trim_matches('"').replace("\\\"", "\"")
                        .replace("\\\\", "\\").replace("$HOME", home);
                    if Path::new(&value).is_absolute() { return value; }
                }
            }
        }
    }
    format!("{}/{}", home, place)
}

fn iso_datetime_now() -> String {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let days = (secs / 86400) as i64;
    let rem = secs % 86400;

    // days -> civil date (Howard Hinnant's algorithm)
    let z = days + 719468;
    let era = if z >= 0 { z } else { z - 146096 } / 146097;
    let doe = (z - era * 146097) as u64;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };

    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}",
        y,
        m,
        d,
        rem / 3600,
        (rem % 3600) / 60,
        rem % 60
    )
}

fn trash_root_dir() -> PathBuf {
    if let Ok(xdg) = std::env::var("XDG_DATA_HOME") {
        if !xdg.is_empty() {
            return PathBuf::from(xdg).join("Trash");
        }
    }
    let home = std::env::var("HOME").unwrap_or_default();
    PathBuf::from(home).join(".local/share/Trash")
}

fn trash_paths() -> (PathBuf, PathBuf) {
    let root = trash_root_dir();
    (root.join("files"), root.join("info"))
}

fn unique_trash_name(files_dir: &Path, name: &str) -> String {
    let available = |name: &str| !entry_exists(&files_dir.join(name))
        && !entry_exists(&files_dir.parent().unwrap().join("info").join(format!("{name}.trashinfo")));
    if available(name) {
        return name.to_string();
    }
    let p = Path::new(name);
    let stem = p.file_stem().and_then(|s| s.to_str()).unwrap_or(name);
    let ext = p
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| format!(".{}", e))
        .unwrap_or_default();
    let mut i = 1;
    loop {
        let candidate = format!("{}.{}{}", stem, i, ext);
        if available(&candidate) {
            return candidate;
        }
        i += 1;
    }
}

/// Moves `path` into the user's trash (#1.1 freedesktop spec) and returns
/// everything needed to reverse the operation.
fn trash_into_home_trash(path: &Path) -> Option<TrashItem> {
    let name = path.file_name().and_then(|n| n.to_str())?.to_string();
    if !entry_exists(path) {
        return None;
    }

    let (files_dir, info_dir) = trash_paths();
    fs::create_dir_all(&files_dir).ok()?;
    fs::create_dir_all(&info_dir).ok()?;

    let trash_name = unique_trash_name(&files_dir, &name);
    let trashed = files_dir.join(&trash_name);
    let info_path = info_dir.join(format!("{}.trashinfo", trash_name));

    // Resolve the parent, never the final link: restoring a trashed symlink
    // must put the link back, rather than overwrite its target.
    let abs = path.parent().and_then(|parent| fs::canonicalize(parent).ok())
        .map(|parent| parent.join(path.file_name().unwrap())).unwrap_or_else(|| path.to_path_buf());
    let abs_str = abs.to_string_lossy().to_string();
    let info_content = format!(
        "[Trash Info]\nPath={}\nDeletionDate={}\n",
        percent_encode_path(&abs_str),
        iso_datetime_now()
    );
    fs::write(&info_path, info_content).ok()?;

    let mut moved = fs::rename(path, &trashed).is_ok();
    if !moved {
        // Cross-device fallback: copy then delete the original.
        let copied = copy_merge_entry(&abs, &trashed);
        if copied {
            moved = remove_path(&abs);
        }
    }

    if !moved {
        let _ = fs::remove_file(&info_path);
        return None;
    }

    Some(TrashItem {
        original: abs_str,
        trashed: trashed.to_string_lossy().to_string(),
        info: info_path.to_string_lossy().to_string(),
    })
}

/// Reads the `Path=` line out of a `.trashinfo` file.
fn parse_trashinfo_path(info_content: &str) -> Option<String> {
    for line in info_content.lines() {
        let line = line.trim();
        if let Some(rest) = line.strip_prefix("Path=") {
            let mut decoded = Vec::with_capacity(rest.len());
            let bytes = rest.as_bytes();
            let mut i = 0;
            while i < bytes.len() {
                if bytes[i] == b'%' && i + 2 < bytes.len() {
                    if let Ok(v) = u8::from_str_radix(&rest[i + 1..i + 3], 16) {
                        decoded.push(v);
                        i += 3;
                        continue;
                    }
                }
                decoded.push(bytes[i]);
                i += 1;
            }
            let s = String::from_utf8_lossy(&decoded).to_string();
            if !s.is_empty() {
                return Some(s);
            }
        }
    }
    None
}

fn config_file_path() -> PathBuf {
    if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        if !xdg.is_empty() {
            return PathBuf::from(xdg).join("seabunny/config.json");
        }
    }
    let home = std::env::var("HOME").unwrap_or_default();
    PathBuf::from(home).join(".config/seabunny/config.json")
}

fn load_settings() -> HashMap<String, String> {
    {
        let guard = SETTINGS_STORE.lock().unwrap();
        if let Some(map) = guard.as_ref() {
            return map.clone();
        }
    }

    let mut map = HashMap::new();
    if let Ok(content) = fs::read_to_string(config_file_path()) {
        if let Ok(serde_json::Value::Object(obj)) = serde_json::from_str::<serde_json::Value>(&content) {
            for (k, v) in obj {
                if let Some(s) = v.as_str() {
                    map.insert(k, s.to_string());
                }
            }
        }
    }

    *SETTINGS_STORE.lock().unwrap() = Some(map.clone());
    map
}

/// Persists settings atomically (temp file in the same directory + rename).
fn save_settings(map: &HashMap<String, String>) {
    // Choosers share appearance preferences but never overwrite the manager profile.
    if qobject::seabunny_portal_mode() { return; }
    let path = config_file_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let json = serde_json::to_string_pretty(map).unwrap_or_else(|_| "{}".to_string());
    let tmp = path.with_extension("json.tmp");
    if fs::write(&tmp, json.as_bytes()).is_ok() {
        if fs::rename(&tmp, &path).is_err() {
            let _ = fs::remove_file(&tmp);
        }
    } else {
        eprintln!("seabunny: could not write settings to {:?}", path);
    }
}

fn find_in_store(keyword: &str, rel: &str) -> Option<String> {
    let entries = fs::read_dir("/nix/store").ok()?;
    let mut best: Option<String> = None;
    for entry in entries.flatten() {
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if !name.contains(keyword) {
            continue;
        }
        let candidate = entry.path().join(rel);
        if candidate.is_file() {
            let s = candidate.to_string_lossy().to_string();
            // Prefer the shortest match so the choice is stable across runs.
            if best.as_ref().map(|b| s.len() < b.len()).unwrap_or(true) {
                best = Some(s);
            }
        }
    }
    best
}

fn resolve_binary_uncached(name: &str, store_keyword: &str) -> Option<String> {
    // 1. PATH (covers `nix develop` and normal host installs).
    if let Ok(path) = std::env::var("PATH") {
        for dir in std::env::split_paths(&path) {
            let candidate = dir.join(name);
            if candidate.is_file() {
                return Some(candidate.to_string_lossy().to_string());
            }
        }
    }

    // 2. Common profile / system locations.
    let home = std::env::var("HOME").unwrap_or_default();
    let user = std::env::var("USER").unwrap_or_default();
    let extra = [
        format!("/run/current-system/sw/bin/{}", name),
        format!("/run/wrappers/bin/{}", name),
        format!("/etc/profiles/per-user/{}/bin/{}", user, name),
        format!("{}/.nix-profile/bin/{}", home, name),
        format!("/nix/var/nix/profiles/default/bin/{}", name),
        format!("/usr/local/bin/{}", name),
        format!("/usr/bin/{}", name),
        format!("/bin/{}", name),
    ];
    for candidate in extra {
        if Path::new(&candidate).is_file() {
            return Some(candidate);
        }
    }

    // 3. Nix store (e.g. `7z` from pkgs.p7zip, `zip` from pkgs.zip when running
    //    the built binary outside of the dev shell).
    find_in_store(store_keyword, &format!("bin/{}", name))
}

fn resolve_binary(name: &str, store_keyword: &str) -> Option<String> {
    {
        let guard = BIN_CACHE.lock().unwrap();
        if let Some(cache) = guard.as_ref() {
            if let Some(hit) = cache.get(name) {
                return hit.clone();
            }
        }
    }

    let resolved = resolve_binary_uncached(name, store_keyword);
    let mut guard = BIN_CACHE.lock().unwrap();
    guard
        .get_or_insert_with(HashMap::new)
        .insert(name.to_string(), resolved.clone());
    resolved
}

/// First available executable from a set of aliases.
fn resolve_any_binary(names: &[&str], store_keyword: &str) -> Option<String> {
    names.iter().find_map(|n| resolve_binary(n, store_keyword))
}

fn archive_base_name(path: &Path) -> String {
    let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("archive");
    let lower = name.to_lowercase();
    for suffix in [
        ".tar.gz", ".tar.xz", ".tar.zst", ".tar.bz2", ".tgz", ".txz", ".tbz2", ".zip", ".7z", ".tar",
    ] {
        if lower.ends_with(suffix) {
            return name[..name.len() - suffix.len()].to_string();
        }
    }
    path.file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("archive")
        .to_string()
}

/// Name to store inside the archive: relative to the archive's directory.
fn relative_name(path: &str, parent: &Path) -> String {
    let p = Path::new(path);
    match p.strip_prefix(parent) {
        Ok(rel) if !rel.as_os_str().is_empty() => rel.to_string_lossy().to_string(),
        _ => p
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_else(|| path.to_string()),
    }
}

fn ran_ok(status: std::io::Result<std::process::ExitStatus>) -> bool {
    status.map(|s| s.success()).unwrap_or(false)
}

fn seven_zip_bin() -> Option<String> {
    resolve_any_binary(&["7z", "7zz", "7za", "7zr"], "p7zip")
}

fn compress_with_7z(archive: &Path, names: &[String], pass: &str, parent: &Path) -> bool {
    let Some(bin) = seven_zip_bin() else {
        eprintln!("seabunny: 7z not found (install p7zip) - cannot create .7z archives");
        return false;
    };

    let mut cmd = std::process::Command::new(bin);
    cmd.current_dir(parent).arg("a").arg("-y");
    if !pass.is_empty() {
        cmd.arg(format!("-p{}", pass));
        // Header encryption is only valid for 7z containers.
        cmd.arg("-mhe=on");
    }
    cmd.arg(archive).args(names);
    ran_ok(cmd.status())
}

fn compress_zip_encrypted(archive: &Path, names: &[String], pass: &str, parent: &Path) -> bool {
    if pass.is_empty() {
        return compress_zip(archive, names, parent);
    }

    // Preferred: AES-256 zip via 7z. `-mhe=on` cannot be used with `-tzip`
    // (p7zip rejects it with E_INVALIDARG), so only the password is passed.
    if let Some(bin) = seven_zip_bin() {
        let ok = ran_ok(
            std::process::Command::new(&bin)
                .current_dir(parent)
                .args(["a", "-y", "-tzip", "-mem=AES256"])
                .arg(format!("-p{}", pass))
                .arg(archive)
                .args(names)
                .status(),
        );
        if ok {
            return true;
        }
    }

    // Fallback: legacy ZipCrypto via the `zip` CLI (weaker, but keeps the menu option working).
    if let Some(zip) = resolve_binary("zip", "zip") {
        eprintln!("seabunny: 7z unavailable, using legacy ZipCrypto encryption for {}", archive.display());
        return ran_ok(
            std::process::Command::new(zip)
                .current_dir(parent)
                .arg("-r")
                .arg(format!("-P{}", pass))
                .arg(archive)
                .args(names)
                .status(),
        );
    }

    eprintln!("seabunny: neither 7z nor zip is installed - cannot create an encrypted archive");
    false
}

fn compress_zip(archive: &Path, names: &[String], parent: &Path) -> bool {
    if let Some(zip) = resolve_binary("zip", "zip") {
        if ran_ok(
            std::process::Command::new(&zip)
                .current_dir(parent)
                .args(["-r", "-q"])
                .arg(archive)
                .args(names)
                .status(),
        ) {
            return true;
        }
    }

    if let Some(bin) = seven_zip_bin() {
        if ran_ok(
            std::process::Command::new(bin)
                .current_dir(parent)
                .args(["a", "-y", "-tzip"])
                .arg(archive)
                .args(names)
                .status(),
        ) {
            return true;
        }
    }

    if let Some(python) = resolve_binary("python3", "python3") {
        return ran_ok(
            std::process::Command::new(python)
                .current_dir(parent)
                .args(["-m", "zipfile", "-c"])
                .arg(archive)
                .args(names)
                .status(),
        );
    }

    eprintln!("seabunny: no zip, 7z or python3 available - cannot create .zip archives");
    false
}

fn compress_tar(archive: &Path, names: &[String], parent: &Path, flag: &str) -> bool {
    ran_ok(
        std::process::Command::new("tar")
            .arg(format!("-c{}f", flag))
            .arg(archive)
            .args(["-C"])
            .arg(parent)
            .args(names)
            .status(),
    )
}

fn compress_tar_zstd(archive: &Path, names: &[String], parent: &Path) -> bool {
    let long = ran_ok(
        std::process::Command::new("tar")
            .args(["--zstd", "-cf"])
            .arg(archive)
            .args(["-C"])
            .arg(parent)
            .args(names)
            .status(),
    );
    if long {
        return true;
    }

    // Older tar builds: pipe through the zstd binary explicitly.
    ran_ok(
        std::process::Command::new("tar")
            .args(["-I", "zstd", "-cf"])
            .arg(archive)
            .args(["-C"])
            .arg(parent)
            .args(names)
            .status(),
    )
}

fn collect_cpio_paths(root: &Path, rel: &str, out: &mut Vec<String>) {
    out.push(rel.to_string());
    if !root.is_dir() {
        return;
    }
    if let Ok(entries) = fs::read_dir(root) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            let child_rel = format!("{}/{}", rel.trim_end_matches('/'), name);
            collect_cpio_paths(&entry.path(), &child_rel, out);
        }
    }
}

fn compress_cpio(archive: &Path, names: &[String], parent: &Path) -> bool {
    use std::io::Write as _;

    let Some(cpio) = resolve_binary("cpio", "cpio") else {
        eprintln!("seabunny: cpio not found (install cpio) - cannot create .cpio archives");
        return false;
    };

    // cpio does not recurse: feed it the full, newline/NUL separated file list.
    let mut list: Vec<String> = Vec::new();
    for name in names {
        collect_cpio_paths(&parent.join(name), name, &mut list);
    }

    let Ok(file) = fs::File::create(archive) else {
        eprintln!("seabunny: could not create {}", archive.display());
        return false;
    };

    let mut child = match std::process::Command::new(cpio)
        .current_dir(parent)
        .args(["--null", "-o", "-H", "newc", "--quiet"])
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::from(file))
        .spawn()
    {
        Ok(child) => child,
        Err(err) => {
            eprintln!("seabunny: could not run cpio: {}", err);
            return false;
        }
    };

    if let Some(stdin) = child.stdin.as_mut() {
        for item in &list {
            if stdin.write_all(item.as_bytes()).is_err() || stdin.write_all(b"\0").is_err() {
                break;
            }
        }
    }
    drop(child.stdin.take());

    ran_ok(child.wait())
}

fn copy_recursive(src: &Path, dst: &Path) -> bool {
    if src.is_dir() {
        std::process::Command::new("cp")
            .arg("-r")
            .arg(src)
            .arg(dst)
            .status()
            .map(|s| s.success())
            .unwrap_or(false)
    } else {
        fs::copy(src, dst).is_ok()
    }
}

fn real_directory(path: &Path) -> bool {
    fs::symlink_metadata(path).is_ok_and(|metadata| metadata.is_dir())
}

fn entry_exists(path: &Path) -> bool { fs::symlink_metadata(path).is_ok() }

fn copy_merge_entry(src: &Path, dst: &Path) -> bool {
    if fs::symlink_metadata(src).is_ok_and(|metadata| metadata.file_type().is_symlink()) {
        fs::read_link(src).and_then(|target| std::os::unix::fs::symlink(target, dst)).is_ok()
    } else { copy_recursive(src, dst) }
}

/// Only real directories on both sides are combined. Other collisions require
/// an explicit per-item choice, including links and file/directory mismatches.
fn merge_folders(src: &Path, dst: &Path, cut: bool, choices: &HashMap<String, String>, actions: &mut Vec<UndoAction>) -> Result<(), String> {
    let source = fs::canonicalize(src).map_err(|e| e.to_string())?;
    let destination = fs::canonicalize(dst).map_err(|e| e.to_string())?;
    if !real_directory(src) || !real_directory(dst) || source.starts_with(&destination) || destination.starts_with(&source) {
        return Err("Cannot merge a folder with itself, its parent, a symbolic link, or one of its subfolders.".into());
    }
    merge_folder_contents(src, dst, cut, choices, actions)
}

fn merge_folder_contents(src: &Path, dst: &Path, cut: bool, choices: &HashMap<String, String>, actions: &mut Vec<UndoAction>) -> Result<(), String> {
    use std::os::unix::fs::PermissionsExt;
    let mode = fs::metadata(src).map_err(|e| e.to_string())?.permissions().mode();
    let entries = fs::read_dir(src).map_err(|e| e.to_string())?
        .collect::<Result<Vec<_>, _>>().map_err(|e| e.to_string())?;
    let mut errors = Vec::new();
    for entry in entries {
        let from = entry.path();
        let mut to = dst.join(entry.file_name());
        if real_directory(&from) && real_directory(&to) {
            if let Err(error) = merge_folder_contents(&from, &to, cut, choices, actions) { errors.push(error); }
            continue;
        }
        if entry_exists(&to) {
            match resolve_merge_collision(&from, &to, choices, actions) {
                Ok(Some(target)) => to = target,
                Ok(None) => continue,
                Err(error) => { errors.push(error); continue; }
            }
        }
        if let Err(error) = transfer_merge_entry(&from, &to, cut, actions) { errors.push(error); }
    }
    if cut && errors.is_empty() {
        let empty = fs::read_dir(src).map(|mut entries| entries.next().is_none()).unwrap_or(false);
        if empty { match fs::remove_dir(src) {
            Ok(()) => actions.push(UndoAction::RemovedDirectory { path: src.to_string_lossy().into_owned(), mode }),
            Err(error) => errors.push(error.to_string()),
        } }
    }
    if errors.is_empty() { Ok(()) } else { Err(errors.join("\n")) }
}

fn transfer_merge_entry(src: &Path, dst: &Path, cut: bool, actions: &mut Vec<UndoAction>) -> Result<(), String> {
    let pairs = vec![(src.to_string_lossy().into_owned(), dst.to_string_lossy().into_owned())];
    if entry_exists(dst) { return Err(format!("Destination changed during merge: {}", dst.display())); }
    if cut && fs::rename(src, dst).is_ok() {
        actions.push(UndoAction::Move { pairs });
        return Ok(());
    }
    if cut && real_directory(src) {
        use std::os::unix::fs::PermissionsExt;
        let mode = fs::metadata(src).map_err(|e| e.to_string())?.permissions().mode();
        fs::create_dir(dst).map_err(|e| e.to_string())?;
        actions.push(UndoAction::CreatedMergeDirectory { path: dst.to_string_lossy().into_owned(), mode });
        fs::set_permissions(dst, fs::Permissions::from_mode(mode | 0o700)).map_err(|e| e.to_string())?;
        // Move children separately and remove only empty source directories.
        // A recursive delete after copying can lose source files on partial failure.
        let result = merge_folder_contents(src, dst, true, &HashMap::new(), actions);
        let permissions = fs::set_permissions(dst, fs::Permissions::from_mode(mode)).map_err(|e| e.to_string());
        return result.and(permissions);
    }
    let copied = copy_merge_entry(src, dst);
    if copied && cut && remove_path(src) {
        actions.push(UndoAction::Move { pairs });
        return Ok(());
    }
    if entry_exists(dst) { actions.push(UndoAction::Copy { pairs }); }
    if copied && !cut { Ok(()) } else { Err(format!("Could not completely transfer {}", src.display())) }
}

fn resolve_merge_collision(src: &Path, dst: &Path, choices: &HashMap<String, String>, actions: &mut Vec<UndoAction>) -> Result<Option<PathBuf>, String> {
    if !entry_exists(src) { return Err("The incoming item is no longer available. The existing item was kept.".into()); }
    match choices.get(&src.to_string_lossy().to_string()).map(String::as_str) {
        Some("keep_existing") => Ok(None),
        Some("keep_both") => Ok(Some(get_unique_name(dst.parent().unwrap(), &dst.file_name().unwrap().to_string_lossy()))),
        Some("replace") => {
            let item = trash_into_home_trash(dst).ok_or_else(|| format!("Could not safely replace {}. The existing item was kept.", dst.display()))?;
            actions.push(UndoAction::Trash { items: vec![item] });
            Ok(Some(dst.to_path_buf()))
        }
        _ => Err(format!("A new conflict appeared at {}. Paste again to choose what to keep.", dst.display())),
    }
}

fn merge_resolution(value: &str) -> (String, HashMap<String, String>) {
    if let Ok(plan) = serde_json::from_str::<serde_json::Value>(value) {
        if plan["mode"] == "merge" {
            let choices = serde_json::from_value(plan["collisions"].clone()).unwrap_or_default();
            return ("merge".into(), choices);
        }
    }
    (value.into(), HashMap::new())
}

fn collect_merge_conflicts(src: &Path, dst: &Path, root: &Path, conflicts: &mut Vec<ConflictItem>) -> Result<(), String> {
    if real_directory(src) && real_directory(dst) {
        let source = fs::canonicalize(src).map_err(|e| e.to_string())?;
        let destination = fs::canonicalize(dst).map_err(|e| e.to_string())?;
        if source.starts_with(&destination) || destination.starts_with(&source) { return Err("Cannot merge overlapping folders.".into()); }
        let mut entries = fs::read_dir(src).map_err(|e| e.to_string())?.collect::<Result<Vec<_>, _>>().map_err(|e| e.to_string())?;
        entries.sort_by_key(|entry| entry.file_name());
        for entry in entries { collect_merge_conflicts(&entry.path(), &dst.join(entry.file_name()), root, conflicts)?; }
    } else if entry_exists(dst) {
        let size = |path: &Path| if real_directory(path) { "Folder".into() }
            else { fs::symlink_metadata(path).map(|m| format_size(m.len())).unwrap_or_else(|_| "Unavailable".into()) };
        conflicts.push(ConflictItem { name: src.strip_prefix(root).unwrap_or(src).to_string_lossy().into_owned(),
            src_path: src.to_string_lossy().into_owned(), dest_path: dst.to_string_lossy().into_owned(),
            src_size: size(src), dest_size: size(dst), is_dir: real_directory(dst), can_merge: false });
    }
    Ok(())
}

fn replay_merge_move(action: &UndoAction, inverse: bool) -> Option<UndoAction> {
    let UndoAction::Move { pairs } = action else { return None };
    let moved = pairs.iter().filter(|(from, to)| {
        let (src, dst) = if inverse { (Path::new(to), Path::new(from)) } else { (Path::new(from), Path::new(to)) };
        !entry_exists(dst) && (fs::rename(src, dst).is_ok() || (copy_merge_entry(src, dst) && remove_path(src)))
    }).cloned().collect::<Vec<_>>();
    if moved.is_empty() { None } else { Some(UndoAction::Move { pairs: moved }) }
}

fn replay_merge_copy(action: &UndoAction, inverse: bool) -> Option<UndoAction> {
    let UndoAction::Copy { pairs } = action else { return None };
    let copied = pairs.iter().filter(|(from, to)| {
        if inverse { remove_path(Path::new(to)) }
        else { !entry_exists(Path::new(to)) && copy_merge_entry(Path::new(from), Path::new(to)) }
    }).cloned().collect::<Vec<_>>();
    if copied.is_empty() { None } else { Some(UndoAction::Copy { pairs: copied }) }
}

fn remove_path(path: &Path) -> bool {
    if path.is_dir() {
        fs::remove_dir_all(path).is_ok()
    } else {
        fs::remove_file(path).is_ok()
    }
}

/// Falls back to the system trash CLI when the in-process trash fails, then
/// recovers the matching `.trashinfo` entry so the action stays undoable.
fn trash_via_cli(path: &Path) -> Option<TrashItem> {
    let (files_dir, info_dir) = trash_paths();
    let before: std::collections::HashSet<String> = fs::read_dir(&info_dir)
        .map(|entries| {
            entries
                .flatten()
                .filter_map(|e| e.file_name().into_string().ok())
                .collect()
        })
        .unwrap_or_default();

    let abs = fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf());
    let ran = std::process::Command::new("trash")
        .arg(&abs)
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
        || std::process::Command::new("gio")
            .arg("trash")
            .arg("--")
            .arg(&abs)
            .status()
            .map(|s| s.success())
            .unwrap_or(false);
    if !ran {
        return None;
    }

    let entries = fs::read_dir(&info_dir).ok()?;
    for entry in entries.flatten() {
        let name = match entry.file_name().into_string() {
            Ok(n) => n,
            Err(_) => continue,
        };
        if before.contains(&name) || !name.ends_with(".trashinfo") {
            continue;
        }
        let Ok(content) = fs::read_to_string(entry.path()) else { continue };
        let Some(original) = parse_trashinfo_path(&content) else { continue };
        if Path::new(&original) == abs {
            let trashed = files_dir.join(name.trim_end_matches(".trashinfo"));
            return Some(TrashItem {
                original,
                trashed: trashed.to_string_lossy().to_string(),
                info: entry.path().to_string_lossy().to_string(),
            });
        }
    }
    None
}

/// Reverses `action` on the filesystem; returns the action that would replay it.
fn apply_inverse(action: &UndoAction) -> Option<UndoAction> {
    match action {
        UndoAction::Merge { actions } => {
            use std::os::unix::fs::PermissionsExt;
            for action in actions {
                if let UndoAction::CreatedMergeDirectory { path, mode } = action {
                    if real_directory(Path::new(path)) { let _ = fs::set_permissions(path, fs::Permissions::from_mode(*mode | 0o700)); }
                }
            }
            let mut undone = actions.iter().rev().filter_map(|action| {
                match action {
                    UndoAction::Move { .. } => replay_merge_move(action, true),
                    UndoAction::Copy { .. } => replay_merge_copy(action, true),
                    _ => apply_inverse(action),
                }
            }).collect::<Vec<_>>();
            // Recreated source directories stay writable until their children
            // have returned, then regain their original permissions.
            for action in &undone {
                if let UndoAction::RemovedDirectory { path, mode } = action {
                    let _ = fs::set_permissions(path, fs::Permissions::from_mode(*mode));
                }
            }
            for action in actions {
                if let UndoAction::CreatedMergeDirectory { path, mode } = action {
                    if real_directory(Path::new(path)) { let _ = fs::set_permissions(path, fs::Permissions::from_mode(*mode)); }
                }
            }
            undone.reverse();
            if undone.is_empty() { None } else { Some(UndoAction::Merge { actions: undone }) }
        }
        UndoAction::RemovedDirectory { path, mode } => {
            use std::os::unix::fs::DirBuilderExt;
            fs::DirBuilder::new().mode(*mode | 0o700).create(path).ok().map(|_| action.clone())
        }
        UndoAction::CreatedMergeDirectory { path, .. } => fs::remove_dir(path).ok().map(|_| action.clone()),
        UndoAction::Rename { dir, old_name, new_name } => {
            let base = Path::new(dir);
            fs::rename(base.join(new_name), base.join(old_name))
                .ok()
                .map(|_| UndoAction::Rename {
                    dir: dir.clone(),
                    old_name: old_name.clone(),
                    new_name: new_name.clone(),
                })
        }
        UndoAction::Create { path, is_dir } => {
            let p = Path::new(path);
            let ok = if *is_dir { fs::remove_dir_all(p).is_ok() } else { fs::remove_file(p).is_ok() };
            if ok {
                Some(UndoAction::Create { path: path.clone(), is_dir: *is_dir })
            } else {
                None
            }
        }
        UndoAction::Move { pairs } => {
            let mut undone = Vec::new();
            for (from, to) in pairs {
                if fs::rename(to, from).is_ok() {
                    undone.push((from.clone(), to.clone()));
                }
            }
            if undone.is_empty() {
                None
            } else {
                Some(UndoAction::Move { pairs: undone })
            }
        }
        UndoAction::Copy { pairs } => {
            let mut removed = Vec::new();
            for (source, created) in pairs {
                if remove_path(Path::new(created)) {
                    removed.push((source.clone(), created.clone()));
                }
            }
            if removed.is_empty() {
                None
            } else {
                Some(UndoAction::Copy { pairs: removed })
            }
        }
        UndoAction::Trash { items } => {
            let mut restored = Vec::new();
            for item in items {
                let from = Path::new(&item.trashed);
                let to = Path::new(&item.original);
                if let Some(parent) = to.parent() {
                    let _ = fs::create_dir_all(parent);
                }
                let mut ok = fs::rename(from, to).is_ok();
                if !ok && entry_exists(from) && copy_merge_entry(from, to) {
                    let _ = remove_path(from);
                    ok = true;
                }
                if ok {
                    let _ = fs::remove_file(&item.info);
                    restored.push(item.clone());
                }
            }
            if restored.is_empty() {
                None
            } else {
                Some(UndoAction::Trash { items: restored })
            }
        }
    }
}

/// Replays `action` on the filesystem; returns the action that would undo it.
fn apply_action(action: &UndoAction) -> Option<UndoAction> {
    match action {
        UndoAction::Merge { actions } => {
            let redone = actions.iter().filter_map(|action| {
                match action {
                    UndoAction::Move { .. } => replay_merge_move(action, false),
                    UndoAction::Copy { .. } => replay_merge_copy(action, false),
                    _ => apply_action(action),
                }
            }).collect::<Vec<_>>();
            use std::os::unix::fs::PermissionsExt;
            for action in &redone {
                if let UndoAction::CreatedMergeDirectory { path, mode } = action {
                    let _ = fs::set_permissions(path, fs::Permissions::from_mode(*mode));
                }
            }
            if redone.is_empty() { None } else { Some(UndoAction::Merge { actions: redone }) }
        }
        UndoAction::RemovedDirectory { path, .. } => fs::remove_dir(path).ok().map(|_| action.clone()),
        UndoAction::CreatedMergeDirectory { path, mode } => {
            use std::os::unix::fs::{DirBuilderExt, PermissionsExt};
            fs::DirBuilder::new().mode(*mode | 0o700).create(path).ok()?;
            let _ = fs::set_permissions(path, fs::Permissions::from_mode(*mode | 0o700));
            Some(action.clone())
        }
        UndoAction::Rename { dir, old_name, new_name } => {
            let base = Path::new(dir);
            fs::rename(base.join(old_name), base.join(new_name))
                .ok()
                .map(|_| action.clone())
        }
        UndoAction::Create { path, is_dir } => {
            let ok = if *is_dir {
                fs::create_dir_all(path).is_ok()
            } else {
                fs::File::create(path).is_ok()
            };
            if ok {
                Some(action.clone())
            } else {
                None
            }
        }
        UndoAction::Move { pairs } => {
            let mut redone = Vec::new();
            for (from, to) in pairs {
                if fs::rename(from, to).is_ok() {
                    redone.push((from.clone(), to.clone()));
                }
            }
            if redone.is_empty() {
                None
            } else {
                Some(UndoAction::Move { pairs: redone })
            }
        }
        UndoAction::Copy { pairs } => {
            let mut redone = Vec::new();
            for (source, created) in pairs {
                if copy_recursive(Path::new(source), Path::new(created)) {
                    redone.push((source.clone(), created.clone()));
                }
            }
            if redone.is_empty() {
                None
            } else {
                Some(UndoAction::Copy { pairs: redone })
            }
        }
        UndoAction::Trash { items } => {
            let mut retrashed = Vec::new();
            for item in items {
                if let Some(new_item) = trash_into_home_trash(Path::new(&item.original)) {
                    retrashed.push(new_item);
                }
            }
            if retrashed.is_empty() {
                None
            } else {
                Some(UndoAction::Trash { items: retrashed })
            }
        }
    }
}

fn format_size(bytes: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = 1024 * KB;
    const GB: u64 = 1024 * MB;

    if bytes >= GB {
        format!("{:.1} GB", bytes as f64 / GB as f64)
    } else if bytes >= MB {
        format!("{:.1} MB", bytes as f64 / MB as f64)
    } else if bytes >= KB {
        format!("{:.1} KB", bytes as f64 / KB as f64)
    } else {
        format!("{} B", bytes)
    }
}

fn format_unix_date(ts: u64) -> String {
    let days = (ts / 86400) as i64;
    let mut y = 1970;
    let mut d = days;
    loop {
        let leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
        let days_in_year = if leap { 366 } else { 365 };
        if d < days_in_year {
            break;
        }
        d -= days_in_year;
        y += 1;
    }
    let leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
    let month_days = [
        31, if leap { 29 } else { 28 }, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
    ];
    let month_names = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    let mut m = 0;
    for (i, &md) in month_days.iter().enumerate() {
        if d < md {
            m = i;
            break;
        }
        d -= md;
    }
    format!("{} {}, {}", month_names[m], d + 1, y)
}

fn format_modified_time(meta: &fs::Metadata) -> (u64, String) {
    if let Ok(mtime) = meta.modified() {
        let ts = mtime.duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
        let elapsed = mtime.elapsed().map(|e| e.as_secs()).unwrap_or(0);
        let s = if elapsed < 60 {
            "Just now".to_string()
        } else if elapsed < 3600 {
            format!("{}m ago", elapsed / 60)
        } else if elapsed < 86400 {
            format!("{}h ago", elapsed / 3600)
        } else if elapsed < 86400 * 7 {
            format!("{}d ago", elapsed / 86400)
        } else {
            format_unix_date(ts)
        };
        (ts, s)
    } else {
        (0, "-".to_string())
    }
}

fn get_unique_name(dest: &Path, name: &str) -> PathBuf {
    let mut target = dest.join(name);
    if !entry_exists(&target) {
        return target;
    }
    let p = Path::new(name);
    let is_tar_gz = name.ends_with(".tar.gz");
    let (stem, ext) = if is_tar_gz {
        let s = name.strip_suffix(".tar.gz").unwrap_or(name);
        (s, ".tar.gz")
    } else {
        let s = p.file_stem().and_then(|s| s.to_str()).unwrap_or(name);
        let _e = p.extension().and_then(|e| e.to_str()).map(|e| format!(".{}", e)).unwrap_or_default();
        (s, "")
    };
    let ext_str = if is_tar_gz { ext.to_string() } else { p.extension().and_then(|e| e.to_str()).map(|e| format!(".{}", e)).unwrap_or_default() };

    let mut count = 1;
    loop {
        let new_name = format!("{} ({}){}", stem, count, ext_str);
        target = dest.join(&new_name);
        if !entry_exists(&target) {
            return target;
        }
        count += 1;
    }
}

fn is_archive_path(path: &Path) -> bool {
    crate::archive::supported(path)
}

fn is_picture_format(ext: &str) -> bool {
    matches!(
        ext,
        "png" | "jpg" | "jpeg" | "jpe" | "jfif"
        | "webp" | "gif" | "bmp" | "dib" | "ico"
        | "svg" | "svgz"
        | "kra" | "ora"
        | "tiff" | "tif"
        | "avif" | "heic" | "heif" | "jxl"
        | "xcf" | "psd"
        | "raw" | "cr2" | "nef" | "dng" | "arw"
    )
}

fn resolve_thumbnail_path(path: &Path) -> String {
    let extension = path.extension().and_then(|value| value.to_str()).unwrap_or("").to_lowercase();
    if !is_picture_format(&extension) && !matches!(extension.as_str(), "mp4" | "mkv" | "webm" | "mov" | "avi" | "flv" | "wmv") {
        return String::new();
    }
    format!("image://seabunnythumb/{}", percent_encode_path(&path.to_string_lossy()))
}

fn resolve_thumbnail_url(path: &Path, _allow_generation: bool) -> String {
    let mut url = resolve_thumbnail_path(path);
    if !url.is_empty() {
        if let Ok(metadata) = fs::metadata(path) {
            let modified = metadata.modified().ok().and_then(|time| time.duration_since(std::time::UNIX_EPOCH).ok()).map(|time| time.as_nanos()).unwrap_or(0);
            url.push_str(&format!("?version={}-{}", modified, metadata.len()));
        }
    }
    url
}

fn icon_for_file(path: &Path, is_dir: bool) -> (&'static str, &'static str) {
    if is_dir {
        return ("folder", "folder");
    }

    let ext = path.extension().and_then(|ext| ext.to_str()).unwrap_or("").to_lowercase();
    if is_picture_format(&ext) {
        return ("file-image", "media");
    }

    match ext.as_str() {
        "mp3" | "flac" | "wav" | "ogg" | "m4a" | "aac" | "opus" => ("file-audio", "media"),
        "mp4" | "mkv" | "webm" | "mov" | "avi" | "flv" | "wmv" => ("file-video", "media"),
        "html" | "htm" => ("file-html", "code"),
        "css" | "scss" | "sass" | "less" => ("file-css", "code"),
        "rs" | "nix" | "js" | "ts" | "jsx" | "tsx" | "py" | "c" | "cpp" | "h" | "hpp" | "lua" | "go" | "java" | "kt" => ("file-code", "code"),
        "sh" | "bash" | "zsh" | "fish" => ("code", "code"),
        "zip" => ("file-zip", "archive"),
        "tar" | "gz" | "xz" | "zst" | "bz2" | "7z" | "rar" | "tgz" | "txz" | "tbz" | "tbz2" | "tzst" | "cab" | "arj" | "lha" | "lzh" | "cpio" | "iso" => ("file-archive", "archive"),
        "appimage" | "run" | "bin" | "exe" => ("terminal", "application"),
        "deb" | "rpm" | "flatpak" | "flatpakref" => ("package", "application"),
        "desktop" => ("desktop", "application"),
        "pdf" => ("file-pdf", "document"),
        "md" | "txt" | "json" | "toml" | "yaml" | "yml" | "csv" | "log" | "doc" | "docx" | "odt" => ("file-text", "text"),
        _ => {
            use std::os::unix::fs::PermissionsExt;
            if fs::metadata(path).is_ok_and(|meta| meta.is_file() && meta.permissions().mode() & 0o111 != 0) {
                ("terminal", "application")
            } else { ("file", "file") }
        },
    }
}

fn system_icon_for_file(path: &Path, is_dir: bool) -> &'static str {
    if is_dir {
        return "folder";
    }

    match icon_for_file(path, false).0 {
        "file-image" => "image-x-generic",
        "file-audio" => "audio-x-generic",
        "file-video" => "video-x-generic",
        "file-code" | "file-html" | "file-css" | "code" => "text-x-script",
        "file-zip" | "file-archive" | "package" => "package-x-generic",
        "terminal" => "application-x-executable",
        "desktop" => "application-x-desktop",
        "file-pdf" => "application-pdf",
        _ => "text-x-generic",
    }
}

fn record_dir_visit(path: &str) {
    let mut guard = VISIT_COUNTS.lock().unwrap();
    let map = guard.get_or_insert_with(HashMap::new);
    *map.entry(path.to_string()).or_insert(0) += 1;
}

fn get_frequent_dirs() -> Vec<FrequentDirItem> {
    let home = std::env::var("HOME").unwrap_or_default();
    // Seed defaults so the row is never empty on first run.
    let defaults = [
        ("seabunny", format!("{}/Projects/seabunny", home), "code"),
        ("Projects", format!("{}/Projects", home), "code"),
        ("Wallpapers", format!("{}/Pictures/Wallpapers", home), "image"),
        ("Downloads", format!("{}/Downloads", home), "download"),
        (".config", format!("{}/.config", home), "gear"),
        ("Documents", format!("{}/Documents", home), "file-text"),
    ];

    let counts = VISIT_COUNTS.lock().unwrap();
    let counts_ref = counts.as_ref();

    let mut res: Vec<(u32, FrequentDirItem)> = Vec::new();

    // Real visited dirs (ranked by visit count), skipping HOME itself.
    if let Some(map) = counts_ref {
        let mut entries: Vec<(&String, &usize)> = map.iter().collect();
        entries.sort_by(|a, b| b.1.cmp(a.1));
        for (path, count) in entries {
            if *path == home {
                continue;
            }
            let p = Path::new(path);
            if !p.is_dir() {
                continue;
            }
            let name = p
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or(path.as_str())
                .to_string();
            let (_, icon) = icon_for_file(p, true);
            res.push((
                *count as u32,
                FrequentDirItem {
                    name,
                    path: path.clone(),
                    icon: icon.to_string(),
                },
            ));
        }
    }

    // Merge in defaults (with their seed counts) if not already present.
    for (name, path, icon) in &defaults {
        if res.iter().any(|(_, it)| it.path == *path) && Path::new(path).is_dir() {
            continue;
        }
        if Path::new(path).is_dir() {
            let seed = match *name {
                "seabunny" => 5,
                "Projects" => 4,
                "Downloads" => 3,
                "Wallpapers" => 2,
                "Documents" => 1,
                _ => 0,
            };
            res.push((
                seed,
                FrequentDirItem {
                    name: name.to_string(),
                    path: path.clone(),
                    icon: icon.to_string(),
                },
            ));
        }
    }

    res.sort_by(|a, b| b.0.cmp(&a.0));
    res.into_iter().map(|(_, it)| it).take(6).collect()
}

fn is_external_device(block_name: &str, rm: bool, hotplug: bool, tran: &str) -> bool {
    // Removable/hotpluggable is authoritative.
    if rm || hotplug {
        return true;
    }

    // Removable buses.
    match tran.to_lowercase().as_str() {
        "usb" | "mmc" | "sdio" | "firewire" | "1394" | "memstick" => return true,
        _ => {}
    }

    // Fall back to sysfs for devices lsblk reports no transport for.
    let base = block_name.trim_start_matches("/dev/").trim();
    if base.is_empty() {
        return false;
    }

    // Partition names ("sdb1", "mmcblk0p2", "nvme0n1p3") resolve to the parent disk.
    let stripped_digits = base.trim_end_matches(|c: char| c.is_ascii_digit());
    let stripped_p = stripped_digits.strip_suffix('p');
    let parent = match stripped_p {
        Some(s) if s.chars().last().map(|c| c.is_ascii_digit()).unwrap_or(false) => s,
        _ => stripped_digits,
    };

    let mut candidates = vec![base.to_string()];
    if parent != base && !parent.is_empty() {
        candidates.push(parent.to_string());
    }

    for candidate in candidates {
        let sys_block = Path::new("/sys/block").join(&candidate);
        if let Ok(removable) = fs::read_to_string(sys_block.join("removable")) {
            if removable.trim() == "1" {
                return true;
            }
        }
        let real = fs::canonicalize(&sys_block)
            .or_else(|_| fs::canonicalize(Path::new("/sys/class/block").join(&candidate)));
        if let Ok(real) = real {
            let s = real.to_string_lossy().to_lowercase();
            if s.contains("/usb") {
                return true;
            }
        }
    }
    false
}

fn read_system_drives() -> Vec<DriveItem> {
    let mut drives = Vec::new();
    let mut seen_devices = std::collections::HashSet::new();

    if let Ok(output) = std::process::Command::new("lsblk")
        .args(["-b", "--json", "-o", "NAME,LABEL,MOUNTPOINT,FSTYPE,SIZE,RM,HOTPLUG,TRAN,MODEL,UUID"])
        .output()
    {
        if let Ok(val) = serde_json::from_slice::<serde_json::Value>(&output.stdout) {
            if let Some(blocks) = val.get("blockdevices").and_then(|b| b.as_array()) {
                fn process_device(
                    dev: &serde_json::Value,
                    parent_model: &str,
                    parent_tran: &str,
                    parent_rm: bool,
                    parent_name: &str,
                    drives: &mut Vec<DriveItem>,
                    seen: &mut std::collections::HashSet<String>,
                ) {
                    let name = dev.get("name").and_then(|n| n.as_str()).unwrap_or("");
                    let model = dev.get("model").and_then(|m| m.as_str()).unwrap_or(parent_model);
                    let tran = dev.get("tran").and_then(|t| t.as_str()).unwrap_or(parent_tran);
                    let rm = dev.get("rm").and_then(|r| r.as_bool()).unwrap_or(parent_rm);
                    let hotplug = dev.get("hotplug").and_then(|h| h.as_bool()).unwrap_or(false);
                    let fstype = dev.get("fstype").and_then(|f| f.as_str()).unwrap_or("");
                    let mountpoint = dev.get("mountpoint").and_then(|m| m.as_str()).unwrap_or("");
                    let label = dev.get("label").and_then(|l| l.as_str()).unwrap_or("");
                    let size = dev.get("size").and_then(|s| s.as_u64()).unwrap_or(0);
                    // Partitions inherit the physical disk name so sysfs lookups work.
                    let block_name = if parent_name.is_empty() { name } else { parent_name };

                    if let Some(children) = dev.get("children").and_then(|c| c.as_array()) {
                        for child in children {
                            process_device(child, model, tran, rm, block_name, drives, seen);
                        }
                    } else if !name.is_empty() && !fstype.is_empty() && fstype != "swap" && mountpoint != "[SWAP]" {
                        let device_path = format!("/dev/{}", name);
                        if seen.contains(&device_path) {
                            return;
                        }
                        seen.insert(device_path.clone());

                        let is_mounted = !mountpoint.is_empty();
                        let is_external = is_external_device(block_name, rm, hotplug, tran);

                        let display_name = if !label.is_empty() {
                            label.to_string()
                        } else if mountpoint == "/" {
                            "Root (/)".to_string()
                        } else if is_mounted {
                            Path::new(mountpoint)
                                .file_name()
                                .and_then(|n| n.to_str())
                                .unwrap_or(name)
                                .to_string()
                        } else {
                            name.to_string()
                        };

                        let (total_bytes, free_bytes, used_bytes, percent) = if is_mounted {
                            let c_mount = std::ffi::CString::new(mountpoint).unwrap_or_default();
                            let mut st: libc::statvfs = unsafe { std::mem::zeroed() };
                            if unsafe { libc::statvfs(c_mount.as_ptr(), &mut st) } == 0 {
                                let total = st.f_blocks as u64 * st.f_frsize as u64;
                                let free = st.f_bavail as u64 * st.f_frsize as u64;
                                let used = total.saturating_sub(free);
                                let p = if total > 0 { ((used as f64 / total as f64) * 100.0).round() } else { 0.0 };
                                (total, free, used, (p * 10.0).round() / 10.0)
                            } else {
                                (size, size, 0, 0.0)
                            }
                        } else {
                            (size, size, 0, 0.0)
                        };

                        drives.push(DriveItem {
                            name: display_name,
                            device: device_path,
                            mount_point: mountpoint.to_string(),
                            is_mounted,
                            is_external,
                            fs_type: fstype.to_string(),
                            total_str: format_size(total_bytes),
                            used_str: format_size(used_bytes),
                            free_str: format_size(free_bytes),
                            total_bytes,
                            used_bytes,
                            free_bytes,
                            percent,
                            model: model.to_string(),
                        });
                    }
                }

                for b in blocks {
                    process_device(b, "", "", false, "", &mut drives, &mut seen_devices);
                }
            }
        }
    }

    if drives.is_empty() {
        let mounts_content = fs::read_to_string("/proc/mounts").unwrap_or_default();
        for line in mounts_content.lines() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() < 3 {
                continue;
            }

            let dev = parts[0];
            let mount = parts[1];
            let fstype = parts[2];

            if (!dev.starts_with("/dev/") && !mount.starts_with("/run/media/"))
                || mount.starts_with("/boot")
                || mount == "/nix/store"
            {
                continue;
            }

            let c_mount = std::ffi::CString::new(mount).unwrap_or_default();
            let mut st: libc::statvfs = unsafe { std::mem::zeroed() };

            if unsafe { libc::statvfs(c_mount.as_ptr(), &mut st) } == 0 {
                let total = st.f_blocks as u64 * st.f_frsize as u64;
                let free = st.f_bavail as u64 * st.f_frsize as u64;
                let used = total.saturating_sub(free);
                let percent = if total > 0 {
                    ((used as f64 / total as f64) * 100.0).round()
                } else {
                    0.0
                };

                let name = if mount == "/" {
                    "Root (/)".to_string()
                } else {
                    Path::new(mount)
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or(mount)
                        .to_string()
                };

                drives.push(DriveItem {
                    name,
                    device: dev.to_string(),
                    mount_point: mount.to_string(),
                    is_mounted: true,
                    is_external: is_external_device(dev, false, false, ""),
                    fs_type: fstype.to_string(),
                    total_str: format_size(total),
                    used_str: format_size(used),
                    free_str: format_size(free),
                    total_bytes: total,
                    used_bytes: used,
                    free_bytes: free,
                    percent: (percent * 10.0).round() / 10.0,
                    model: String::new(),
                });
            }
        }
    }

    drives
}

fn scan_trash_files() -> Vec<FileItem> {
    let (files_dir, _) = trash_paths();
    scan_directory(&files_dir, true, "name", true, "first", || false)
}

fn build_breadcrumbs(target_path: &Path, forward_target: Option<&str>) -> Vec<Breadcrumb> {
    let home = std::env::var("HOME").unwrap_or_default();
    let home_path = Path::new(&home);

    let mut crumbs = Vec::new();

    let known_places = [
        ("Projects", "code", "utilities-terminal-symbolic"),
        ("Downloads", "download", "folder-download-symbolic"),
        ("Documents", "file-text", "x-office-document-symbolic"),
        ("Pictures", "image", "image-x-generic-symbolic"),
        ("Music", "music", "audio-x-generic-symbolic"),
        ("Videos", "video", "video-x-generic-symbolic"),
    ];

    let mut base_matched: Option<(PathBuf, String, &'static str, &'static str)> = None;

    for (dir_name, icon, sys_icon) in &known_places {
        let p = home_path.join(dir_name);
        if target_path.starts_with(&p) {
            base_matched = Some((p, dir_name.to_string(), icon, sys_icon));
            break;
        }
    }

    if let Some((base_path, place_name, icon, sys_icon)) = base_matched {
        crumbs.push(Breadcrumb {
            name: place_name,
            path: base_path.to_string_lossy().to_string(),
            icon: icon.to_string(),
            system_icon: sys_icon.to_string(),
            is_root_place: true,
            is_forward: false,
        });

        if let Ok(rel) = target_path.strip_prefix(&base_path) {
            let mut cur = base_path;
            for comp in rel.components() {
                if let std::path::Component::Normal(c) = comp {
                    let s = c.to_string_lossy().to_string();
                    cur.push(&s);
                    crumbs.push(Breadcrumb {
                        name: s,
                        path: cur.to_string_lossy().to_string(),
                        icon: "folder".to_string(),
                        system_icon: "folder".to_string(),
                        is_root_place: false,
                        is_forward: false,
                    });
                }
            }
        }
    } else if target_path.starts_with(home_path) {
        crumbs.push(Breadcrumb {
            name: "Home".to_string(),
            path: home_path.to_string_lossy().to_string(),
            icon: "house".to_string(),
            system_icon: "user-home-symbolic".to_string(),
            is_root_place: true,
            is_forward: false,
        });

        if let Ok(rel) = target_path.strip_prefix(home_path) {
            let mut cur = home_path.to_path_buf();
            for comp in rel.components() {
                if let std::path::Component::Normal(c) = comp {
                    let s = c.to_string_lossy().to_string();
                    cur.push(&s);
                    crumbs.push(Breadcrumb {
                        name: s,
                        path: cur.to_string_lossy().to_string(),
                        icon: "folder".to_string(),
                        system_icon: "folder".to_string(),
                        is_root_place: false,
                        is_forward: false,
                    });
                }
            }
        }
    } else {
        let mut cur = PathBuf::new();
        for comp in target_path.components() {
            match comp {
                std::path::Component::RootDir => {
                    cur.push("/");
                    crumbs.push(Breadcrumb {
                        name: "root".to_string(),
                        path: "/".to_string(),
                        icon: "hard-drive".to_string(),
                        system_icon: "drive-harddisk-symbolic".to_string(),
                        is_root_place: true,
                        is_forward: false,
                    });
                }
                std::path::Component::Normal(c) => {
                    let s = c.to_string_lossy().to_string();
                    cur.push(&s);
                    crumbs.push(Breadcrumb {
                        name: s,
                        path: cur.to_string_lossy().to_string(),
                        icon: "folder".to_string(),
                        system_icon: "folder".to_string(),
                        is_root_place: false,
                        is_forward: false,
                    });
                }
                _ => {}
            }
        }
    }

    if let Some(fwd_str) = forward_target {
        let fwd_p = Path::new(fwd_str);
        if fwd_p != target_path && fwd_p.starts_with(target_path) {
            if let Ok(rel) = fwd_p.strip_prefix(target_path) {
                let mut cur = target_path.to_path_buf();
                for comp in rel.components() {
                    if let std::path::Component::Normal(c) = comp {
                        let fwd_name = c.to_string_lossy().to_string();
                        cur.push(&fwd_name);
                        crumbs.push(Breadcrumb {
                            name: fwd_name,
                            path: cur.to_string_lossy().to_string(),
                            icon: "folder".to_string(),
                            system_icon: "folder".to_string(),
                            is_root_place: false,
                            is_forward: true,
                        });
                    }
                }
            }
        }
    }

    crumbs
}

fn scan_directory(
    dir_path: &Path,
    show_hidden: bool,
    sort_by: &str,
    sort_ascending: bool,
    folder_position: &str,
    cancelled: impl Fn() -> bool,
) -> Vec<FileItem> {
    let mut items = Vec::new();

    if let Ok(entries) = fs::read_dir(dir_path) {
        for entry in entries.flatten() {
            if cancelled() { return Vec::new(); }
            let path = entry.path();
            let name = match entry.file_name().into_string() {
                Ok(n) => n,
                Err(_) => continue,
            };

            if !show_hidden && name.starts_with('.') {
                continue;
            }

            let is_dir = entry.file_type().map(|t| t.is_dir()).unwrap_or(false);
            let is_symlink = path.is_symlink();
            let (icon, category) = icon_for_file(&path, is_dir);
            let sys_icon_name = system_icon_for_file(&path, is_dir);
            let icon_path = resolve_system_icon(sys_icon_name);
            let thumbnail = if is_dir {
                String::new()
            } else {
                resolve_thumbnail_url(&path, false)
            };

            let (size, size_str, modified, modified_str) = if let Ok(meta) = entry.metadata() {
                let sz = if is_dir { 0 } else { meta.len() };
                let sz_str = if is_dir {
                    "-".to_string()
                } else {
                    format_size(sz)
                };
                let (ts, m_str) = format_modified_time(&meta);
                (sz, sz_str, ts, m_str)
            } else {
                (0, "-".to_string(), 0, "-".to_string())
            };

            items.push(FileItem {
                name,
                is_dir,
                is_symlink,
                icon: icon.to_string(),
                icon_path,
                thumbnail,
                category: category.to_string(),
                size,
                size_str,
                modified,
                modified_str,
            });
        }
    }

    sort_items(&mut items, sort_by, sort_ascending, folder_position);
    items
}

fn sort_items(items: &mut [FileItem], sort_by: &str, sort_ascending: bool, folder_position: &str) {
    items.sort_by(|a, b| {
        match folder_position {
            "last" => {
                if a.is_dir != b.is_dir {
                    return a.is_dir.cmp(&b.is_dir);
                }
            }
            "mixed" => {}
            _ => {
                // "first" is default
                if a.is_dir != b.is_dir {
                    return b.is_dir.cmp(&a.is_dir);
                }
            }
        }
        let ord = match sort_by {
            "size" => a.size.cmp(&b.size).then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())),
            "modified" => a.modified.cmp(&b.modified).then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())),
            "type" => a.category.cmp(&b.category).then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())),
            _ => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
        };
        if sort_ascending {
            ord
        } else {
            ord.reverse()
        }
    });
}

fn archive_directory(location: &str, hidden: bool, sort: &str, ascending: bool, folders: &str,
    cancelled: impl Fn() -> bool) -> Result<Vec<FileItem>, String> {
    let result = crate::archive::list(location, cancelled)?;
    let mut items = Vec::new();
    for entry in result["entries"].as_array().ok_or("Invalid archive index")? {
        let name = entry["name"].as_str().ok_or("Archive member is missing its name")?.to_string();
        if !hidden && name.starts_with('.') { continue; }
        let is_dir = entry["is_dir"].as_bool().unwrap_or(false);
        let path = Path::new(&name);
        let (icon, category) = icon_for_file(path, is_dir);
        let size = entry["size"].as_u64().unwrap_or(0);
        items.push(FileItem { name: name.clone(), is_dir, is_symlink: entry["blocked"].as_bool().unwrap_or(false),
            icon: icon.into(), icon_path: resolve_system_icon(system_icon_for_file(path, is_dir)),
            thumbnail: String::new(), category: category.into(), size,
            size_str: if is_dir { "-".into() } else { format_size(size) },
            modified: entry["modified"].as_u64().unwrap_or(0),
            modified_str: entry["modified_str"].as_str().unwrap_or("-").to_string() });
    }
    sort_items(&mut items, sort, ascending, folders);
    Ok(items)
}

fn navigation_metadata(location: &str, forward: Option<&str>) -> (String, Vec<Breadcrumb>, String) {
    if let Some((archive, member)) = crate::archive::parse(location) {
        let parent = archive.parent().unwrap_or(Path::new("/"));
        let mut crumbs = build_breadcrumbs(parent, None);
        let root = crate::archive::root(&archive);
        let label = archive.file_name().unwrap_or_default().to_string_lossy().to_string();
        crumbs.push(Breadcrumb { name: label.clone(), path: root.clone(), icon: "archive".into(),
            system_icon: "package-x-generic".into(), is_root_place: false, is_forward: false });
        let mut current = root;
        for part in member.split('/').filter(|part| !part.is_empty()) {
            current.push('/'); current.push_str(part);
            crumbs.push(Breadcrumb { name: part.to_string(), path: current.clone(), icon: "folder".into(),
                system_icon: "folder".into(), is_root_place: false, is_forward: false });
        }
        let name = if member.is_empty() { label } else { member.rsplit('/').next().unwrap_or("").to_string() };
        (name, crumbs, archive.to_string_lossy().to_string())
    } else {
        let path = Path::new(location);
        (path.file_name().and_then(|name| name.to_str()).unwrap_or(location).to_string(),
            build_breadcrumbs(path, forward), String::new())
    }
}

fn execute_search_everywhere(query_str: &str, show_hidden: bool, disambiguate_duplicates: bool,
    cancelled: impl Fn() -> bool) -> Vec<SearchResultItem> {
    let q = query_str.to_lowercase();
    let home = std::env::var("HOME").unwrap_or_default();
    let mut results: Vec<(i32, SearchResultItem)> = Vec::new();

    let mut stack = vec![(PathBuf::from(&home), 0)];
    let skip_dirs = [
        ".git", "node_modules", "target", ".cache", ".local/share/Trash",
        ".direnv", "venv", ".npm", ".cargo", ".rustup"
    ];

    while let Some((dir, depth)) = stack.pop() {
        if cancelled() { return Vec::new(); }
        if depth > 5 || results.len() > 300 {
            continue;
        }

        if let Ok(entries) = fs::read_dir(&dir) {
            for entry in entries.flatten() {
                if cancelled() { return Vec::new(); }
                let path = entry.path();
                let file_name = match entry.file_name().into_string() {
                    Ok(n) => n,
                    Err(_) => continue,
                };

                let is_dir = entry.file_type().map(|t| t.is_dir()).unwrap_or(false);

                if is_dir {
                    if skip_dirs.iter().any(|s| file_name == *s) {
                        continue;
                    }
                    if !show_hidden && file_name.starts_with('.') {
                        continue;
                    }
                    stack.push((path.clone(), depth + 1));
                } else if !show_hidden && file_name.starts_with('.') {
                    continue;
                }

                let name_lower = file_name.to_lowercase();
                let score = if name_lower == q {
                    120
                } else if name_lower.starts_with(&q) {
                    100
                } else if name_lower.contains(&q) {
                    60
                } else {
                    continue;
                };

                let parent_path = path.parent().map(|p| p.to_string_lossy().to_string()).unwrap_or_default();
                let (icon, category) = icon_for_file(&path, is_dir);
                let sys_icon = system_icon_for_file(&path, is_dir);
                let icon_path = resolve_system_icon(sys_icon);
                let thumbnail = if is_dir {
                    String::new()
                } else {
                    // Recursive search can hit hundreds of images: reuse the cache
                    // instead of spawning an image converter for each hit.
                    resolve_thumbnail_url(&path, false)
                };

                results.push((
                    score,
                    SearchResultItem {
                        name: file_name.clone(),
                        display_name: file_name,
                        path: path.to_string_lossy().to_string(),
                        parent_path,
                        is_dir,
                        icon: icon.to_string(),
                        icon_path,
                        thumbnail,
                        category: category.to_string(),
                    },
                ));
            }
        }
    }

    results.sort_by(|(s1, i1), (s2, i2)| {
        s2.cmp(s1).then_with(|| i2.is_dir.cmp(&i1.is_dir))
    });

    let mut items: Vec<SearchResultItem> = results.into_iter().take(150).map(|(_, it)| it).collect();

    if disambiguate_duplicates {
        let mut name_counts: HashMap<String, usize> = HashMap::new();
        for it in &items {
            *name_counts.entry(it.name.clone()).or_insert(0) += 1;
        }

        for it in &mut items {
            if let Some(&count) = name_counts.get(&it.name) {
                if count > 1 {
                    let p = Path::new(&it.path);
                    if let Some(parent) = p.parent() {
                        let parent_name = parent.file_name().and_then(|n| n.to_str()).unwrap_or("..");
                        it.display_name = format!("{}/{}", parent_name, it.name);
                    }
                }
            }
        }
    }

    items
}

impl Default for SeabunnyEngineRust {
    fn default() -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/home".to_string());
        let home_path = Path::new(&home);
        let dir_name = home_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("Home")
            .to_string();

        let files_json = "[]".to_string();

        let crumbs = build_breadcrumbs(home_path, None);
        let crumbs_json = serde_json::to_string(&crumbs).unwrap_or_else(|_| "[]".to_string());

        let wp_colors = read_wallpaper_colors();
        let drives = read_system_drives();
        let drives_json = serde_json::to_string(&drives).unwrap_or_else(|_| "[]".to_string());

        let trash = scan_trash_files();
        let trash_json = serde_json::to_string(&trash).unwrap_or_else(|_| "[]".to_string());

        let freq = get_frequent_dirs();
        let frequent_dirs_json = serde_json::to_string(&freq).unwrap_or_else(|_| "[]".to_string());

        Self {
            current_path: QString::from(&home),
            current_dir_name: QString::from(&dir_name),
            files_json: QString::from(&files_json),
            is_loading: false,
            navigation_error: QString::from(""),
            archive_path: QString::from(""),
            archive_busy: false,
            archive_status: QString::from(""),
            archive_generation: Arc::new(AtomicU64::new(0)),
            breadcrumbs_json: QString::from(&crumbs_json),
            is_dark: detect_system_dark_mode(),
            has_clipboard: false,
            show_hidden: true,
            disambiguate_duplicates: true,
            wallpaper_colors_json: QString::from(&wp_colors),
            is_searching_everywhere: false,
            search_everywhere_json: QString::from("[]"),
            can_go_back: false,
            can_go_forward: false,
            hostname: QString::from(&read_system_hostname()),
            drives_json: QString::from(&drives_json),
            trash_json: QString::from(&trash_json),
            frequent_dirs_json: QString::from(&frequent_dirs_json),
            sort_by: QString::from("name"),
            sort_ascending: true,
            dirs_first: false,
            folder_position: QString::from("mixed"),
            view_mode: QString::from("grid"),
            clipboard_cut_paths_json: QString::from("[]"),
            device_type: QString::from(detect_device_type()),
            can_undo: false,
            can_redo: false,
            trash_root: QString::from(&trash_paths().0.to_string_lossy().to_string()),
            history_stack: Vec::new(),
            forward_stack: Vec::new(),
            scan_generation: Arc::new(AtomicU64::new(0)),
            scan_requests: None,
        }
    }
}

impl qobject::SeabunnyEngine {
    fn reject_archive_write(mut self: Pin<&mut Self>, path: &str) -> bool {
        if path.starts_with(crate::archive::PREFIX) {
            self.as_mut().set_navigation_error(QString::from("Archives are read-only. Copy or extract files to a normal folder first."));
            true
        } else { false }
    }

    fn reject_archive_sources(mut self: Pin<&mut Self>, paths: &QString) -> bool {
        let paths = serde_json::from_str::<Vec<String>>(&paths.to_string()).unwrap_or_default();
        if paths.iter().any(|path| path.starts_with(crate::archive::PREFIX)) {
            self.as_mut().set_navigation_error(QString::from("Archive members cannot be moved, renamed, deleted or edited in place."));
            true
        } else { false }
    }

    pub fn valid_location(&self, path: &QString) -> bool {
        let path = path.to_string();
        crate::archive::available(&path) || crate::archive::supported(Path::new(&path)) && Path::new(&path).is_file()
    }

    pub fn startup_locations(&self) -> QString {
        let arguments = serde_json::from_str::<Vec<String>>(&qobject::seabunny_startup_arguments().to_string()).unwrap_or_default();
        let locations = arguments.into_iter().map(|argument| {
            let path = PathBuf::from(&argument);
            if path.is_file() && !crate::archive::supported(&path) {
                path.parent().unwrap_or(Path::new("/")).to_string_lossy().to_string()
            } else { argument }
        }).collect::<Vec<_>>();
        QString::from(&serde_json::to_string(&locations).unwrap_or_else(|_| "[]".into()))
    }

    fn start_archive_job(mut self: Pin<&mut Self>, request: serde_json::Value) {
        if *self.as_ref().archive_busy() {
            self.as_mut().set_navigation_error(QString::from("An archive operation is already running in this tab"));
            return;
        }
        let generation = self.as_ref().archive_generation.clone();
        let current = generation.fetch_add(1, Ordering::Relaxed) + 1;
        let qt_thread = self.qt_thread();
        self.as_mut().set_archive_busy(true);
        self.as_mut().set_archive_status(QString::from("Extracting archive contents…"));
        self.as_mut().set_navigation_error(QString::from(""));
        std::thread::spawn(move || {
            let result = crate::archive::run(&request, || generation.load(Ordering::Relaxed) != current);
            if generation.load(Ordering::Relaxed) != current { return; }
            let _ = qt_thread.queue(move |mut object| {
                if object.as_ref().archive_generation.load(Ordering::Relaxed) != current { return; }
                object.as_mut().set_archive_busy(false);
                match result {
                    Ok(value) => {
                        let paths = value["paths"].as_array().map(|paths| {
                            let summary = paths.iter().take(3).filter_map(|path| path.as_str()).collect::<Vec<_>>().join(", ");
                            if paths.len() > 3 { format!("{summary}, and {} more", paths.len() - 3) } else { summary }
                        }).unwrap_or_default();
                        object.as_mut().set_archive_status(QString::from(&format!("Extracted to {paths}")));
                        object.as_mut().file_operation_finished();
                        if let Some(path) = value["open_path"].as_str() {
                            let _ = std::process::Command::new("xdg-open").arg(path).spawn();
                        }
                        object.as_mut().refresh();
                    }
                    Err(error) => {
                        object.as_mut().set_archive_status(QString::from(""));
                        object.as_mut().set_navigation_error(QString::from(&format!("Archive: {error}")));
                    }
                }
            });
        });
    }

    fn copy_archive_paths(mut self: Pin<&mut Self>, paths: &[String], destination: &str) -> bool {
        if !paths.iter().any(|path| path.starts_with(crate::archive::PREFIX)) { return false; }
        if self.as_mut().reject_archive_write(destination) { return true; }
        let parsed = paths.iter().map(|path| crate::archive::parse(path)).collect::<Option<Vec<_>>>();
        if let Some(parsed) = parsed {
            if !parsed.is_empty() && parsed.iter().all(|(archive, member)| archive == &parsed[0].0 && !member.is_empty()) {
                let selection = parsed.iter().map(|(_, member)| member.clone()).collect::<Vec<_>>();
                self.start_archive_job(serde_json::json!({"action": "copy", "archive": parsed[0].0, "selection": selection, "destination": destination}));
                return true;
            }
        }
        self.as_mut().set_navigation_error(QString::from("Copy archive files from one archive at a time"));
        true
    }

    pub fn extract_current_archive(mut self: Pin<&mut Self>, selected_json: &QString) {
        let Some((archive, _)) = crate::archive::parse(&self.as_ref().current_path().to_string()) else { return; };
        let Ok(selected) = serde_json::from_str::<Vec<String>>(&selected_json.to_string()) else { return; };
        let mut members = Vec::new();
        for location in selected {
            match crate::archive::parse(&location) {
                Some((source, member)) if source == archive && !member.is_empty() => members.push(member),
                _ => { self.as_mut().set_navigation_error(QString::from("Invalid archive selection")); return; }
            }
        }
        let destination = archive.parent().unwrap_or(Path::new(".")).to_path_buf();
        self.start_archive_job(serde_json::json!({"action": "extract", "archive": archive, "selection": members, "destination": destination}));
    }

    fn load_directory_async(mut self: Pin<&mut Self>, path: PathBuf, search: Option<(String, bool)>) {
        if self.as_ref().scan_requests.is_none() {
            let inbox = Arc::new(DirectoryInbox {
                request: Mutex::new(None), ready: Condvar::new(), closed: AtomicBool::new(false),
            });
            let pending = inbox.clone();
            let generation = self.as_ref().scan_generation.clone();
            let qt_thread = self.qt_thread();
            std::thread::spawn(move || {
                loop {
                    let request = {
                        let mut request = pending.request.lock().unwrap();
                        while request.is_none() && !pending.closed.load(Ordering::Relaxed) {
                            request = pending.ready.wait(request).unwrap();
                        }
                        if pending.closed.load(Ordering::Relaxed) { break; }
                        request.take().unwrap()
                    };
                    let current = request.generation;
                    if generation.load(Ordering::Relaxed) != current { continue; }
                    let searching = request.search.is_some();
                    let result = if let Some((query, disambiguate)) = &request.search {
                        let items = execute_search_everywhere(query, request.hidden, *disambiguate,
                            || generation.load(Ordering::Relaxed) != current);
                        Ok(serde_json::to_string(&items).unwrap_or_else(|_| "[]".to_string()))
                    } else if request.path.starts_with(crate::archive::PREFIX) {
                        archive_directory(&request.path, request.hidden, &request.sort, request.ascending, &request.folders,
                            || generation.load(Ordering::Relaxed) != current)
                            .map(|items| serde_json::to_string(&items).unwrap_or_else(|_| "[]".to_string()))
                    } else { fs::read_dir(&request.path).map(|_| {
                        let items = scan_directory(Path::new(&request.path), request.hidden,
                            &request.sort, request.ascending, &request.folders,
                            || generation.load(Ordering::Relaxed) != current);
                        if generation.load(Ordering::Relaxed) != current { return "[]".to_string(); }
                        serde_json::to_string(&items).unwrap_or_else(|_| "[]".to_string())
                    }).map_err(|error| format!("Cannot open {}: {}", request.path, error)) };
                    if generation.load(Ordering::Relaxed) != current { continue; }
                    let _ = qt_thread.queue(move |mut object| {
                        if object.as_ref().scan_generation.load(Ordering::Relaxed) != current { return; }
                        match result {
                            Ok(json) => {
                                if searching {
                                    object.as_mut().set_search_everywhere_json(QString::from(&json));
                                } else if object.as_ref().files_json().to_string() != json {
                                    object.as_mut().set_files_json(QString::from(&json));
                                }
                            }
                            Err(error) => object.as_mut().set_navigation_error(QString::from(&error)),
                        }
                        object.as_mut().set_is_loading(false);
                    });
                }
            });
            self.as_mut().rust_mut().scan_requests = Some(inbox);
        }
        let generation = self.as_ref().scan_generation.fetch_add(1, Ordering::Relaxed) + 1;
        let request = DirectoryRequest {
            generation, path: path.to_string_lossy().to_string(),
            hidden: *self.as_ref().show_hidden(), sort: self.as_ref().sort_by().to_string(),
            ascending: *self.as_ref().sort_ascending(), folders: self.as_ref().folder_position().to_string(), search,
        };
        if request.path != self.as_ref().current_path().to_string() {
            self.as_mut().set_files_json(QString::from("[]"));
        }
        self.as_mut().set_navigation_error(QString::from(""));
        self.as_mut().set_is_loading(true);
        let inbox = self.as_ref().scan_requests.as_ref().unwrap().clone();
        *inbox.request.lock().unwrap() = Some(request);
        inbox.ready.notify_one();
    }

    /// Keeps can_undo / can_redo in sync with the stacks.
    fn sync_undo_flags(mut self: Pin<&mut Self>) {
        let undo = stack_len(&UNDO_STACK) > 0;
        let redo = stack_len(&REDO_STACK) > 0;
        if *self.as_ref().can_undo() != undo {
            self.as_mut().set_can_undo(undo);
        }
        if *self.as_ref().can_redo() != redo {
            self.as_mut().set_can_redo(redo);
        }
    }

    /// Records an undo entry and refreshes the can_undo/can_redo properties.
    fn record_undo(mut self: Pin<&mut Self>, action: UndoAction) {
        push_undo(action);
        self.as_mut().sync_undo_flags();
    }

    /// Drops clipboard paths that no longer exist and republishes the state.
    fn refresh_clipboard_state(mut self: Pin<&mut Self>) {
        let (has, json) = {
            let mut clip = CLIPBOARD.lock().unwrap();
            clip.0.retain(|p| crate::archive::parse(p).map(|(path, _)| path.is_file()).unwrap_or_else(|| Path::new(p).exists()));
            let has = !clip.0.is_empty();
            if !has {
                clip.1 = false;
            }
            let json = if clip.1 && has {
                serde_json::to_string(&clip.0).unwrap_or_else(|_| "[]".to_string())
            } else {
                "[]".to_string()
            };
            (has, json)
        };
        self.as_mut().set_has_clipboard(has);
        self.as_mut().set_clipboard_cut_paths_json(QString::from(&json));
    }

    pub fn set_path(mut self: Pin<&mut Self>, path: &QString) {
        let mut p = path.to_string();
        if !p.starts_with(crate::archive::PREFIX) && Path::new(&p).is_file() && crate::archive::supported(Path::new(&p)) {
            if let Ok(canonical) = fs::canonicalize(&p) { p = crate::archive::root(&canonical); }
        }
        let path_buf = PathBuf::from(&p);

        if !crate::archive::available(&p) {
            self.as_mut().set_navigation_error(QString::from(&format!("Folder is missing or unavailable: {}", p)));
            return;
        }

        if !p.starts_with(crate::archive::PREFIX) { record_dir_visit(&p); }

        let old_path = self.as_ref().current_path().to_string();

        if old_path != p {
            self.as_mut().set_archive_status(QString::from(""));
            self.as_mut().rust_mut().history_stack.push(old_path.clone());
            self.as_mut().rust_mut().forward_stack.clear();
        }

        let fwd_target = self.as_ref().forward_stack.last().cloned();

        let (name, crumbs, archive) = navigation_metadata(&p, fwd_target.as_deref());
        self.as_mut().restore_folder_sort(&path_buf);
        self.as_mut().load_directory_async(path_buf.clone(), None);
        let crumbs_json = serde_json::to_string(&crumbs).unwrap_or_else(|_| "[]".to_string());
        self.as_mut().set_archive_path(QString::from(&archive));

        let can_back = !self.as_ref().history_stack.is_empty();
        let can_fwd = !self.as_ref().forward_stack.is_empty();

        self.as_mut().set_can_go_back(can_back);
        self.as_mut().set_can_go_forward(can_fwd);
        self.as_mut().set_is_searching_everywhere(false);
        self.as_mut().set_current_path(QString::from(&p));
        self.as_mut().set_current_dir_name(QString::from(&name));
        self.as_mut().set_breadcrumbs_json(QString::from(&crumbs_json));

        let freq = get_frequent_dirs();
        let freq_json = serde_json::to_string(&freq).unwrap_or_else(|_| "[]".to_string());
        self.as_mut().set_frequent_dirs_json(QString::from(&freq_json));
    }

    pub fn navigate_up(self: Pin<&mut Self>) {
        let cur = self.as_ref().current_path().to_string();
        if let Some((archive, member)) = crate::archive::parse(&cur) {
            let parent = if member.is_empty() {
                archive.parent().unwrap_or(Path::new("/")).to_string_lossy().to_string()
            } else {
                let member_parent = member.rsplit_once('/').map(|(parent, _)| parent).unwrap_or("");
                let root = crate::archive::root(&archive);
                if member_parent.is_empty() { root } else { format!("{root}/{member_parent}") }
            };
            self.set_path(&QString::from(&parent));
            return;
        }
        let path = Path::new(&cur);
        if let Some(parent) = path.parent() {
            let parent_str = parent.to_string_lossy().to_string();
            self.set_path(&QString::from(&parent_str));
        }
    }

    pub fn go_back(mut self: Pin<&mut Self>) {
        if let Some(prev) = self.as_mut().rust_mut().history_stack.pop() {
            let cur = self.as_ref().current_path().to_string();
            self.as_mut().rust_mut().forward_stack.push(cur);

            let path_buf = PathBuf::from(&prev);
            self.as_mut().restore_folder_sort(&path_buf);
            self.as_mut().load_directory_async(path_buf.clone(), None);

            let fwd_target = self.as_ref().forward_stack.last().cloned();
            let (name, crumbs, archive) = navigation_metadata(&prev, fwd_target.as_deref());
            self.as_mut().set_archive_path(QString::from(&archive));
            let crumbs_json = serde_json::to_string(&crumbs).unwrap_or_else(|_| "[]".to_string());

            let can_back = !self.as_ref().history_stack.is_empty();
            let can_fwd = !self.as_ref().forward_stack.is_empty();

            self.as_mut().set_can_go_back(can_back);
            self.as_mut().set_can_go_forward(can_fwd);
            self.as_mut().set_is_searching_everywhere(false);
            self.as_mut().set_current_path(QString::from(&prev));
            self.as_mut().set_current_dir_name(QString::from(&name));
            self.as_mut().set_breadcrumbs_json(QString::from(&crumbs_json));
        }
    }

    pub fn go_forward(mut self: Pin<&mut Self>) {
        if let Some(next) = self.as_mut().rust_mut().forward_stack.pop() {
            let cur = self.as_ref().current_path().to_string();
            self.as_mut().rust_mut().history_stack.push(cur);

            let path_buf = PathBuf::from(&next);
            self.as_mut().restore_folder_sort(&path_buf);
            self.as_mut().load_directory_async(path_buf.clone(), None);

            let fwd_target = self.as_ref().forward_stack.last().cloned();
            let (name, crumbs, archive) = navigation_metadata(&next, fwd_target.as_deref());
            self.as_mut().set_archive_path(QString::from(&archive));
            let crumbs_json = serde_json::to_string(&crumbs).unwrap_or_else(|_| "[]".to_string());

            let can_back = !self.as_ref().history_stack.is_empty();
            let can_fwd = !self.as_ref().forward_stack.is_empty();

            self.as_mut().set_can_go_back(can_back);
            self.as_mut().set_can_go_forward(can_fwd);
            self.as_mut().set_is_searching_everywhere(false);
            self.as_mut().set_current_path(QString::from(&next));
            self.as_mut().set_current_dir_name(QString::from(&name));
            self.as_mut().set_breadcrumbs_json(QString::from(&crumbs_json));
        }
    }

    pub fn refresh(self: Pin<&mut Self>) {
        let cur = self.as_ref().current_path().clone();
        self.set_path(&cur);
    }

    pub fn sync_shared_state(mut self: Pin<&mut Self>) {
        self.as_mut().refresh_clipboard_state();
        self.as_mut().sync_undo_flags();
    }

    pub fn toggle_show_hidden(mut self: Pin<&mut Self>) {
        let cur_val = *self.as_ref().show_hidden();
        self.as_mut().set_show_hidden(!cur_val);
        self.refresh();
    }

    pub fn toggle_disambiguate_duplicates(mut self: Pin<&mut Self>) {
        let cur_val = *self.as_ref().disambiguate_duplicates();
        self.as_mut().set_disambiguate_duplicates(!cur_val);
    }

    pub fn load_drives(mut self: Pin<&mut Self>) {
        let drives = read_system_drives();
        let json = serde_json::to_string(&drives).unwrap_or_else(|_| "[]".to_string());
        self.as_mut().set_drives_json(QString::from(&json));
    }

    pub fn refresh_frequent_dirs(mut self: Pin<&mut Self>) {
        let freq = get_frequent_dirs();
        let json = serde_json::to_string(&freq).unwrap_or_else(|_| "[]".to_string());
        self.as_mut().set_frequent_dirs_json(QString::from(&json));
    }

    pub fn load_trash(mut self: Pin<&mut Self>) {
        let trash = scan_trash_files();
        let json = serde_json::to_string(&trash).unwrap_or_else(|_| "[]".to_string());
        self.as_mut().set_trash_json(QString::from(&json));
    }

    pub fn empty_trash(mut self: Pin<&mut Self>) {
        let _ = std::process::Command::new("gio").args(["trash", "--empty"]).status();

        let (trash_files, trash_info) = trash_paths();

        if let Ok(entries) = fs::read_dir(&trash_files) {
            for entry in entries.flatten() {
                let _ = fs::remove_dir_all(entry.path()).or_else(|_| fs::remove_file(entry.path()));
            }
        }
        if let Ok(entries) = fs::read_dir(&trash_info) {
            for entry in entries.flatten() {
                let _ = fs::remove_file(entry.path());
            }
        }
        // Trash entries can no longer be restored, so the stack is stale.
        clear_stack(&UNDO_STACK);
        clear_stack(&REDO_STACK);

        self.as_mut().sync_undo_flags();
        self.as_mut().file_operation_finished();
        self.as_mut().load_trash();
        self.refresh();
    }

    /// Restores a single item from the trash by following its `.trashinfo` entry.
    pub fn restore_trash_item(mut self: Pin<&mut Self>, path: &QString) {
        let item_path = PathBuf::from(path.to_string());
        let Some(name) = item_path.file_name().and_then(|n| n.to_str()).map(|n| n.to_string()) else {
            return;
        };

        let (files_dir, info_dir) = trash_paths();
        let trashed = if item_path.is_absolute() { item_path.clone() } else { files_dir.join(&name) };
        let info_path = info_dir.join(format!("{}.trashinfo", name));

        let Ok(content) = fs::read_to_string(&info_path) else {
            eprintln!("seabunny: no trash metadata for {}", name);
            return;
        };
        let Some(original) = parse_trashinfo_path(&content) else {
            eprintln!("seabunny: malformed trash metadata for {}", name);
            return;
        };

        let target = PathBuf::from(&original);
        if let Some(parent) = target.parent() {
            let _ = fs::create_dir_all(parent);
        }

        let restored = fs::rename(&trashed, &target).is_ok();
        if restored || copy_recursive(&trashed, &target) {
            if !restored {
                let _ = remove_path(&trashed);
            }
            let _ = fs::remove_file(&info_path);
        } else {
            eprintln!("seabunny: could not restore {} to {}", name, original);
        }

        self.as_mut().load_trash();
        self.as_mut().file_operation_finished();
        self.refresh();
    }

    pub fn search_everywhere(mut self: Pin<&mut Self>, query: &QString) {
        if !self.as_ref().archive_path().is_empty() {
            self.as_mut().set_navigation_error(QString::from("Search filters the current archive folder; filesystem-wide search is unavailable here"));
            return;
        }
        let q = query.to_string();
        if q.trim().is_empty() {
            self.as_mut().clear_search_everywhere();
            return;
        }

        let disambiguate = *self.as_ref().disambiguate_duplicates();
        self.as_mut().set_is_searching_everywhere(true);
        self.as_mut().set_search_everywhere_json(QString::from("[]"));
        let path = PathBuf::from(self.as_ref().current_path().to_string());
        self.as_mut().load_directory_async(path, Some((q, disambiguate)));
    }

    pub fn clear_search_everywhere(mut self: Pin<&mut Self>) {
        if *self.as_ref().is_searching_everywhere() {
            self.as_ref().scan_generation.fetch_add(1, Ordering::Relaxed);
            self.as_mut().set_is_loading(false);
        }
        self.as_mut().set_is_searching_everywhere(false);
        self.as_mut().set_search_everywhere_json(QString::from("[]"));
    }

    pub fn resolve_icon(&self, name: &QString) -> QString {
        let n = name.to_string();
        let path = resolve_system_icon(&n);
        QString::from(&path)
    }

    pub fn get_thumbnail(&self, path: &QString) -> QString {
        let path_str = path.to_string();
        QString::from(&resolve_thumbnail_path(Path::new(&path_str)))
    }

    pub fn place_path(&self, place: &QString) -> QString {
        let home = std::env::var("HOME").unwrap_or_default();
        QString::from(&user_directory(&place.to_string(), &home,
            &std::env::var("XDG_CONFIG_HOME").unwrap_or_else(|_| format!("{}/.config", home))))
    }

    pub fn favorites_json(&self) -> QString {
        match crate::favorites::load(&config_file_path().with_file_name("favorites.json")) {
            Ok(items) => QString::from(&serde_json::to_string(&items).unwrap()),
            Err(err) => { eprintln!("seabunny: {err}"); QString::from("[]") }
        }
    }

    pub fn update_favorite(mut self: Pin<&mut Self>, path: &QString, label: &QString, remove: bool) -> bool {
        let label = label.to_string();
        match crate::favorites::update(&config_file_path().with_file_name("favorites.json"), &path.to_string(), if remove { None } else { Some(&label) }) {
            Ok(()) => { self.as_mut().set_navigation_error(QString::from("")); true }
            Err(err) => { self.as_mut().set_navigation_error(QString::from(&err)); false }
        }
    }

    pub fn thumbnail_stats(&self) -> QString { qobject::thumbnail_statistics() }

    pub fn open_with_apps(&self, paths: &QString) -> QString { qobject::seabunny_open_with_apps(paths) }

    pub fn open_with(self: Pin<&mut Self>, paths: &QString, desktop_id: &QString, make_default: bool) -> QString {
        if qobject::seabunny_portal_mode() { return QString::from("Applications cannot be launched from the file picker."); }
        qobject::seabunny_open_with(paths, desktop_id, make_default)
    }

    pub fn open_item(mut self: Pin<&mut Self>, path: &QString) {
        let value = path.to_string();
        if let Some((archive, member)) = crate::archive::parse(&value) {
            let cache = std::env::var("XDG_CACHE_HOME").map(PathBuf::from).unwrap_or_else(|_| PathBuf::from(std::env::var("HOME").unwrap_or_default()).join(".cache")).join("seabunny/archive-open");
            if fs::symlink_metadata(&cache).map(|meta| meta.file_type().is_symlink()).unwrap_or(false) || fs::create_dir_all(&cache).is_err() {
                self.as_mut().set_navigation_error(QString::from("Cannot create a safe archive preview cache"));
                return;
            }
            self.start_archive_job(serde_json::json!({"action": "open", "archive": archive, "selection": [member], "destination": cache}));
        } else if value.starts_with(crate::archive::PREFIX) {
            self.as_mut().set_navigation_error(QString::from("Invalid archive location"));
        } else if crate::archive::supported(Path::new(&value)) && Path::new(&value).is_file() {
            self.set_path(path);
        } else {
            let error = qobject::seabunny_open_file(path);
            self.as_mut().set_navigation_error(error);
        }
    }

    pub fn open_terminal(&self, dir_path: &QString) {
        if dir_path.to_string().starts_with(crate::archive::PREFIX) { return; }
        let dir = dir_path.to_string();
        if Path::new("/etc/profiles/per-user/m_uvex/bin/kitty").exists() {
            let _ = std::process::Command::new("kitty").arg("--directory").arg(&dir).spawn();
        } else if Path::new("/etc/profiles/per-user/m_uvex/bin/foot").exists() {
            let _ = std::process::Command::new("foot").arg("-D").arg(&dir).spawn();
        } else {
            let _ = std::process::Command::new("xdg-terminal-exec").current_dir(&dir).spawn();
        }
    }

    pub fn create_folder(mut self: Pin<&mut Self>, dir: &QString, name: &QString) {
        if self.as_mut().reject_archive_write(&dir.to_string()) { return; }
        let target = Path::new(&dir.to_string()).join(name.to_string());
        if fs::create_dir_all(&target).is_ok() {
            self.as_mut().record_undo(UndoAction::Create {
                path: target.to_string_lossy().to_string(),
                is_dir: true,
            });
        }
        self.as_mut().file_operation_finished();
        self.refresh();
    }

    pub fn create_file(mut self: Pin<&mut Self>, dir: &QString, name: &QString) {
        if self.as_mut().reject_archive_write(&dir.to_string()) { return; }
        let target = Path::new(&dir.to_string()).join(name.to_string());
        if fs::File::create(&target).is_ok() {
            self.as_mut().record_undo(UndoAction::Create {
                path: target.to_string_lossy().to_string(),
                is_dir: false,
            });
        }
        self.as_mut().file_operation_finished();
        self.refresh();
    }

    pub fn rename_item(mut self: Pin<&mut Self>, dir: &QString, old_name: &QString, new_name: &QString) {
        if self.as_mut().reject_archive_write(&dir.to_string()) { return; }
        let dir_str = dir.to_string();
        let base = Path::new(&dir_str);
        let src = base.join(old_name.to_string());
        let dst = base.join(new_name.to_string());
        if fs::rename(&src, &dst).is_ok() {
            self.as_mut().record_undo(UndoAction::Rename {
                dir: dir_str,
                old_name: old_name.to_string(),
                new_name: new_name.to_string(),
            });
        }
        self.as_mut().file_operation_finished();
        self.refresh();
    }

    pub fn trash_items(mut self: Pin<&mut Self>, paths_json: &QString) {
        if self.as_mut().reject_archive_sources(paths_json) { return; }
        if let Ok(paths) = serde_json::from_str::<Vec<String>>(&paths_json.to_string()) {
            let mut items = Vec::new();
            for p in paths {
                let path = Path::new(&p);
                if let Some(item) = trash_into_home_trash(path) {
                    items.push(item);
                } else if let Some(item) = trash_via_cli(path) {
                    items.push(item);
                } else {
                    eprintln!("seabunny: could not move {} to trash", p);
                }
            }
            if !items.is_empty() {
                self.as_mut().record_undo(UndoAction::Trash { items });
            }
        }
        self.as_mut().load_trash();
        self.as_mut().file_operation_finished();
        self.refresh();
    }

    pub fn copy_items(mut self: Pin<&mut Self>, paths_json: &QString, is_cut: bool) {
        let archive_source = serde_json::from_str::<Vec<String>>(&paths_json.to_string()).unwrap_or_default().iter().any(|path| path.starts_with(crate::archive::PREFIX));
        let is_cut = is_cut && !archive_source;
        if let Ok(paths) = serde_json::from_str::<Vec<String>>(&paths_json.to_string()) {
            let mut clip = CLIPBOARD.lock().unwrap();
            *clip = (paths.clone(), is_cut);
            let has = !clip.0.is_empty();
            self.as_mut().set_has_clipboard(has);
            if is_cut {
                self.as_mut().set_clipboard_cut_paths_json(paths_json.clone());
            } else {
                self.as_mut().set_clipboard_cut_paths_json(QString::from("[]"));
            }
        }
    }

    pub fn paste_items(self: Pin<&mut Self>, dest_dir: &QString) {
        self.paste_items_resolved(dest_dir, &QString::from("overwrite"));
    }

    pub fn drop_items(self: Pin<&mut Self>, paths_json: &QString, dest_dir: &QString, as_copy: bool) {
        self.drop_items_resolved(paths_json, dest_dir, as_copy, &QString::from("overwrite"));
    }

    fn restore_folder_sort(mut self: Pin<&mut Self>, path: &Path) {
        if path.to_string_lossy().starts_with(crate::archive::PREFIX) { return; }
        let sort = crate::folder_sort::get(&crate::folder_sort::state_file(), path);
        self.as_mut().set_sort_by(QString::from(&sort.field));
        self.as_mut().set_sort_ascending(sort.ascending);
        self.as_mut().set_dirs_first(sort.folders != "mixed");
        self.as_mut().set_folder_position(QString::from(&sort.folders));
    }

    fn remember_folder_sort(mut self: Pin<&mut Self>) {
        let sort = crate::folder_sort::Sort {
            field: self.as_ref().sort_by().to_string(),
            ascending: *self.as_ref().sort_ascending(),
            folders: self.as_ref().folder_position().to_string(),
        };
        let path = PathBuf::from(self.as_ref().current_path().to_string());
        if let Err(error) = crate::folder_sort::save(&crate::folder_sort::state_file(), &path, sort) {
            self.as_mut().set_navigation_error(QString::from(&format!("Could not remember folder sorting: {error}")));
        }
    }

    pub fn change_folder_position(mut self: Pin<&mut Self>, position: &QString) {
        if !["first", "last", "mixed"].contains(&position.to_string().as_str()) { return; }
        self.as_mut().set_folder_position(position.clone());
        let pos_str = position.to_string();
        self.as_mut().set_dirs_first(pos_str != "mixed");
        let path = PathBuf::from(self.as_ref().current_path().to_string());
        self.as_mut().set_is_searching_everywhere(false);
        self.as_mut().load_directory_async(path, None);
        self.remember_folder_sort();
    }

    pub fn set_sort(mut self: Pin<&mut Self>, sort_by: &QString, ascending: bool) {
        if !["name", "modified", "size", "type"].contains(&sort_by.to_string().as_str()) { return; }
        self.as_mut().set_sort_by(sort_by.clone());
        self.as_mut().set_sort_ascending(ascending);
        let path = PathBuf::from(self.as_ref().current_path().to_string());
        self.as_mut().set_is_searching_everywhere(false);
        self.as_mut().load_directory_async(path, None);
        self.remember_folder_sort();
    }

    pub fn toggle_sort_order(mut self: Pin<&mut Self>) {
        let cur = *self.as_ref().sort_ascending();
        self.as_mut().set_sort_ascending(!cur);
        let path = PathBuf::from(self.as_ref().current_path().to_string());
        self.as_mut().set_is_searching_everywhere(false);
        self.as_mut().load_directory_async(path, None);
        self.remember_folder_sort();
    }

    pub fn toggle_view_mode(mut self: Pin<&mut Self>) {
        let cur = self.as_ref().view_mode().to_string();
        let next = if cur == "list" { "grid" } else { "list" };
        self.as_mut().set_view_mode(QString::from(next));
    }

    pub fn check_paste_conflicts(&self, paths_json: &QString, dest_dir: &QString) -> QString {
        let dest = PathBuf::from(dest_dir.to_string());
        let Ok(paths) = serde_json::from_str::<Vec<String>>(&paths_json.to_string()) else {
            return QString::from("[]");
        };

        if paths.iter().any(|path| path.starts_with(crate::archive::PREFIX)) { return QString::from("[]"); }
        let mut conflicts = Vec::new();
        for p_str in paths {
            let src = PathBuf::from(&p_str);
            // Self-drop guard: if destination is the same directory as source parent, ignore it!
            if let Some(src_parent) = src.parent() {
                if src_parent == dest {
                    continue;
                }
            }
            let Some(file_name) = src.file_name() else { continue };
            let target = dest.join(file_name);
            if entry_exists(&target) {
                let name = file_name.to_string_lossy().to_string();
                let is_dir = target.is_dir();
                let src_size = src.metadata().map(|m| format_size(m.len())).unwrap_or_else(|_| "-".to_string());
                let dest_size = target.metadata().map(|m| format_size(m.len())).unwrap_or_else(|_| "-".to_string());
                conflicts.push(ConflictItem {
                    name,
                    src_path: p_str,
                    dest_path: target.to_string_lossy().to_string(),
                    src_size,
                    dest_size,
                    is_dir,
                    can_merge: real_directory(&src) && real_directory(&target),
                });
            }
        }

        QString::from(&serde_json::to_string(&conflicts).unwrap_or_else(|_| "[]".to_string()))
    }

    pub fn check_clipboard_conflicts(&self, dest_dir: &QString) -> QString {
        let clip = CLIPBOARD.lock().unwrap();
        let paths_json = serde_json::to_string(&clip.0).unwrap_or_else(|_| "[]".to_string());
        drop(clip);
        self.check_paste_conflicts(&QString::from(&paths_json), dest_dir)
    }

    pub fn check_merge_conflicts(&self, paths_json: &QString, dest_dir: &QString) -> QString {
        let paths = serde_json::from_str::<Vec<String>>(&paths_json.to_string()).unwrap_or_default();
        let dest = PathBuf::from(dest_dir.to_string());
        let mut conflicts = Vec::new();
        for path in paths {
            let src = PathBuf::from(path);
            let Some(name) = src.file_name() else { continue };
            if let Err(error) = collect_merge_conflicts(&src, &dest.join(name), src.parent().unwrap_or(&src), &mut conflicts) {
                return QString::from(&serde_json::json!({"error": error}).to_string());
            }
        }
        QString::from(&serde_json::json!({"conflicts": conflicts}).to_string())
    }

    pub fn check_clipboard_merge_conflicts(&self, dest_dir: &QString) -> QString {
        let paths = CLIPBOARD.lock().unwrap().0.clone();
        self.check_merge_conflicts(&QString::from(&serde_json::to_string(&paths).unwrap_or_else(|_| "[]".into())), dest_dir)
    }

    pub fn paste_items_resolved(mut self: Pin<&mut Self>, dest_dir: &QString, resolution: &QString) {
        if self.as_mut().reject_archive_write(&dest_dir.to_string()) { return; }
        let dest = PathBuf::from(dest_dir.to_string());
        let (files, is_cut) = {
            let clip = CLIPBOARD.lock().unwrap();
            (clip.0.clone(), clip.1)
        };
        if self.as_mut().copy_archive_paths(&files, &dest_dir.to_string()) { return; }
        let (res, merge_choices) = merge_resolution(&resolution.to_string());

        let mut move_pairs: Vec<(String, String)> = Vec::new();
        let mut copy_pairs: Vec<(String, String)> = Vec::new();
        let mut merged_actions = Vec::new();
        let mut merge_errors = Vec::new();
        let mut completed_cuts = Vec::new();

        for src_str in &files {
            let src = PathBuf::from(src_str);
            let Some(file_name) = src.file_name().and_then(|n| n.to_str()) else { continue };
            let original_target = dest.join(file_name);
            if res == "merge" && real_directory(&src) && real_directory(&original_target) {
                match merge_folders(&src, &original_target, is_cut, &merge_choices, &mut merged_actions) {
                    Ok(()) => { if is_cut && !entry_exists(&src) { completed_cuts.push(src_str.clone()); } }
                    Err(error) => merge_errors.push(error),
                }
                continue;
            }
            let target = if res == "merge" && entry_exists(&original_target) {
                match resolve_merge_collision(&src, &original_target, &merge_choices, &mut merged_actions) {
                    Ok(Some(target)) => target,
                    Ok(None) => continue,
                    Err(error) => { merge_errors.push(error); continue; }
                }
            } else if res == "rename" {
                get_unique_name(&dest, file_name)
            } else {
                dest.join(file_name)
            };

            if res == "skip" && dest.join(file_name).exists() {
                continue;
            }
            if target == src {
                continue;
            }
            if res == "merge" {
                let overlaps = real_directory(&src) && fs::canonicalize(&src).ok().zip(fs::canonicalize(&dest).ok())
                    .is_some_and(|(source, destination)| destination.starts_with(source));
                if overlaps { merge_errors.push("Cannot paste a folder into itself or its subfolders.".into()); continue; }
                match transfer_merge_entry(&src, &target, is_cut, &mut merged_actions) {
                    Ok(()) => { if is_cut { completed_cuts.push(src_str.clone()); } }
                    Err(error) => merge_errors.push(error),
                }
                continue;
            }
            // Overwriting an existing entry cannot be reversed, so skip undo for it.
            let undoable = res == "rename" || !target.exists();

            let ok = if is_cut {
                let mut moved_ok = fs::rename(&src, &target).is_ok();
                if !moved_ok && copy_recursive(&src, &target) {
                    let _ = remove_path(&src);
                    moved_ok = true;
                }
                moved_ok
            } else {
                copy_recursive(&src, &target)
            };

            if !ok {
                continue;
            }
            let target_str = target.to_string_lossy().to_string();
            if is_cut {
                completed_cuts.push(src_str.clone());
                if undoable {
                    move_pairs.push((src_str.clone(), target_str));
                }
            } else if undoable {
                copy_pairs.push((src_str.clone(), target_str));
            }
        }

        if is_cut {
            let remaining = if let Ok(mut clip) = CLIPBOARD.lock() {
                clip.0.retain(|path| !completed_cuts.contains(path));
                clip.1 = !clip.0.is_empty();
                clip.0.clone()
            } else { files.clone() };
            self.as_mut().set_clipboard_cut_paths_json(QString::from(&serde_json::to_string(&remaining).unwrap_or_else(|_| "[]".into())));
            self.as_mut().set_has_clipboard(!remaining.is_empty());
        }

        if !merged_actions.is_empty() {
            if !move_pairs.is_empty() { merged_actions.push(UndoAction::Move { pairs: move_pairs }); }
            if !copy_pairs.is_empty() { merged_actions.push(UndoAction::Copy { pairs: copy_pairs }); }
            self.as_mut().record_undo(UndoAction::Merge { actions: merged_actions });
        } else if !move_pairs.is_empty() {
            self.as_mut().record_undo(UndoAction::Move { pairs: move_pairs });
        } else if !copy_pairs.is_empty() {
            self.as_mut().record_undo(UndoAction::Copy { pairs: copy_pairs });
        }

        self.as_mut().file_operation_finished();
        self.as_mut().refresh();
        self.set_navigation_error(QString::from(&merge_errors.join("\n")));
    }

    pub fn drop_items_resolved(mut self: Pin<&mut Self>, paths_json: &QString, dest_dir: &QString, as_copy: bool, resolution: &QString) {
        let paths = serde_json::from_str::<Vec<String>>(&paths_json.to_string()).unwrap_or_default();
        if self.as_mut().copy_archive_paths(&paths, &dest_dir.to_string()) { return; }
        if self.as_mut().reject_archive_write(&dest_dir.to_string()) { return; }
        let dest = PathBuf::from(dest_dir.to_string());
        if !dest.is_dir() { return; }
        let Ok(canonical_dest) = fs::canonicalize(&dest) else { return; };
        let (res, merge_choices) = merge_resolution(&resolution.to_string());

        let mut move_pairs: Vec<(String, String)> = Vec::new();
        let mut copy_pairs: Vec<(String, String)> = Vec::new();
        let mut merged_actions = Vec::new();
        let mut merge_errors = Vec::new();

        if let Ok(paths) = serde_json::from_str::<Vec<String>>(&paths_json.to_string()) {
            for src_str in paths {
                let src = PathBuf::from(&src_str);
                let Ok(canonical_src) = fs::canonicalize(&src) else { continue; };
                if canonical_src == canonical_dest || (src.is_dir() && canonical_dest.starts_with(&canonical_src)) { continue; }
                if !as_copy && src.parent().and_then(|parent| fs::canonicalize(parent).ok()).as_ref() == Some(&canonical_dest) { continue; }
                if src.is_dir() && dest.starts_with(&src) { continue; }
                if src == dest { continue; }
                if !as_copy {
                    if let Some(src_parent) = src.parent() {
                        if src_parent == dest {
                            continue; // Self-drop canceled
                        }
                    }
                }

                let Some(file_name) = src.file_name().and_then(|n| n.to_str()) else { continue };
                let original_target = dest.join(file_name);
                if res == "merge" && real_directory(&src) && real_directory(&original_target) {
                    if let Err(error) = merge_folders(&src, &original_target, !as_copy, &merge_choices, &mut merged_actions) { merge_errors.push(error); }
                    continue;
                }
                let target = if res == "merge" && entry_exists(&original_target) {
                    match resolve_merge_collision(&src, &original_target, &merge_choices, &mut merged_actions) {
                        Ok(Some(target)) => target,
                        Ok(None) => continue,
                        Err(error) => { merge_errors.push(error); continue; }
                    }
                } else if res == "rename" {
                    get_unique_name(&dest, file_name)
                } else {
                    dest.join(file_name)
                };

                if res == "skip" && dest.join(file_name).exists() {
                    continue;
                }
                if res == "merge" {
                    if let Err(error) = transfer_merge_entry(&src, &target, !as_copy, &mut merged_actions) { merge_errors.push(error); }
                    continue;
                }
                let undoable = res == "rename" || !target.exists();

                let ok = if as_copy {
                    copy_recursive(&src, &target)
                } else {
                    let mut moved_ok = fs::rename(&src, &target).is_ok();
                    if !moved_ok && copy_recursive(&src, &target) {
                        let _ = remove_path(&src);
                        moved_ok = true;
                    }
                    moved_ok
                };

                if !ok {
                    continue;
                }
                let target_str = target.to_string_lossy().to_string();
                if as_copy {
                    if undoable {
                        copy_pairs.push((src_str.clone(), target_str));
                    }
                } else if undoable {
                    move_pairs.push((src_str.clone(), target_str));
                }
            }
        }

        if !merged_actions.is_empty() {
            if !move_pairs.is_empty() { merged_actions.push(UndoAction::Move { pairs: move_pairs }); }
            if !copy_pairs.is_empty() { merged_actions.push(UndoAction::Copy { pairs: copy_pairs }); }
            self.as_mut().record_undo(UndoAction::Merge { actions: merged_actions });
        } else if !move_pairs.is_empty() {
            self.as_mut().record_undo(UndoAction::Move { pairs: move_pairs });
        } else if !copy_pairs.is_empty() {
            self.as_mut().record_undo(UndoAction::Copy { pairs: copy_pairs });
        }

        self.as_mut().file_operation_finished();
        self.as_mut().refresh();
        self.set_navigation_error(QString::from(&merge_errors.join("\n")));
    }

    pub fn create_symlinks(mut self: Pin<&mut Self>, paths_json: &QString, dest_dir: &QString) {
        if self.as_mut().reject_archive_sources(paths_json) { return; }
        if self.as_mut().reject_archive_write(&dest_dir.to_string()) { return; }
        let dest = PathBuf::from(dest_dir.to_string());
        if !dest.is_dir() { return; }
        if let Ok(paths) = serde_json::from_str::<Vec<String>>(&paths_json.to_string()) {
            for p_str in paths {
                let src = PathBuf::from(&p_str);
                let Some(name) = src.file_name().and_then(|n| n.to_str()) else { continue };
                let target = get_unique_name(&dest, name);
                #[cfg(unix)]
                let _ = std::os::unix::fs::symlink(&src, &target);
            }
        }
        self.as_mut().file_operation_finished();
        self.refresh();
    }

    pub fn compress_items_with_options(mut self: Pin<&mut Self>, paths_json: &QString, format: &QString, password: &QString) {
        if self.as_mut().reject_archive_sources(paths_json) { return; }
        let Ok(paths) = serde_json::from_str::<Vec<String>>(&paths_json.to_string()) else {
            eprintln!("seabunny: compress: invalid paths payload");
            return;
        };
        if paths.is_empty() {
            return;
        }

        let fmt = format.to_string();
        let pass = password.to_string();
        let first_p = PathBuf::from(&paths[0]);
        let parent_dir = first_p.parent().unwrap_or(Path::new(".")).to_path_buf();

        let base_name = if paths.len() == 1 {
            archive_base_name(&first_p)
        } else {
            "Archive".to_string()
        };

        let archive_ext = match fmt.as_str() {
            "zip" | "zip_encrypted" => "zip",
            "7z" => "7z",
            "tar.gz" => "tar.gz",
            "tar.xz" => "tar.xz",
            "tar.zst" => "tar.zst",
            "tar.bz2" => "tar.bz2",
            "cpio" => "cpio",
            _ => "zip",
        };
        let archive_filename = format!("{}.{}", base_name, archive_ext);
        let archive_target = get_unique_name(&parent_dir, &archive_filename);

        // Names stored inside the archive are relative to the archive's directory.
        let relative_names: Vec<String> = paths.iter().map(|p| relative_name(p, &parent_dir)).collect();

        let created = match fmt.as_str() {
            "7z" => compress_with_7z(&archive_target, &relative_names, &pass, &parent_dir),
            "zip_encrypted" => compress_zip_encrypted(&archive_target, &relative_names, &pass, &parent_dir),
            "zip" if !pass.is_empty() => compress_zip_encrypted(&archive_target, &relative_names, &pass, &parent_dir),
            "zip" => compress_zip(&archive_target, &relative_names, &parent_dir),
            "tar.gz" => compress_tar(&archive_target, &relative_names, &parent_dir, "z"),
            "tar.xz" => compress_tar(&archive_target, &relative_names, &parent_dir, "J"),
            "tar.bz2" => compress_tar(&archive_target, &relative_names, &parent_dir, "j"),
            "tar.zst" => compress_tar_zstd(&archive_target, &relative_names, &parent_dir),
            "cpio" => compress_cpio(&archive_target, &relative_names, &parent_dir),
            other => {
                eprintln!("seabunny: unsupported archive format '{}'", other);
                false
            }
        };

        if !created {
            // Leave no half-written archive behind.
            if archive_target.exists() && archive_target.metadata().map(|m| m.len() == 0).unwrap_or(false) {
                let _ = fs::remove_file(&archive_target);
            }
            eprintln!("seabunny: failed to create {}", archive_target.display());
        }

        self.as_mut().file_operation_finished();
        self.refresh();
    }

    pub fn compress_items(self: Pin<&mut Self>, paths_json: &QString, format: &QString) {
        self.compress_items_with_options(paths_json, format, &QString::from(""));
    }

    pub fn extract_archive(mut self: Pin<&mut Self>, archive_path: &QString, into_subfolder: bool) {
        let archive = PathBuf::from(archive_path.to_string());
        if !archive.is_file() || !crate::archive::supported(&archive) {
            self.as_mut().set_navigation_error(QString::from("Unsupported or unavailable archive"));
            return;
        }
        let destination = archive.parent().unwrap_or(Path::new(".")).to_path_buf();
        self.start_archive_job(serde_json::json!({"action": if into_subfolder { "extract" } else { "copy" },
            "archive": archive, "selection": [], "destination": destination}));
    }

    pub fn is_archive_file(&self, path: &QString) -> bool {
        is_archive_path(Path::new(&path.to_string()))
    }

    pub fn get_item_info(&self, path: &QString) -> QString {
        let p = PathBuf::from(path.to_string());
        let name = p.file_name().and_then(|n| n.to_str()).unwrap_or("").to_string();
        let is_dir = p.is_dir();

        let (size_str, mod_str) = if let Ok(meta) = p.metadata() {
            let s = if is_dir { "Folder".to_string() } else { format_size(meta.len()) };
            let m = meta.modified().ok()
                .and_then(|t| t.elapsed().ok())
                .map(|e| {
                    let secs = e.as_secs();
                    if secs < 60 { "Just now".to_string() }
                    else if secs < 3600 { format!("{} min ago", secs / 60) }
                    else if secs < 86400 { format!("{} hrs ago", secs / 3600) }
                    else { format!("{} days ago", secs / 86400) }
                })
                .unwrap_or_else(|| "-".to_string());
            (s, m)
        } else {
            ("-".to_string(), "-".to_string())
        };

        let info = ItemInfo {
            name,
            path: p.to_string_lossy().to_string(),
            size: size_str,
            is_dir,
            modified: mod_str,
            icon: icon_for_file(&p, is_dir).0.into(),
            icon_path: resolve_system_icon(system_icon_for_file(&p, is_dir)),
            permissions: crate::permissions::inspect(&p).ok(),
        };

        serde_json::to_string(&info).unwrap_or_else(|_| "{}".to_string()).into()
    }

    pub fn set_item_permissions(mut self: Pin<&mut Self>, path: &QString, identity: &QString, expected_mode: u32, mode: u32) -> QString {
        let result = if !self.archive_path().to_string().is_empty() || qobject::seabunny_portal_mode() {
            Err("Permissions cannot be changed in this view.".into())
        } else {
            crate::permissions::apply(Path::new(&path.to_string()), &identity.to_string(), expected_mode, mode)
        };
        if let Err(error) = result {
            return serde_json::json!({"error": error}).to_string().into();
        }
        self.as_mut().file_operation_finished();
        self.as_mut().refresh();
        self.get_item_info(path)
    }

    pub fn undo(mut self: Pin<&mut Self>) {
        let action = {
            let mut guard = UNDO_STACK.lock().unwrap();
            let stack = guard.get_or_insert_with(Vec::new);
            stack.pop()
        };

        let Some(act) = action else { return };
        let redo_entry = apply_inverse(&act);

        if let Some(entry) = redo_entry {
            let mut guard = REDO_STACK.lock().unwrap();
            guard.get_or_insert_with(Vec::new).push(entry);
        }

        // The view may need to be reloaded either way: a partially applied action
        // still changed the filesystem.
        self.as_mut().sync_undo_flags();
        self.as_mut().refresh_clipboard_state();
        self.as_mut().load_trash();
        self.as_mut().file_operation_finished();
        self.refresh();
    }

    pub fn redo(mut self: Pin<&mut Self>) {
        let action = {
            let mut guard = REDO_STACK.lock().unwrap();
            let stack = guard.get_or_insert_with(Vec::new);
            stack.pop()
        };

        let Some(act) = action else { return };
        let undo_entry = apply_action(&act);

        if let Some(entry) = undo_entry {
            let mut guard = UNDO_STACK.lock().unwrap();
            guard.get_or_insert_with(Vec::new).push(entry);
        }

        self.as_mut().sync_undo_flags();
        self.as_mut().refresh_clipboard_state();
        self.as_mut().load_trash();
        self.as_mut().file_operation_finished();
        self.refresh();
    }

    /// Re-detects the system color scheme and republishes `is_dark`.
    pub fn refresh_system_theme(mut self: Pin<&mut Self>) {
        let dark = detect_system_dark_mode();
        self.as_mut().set_is_dark(dark);
    }

    pub fn get_setting(&self, key: &QString) -> QString {
        let k = key.to_string();
        let value = load_settings().get(&k).cloned().unwrap_or_default();
        QString::from(&value)
    }

    pub fn sidebar_state(&self, chooser: bool) -> QString {
        qobject::seabunny_sidebar_state(chooser)
    }

    pub fn save_sidebar_state(&self, chooser: bool, expanded: bool, width: f64) -> bool {
        qobject::seabunny_save_sidebar_state(chooser, expanded, width)
    }

    pub fn set_setting(self: Pin<&mut Self>, key: &QString, value: &QString) {
        let k = key.to_string();
        let v = value.to_string();
        let mut map = load_settings();
        if map.get(&k).map(|existing| existing == &v).unwrap_or(false) {
            return;
        }
        map.insert(k, v);
        save_settings(&map);
        *SETTINGS_STORE.lock().unwrap() = Some(map);
    }

    pub fn mount_drive(mut self: Pin<&mut Self>, device: &QString) {
        let dev = device.to_string();
        let _ = std::process::Command::new("udisksctl")
            .args(["mount", "-b", &dev])
            .status();
        self.as_mut().load_drives();
    }

    pub fn unmount_drive(mut self: Pin<&mut Self>, device: &QString) {
        let dev = device.to_string();
        let _ = std::process::Command::new("udisksctl")
            .args(["unmount", "-b", &dev])
            .status();
        self.as_mut().load_drives();
    }

    pub fn rename_drive(mut self: Pin<&mut Self>, device: &QString, new_name: &QString) {
        let dev = device.to_string();
        let name = new_name.to_string();
        let _ = std::process::Command::new("e2label").args([&dev, &name]).status()
            .or_else(|_| std::process::Command::new("fatlabel").args([&dev, &name]).status())
            .or_else(|_| std::process::Command::new("exfatlabel").args([&dev, &name]).status());
        self.as_mut().load_drives();
    }

    pub fn reload_wallpaper_colors(mut self: Pin<&mut Self>) -> bool {
        // Always re-read the wallpaper color source from disk: matugen/pywal may
        // have rewritten it since the last check.
        let Some((_source, content, _mtime)) = read_wallpaper_colors_source() else {
            // Nothing readable yet: keep the colors we already have.
            return false;
        };

        if content == self.as_ref().wallpaper_colors_json().to_string() {
            return false;
        }

        self.as_mut().set_wallpaper_colors_json(QString::from(&content));
        true
    }
}
