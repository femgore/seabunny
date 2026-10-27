//! `SeabunnyCore`: the single application-wide object. It owns everything that
//! is not tied to one file view: file operations (with progress, cancel and
//! undo), drives, sidebar places, Open With, previews, settings and theme.
//!
//! Long work runs on worker threads and reports back through
//! `qt_thread().queue(..)`; nothing here blocks the UI thread on disk or
//! external programs except trivially quick calls.

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(bool, is_dark)]
        #[qproperty(QString, wallpaper_colors_json)]
        #[qproperty(QString, hostname)]
        #[qproperty(QString, device_type)]
        #[qproperty(QString, icon_theme)]
        #[qproperty(QString, drives_json)]
        #[qproperty(QString, frequent_dirs_json)]
        #[qproperty(QString, places_json)]
        #[qproperty(QString, smb_profiles_json)]
        #[qproperty(QString, operations_json)]
        #[qproperty(bool, busy)]
        #[qproperty(bool, can_undo)]
        #[qproperty(bool, can_redo)]
        #[qproperty(QString, undo_text)]
        #[qproperty(QString, redo_text)]
        #[qproperty(bool, trash_empty)]
        #[qproperty(bool, cloudflared_ready)]
        /// Little RAM or few CPU cores: low-power mode's "Auto" turns on.
        #[qproperty(bool, low_end_hardware)]
        type SeabunnyCore = super::CoreRust;
    }

    unsafe extern "RustQt" {
        /// kind: "info" | "error" | "undo" (offers an Undo button).
        #[qsignal]
        fn notify(self: Pin<&mut SeabunnyCore>, kind: QString, text: QString);
        #[qsignal]
        fn operation_finished(self: Pin<&mut SeabunnyCore>, kind: QString, ok: bool, result_json: QString);
        /// An archive or encrypted drive needs a password: {kind, ...}.
        #[qsignal]
        fn password_required(self: Pin<&mut SeabunnyCore>, request_json: QString);
        #[qsignal]
        fn dir_size_ready(self: Pin<&mut SeabunnyCore>, key: QString, info_json: QString);
        #[qsignal]
        fn starred_changed(self: Pin<&mut SeabunnyCore>);
        #[qsignal]
        fn smb_mounted(self: Pin<&mut SeabunnyCore>, profile_id: QString, path: QString);
        #[qsignal]
        fn share_link_ready(self: Pin<&mut SeabunnyCore>, share_id: QString, url: QString);
        #[qsignal]
        fn share_link_error(self: Pin<&mut SeabunnyCore>, message: QString);
        #[qsignal]
        fn cloudflared_status_changed(self: Pin<&mut SeabunnyCore>, installed: bool);
    }

    unsafe extern "RustQt" {
        #[qinvokable]
        fn get_setting(self: &SeabunnyCore, key: &QString) -> QString;
        #[qinvokable]
        fn set_setting(self: Pin<&mut SeabunnyCore>, key: &QString, value: &QString);
        #[qinvokable]
        fn refresh_system_theme(self: Pin<&mut SeabunnyCore>);
        #[qinvokable]
        fn reload_wallpaper_colors(self: Pin<&mut SeabunnyCore>) -> bool;
        #[qinvokable]
        fn resolve_icon(self: &SeabunnyCore, theme: &QString, name: &QString) -> QString;
        #[qinvokable]
        fn load_places(self: Pin<&mut SeabunnyCore>);
        #[qinvokable]
        fn all_places_json(self: &SeabunnyCore) -> QString;
        #[qinvokable]
        fn add_bookmark(self: Pin<&mut SeabunnyCore>, path: &QString);
        #[qinvokable]
        fn remove_bookmark(self: Pin<&mut SeabunnyCore>, path: &QString);
        #[qinvokable]
        fn rename_bookmark(self: Pin<&mut SeabunnyCore>, path: &QString, label: &QString);
        #[qinvokable]
        fn create_symlink(self: &SeabunnyCore, target: &QString, link_path: &QString) -> bool;
        #[qinvokable]
        fn is_bookmarked(self: &SeabunnyCore, path: &QString) -> bool;
        #[qinvokable]
        fn set_place_hidden(self: Pin<&mut SeabunnyCore>, id: &QString, hidden: bool);
        #[qinvokable]
        fn move_place(self: Pin<&mut SeabunnyCore>, id: &QString, to: i32);
        #[qinvokable]
        fn edit_place(self: Pin<&mut SeabunnyCore>, id: &QString, name: &QString, path: &QString);
        #[qinvokable]
        fn reset_places(self: Pin<&mut SeabunnyCore>);
        #[qinvokable]
        fn set_starred(self: Pin<&mut SeabunnyCore>, paths_json: &QString, on: bool);
        #[qinvokable]
        fn is_starred(self: &SeabunnyCore, path: &QString) -> bool;
        #[qinvokable]
        fn refresh_frequent_dirs(self: Pin<&mut SeabunnyCore>);
        #[qinvokable]
        fn templates_json(self: &SeabunnyCore) -> QString;
        #[qinvokable]
        fn scripts_json(self: &SeabunnyCore) -> QString;
        #[qinvokable]
        fn user_dir(self: &SeabunnyCore, key: &QString) -> QString;
        /// Tab completion for the path bar: completes the last component
        /// to the longest common prefix of matching folders.
        #[qinvokable]
        fn complete_path(self: &SeabunnyCore, text: &QString, show_hidden: bool) -> QString;
        #[qinvokable]
        fn load_drives(self: Pin<&mut SeabunnyCore>);
        #[qinvokable]
        fn mount_drive(self: Pin<&mut SeabunnyCore>, device: &QString);
        #[qinvokable]
        fn unmount_drive(self: Pin<&mut SeabunnyCore>, device: &QString);
        #[qinvokable]
        fn eject_drive(self: Pin<&mut SeabunnyCore>, disk: &QString);
        #[qinvokable]
        fn unlock_drive(self: Pin<&mut SeabunnyCore>, device: &QString, passphrase: &QString, remember: bool);
        #[qinvokable]
        fn lock_drive(self: Pin<&mut SeabunnyCore>, device: &QString);
        #[qinvokable]
        fn rename_drive(self: Pin<&mut SeabunnyCore>, device: &QString, name: &QString);
        #[qinvokable]
        fn load_smb_profiles(self: Pin<&mut SeabunnyCore>);
        #[qinvokable]
        fn save_smb_profile(
            self: Pin<&mut SeabunnyCore>,
            id: &QString,
            name: &QString,
            server: &QString,
            share: &QString,
            username: &QString,
            domain: &QString,
        ) -> QString;
        #[qinvokable]
        fn remove_smb_profile(self: Pin<&mut SeabunnyCore>, id: &QString);
        #[qinvokable]
        fn connect_smb(self: Pin<&mut SeabunnyCore>, id: &QString, password: &QString, remember: bool);
        #[qinvokable]
        fn disconnect_smb(self: Pin<&mut SeabunnyCore>, id: &QString);
        #[qinvokable]
        fn open_item(self: Pin<&mut SeabunnyCore>, path: &QString);
        #[qinvokable]
        fn open_with_apps(self: &SeabunnyCore, path: &QString) -> QString;
        #[qinvokable]
        fn open_with_data(self: &SeabunnyCore, path: &QString) -> QString;
        #[qinvokable]
        fn all_open_with_apps(self: &SeabunnyCore) -> QString;
        #[qinvokable]
        fn recent_open_with_apps(self: &SeabunnyCore) -> QString;
        #[qinvokable]
        fn default_app_for(self: &SeabunnyCore, path: &QString) -> QString;
        #[qinvokable]
        fn open_with_app(self: Pin<&mut SeabunnyCore>, paths_json: &QString, app_id: &QString);
        #[qinvokable]
        fn set_default_app(self: Pin<&mut SeabunnyCore>, path: &QString, app_id: &QString);
        #[qinvokable]
        fn run_custom_command(self: Pin<&mut SeabunnyCore>, command: &QString, path: &QString) -> bool;
        #[qinvokable]
        fn run_script(self: Pin<&mut SeabunnyCore>, script: &QString, dir: &QString, paths_json: &QString);
        #[qinvokable]
        fn open_terminal(self: Pin<&mut SeabunnyCore>, dir: &QString);
        #[qinvokable]
        fn open_as_admin(self: Pin<&mut SeabunnyCore>, path: &QString);
        #[qinvokable]
        fn open_new_window(self: &SeabunnyCore, path: &QString);
        #[qinvokable]
        fn quick_look(self: &SeabunnyCore, path: &QString) -> QString;
        #[qinvokable]
        fn get_item_info(self: &SeabunnyCore, path: &QString) -> QString;
        #[qinvokable]
        fn start_dir_size(self: Pin<&mut SeabunnyCore>, key: &QString, paths_json: &QString);
        #[qinvokable]
        fn checked_permissions(self: Pin<&mut SeabunnyCore>, path: &QString, identity: &QString, expected: u32, mode: u32) -> QString;
        #[qinvokable]
        fn chooser_sidebar_state(self: &SeabunnyCore, chooser: bool) -> QString;
        #[qinvokable]
        fn save_sidebar_state(self: &SeabunnyCore, chooser: bool, expanded: bool, width: f64) -> bool;
        #[qinvokable]
        fn open_with_selection(self: &SeabunnyCore, paths: &QString) -> QString;
        #[qinvokable]
        fn launch_with(self: Pin<&mut SeabunnyCore>, paths: &QString, app: &QString, make_default: bool) -> QString;
        #[qinvokable]
        fn set_permissions(self: Pin<&mut SeabunnyCore>, path: &QString, mode: i32, recursive: bool) -> QString;
        #[qinvokable]
        fn is_archive_file(self: &SeabunnyCore, path: &QString) -> bool;
        #[qinvokable]
        fn mime_type(self: &SeabunnyCore, path: &QString) -> QString;
        #[qinvokable]
        fn secret_lookup(self: &SeabunnyCore, key: &QString) -> QString;
        #[qinvokable]
        fn check_merge_conflicts(self: &SeabunnyCore, paths: &QString, dest: &QString) -> QString;
        #[qinvokable]
        fn check_conflicts(self: &SeabunnyCore, paths_json: &QString, dest: &QString) -> QString;
        /// mode: copy | move | link; resolution: rename | skip | overwrite.
        #[qinvokable]
        fn transfer(self: Pin<&mut SeabunnyCore>, paths_json: &QString, dest: &QString, mode: &QString, resolution: &QString);
        #[qinvokable]
        fn trash_items(self: Pin<&mut SeabunnyCore>, paths_json: &QString);
        #[qinvokable]
        fn delete_items(self: Pin<&mut SeabunnyCore>, paths_json: &QString);
        #[qinvokable]
        fn restore_items(self: Pin<&mut SeabunnyCore>, paths_json: &QString);
        #[qinvokable]
        fn empty_trash(self: Pin<&mut SeabunnyCore>);
        #[qinvokable]
        fn compress(self: Pin<&mut SeabunnyCore>, paths_json: &QString, format: &QString, password: &QString);
        #[qinvokable]
        fn extract(self: Pin<&mut SeabunnyCore>, archive: &QString, into_subfolder: bool, password: &QString);
        #[qinvokable]
        fn create_folder(self: Pin<&mut SeabunnyCore>, dir: &QString, name: &QString) -> QString;
        #[qinvokable]
        fn create_file(self: Pin<&mut SeabunnyCore>, dir: &QString, name: &QString) -> QString;
        #[qinvokable]
        fn create_from_template(self: Pin<&mut SeabunnyCore>, template_path: &QString, dir: &QString) -> QString;
        /// Returns "" on success or an error message.
        #[qinvokable]
        fn rename_item(self: Pin<&mut SeabunnyCore>, path: &QString, new_name: &QString) -> QString;
        /// renames_json: [{path, name}]. Returns "" or an error message.
        #[qinvokable]
        fn batch_rename(self: Pin<&mut SeabunnyCore>, renames_json: &QString) -> QString;
        #[qinvokable]
        fn cancel_operation(self: Pin<&mut SeabunnyCore>, id: i32);
        #[qinvokable]
        fn undo(self: Pin<&mut SeabunnyCore>);
        #[qinvokable]
        fn redo(self: Pin<&mut SeabunnyCore>);
        #[qinvokable]
        fn is_cloudflared_installed(self: &SeabunnyCore) -> bool;
        #[qinvokable]
        fn install_cloudflared(self: Pin<&mut SeabunnyCore>);
        #[qinvokable]
        fn start_share(self: Pin<&mut SeabunnyCore>, paths_json: &QString);
        #[qinvokable]
        fn list_shares_json(self: &SeabunnyCore) -> QString;
        #[qinvokable]
        fn stop_share(self: Pin<&mut SeabunnyCore>, share_id: &QString) -> bool;
        #[qinvokable]
        fn remove_share(self: Pin<&mut SeabunnyCore>, share_id: &QString) -> bool;
    }

    impl cxx_qt::Threading for SeabunnyCore {}
    impl cxx_qt::Initialize for SeabunnyCore {}
}

use crate::archive::{self, ArchiveError};
use crate::fsops::{self, Monitor};
use crate::share;
use crate::{apps, drives, icons, info, native, smb, state, theme, trash, util, watcher, xdg};
use core::pin::Pin;
use cxx_qt::{CxxQtThread, CxxQtType, Threading};
use cxx_qt_lib::QString;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Instant;
struct Op {
    id: u64,
    title: String,
    kind: String,
    total: AtomicU64,
    done: AtomicU64,
    cancel: AtomicBool,
    current: Mutex<String>,
    last_publish: AtomicU64,
    started: Instant,
    thread: CxxQtThread<qobject::SeabunnyCore>,
}

impl Op {
    fn publish_soon(&self) {
        let now = self.started.elapsed().as_millis() as u64;
        let last = self.last_publish.load(Ordering::Relaxed);
        if now >= last + 200
            && self.last_publish.compare_exchange(last, now, Ordering::Relaxed, Ordering::Relaxed).is_ok()
        {
            let _ = self.thread.queue(|core| core.publish_ops());
        }
    }
}

impl Monitor for Op {
    fn cancelled(&self) -> bool {
        self.cancel.load(Ordering::Relaxed)
    }
    fn advance(&self, bytes: u64, current: &Path) {
        self.done.fetch_add(bytes, Ordering::Relaxed);
        if let Some(n) = current.file_name() {
            *util::lock(&self.current) = n.to_string_lossy().to_string();
        }
        self.publish_soon();
    }
}

#[derive(Clone, Debug)]
pub(crate) enum UndoAction {
    Group(Vec<UndoAction>),
    MadeDirectory(PathBuf, u32),
    RemovedDirectory(PathBuf, u32),
    /// (from, to) pairs as performed.
    Rename(Vec<(PathBuf, PathBuf)>),
    /// Items that were created (undo moves them to the trash).
    Create(Vec<PathBuf>),
    /// (from, to) pairs as performed.
    Move(Vec<(PathBuf, PathBuf)>),
    /// (source, created copy) pairs.
    Copy(Vec<(PathBuf, PathBuf)>),
    Trash(Vec<trash::TrashedItem>),
}

#[derive(Clone)]
struct UndoEntry {
    label: String,
    action: UndoAction,
}

struct Outcome {
    ok: bool,
    message: String,
    undo: Option<UndoEntry>,
    result: serde_json::Value,
    /// Push `undo` to the redo stack instead (this op was an undo).
    is_undo: bool,
    /// This op replays a redo entry: keep the redo stack.
    is_redo: bool,
    /// Unfinished part of an undo/redo: goes back onto the stack it came from.
    requeue: Option<UndoEntry>,
}

impl Outcome {
    fn ok(message: impl Into<String>) -> Self {
        Outcome { ok: true, message: message.into(), undo: None, result: serde_json::Value::Null, is_undo: false, is_redo: false, requeue: None }
    }
    fn err(message: impl Into<String>) -> Self {
        Outcome { ok: false, ..Outcome::ok(message) }
    }
}

pub struct CoreRust {
    is_dark: bool,
    wallpaper_colors_json: QString,
    hostname: QString,
    device_type: QString,
    icon_theme: QString,
    drives_json: QString,
    frequent_dirs_json: QString,
    places_json: QString,
    smb_profiles_json: QString,
    operations_json: QString,
    busy: bool,
    can_undo: bool,
    can_redo: bool,
    undo_text: QString,
    redo_text: QString,
    trash_empty: bool,
    cloudflared_ready: bool,
    low_end_hardware: bool,

    ops: Vec<Arc<Op>>,
    next_op: u64,
    undo_stack: Vec<UndoEntry>,
    redo_stack: Vec<UndoEntry>,
    /// An undo or redo is running; further requests wait for it.
    history_running: bool,
    drives: Vec<drives::Drive>,
    size_generation: Arc<AtomicU64>,
    device_watcher: Option<watcher::DeviceWatcher>,
    color_watcher: Option<watcher::DirWatcher>,
}

impl Default for CoreRust {
    fn default() -> Self {
        Self {
            is_dark: true,
            wallpaper_colors_json: QString::from(&*theme::read_wallpaper_colors()),
            hostname: QString::from(&*theme::read_system_hostname()),
            device_type: QString::from(theme::detect_device_type()),
            icon_theme: QString::from("hicolor"),
            drives_json: QString::from("[]"),
            frequent_dirs_json: QString::from("[]"),
            places_json: QString::from("[]"),
            smb_profiles_json: QString::from("[]"),
            operations_json: QString::from("[]"),
            busy: false,
            can_undo: false,
            can_redo: false,
            undo_text: QString::default(),
            redo_text: QString::default(),
            trash_empty: true,
            cloudflared_ready: share::is_cloudflared_installed(),
            low_end_hardware: is_low_end_hardware(),
            ops: Vec::new(),
            next_op: 1,
            undo_stack: Vec::new(),
            redo_stack: Vec::new(),
            history_running: false,
            drives: Vec::new(),
            size_generation: Arc::new(AtomicU64::new(0)),
            device_watcher: None,
            color_watcher: None,
        }
    }
}

fn q(s: &str) -> QString {
    QString::from(s)
}

fn parse_paths(json: &QString) -> Vec<PathBuf> {
    serde_json::from_str::<Vec<String>>(&json.to_string())
        .unwrap_or_default()
        .into_iter()
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .collect()
}

fn file_name(p: &Path) -> String {
    p.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_else(|| p.to_string_lossy().to_string())
}

fn plural(n: usize, one: &str, many: &str) -> String {
    if n == 1 {
        format!("1 {}", one)
    } else {
        format!("{} {}", n, many)
    }
}

/// Valid single path component for a new or renamed item.
pub fn validate_name(name: &str) -> Result<String, String> {
    let n = name.trim();
    if n.is_empty() {
        return Err("The name can't be empty".into());
    }
    if n == "." || n == ".." {
        return Err("\".\" and \"..\" are reserved names".into());
    }
    if n.contains('/') {
        return Err("Names can't contain \"/\"".into());
    }
    if n.contains('\0') {
        return Err("Invalid character in name".into());
    }
    if n.len() > 255 {
        return Err("The name is too long".into());
    }
    Ok(n.to_string())
}

/// Copying to removable media must be flushed before we call it done.
fn needs_sync(dest: &Path) -> bool {
    use std::os::unix::fs::MetadataExt;
    let dev = match std::fs::metadata(dest) {
        Ok(m) => m.dev(),
        Err(_) => return false,
    };
    let root = std::fs::metadata("/").map(|m| m.dev()).ok();
    let home = std::fs::metadata(util::home()).map(|m| m.dev()).ok();
    Some(dev) != root && Some(dev) != home
}

/// Under 4 GiB of RAM or at most two CPU threads.
fn is_low_end_hardware() -> bool {
    let mem_kib: u64 = std::fs::read_to_string("/proc/meminfo")
        .ok()
        .and_then(|m| {
            m.lines()
                .find(|l| l.starts_with("MemTotal:"))
                .and_then(|l| l.split_whitespace().nth(1))
                .and_then(|v| v.parse().ok())
        })
        .unwrap_or(u64::MAX);
    let cpus = std::thread::available_parallelism().map(|n| n.get()).unwrap_or(4);
    mem_kib < 4 * 1024 * 1024 || cpus <= 2
}

/// Places configuration stored in settings ("placesConfig").
#[derive(serde::Serialize, serde::Deserialize, Default, Clone)]
struct PlacesConfig {
    #[serde(default)]
    order: Vec<String>,
    #[serde(default)]
    hidden: Vec<String>,
    #[serde(default)]
    overrides: std::collections::HashMap<String, (String, String)>,
}

fn places_config() -> PlacesConfig {
    if let Some(config) = state::get("placesConfig").and_then(|s| serde_json::from_str(&s).ok()) { return config; }
    let legacy: serde_json::Value = state::get("sidebarLayout").and_then(|s|serde_json::from_str(&s).ok()).unwrap_or_default();
    let id = |value: &str| -> String {
        if let Some(path) = value.strip_prefix("folder:") { return format!("favorite:{path}"); }
        match value.strip_prefix("place:").unwrap_or(value) {
            "Documents" => "DOCUMENTS", "Downloads" => "DOWNLOAD", "Pictures" => "PICTURES", "Music" => "MUSIC", "Videos" => "VIDEOS", "Desktop" => "DESKTOP", "Projects" => "PROJECTS", other => other,
        }.into()
    };
    let strings = |key: &str| legacy[key].as_array().into_iter().flatten().filter_map(|v|v.as_str()).map(id).collect();
    PlacesConfig {order:strings("order"), hidden:strings("hidden"), overrides:Default::default()}
}

fn save_places_config(c: &PlacesConfig) {
    state::set("placesConfig", &serde_json::to_string(c).unwrap_or_default());
}

/// Every sidebar entry, with a `hidden` flag.
fn build_places(hostname: &str, device_type: &str) -> Vec<serde_json::Value> {
    let cfg = places_config();
    let mut items: Vec<serde_json::Value> = Vec::new();
    let pc_icon = if device_type == "laptop" { "laptop" } else { "desktop" };
    items.push(serde_json::json!({"id": "pc", "kind": "pc", "name": if hostname.is_empty() { "This PC" } else { hostname }, "path": "", "icon": pc_icon, "system_icon": "computer-symbolic"}));
    items.push(serde_json::json!({"id": "recent", "kind": "recent", "name": "Recent", "path": "recent:///", "icon": "clock", "system_icon": "document-open-recent-symbolic"}));
    items.push(serde_json::json!({"id": "starred", "kind": "starred", "name": "Starred", "path": "starred:///", "icon": "star", "system_icon": "starred-symbolic"}));
    // Paths already shown by a built-in place, so a GTK bookmark pointing at
    // the same folder (e.g. ~/Projects) is not listed twice.
    let mut shown_paths: std::collections::HashSet<String> = std::collections::HashSet::new();
    for p in xdg::default_places() {
        let (name, path) = cfg.overrides.get(&p.id).cloned().unwrap_or((p.name.clone(), p.path.clone()));
        if !Path::new(&path).is_dir() {
            continue; // issue #22: only show folders that exist
        }
        shown_paths.insert(path.clone());
        items.push(serde_json::json!({"id": p.id, "kind": "place", "name": name, "path": path, "icon": p.icon, "system_icon": format!("{}-symbolic", p.system_icon)}));
    }
    for b in xdg::bookmarks() {
        let Some(path) = b.path() else { continue };
        if !shown_paths.insert(path.to_string_lossy().to_string()) {
            continue;
        }
        let exists = path.is_dir();
        items.push(serde_json::json!({
            "id": format!("bookmark:{}", path.to_string_lossy()),
            "kind": "bookmark",
            "name": b.display_name(),
            "path": path.to_string_lossy(),
            "icon": "folder-simple",
            "system_icon": "folder-symbolic",
            "missing": !exists,
        }));
    }
    let favorites = crate::favorites::load(&util::config_home().join("seabunny/favorites.json")).unwrap_or_default();
    for favorite in favorites {
        if !shown_paths.insert(favorite.path.clone()) { continue; }
        items.push(serde_json::json!({"id":format!("favorite:{}",favorite.path),"kind":"bookmark","name":favorite.label,
            "path":favorite.path,"icon":"folder-simple","system_icon":"folder-symbolic","missing":!Path::new(&favorite.path).is_dir()}));
    }
    for p in smb::profiles() {
        let state = smb::state_for(&p);
        items.push(serde_json::json!({
            "id": format!("smb:{}", p.id),
            "kind": "smb",
            "name": state.label,
            "path": state.path,
            "icon": "network",
            "system_icon": "folder-remote-symbolic",
            "profile_id": p.id,
            "server": p.server,
            "share": p.share,
            "username": p.username,
            "domain": p.domain,
            "connected": state.connected,
        }));
    }
    items.push(serde_json::json!({"id": "trash", "kind": "trash", "name": "Trash", "path": "trash:///", "icon": "trash", "system_icon": "user-trash-symbolic"}));

    let legacy: serde_json::Value = state::get("sidebarLayout").and_then(|raw|serde_json::from_str(&raw).ok()).unwrap_or_default();
    for item in &mut items {
        let id = item["id"].as_str().unwrap_or_default();
        let old = if let Some(path) = id.strip_prefix("favorite:") { format!("folder:{path}") }
            else { format!("place:{}", match id {"DOCUMENTS"=>"Documents", "DOWNLOAD"=>"Downloads", "PICTURES"=>"Pictures", "MUSIC"=>"Music", "VIDEOS"=>"Videos", "DESKTOP"=>"Desktop", "PROJECTS"=>"Projects", other=>other}) };
        if let Some(icon) = legacy["icons"][&old].as_str() { item["icon"] = serde_json::json!(icon); }
    }
    // Apply the user's order: listed ids first in that order, then the rest.
    let pos = |id: &str| cfg.order.iter().position(|o| o == id).unwrap_or(usize::MAX);
    let mut indexed: Vec<(usize, usize, serde_json::Value)> =
        items.into_iter().enumerate().map(|(i, v)| (pos(v["id"].as_str().unwrap_or("")), i, v)).collect();
    indexed.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));
    indexed
        .into_iter()
        .map(|(_, _, mut v)| {
            let id = v["id"].as_str().unwrap_or("").to_string();
            v["hidden"] = serde_json::Value::Bool(cfg.hidden.contains(&id));
            v
        })
        .collect()
}

fn secret_tool() -> Option<PathBuf> {
    util::which("secret-tool")
}

fn secret_store(key: &str, label: &str, secret: &str) {
    if let Some(tool) = secret_tool() {
        let mut cmd = std::process::Command::new(tool);
        cmd.args(["store", "--label", label, "application", "seabunny", "key", key]);
        let _ = util::run_capture(cmd, Some(secret.as_bytes()));
    }
}

fn secret_get(key: &str) -> String {
    let Some(tool) = secret_tool() else { return String::new() };
    let mut cmd = std::process::Command::new(tool);
    cmd.args(["lookup", "application", "seabunny", "key", key]);
    let (ok, out, _) = util::run_capture(cmd, None);
    if ok {
        out.trim_end_matches('\n').to_string()
    } else {
        String::new()
    }
}

/// Wallpaper color files live in these folders; watched for changes.
fn wallpaper_dirs() -> Vec<PathBuf> {
    let h = util::home();
    [".local/state/quickshell/user/generated", ".cache/wal", ".cache/matugen", ".config/matugen", ".cache/DankMaterialShell", ".cache"]
        .iter()
        .map(|d| h.join(d))
        .filter(|d| d.is_dir())
        .collect()
}

impl qobject::SeabunnyCore {
    fn publish_ops(mut self: Pin<&mut Self>) {
        let list: Vec<serde_json::Value> = self
            .ops
            .iter()
            .map(|op| {
                let total = op.total.load(Ordering::Relaxed);
                let done = op.done.load(Ordering::Relaxed).min(total.max(1));
                let progress = if total > 0 { done as f64 / total as f64 } else { -1.0 };
                let detail = if total > 0 && op.kind != "delete" && op.kind != "trash" {
                    format!("{} of {}", util::format_size(done), util::format_size(total))
                } else if total > 0 {
                    format!("{} of {}", done, total)
                } else {
                    String::new()
                };
                serde_json::json!({
                    "id": op.id,
                    "title": op.title,
                    "kind": op.kind,
                    "progress": progress,
                    "detail": detail,
                    "current": util::lock(&op.current).clone(),
                    "seconds": op.started.elapsed().as_secs(),
                })
            })
            .collect();
        let busy = !self.ops.is_empty();
        self.as_mut().set_operations_json(q(&serde_json::to_string(&list).unwrap_or_default()));
        if *self.busy() != busy {
            self.as_mut().set_busy(busy);
        }
    }

    /// Runs `work` on a worker thread as a tracked, cancellable operation.
    fn spawn_op<F>(mut self: Pin<&mut Self>, kind: &str, title: String, work: F)
    where
        F: FnOnce(&Op) -> Outcome + Send + 'static,
    {
        let id = self.next_op;
        self.as_mut().rust_mut().next_op += 1;
        let op = Arc::new(Op {
            id,
            title,
            kind: kind.to_string(),
            total: AtomicU64::new(0),
            done: AtomicU64::new(0),
            cancel: AtomicBool::new(false),
            current: Mutex::new(String::new()),
            last_publish: AtomicU64::new(0),
            started: Instant::now(),
            thread: self.qt_thread(),
        });
        self.as_mut().rust_mut().ops.push(op.clone());
        self.as_mut().publish_ops();
        let kind = kind.to_string();
        std::thread::spawn(move || {
            let outcome = work(&op);
            let cancelled = op.cancel.load(Ordering::Relaxed);
            let _ = op.thread.queue(move |core| core.finish_op(id, kind, outcome, cancelled));
        });
    }

    fn finish_op(mut self: Pin<&mut Self>, id: u64, kind: String, outcome: Outcome, cancelled: bool) {
        self.as_mut().rust_mut().ops.retain(|o| o.id != id);
        self.as_mut().publish_ops();
        if let Some(entry) = outcome.undo.clone() {
            if outcome.is_undo {
                self.as_mut().rust_mut().redo_stack.push(entry);
            } else {
                self.as_mut().rust_mut().undo_stack.push(entry);
                if self.undo_stack.len() > 100 {
                    self.as_mut().rust_mut().undo_stack.remove(0);
                }
                if !outcome.is_redo {
                    self.as_mut().rust_mut().redo_stack.clear();
                }
            }
        }
        if let Some(entry) = outcome.requeue.clone() {
            if outcome.is_undo {
                self.as_mut().rust_mut().undo_stack.push(entry);
            } else {
                self.as_mut().rust_mut().redo_stack.push(entry);
            }
        }
        if outcome.is_undo || outcome.is_redo {
            self.as_mut().rust_mut().history_running = false;
        }
        // Failures are always reported, even when part of the work succeeded
        // and can be undone.
        if cancelled && outcome.undo.is_none() {
            self.as_mut().notify(q("info"), q("Cancelled"));
        } else if !outcome.message.is_empty() {
            let kind_s = if !outcome.ok {
                "error"
            } else if outcome.undo.is_some() && !outcome.is_undo {
                "undo"
            } else {
                "info"
            };
            self.as_mut().notify(q(kind_s), q(&outcome.message));
        }
        self.as_mut().sync_undo_props();
        if matches!(kind.as_str(), "trash" | "restore" | "empty" | "delete" | "undo" | "redo") {
            self.as_mut().update_trash_empty();
        }
        let result = serde_json::to_string(&outcome.result).unwrap_or_else(|_| "null".into());
        self.operation_finished(q(&kind), outcome.ok, q(&result));
    }

    fn record_undo(mut self: Pin<&mut Self>, entry: UndoEntry) {
        self.as_mut().rust_mut().undo_stack.push(entry);
        self.as_mut().rust_mut().redo_stack.clear();
        self.sync_undo_props();
    }

    fn sync_undo_props(mut self: Pin<&mut Self>) {
        let u = self.undo_stack.last().map(|e| e.label.clone()).unwrap_or_default();
        let r = self.redo_stack.last().map(|e| e.label.clone()).unwrap_or_default();
        let (cu, cr) = (!self.undo_stack.is_empty(), !self.redo_stack.is_empty());
        self.as_mut().set_can_undo(cu);
        self.as_mut().set_can_redo(cr);
        self.as_mut().set_undo_text(q(&u));
        self.as_mut().set_redo_text(q(&r));
    }

    fn update_trash_empty(self: Pin<&mut Self>) {
        let thread = self.qt_thread();
        std::thread::spawn(move || {
            let empty = trash::list().is_empty();
            let _ = thread.queue(move |mut core| {
                if *core.trash_empty() != empty {
                    core.as_mut().set_trash_empty(empty);
                }
            });
        });
    }

    pub fn cancel_operation(self: Pin<&mut Self>, id: i32) {
        for op in &self.ops {
            if op.id == id as u64 {
                op.cancel.store(true, Ordering::Relaxed);
            }
        }
    }
    pub fn get_setting(&self, key: &QString) -> QString {
        q(&state::get(&key.to_string()).unwrap_or_default())
    }

    pub fn set_setting(self: Pin<&mut Self>, key: &QString, value: &QString) {
        state::set(&key.to_string(), &value.to_string());
    }

    pub fn refresh_system_theme(self: Pin<&mut Self>) {
        let thread = self.qt_thread();
        std::thread::spawn(move || {
            let dark = theme::detect_system_dark_mode();
            let icon_theme = icons::system_theme();
            let _ = thread.queue(move |mut core| {
                if *core.is_dark() != dark {
                    core.as_mut().set_is_dark(dark);
                }
                core.as_mut().set_icon_theme(q(&icon_theme));
            });
        });
    }

    pub fn reload_wallpaper_colors(mut self: Pin<&mut Self>) -> bool {
        let Some((_, content, _)) = theme::read_wallpaper_colors_source() else { return false };
        if content == self.wallpaper_colors_json().to_string() {
            return false;
        }
        self.as_mut().set_wallpaper_colors_json(q(&content));
        true
    }

    pub fn resolve_icon(&self, theme_name: &QString, name: &QString) -> QString {
        let t = theme_name.to_string();
        let t = match t.as_str() {
            "" | "system" => self.icon_theme().to_string(),
            "adwaita" => "Adwaita".to_string(),
            other => other.to_string(),
        };
        q(&icons::resolve(&t, &name.to_string(), 48))
    }
    pub fn load_places(mut self: Pin<&mut Self>) {
        let places: Vec<serde_json::Value> = build_places(&self.hostname().to_string(), &self.device_type().to_string())
            .into_iter()
            .filter(|p| !p["hidden"].as_bool().unwrap_or(false))
            .collect();
        self.as_mut().set_places_json(q(&serde_json::to_string(&places).unwrap_or_default()));
    }

    pub fn all_places_json(&self) -> QString {
        q(&serde_json::to_string(&build_places(&self.hostname().to_string(), &self.device_type().to_string())).unwrap_or_default())
    }

    pub fn add_bookmark(mut self: Pin<&mut Self>, path: &QString) {
        match xdg::add_bookmark(Path::new(&path.to_string())) {
            Ok(()) => self.as_mut().notify(q("info"), q(&format!("Added “{}” to the sidebar", file_name(Path::new(&path.to_string()))))),
            Err(e) => self.as_mut().notify(q("error"), q(&e.to_string())),
        }
        self.load_places();
    }

    pub fn remove_bookmark(self: Pin<&mut Self>, path: &QString) {
        let _ = xdg::remove_bookmark(Path::new(&path.to_string()));
        let _ = crate::favorites::update(&util::config_home().join("seabunny/favorites.json"), &path.to_string(), None);
        self.load_places();
    }

    pub fn rename_bookmark(self: Pin<&mut Self>, path: &QString, label: &QString) {
        let file = util::config_home().join("seabunny/favorites.json");
        if crate::favorites::load(&file).unwrap_or_default().iter().any(|item| item.path == path.to_string()) {
            let _ = crate::favorites::update(&file, &path.to_string(), Some(&label.to_string()));
        } else { let _ = xdg::rename_bookmark(Path::new(&path.to_string()), &label.to_string()); }
        self.load_places();
    }

    pub fn is_bookmarked(&self, path: &QString) -> bool {
        let p = PathBuf::from(path.to_string());
        xdg::bookmarks().iter().any(|b| b.path().as_deref() == Some(p.as_path()))
    }

    pub fn create_symlink(&self, target: &QString, link_path: &QString) -> bool {
        let t = target.to_string();
        let l = link_path.to_string();
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(&t, &l).is_ok()
        }
        #[cfg(not(unix))]
        {
            let _ = (t, l);
            false
        }
    }

    pub fn set_place_hidden(self: Pin<&mut Self>, id: &QString, hidden: bool) {
        let mut c = places_config();
        let id = id.to_string();
        c.hidden.retain(|h| *h != id);
        if hidden {
            c.hidden.push(id);
        }
        save_places_config(&c);
        self.load_places();
    }

    pub fn move_place(self: Pin<&mut Self>, id: &QString, to: i32) {
        let mut c = places_config();
        let mut order: Vec<String> = build_places(&self.hostname().to_string(), &self.device_type().to_string())
            .iter()
            .filter_map(|p| p["id"].as_str().map(String::from))
            .collect();
        let id = id.to_string();
        if let Some(from) = order.iter().position(|o| *o == id) {
            let item = order.remove(from);
            order.insert((to.max(0) as usize).min(order.len()), item);
        }
        c.order = order;
        save_places_config(&c);
        self.load_places();
    }

    pub fn edit_place(mut self: Pin<&mut Self>, id: &QString, name: &QString, path: &QString) {
        let id = id.to_string();
        let path_s = path.to_string();
        if !Path::new(&path_s).is_dir() {
            self.as_mut().notify(q("error"), q("That folder doesn't exist"));
            return;
        }
        if let Some(bm) = id.strip_prefix("bookmark:") {
            let _ = xdg::remove_bookmark(Path::new(bm));
            let _ = xdg::add_bookmark(Path::new(&path_s));
            let _ = xdg::rename_bookmark(Path::new(&path_s), &name.to_string());
        } else {
            let mut c = places_config();
            c.overrides.insert(id, (name.to_string(), path_s));
            save_places_config(&c);
        }
        self.load_places();
    }

    pub fn reset_places(self: Pin<&mut Self>) {
        save_places_config(&PlacesConfig::default());
        self.load_places();
    }

    pub fn set_starred(mut self: Pin<&mut Self>, paths_json: &QString, on: bool) {
        for p in parse_paths(paths_json) {
            let _ = xdg::set_starred(&p, on);
        }
        self.as_mut().starred_changed();
    }

    pub fn is_starred(&self, path: &QString) -> bool {
        let p = PathBuf::from(path.to_string());
        xdg::starred().contains(&p)
    }

    pub fn refresh_frequent_dirs(mut self: Pin<&mut Self>) {
        let list: Vec<serde_json::Value> = state::frequent(6)
            .into_iter()
            .map(|p| {
                let name = file_name(Path::new(&p));
                serde_json::json!({"name": name, "path": p, "icon": "folder"})
            })
            .collect();
        self.as_mut().set_frequent_dirs_json(q(&serde_json::to_string(&list).unwrap_or_default()));
    }

    pub fn templates_json(&self) -> QString {
        q(&serde_json::to_string(&xdg::templates()).unwrap_or_else(|_| "[]".into()))
    }

    pub fn scripts_json(&self) -> QString {
        q(&serde_json::to_string(&xdg::scripts()).unwrap_or_else(|_| "[]".into()))
    }

    pub fn user_dir(&self, key: &QString) -> QString {
        let k = key.to_string();
        if k == "HOME" {
            return q(&util::home().to_string_lossy());
        }
        q(&xdg::user_dir(&k).map(|p| p.to_string_lossy().to_string()).unwrap_or_default())
    }

    pub fn complete_path(&self, text: &QString, show_hidden: bool) -> QString {
        q(&complete_path(&text.to_string(), show_hidden))
    }
    pub fn load_drives(self: Pin<&mut Self>) {
        let thread = self.qt_thread();
        std::thread::spawn(move || {
            let list = drives::list();
            let _ = thread.queue(move |mut core| {
                let json = serde_json::to_string(&list).unwrap_or_else(|_| "[]".into());
                core.as_mut().rust_mut().drives = list;
                if core.drives_json().to_string() != json {
                    core.as_mut().set_drives_json(q(&json));
                }
            });
        });
    }

    fn drive_job<F>(self: Pin<&mut Self>, title: String, work: F)
    where
        F: FnOnce() -> Result<String, String> + Send + 'static,
    {
        self.spawn_op("drive", title, move |_op| match work() {
            Ok(msg) => {
                let mut o = Outcome::ok(msg);
                o.result = serde_json::json!({"reload_drives": true});
                o
            }
            Err(e) => {
                let mut o = Outcome::err(e);
                o.result = serde_json::json!({"reload_drives": true});
                o
            }
        });
    }

    pub fn mount_drive(self: Pin<&mut Self>, device: &QString) {
        let dev = device.to_string();
        self.drive_job(format!("Mounting {}", dev), move || drives::mount(&dev).map(|_| String::new()));
    }

    pub fn unmount_drive(self: Pin<&mut Self>, device: &QString) {
        let dev = device.to_string();
        self.drive_job(format!("Unmounting {}", dev), move || drives::unmount(&dev).map(|_| String::new()));
    }

    pub fn eject_drive(self: Pin<&mut Self>, disk: &QString) {
        let disk = disk.to_string();
        let snapshot = self.drives.clone();
        self.drive_job(format!("Ejecting {}", disk), move || {
            drives::eject(&disk, &snapshot).map(|_| "It is now safe to remove the drive".to_string())
        });
    }

    pub fn unlock_drive(mut self: Pin<&mut Self>, device: &QString, passphrase: &QString, remember: bool) {
        let dev = device.to_string();
        let mut pass = passphrase.to_string();
        if pass.is_empty() {
            pass = secret_get(&format!("luks:{}", dev));
            if pass.is_empty() {
                self.as_mut().password_required(q(&serde_json::json!({"kind": "luks", "device": dev}).to_string()));
                return;
            }
        }
        let thread = self.qt_thread();
        self.drive_job(format!("Unlocking {}", dev.clone()), move || match drives::unlock(&dev, &pass) {
            Ok(clear) => {
                if remember {
                    secret_store(&format!("luks:{}", dev), &format!("Seabunny: encrypted drive {}", dev), &pass);
                }
                let _ = drives::mount(&clear);
                Ok(String::new())
            }
            Err(e) => {
                let dev2 = dev.clone();
                let _ = thread.queue(move |mut core| {
                    core.as_mut().password_required(q(&serde_json::json!({"kind": "luks", "device": dev2, "error": true}).to_string()));
                });
                Err(e)
            }
        });
    }

    pub fn lock_drive(self: Pin<&mut Self>, device: &QString) {
        let dev = device.to_string();
        self.drive_job(format!("Locking {}", dev), move || drives::lock(&dev).map(|_| String::new()));
    }

    pub fn rename_drive(self: Pin<&mut Self>, device: &QString, name: &QString) {
        let dev = device.to_string();
        let name = name.to_string();
        self.drive_job(format!("Renaming {}", dev), move || drives::set_label(&dev, &name).map(|_| String::new()));
    }

    fn refresh_smb(mut self: Pin<&mut Self>) {
        self.as_mut().load_smb_profiles();
        self.as_mut().load_places();
    }

    pub fn load_smb_profiles(mut self: Pin<&mut Self>) {
        let json = smb::list_json();
        if self.smb_profiles_json().to_string() != json {
            self.as_mut().set_smb_profiles_json(q(&json));
        }
    }

    pub fn save_smb_profile(
        mut self: Pin<&mut Self>,
        id: &QString,
        name: &QString,
        server: &QString,
        share: &QString,
        username: &QString,
        domain: &QString,
    ) -> QString {
        let server = server.to_string();
        let server = server.trim();
        let share_text = share.to_string();
        let share_text = share_text.trim().trim_matches('/');
        let share_text = share_text.split('/').next().unwrap_or("").trim();
        if server.is_empty() || share_text.is_empty() {
            return QString::default();
        }
        let current = id.to_string();
        let profile_id = if current.trim().is_empty() { smb::new_id() } else { current };
        let name = name.to_string();
        let username = username.to_string();
        let domain = domain.to_string();
        let mut list = smb::profiles();
        let previous = list.iter().find(|p| p.id == profile_id).cloned();
        let mut profile = smb::Profile {
            id: profile_id.clone(),
            name: name.trim().to_string(),
            server: server.to_string(),
            share: share_text.to_string(),
            username: username.trim().to_string(),
            domain: domain.trim().to_string(),
            remember: previous.as_ref().map(|p| p.remember).unwrap_or(false),
        };
        let identity_changed = previous.as_ref().map(|old| {
            old.server != profile.server
                || old.username != profile.username
                || old.domain != profile.domain
        }).unwrap_or(false);
        if identity_changed {
            profile.remember = false;
            if let Some(old) = previous.as_ref() {
                if old.remember {
                    smb::clear_password(old);
                }
            }
        }
        let reconnect = previous.as_ref().map(|old| {
            (identity_changed || old.share != profile.share)
                && smb::connected_path(old).is_some()
        }).unwrap_or(false);
        if let Some(existing) = list.iter_mut().find(|p| p.id == profile_id) {
            *existing = profile;
        } else {
            list.push(profile);
        }
        smb::save(&list);
        self.as_mut().refresh_smb();
        if reconnect {
            if let Some(old) = previous {
                let thread = self.qt_thread();
                self.spawn_op("smb", format!("Disconnecting from {}", old.label()), move |_op| {
                    match smb::unmount(&old) {
                        Ok(()) => {
                            let _ = thread.queue(|mut core| core.as_mut().refresh_smb());
                            Outcome::ok(String::new())
                        }
                        Err(e) => Outcome::err(e),
                    }
                });
            }
        }
        q(&profile_id)
    }

    pub fn remove_smb_profile(mut self: Pin<&mut Self>, id: &QString) {
        let profile_id = id.to_string();
        let mut list = smb::profiles();
        let profile = list.iter().find(|p| p.id == profile_id).cloned();
        list.retain(|p| p.id != profile_id);
        smb::save(&list);
        if let Some(profile) = profile {
            if profile.remember {
                smb::clear_password(&profile);
            }
            self.as_mut().refresh_smb();
            if smb::connected_path(&profile).is_some() {
                let thread = self.qt_thread();
                self.spawn_op("smb", format!("Disconnecting from {}", profile.label()), move |_op| {
                    match smb::unmount(&profile) {
                        Ok(()) => {
                            let _ = thread.queue(|mut core| core.as_mut().refresh_smb());
                            Outcome::ok(String::new())
                        }
                        Err(e) => Outcome::err(e),
                    }
                });
            }
        } else {
            self.as_mut().refresh_smb();
        }
    }

    pub fn connect_smb(mut self: Pin<&mut Self>, id: &QString, password: &QString, remember: bool) {
        let profile_id = id.to_string();
        let Some(profile) = smb::profiles().into_iter().find(|p| p.id == profile_id) else {
            self.as_mut().notify(q("error"), q("That SMB share no longer exists"));
            return;
        };
        let typed = password.to_string();
        let entered = !typed.is_empty();
        let mut pass = typed;
        if pass.is_empty() {
            pass = smb::saved_password(&profile);
        }
        if pass.is_empty() && !profile.username.trim().is_empty() {
            let request = serde_json::json!({
                "kind": "smb",
                "id": profile.id,
                "name": profile.label(),
                "server": profile.server,
                "share": profile.share,
                "username": profile.username,
            });
            self.as_mut().password_required(q(&request.to_string()));
            return;
        }
        if entered && !smb::store_password(&profile, &pass) {
            self.as_mut().notify(q("error"), q("Could not save the password in the system keyring"));
            return;
        }
        if entered {
            smb::set_remember(&profile_id, remember);
        }
        let temporary = entered && !remember;
        let label = profile.label();
        let thread = self.qt_thread();
        self.spawn_op("smb", format!("Connecting to {}", label), move |_op| {
            let result = smb::mount(&profile);
            if temporary {
                smb::clear_password(&profile);
            }
            match result {
                Ok(path) => {
                    let id = profile.id.clone();
                    let mounted = path.clone();
                    let _ = thread.queue(move |mut core| {
                        core.as_mut().refresh_smb();
                        core.as_mut().smb_mounted(q(&id), q(&mounted));
                    });
                    Outcome::ok(format!("Connected to {}", profile.label()))
                }
                Err(e) => {
                    if e.needs_password && !profile.username.trim().is_empty() {
                        let request = serde_json::json!({
                            "kind": "smb",
                            "id": profile.id,
                            "name": profile.label(),
                            "server": profile.server,
                            "share": profile.share,
                            "username": profile.username,
                            "error": true,
                        });
                        let _ = thread.queue(move |mut core| {
                            core.as_mut().password_required(q(&request.to_string()));
                        });
                    }
                    Outcome::err(e.message)
                }
            }
        });
    }

    pub fn disconnect_smb(self: Pin<&mut Self>, id: &QString) {
        let profile_id = id.to_string();
        let Some(profile) = smb::profiles().into_iter().find(|p| p.id == profile_id) else { return };
        let thread = self.qt_thread();
        self.spawn_op("smb", format!("Disconnecting from {}", profile.label()), move |_op| {
            match smb::unmount(&profile) {
                Ok(()) => {
                    let _ = thread.queue(|mut core| core.as_mut().refresh_smb());
                    Outcome::ok(String::new())
                }
                Err(e) => Outcome::err(e),
            }
        });
    }
    pub fn open_item(mut self: Pin<&mut Self>, path: &QString) {
        let p = path.to_string();
        if p.starts_with(crate::pane::ARCHIVE_SCHEME) {
            return self.open_archive_member(p);
        }
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        let path = PathBuf::from(&p);
        let failure = crate::integration::ffi::seabunny_open_file(&q(&p)).to_string();
        if !failure.is_empty() { self.as_mut().notify(q("error"), q(&failure)); return; }
        let mime = native::mime_type(&path, true);
        std::thread::spawn(move || xdg::add_recent(&path, &mime));
    }

    /// Extracts a file from an archive to a private temp folder and opens it.
    fn open_archive_member(self: Pin<&mut Self>, url: String) {
        let rest = &url[crate::pane::ARCHIVE_SCHEME.len()..];
        let (file, member) = crate::pane::split_archive_url(rest);
        let runtime = std::env::var("XDG_RUNTIME_DIR").map(PathBuf::from).unwrap_or_else(|_| std::env::temp_dir());
        // One folder per archive: hash the whole path, not a prefix of it.
        let key = {
            use std::hash::{Hash, Hasher};
            let mut h = std::collections::hash_map::DefaultHasher::new();
            file.hash(&mut h);
            format!("{:016x}", h.finish())
        };
        let target = runtime.join("seabunny-archives").join(key);
        let thread = self.qt_thread();
        self.spawn_op("open", format!("Opening {}", Path::new(&member).file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default()), move |_op| {
            let pw = secret_get(&format!("archive:{}", file.to_string_lossy()));
            match archive::extract_member(&file, &member, &target, &pw) {
                Ok(out) => {
                    let out_s = out.to_string_lossy().to_string();
                    let _ = thread.queue(move |core| core.open_item(&q(&out_s)));
                    Outcome::ok("")
                }
                Err(e) => Outcome::err(e.to_string()),
            }
        });
    }

    fn app_entry(app: &apps::DesktopApp, theme_name: &str) -> serde_json::Value {
        let icon = if app.icon.starts_with('/') {
            format!("file://{}", trash::encode_path(Path::new(&app.icon)))
        } else {
            icons::resolve(theme_name, &app.icon, 32)
        };
        serde_json::json!({"id": app.id, "name": app.name, "icon": icon})
    }

    fn app_entries(list: Vec<apps::DesktopApp>, theme_name: &str) -> QString {
        let v: Vec<serde_json::Value> = list.iter().map(|a| Self::app_entry(a, theme_name)).collect();
        q(&serde_json::to_string(&v).unwrap_or_else(|_| "[]".into()))
    }

    pub fn open_with_apps(&self, path: &QString) -> QString {
        let p = PathBuf::from(path.to_string());
        let mime = if p.is_dir() { "inode/directory".to_string() } else { native::mime_type(&p, true) };
        Self::app_entries(apps::for_mime(&mime), &self.icon_theme().to_string())
    }

    pub fn open_with_selection(&self, paths: &QString) -> QString { crate::integration::ffi::seabunny_open_with_apps(paths) }
    pub fn launch_with(self: Pin<&mut Self>, paths: &QString, app: &QString, make_default: bool) -> QString {
        if crate::integration::ffi::seabunny_portal_mode() { return q("Opening files is unavailable in the chooser."); }
        crate::integration::ffi::seabunny_open_with(paths, app, make_default)
    }
    pub fn open_with_data(&self, path: &QString) -> QString {
        let json = serde_json::json!([path.to_string()]).to_string();
        let payload: serde_json::Value = serde_json::from_str(&self.open_with_selection(&q(&json)).to_string()).unwrap_or_default();
        let mut recommended = Vec::new(); let mut others = Vec::new(); let mut default = String::new();
        for app in payload["apps"].as_array().into_iter().flatten() {
            let mut app = app.clone();
            if app["isDefault"] == true { default = app["id"].as_str().unwrap_or_default().into(); }
            let icon = app["icon"].as_str().unwrap_or_default();
            if !icon.starts_with("file:") { app["icon"] = serde_json::json!(icons::resolve(&self.icon_theme().to_string(), icon, 32)); }
            if app["recommended"] == true { recommended.push(app); } else { others.push(app); }
        }
        q(&serde_json::json!({"mime":payload["mimeType"], "defaultId":default, "recommended":recommended,"recent":[],"others":others}).to_string())
    }

    pub fn all_open_with_apps(&self) -> QString {
        Self::app_entries(apps::all().into_iter().filter(|a| !a.no_display).collect(), &self.icon_theme().to_string())
    }

    pub fn recent_open_with_apps(&self) -> QString {
        let ids: Vec<String> = state::get("recentOpenApps")
            .unwrap_or_default()
            .split('\u{1}')
            .filter(|s| !s.is_empty() && !s.starts_with("cmd:"))
            .map(String::from)
            .collect();
        let list: Vec<apps::DesktopApp> = ids.iter().filter_map(|id| apps::find(id)).collect();
        Self::app_entries(list, &self.icon_theme().to_string())
    }

    pub fn default_app_for(&self, path: &QString) -> QString {
        let p = PathBuf::from(path.to_string());
        let mime = if p.is_dir() { "inode/directory".to_string() } else { native::mime_type(&p, true) };
        q(&apps::default_for(&mime).map(|a| a.id).unwrap_or_default())
    }

    fn push_recent_app(id: &str) {
        let mut list: Vec<String> = state::get("recentOpenApps")
            .unwrap_or_default()
            .split('\u{1}')
            .filter(|s| !s.is_empty())
            .map(String::from)
            .collect();
        list.retain(|x| x != id);
        list.insert(0, id.to_string());
        list.truncate(8);
        state::set("recentOpenApps", &list.join("\u{1}"));
    }

    pub fn open_with_app(mut self: Pin<&mut Self>, paths_json: &QString, app_id: &QString) {
        let error = self.as_mut().launch_with(paths_json, app_id, false);
        if !error.is_empty() { self.as_mut().notify(q("error"), error); }
    }
    pub fn set_default_app(mut self: Pin<&mut Self>, path: &QString, app_id: &QString) {
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        let paths = q(&serde_json::json!([path.to_string()]).to_string());
        let error = crate::integration::ffi::seabunny_set_default_app(&paths, app_id);
        if !error.is_empty() { self.as_mut().notify(q("error"), error); }
    }

    pub fn run_custom_command(mut self: Pin<&mut Self>, command: &QString, path: &QString) -> bool {
        if crate::integration::ffi::seabunny_portal_mode() { return false; }
        let cmd_s = command.to_string();
        let trimmed = cmd_s.trim();
        if trimmed.is_empty() {
            return false;
        }
        Self::push_recent_app(&format!("cmd:{}", trimmed));
        let p = PathBuf::from(path.to_string());
        let mut cmd = std::process::Command::new("sh");
        cmd.arg("-c").arg(apps::command_script(trimmed)).arg("sh").arg(&p);
        if let Some(parent) = p.parent().filter(|d| d.is_dir()) {
            cmd.current_dir(parent);
        }
        match util::spawn_detached(cmd) {
            Ok(()) => true,
            Err(e) => {
                self.as_mut().notify(q("error"), q(&format!("Could not run the command: {}", e)));
                false
            }
        }
    }

    pub fn run_script(mut self: Pin<&mut Self>, script: &QString, dir: &QString, paths_json: &QString) {
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        if let Err(e) = xdg::run_script(Path::new(&script.to_string()), Path::new(&dir.to_string()), &parse_paths(paths_json)) {
            self.as_mut().notify(q("error"), q(&format!("Could not run the script: {}", e)));
        }
    }

    pub fn open_terminal(mut self: Pin<&mut Self>, dir: &QString) {
        if let Err(e) = apps::open_terminal_in(Path::new(&dir.to_string())) {
            self.as_mut().notify(q("error"), q(&e.to_string()));
        }
    }

    pub fn open_as_admin(mut self: Pin<&mut Self>, path: &QString) {
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        let p = PathBuf::from(path.to_string());
        let dir = if p.is_dir() { p } else { p.parent().map(|x| x.to_path_buf()).unwrap_or_else(|| PathBuf::from("/")) };
        let Some(pkexec) = util::which("pkexec") else {
            self.as_mut().notify(q("error"), q("pkexec (polkit) is not installed"));
            return;
        };
        let exe = std::env::current_exe().unwrap_or_else(|_| PathBuf::from("seabunny"));
        let mut cmd = std::process::Command::new(pkexec);
        cmd.arg("env");
        // A root GUI needs to reach the user's display server.
        for var in ["DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "XAUTHORITY", "QT_QPA_PLATFORM", "XDG_CURRENT_DESKTOP", "LANG"] {
            if let Ok(v) = std::env::var(var) {
                cmd.arg(format!("{}={}", var, v));
            }
        }
        cmd.arg("SEABUNNY_ADMIN=1").arg(exe).arg("--new-window").arg(&dir);
        if let Err(e) = util::spawn_detached(cmd) {
            self.as_mut().notify(q("error"), q(&e.to_string()));
        }
    }

    pub fn open_new_window(&self, path: &QString) {
        let exe = std::env::current_exe().unwrap_or_else(|_| PathBuf::from("seabunny"));
        let mut cmd = std::process::Command::new(exe);
        cmd.arg("--new-window");
        let p = path.to_string();
        if !p.is_empty() {
            cmd.arg(p);
        }
        let _ = util::spawn_detached(cmd);
    }
    pub fn quick_look(&self, path: &QString) -> QString {
        q(&serde_json::to_string(&info::quick_look(Path::new(&path.to_string()))).unwrap_or_else(|_| "{}".into()))
    }

    pub fn get_item_info(&self, path: &QString) -> QString {
        let mut value = info::item_info(Path::new(&path.to_string()));
        if let Ok(permissions) = crate::permissions::inspect(Path::new(&path.to_string())) {
            if let (Some(object), Ok(serde_json::Value::Object(fields))) = (value.as_object_mut(), serde_json::to_value(permissions)) { object.extend(fields); }
        }
        q(&value.to_string())
    }

    pub fn start_dir_size(self: Pin<&mut Self>, key: &QString, paths_json: &QString) {
        let gen = self.size_generation.fetch_add(1, Ordering::SeqCst) + 1;
        let gen_ref = self.size_generation.clone();
        let paths = parse_paths(paths_json);
        let key = key.to_string();
        let thread = self.qt_thread();
        std::thread::spawn(move || {
            struct C(Arc<AtomicU64>, u64);
            impl Monitor for C {
                fn cancelled(&self) -> bool {
                    self.0.load(Ordering::Relaxed) != self.1
                }
                fn advance(&self, _: u64, _: &Path) {}
            }
            let (bytes, count) = fsops::measure(&paths, &C(gen_ref.clone(), gen));
            if gen_ref.load(Ordering::Relaxed) != gen {
                return;
            }
            let items = count.saturating_sub(paths.len() as u64);
            let json = serde_json::json!({
                "bytes": bytes,
                "items": items,
                "text": if bytes >= 1024 {
                    format!("{} ({} bytes), {}", util::format_size(bytes), bytes, plural(items as usize, "item", "items"))
                } else {
                    format!("{}, {}", util::format_size(bytes), plural(items as usize, "item", "items"))
                },
            })
            .to_string();
            let _ = thread.queue(move |mut core| core.as_mut().dir_size_ready(q(&key), q(&json)));
        });
    }

    pub fn chooser_sidebar_state(&self, chooser: bool) -> QString { crate::integration::ffi::seabunny_sidebar_state(chooser) }
    pub fn save_sidebar_state(&self, chooser: bool, expanded: bool, width: f64) -> bool { crate::integration::ffi::seabunny_save_sidebar_state(chooser, expanded, width) }
    pub fn checked_permissions(self: Pin<&mut Self>, path: &QString, identity: &QString, expected: u32, mode: u32) -> QString {
        if crate::integration::ffi::seabunny_portal_mode() { return q("Permissions cannot be changed in the chooser."); }
        match crate::permissions::apply(Path::new(&path.to_string()), &identity.to_string(), expected, mode) { Ok(()) => q(""), Err(error) => q(&error) }
    }
    pub fn set_permissions(self: Pin<&mut Self>, path: &QString, mode: i32, recursive: bool) -> QString {
        match info::set_permissions(Path::new(&path.to_string()), mode as u32, recursive) {
            Ok(()) => QString::default(),
            Err(e) => q(&e.to_string()),
        }
    }

    pub fn is_archive_file(&self, path: &QString) -> bool {
        archive::is_archive(Path::new(&path.to_string()))
    }

    pub fn mime_type(&self, path: &QString) -> QString {
        q(&native::mime_type(Path::new(&path.to_string()), true))
    }

    pub fn secret_lookup(&self, key: &QString) -> QString {
        q(&secret_get(&key.to_string()))
    }
    pub fn check_merge_conflicts(&self, paths: &QString, dest: &QString) -> QString {
        match crate::merge::scan(&parse_paths(paths), Path::new(&dest.to_string())) {
            Ok(conflicts) => q(&serde_json::json!({"conflicts":conflicts}).to_string()),
            Err(error) => q(&serde_json::json!({"error":error}).to_string()),
        }
    }
    pub fn check_conflicts(&self, paths_json: &QString, dest: &QString) -> QString {
        let dest = PathBuf::from(dest.to_string());
        let mut out = Vec::new();
        for src in parse_paths(paths_json) {
            if src.to_string_lossy().starts_with(crate::pane::ARCHIVE_SCHEME) { continue; }
            if src.parent() == Some(dest.as_path()) {
                continue; // same folder: becomes a duplicate, not a conflict
            }
            let Some(name) = src.file_name() else { continue };
            let target = dest.join(name);
            let Ok(dmeta) = std::fs::symlink_metadata(&target) else { continue };
            let smeta = std::fs::symlink_metadata(&src).ok();
            let mtime = |m: &std::fs::Metadata| crate::pane::relative_time(std::os::unix::fs::MetadataExt::mtime(m));
            out.push(serde_json::json!({
                "name": name.to_string_lossy(),
                "src_path": src.to_string_lossy(),
                "dest_path": target.to_string_lossy(),
                "src_size": smeta.as_ref().map(|m| if m.is_dir() { "Folder".to_string() } else { util::format_size(m.len()) }).unwrap_or_default(),
                "dest_size": if dmeta.is_dir() { "Folder".to_string() } else { util::format_size(dmeta.len()) },
                "src_modified": smeta.as_ref().map(mtime).unwrap_or_default(),
                "dest_modified": mtime(&dmeta),
                "is_dir": dmeta.is_dir(),
                "can_merge": crate::merge::directory(&src) && crate::merge::directory(&target),
                "src_is_dir": smeta.map(|m| m.is_dir()).unwrap_or(false),
            }));
        }
        q(&serde_json::to_string(&out).unwrap_or_else(|_| "[]".into()))
    }

    pub fn transfer(self: Pin<&mut Self>, paths_json: &QString, dest: &QString, mode: &QString, resolution: &QString) {
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        let sources = parse_paths(paths_json);
        let dest = PathBuf::from(dest.to_string());
        let mode = mode.to_string();
        let res = resolution.to_string();
        if sources.is_empty() || !dest.is_dir() {
            return;
        }
        let verb = match mode.as_str() {
            "move" => "Moving",
            "link" => "Linking",
            _ => "Copying",
        };
        let what = if sources.len() == 1 { format!("“{}”", file_name(&sources[0])) } else { plural(sources.len(), "item", "items") };
        let title = format!("{} {} to {}", verb, what, file_name(&dest));
        let kind = mode.clone();
        self.spawn_op(&kind, title, move |op| run_transfer(op, sources, dest, &mode, &res));
    }

    pub fn trash_items(self: Pin<&mut Self>, paths_json: &QString) {
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        let paths = parse_paths(paths_json);
        if paths.is_empty() {
            return;
        }
        let title = format!("Moving {} to the trash", if paths.len() == 1 { format!("“{}”", file_name(&paths[0])) } else { plural(paths.len(), "item", "items") });
        self.spawn_op("trash", title, move |op| {
            op.total.store(paths.len() as u64, Ordering::Relaxed);
            let mut done = Vec::new();
            let mut failed = Vec::new();
            let mut last_err = String::new();
            for p in &paths {
                if op.cancelled() {
                    break;
                }
                match trash::trash(p) {
                    Ok(item) => done.push(item),
                    Err(e) => {
                        last_err = e.to_string();
                        failed.push(p.to_string_lossy().to_string());
                    }
                }
                op.advance(1, p);
            }
            let n = done.len();
            let mut o = Outcome::ok(if n == 0 {
                String::new()
            } else if n == 1 {
                format!("“{}” moved to the trash", file_name(&done[0].original))
            } else {
                format!("{} moved to the trash", plural(n, "item", "items"))
            });
            if n > 0 {
                o.undo = Some(UndoEntry { label: "Move to Trash".into(), action: UndoAction::Trash(done) });
            }
            if !failed.is_empty() {
                // The UI offers to delete these permanently instead.
                o.ok = n > 0;
                o.result = serde_json::json!({"failed": failed, "error": last_err});
            }
            o
        });
    }

    pub fn delete_items(self: Pin<&mut Self>, paths_json: &QString) {
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        let paths = parse_paths(paths_json);
        if paths.is_empty() {
            return;
        }
        let title = format!("Deleting {}", if paths.len() == 1 { format!("“{}”", file_name(&paths[0])) } else { plural(paths.len(), "item", "items") });
        self.spawn_op("delete", title, move |op| {
            op.total.store(paths.len() as u64, Ordering::Relaxed);
            let mut errors = 0;
            let mut last = String::new();
            for p in &paths {
                if op.cancelled() {
                    break;
                }
                // Items inside a trash also drop their .trashinfo.
                let res = match trash::lookup(p) {
                    Some(item) => trash::erase(&item),
                    None => fsops::remove_tree(p),
                };
                if let Err(e) = res {
                    errors += 1;
                    last = e.to_string();
                }
                op.advance(1, p);
            }
            if errors > 0 {
                Outcome::err(format!("Could not delete {}: {}", plural(errors, "item", "items"), last))
            } else {
                Outcome::ok(format!("Deleted {}", plural(paths.len(), "item", "items")))
            }
        });
    }

    pub fn restore_items(self: Pin<&mut Self>, paths_json: &QString) {
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        let paths = parse_paths(paths_json);
        if paths.is_empty() {
            return;
        }
        self.spawn_op("restore", format!("Restoring {}", plural(paths.len(), "item", "items")), move |op| {
            let records = trash::list();
            let mut moved = Vec::new();
            let mut renamed = 0;
            let mut errors = Vec::new();
            for p in &paths {
                if op.cancelled() {
                    break;
                }
                let Some(item) = records.iter().find(|r| r.trashed == *p) else {
                    errors.push(format!("{}: no trash record", file_name(p)));
                    continue;
                };
                match trash::restore(item) {
                    Ok(to) => {
                        if to != item.original {
                            renamed += 1;
                        }
                        moved.push((item.trashed.clone(), to));
                    }
                    Err(e) => errors.push(format!("{}: {}", file_name(p), e)),
                }
            }
            let mut msg = format!("Restored {}", plural(moved.len(), "item", "items"));
            if renamed > 0 {
                msg.push_str(&format!(" ({} renamed because the name was taken)", renamed));
            }
            if !errors.is_empty() {
                return Outcome::err(format!("{}. Failed: {}", msg, errors.join("; ")));
            }
            Outcome::ok(msg)
        });
    }

    pub fn empty_trash(mut self: Pin<&mut Self>) {
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        // Trashed items can't be restored afterwards: drop stale undo steps.
        self.as_mut().rust_mut().undo_stack.retain(|e| !matches!(e.action, UndoAction::Trash(_)));
        self.as_mut().rust_mut().redo_stack.retain(|e| !matches!(e.action, UndoAction::Trash(_)));
        self.as_mut().sync_undo_props();
        self.spawn_op("empty", "Emptying the trash".into(), |_op| match trash::empty_all() {
            Ok(()) => Outcome::ok("Trash emptied"),
            Err(e) => Outcome::err(format!("Some items could not be deleted: {}", e)),
        });
    }

    pub fn compress(self: Pin<&mut Self>, paths_json: &QString, format: &QString, password: &QString) {
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        let items = parse_paths(paths_json);
        if items.is_empty() {
            return;
        }
        let fmt = format.to_string();
        let pass = password.to_string();
        let parent = items[0].parent().unwrap_or(Path::new("/")).to_path_buf();
        let base = match items.len() {
            1 if items[0].is_dir() => file_name(&items[0]),
            1 => {
                // "report.pdf" -> "report.zip"; archives keep their stem.
                let b = archive::base_name(&items[0]);
                if b == file_name(&items[0]) {
                    items[0].file_stem().map(|s| s.to_string_lossy().to_string()).unwrap_or(b)
                } else {
                    b
                }
            }
            _ => "Archive".into(),
        };
        let ext = match fmt.as_str() {
            "zip" | "zip_encrypted" => "zip",
            "7z" => "7z",
            "tar.gz" => "tar.gz",
            "tar.xz" => "tar.xz",
            "tar.zst" => "tar.zst",
            "tar.bz2" => "tar.bz2",
            "cpio" => "cpio",
            _ => "zip",
        };
        let target = fsops::unique_name(&parent, &format!("{}.{}", base, ext));
        let title = format!("Compressing into “{}”", file_name(&target));
        self.spawn_op("compress", title, move |op| {
            // Items from other folders can't share relative names: skip them.
            let items: Vec<PathBuf> = items.into_iter().filter(|p| p.parent() == Some(parent.as_path())).collect();
            // Build inside a private staging folder so a cancelled or failed
            // run never leaves a broken archive, and two runs never write
            // into the same file. Then move it to a free name.
            let name = file_name(&target);
            let staging = parent.join(format!(".seabunny-compress-{}-{}", std::process::id(), op.id));
            if let Err(e) = std::fs::create_dir(&staging) {
                return Outcome::err(format!("Could not create the archive: {}", e));
            }
            let built = archive::compress(&staging.join(&name), &items, &fmt, &pass, &|| op.cancelled())
                .and_then(|()| fsops::place_unique(&staging.join(&name), &parent, &name).map_err(|e| ArchiveError::Failed(e.to_string())));
            let _ = fsops::remove_tree(&staging);
            match built {
                Ok(target) => {
                    fsops::sync_filesystem(&target);
                    let mut o = Outcome::ok(format!("Created “{}”", file_name(&target)));
                    o.undo = Some(UndoEntry { label: "Compress".into(), action: UndoAction::Create(vec![target.clone()]) });
                    o.result = serde_json::json!({"created": [target.to_string_lossy()]});
                    o
                }
                Err(ArchiveError::Cancelled) => Outcome::ok(""),
                Err(e) => Outcome::err(format!("Could not create the archive: {}", e)),
            }
        });
    }

    pub fn extract(self: Pin<&mut Self>, archive_path: &QString, into_subfolder: bool, password: &QString) {
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        let arch = PathBuf::from(archive_path.to_string());
        if !arch.is_file() {
            return;
        }
        let mut pass = password.to_string();
        if pass.is_empty() {
            pass = secret_get(&format!("archive:{}", arch.to_string_lossy()));
        }
        let parent = arch.parent().unwrap_or(Path::new("/")).to_path_buf();
        let thread = self.qt_thread();
        let title = format!("Extracting “{}”", file_name(&arch));
        self.spawn_op("extract", title, move |op| {
            match extract_safely(&arch, &parent, into_subfolder, &pass, op.id, &|| op.cancelled()) {
                Ok((created, failed)) => {
                    let mut o = match failed {
                        None => Outcome::ok(format!("Extracted “{}”", file_name(&arch))),
                        Some(e) => Outcome::err(format!("Extracted “{}” only partly: {}", file_name(&arch), e)),
                    };
                    o.result = serde_json::json!({"created": created.iter().map(|p| p.to_string_lossy().to_string()).collect::<Vec<_>>()});
                    if !created.is_empty() {
                        o.undo = Some(UndoEntry { label: "Extract".into(), action: UndoAction::Create(created) });
                    }
                    o
                }
                Err(ArchiveError::NeedPassword) => {
                    let req = serde_json::json!({"kind": "archive", "archive": arch.to_string_lossy(), "into_subfolder": into_subfolder, "error": !pass.is_empty()}).to_string();
                    let _ = thread.queue(move |mut core| core.as_mut().password_required(q(&req)));
                    Outcome::ok("")
                }
                Err(ArchiveError::Cancelled) => Outcome::ok(""),
                Err(other) => Outcome::err(format!("Could not extract “{}”: {}", file_name(&arch), other)),
            }
        });
    }

    fn create_item(mut self: Pin<&mut Self>, dir: &QString, name: &QString, is_dir: bool) -> QString {
        if crate::integration::ffi::seabunny_portal_mode() { return q("Unavailable in a file chooser"); }
        let name = match validate_name(&name.to_string()) {
            Ok(n) => n,
            Err(e) => {
                self.as_mut().notify(q("error"), q(&e));
                return QString::default();
            }
        };
        let target = PathBuf::from(dir.to_string()).join(&name);
        if std::fs::symlink_metadata(&target).is_ok() {
            self.as_mut().notify(q("error"), q(&format!("“{}” already exists", name)));
            return QString::default();
        }
        let res = if is_dir {
            std::fs::create_dir(&target)
        } else {
            std::fs::OpenOptions::new().write(true).create_new(true).open(&target).map(|_| ())
        };
        match res {
            Ok(()) => {
                self.as_mut().record_undo(UndoEntry {
                    label: if is_dir { "New Folder".into() } else { "New File".into() },
                    action: UndoAction::Create(vec![target.clone()]),
                });
                q(&target.to_string_lossy())
            }
            Err(e) => {
                self.as_mut().notify(q("error"), q(&format!("Could not create “{}”: {}", name, e)));
                QString::default()
            }
        }
    }

    pub fn create_folder(self: Pin<&mut Self>, dir: &QString, name: &QString) -> QString {
        self.create_item(dir, name, true)
    }

    pub fn create_file(self: Pin<&mut Self>, dir: &QString, name: &QString) -> QString {
        self.create_item(dir, name, false)
    }

    pub fn create_from_template(mut self: Pin<&mut Self>, template_path: &QString, dir: &QString) -> QString {
        let tpl = PathBuf::from(template_path.to_string());
        let target = fsops::unique_name(Path::new(&dir.to_string()), &file_name(&tpl));
        match fsops::copy_tree(&tpl, &target, &fsops::Silent) {
            Ok(()) => {
                // A new document should look new, not inherit the template's age.
                let _ = std::fs::File::options().write(true).open(&target).and_then(|f| f.set_modified(std::time::SystemTime::now()));
                self.as_mut().record_undo(UndoEntry { label: "New Document".into(), action: UndoAction::Create(vec![target.clone()]) });
                q(&target.to_string_lossy())
            }
            Err(e) => {
                self.as_mut().notify(q("error"), q(&e.to_string()));
                QString::default()
            }
        }
    }

    pub fn rename_item(mut self: Pin<&mut Self>, path: &QString, new_name: &QString) -> QString {
        if crate::integration::ffi::seabunny_portal_mode() { return q("Unavailable in a file chooser"); }
        let from = PathBuf::from(path.to_string());
        let name = match validate_name(&new_name.to_string()) {
            Ok(n) => n,
            Err(e) => return q(&e),
        };
        let Some(parent) = from.parent() else { return q("Can't rename this item") };
        let to = parent.join(&name);
        if to == from {
            return QString::default();
        }
        if let Ok(existing) = std::fs::symlink_metadata(&to) {
            // Case-only renames on case-insensitive drives hit the same file.
            let same = std::fs::symlink_metadata(&from)
                .map(|m| std::os::unix::fs::MetadataExt::ino(&m) == std::os::unix::fs::MetadataExt::ino(&existing))
                .unwrap_or(false);
            if !same {
                return q(&format!("“{}” already exists", name));
            }
        }
        match std::fs::rename(&from, &to) {
            Ok(()) => {
                if xdg::starred().contains(&from) {
                    let _ = xdg::set_starred(&from, false);
                    let _ = xdg::set_starred(&to, true);
                }
                self.as_mut().record_undo(UndoEntry { label: "Rename".into(), action: UndoAction::Rename(vec![(from, to)]) });
                QString::default()
            }
            Err(e) => q(&e.to_string()),
        }
    }

    pub fn batch_rename(mut self: Pin<&mut Self>, renames_json: &QString) -> QString {
        if crate::integration::ffi::seabunny_portal_mode() { return q("Unavailable in a file chooser"); }
        #[derive(serde::Deserialize)]
        struct R {
            path: String,
            name: String,
        }
        let list: Vec<R> = match serde_json::from_str(&renames_json.to_string()) {
            Ok(l) => l,
            Err(_) => return q("Invalid rename list"),
        };
        let mut pairs = Vec::new();
        for r in &list {
            let from = PathBuf::from(&r.path);
            let name = match validate_name(&r.name) {
                Ok(n) => n,
                Err(e) => return q(&format!("{}: {}", r.name, e)),
            };
            let to = from.parent().unwrap_or(Path::new("/")).join(name);
            if to != from {
                pairs.push((from, to));
            }
        }
        match batch_rename_pairs(&pairs) {
            Ok(()) => {
                if !pairs.is_empty() {
                    let n = pairs.len();
                    self.as_mut().record_undo(UndoEntry { label: "Rename".into(), action: UndoAction::Rename(pairs) });
                    self.as_mut().notify(q("undo"), q(&format!("Renamed {}", plural(n, "item", "items"))));
                }
                QString::default()
            }
            Err(e) => q(&e),
        }
    }

    pub fn undo(self: Pin<&mut Self>) {
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        self.undo_or_redo(true);
    }

    pub fn redo(self: Pin<&mut Self>) {
        if crate::integration::ffi::seabunny_portal_mode() { return; }
        self.undo_or_redo(false);
    }

    /// One undo/redo at a time: steps depend on each other ("rename a→b"
    /// then "move b→dir/b" must be reverted in order).
    fn undo_or_redo(mut self: Pin<&mut Self>, is_undo: bool) {
        if self.history_running {
            return;
        }
        let entry = if is_undo { self.as_mut().rust_mut().undo_stack.pop() } else { self.as_mut().rust_mut().redo_stack.pop() };
        let Some(entry) = entry else { return };
        self.as_mut().rust_mut().history_running = true;
        self.as_mut().sync_undo_props();
        let label = entry.label.clone();
        let (kind, doing, did, fail) = if is_undo {
            ("undo", "Undoing", "Undid", "Could not undo")
        } else {
            ("redo", "Redoing", "Redid", "Could not redo")
        };
        self.spawn_op(kind, format!("{} {}", doing, label), move |op| {
            let p = if is_undo { invert(&entry.action, op) } else { replay(&entry.action, op) };
            let mut o = match &p.error {
                None => Outcome::ok(format!("{} {}", did, label)),
                Some(e) => Outcome::err(format!("{} {}: {}", fail, label, e)),
            };
            o.undo = p.reverse.map(|a| UndoEntry { label: label.clone(), action: a });
            o.requeue = p.rest.map(|a| UndoEntry { label: label.clone(), action: a });
            o.is_undo = is_undo;
            o.is_redo = !is_undo;
            o
        });
    }

    pub fn is_cloudflared_installed(&self) -> bool {
        share::is_cloudflared_installed()
    }

    pub fn install_cloudflared(mut self: Pin<&mut Self>) {
        let ready = share::is_cloudflared_installed();
        self.as_mut().set_cloudflared_ready(ready);
        self.as_mut().cloudflared_status_changed(ready);
        self.notify(q(if ready { "info" } else { "error" }), q(if ready { "cloudflared is available." } else { "Install cloudflared using your distribution's package manager, then check again." }));
    }

    pub fn start_share(self: Pin<&mut Self>, paths_json: &QString) {
        let paths = parse_paths(paths_json);
        if paths.is_empty() {
            return;
        }
        let compress_folders = match self.get_setting(&q("shareCompressFolders")).to_string().as_str() {
            "false" => false,
            _ => true,
        };
        let compress_files = match self.get_setting(&q("shareCompressFiles")).to_string().as_str() {
            "true" => true,
            _ => false,
        };
        let format = match self.get_setting(&q("shareCompressFormat")).to_string().as_str() {
            "7z" => "7z".to_string(),
            "tar.gz" => "tar.gz".to_string(),
            _ => "zip".to_string(),
        };
        let password = self.get_setting(&q("sharePassword")).to_string();
        let expiration_hours = self.get_setting(&q("shareExpirationHours")).to_string().parse::<u32>().unwrap_or(24);
        let throttle_kbps = self.get_setting(&q("shareThrottleKbps")).to_string().parse::<u32>().unwrap_or(0);

        let params = share::CreateShareParams {
            paths,
            compress_folders,
            compress_files,
            format,
            password,
            expiration_hours,
            throttle_kbps,
        };

        let thread = self.qt_thread();
        share::start_share_pipeline(params, move |result| {
            let _ = thread.queue(move |mut core| {
                match result {
                    Ok((id, url)) => {
                        core.as_mut().share_link_ready(q(&id), q(&url));
                    }
                    Err(e) => {
                        core.as_mut().share_link_error(q(&e));
                    }
                }
            });
        });
    }

    pub fn list_shares_json(&self) -> QString {
        q(&share::get_manager().list_shares_json())
    }

    pub fn stop_share(self: Pin<&mut Self>, share_id: &QString) -> bool {
        share::get_manager().stop_share(&share_id.to_string())
    }

    pub fn remove_share(self: Pin<&mut Self>, share_id: &QString) -> bool {
        share::get_manager().remove_share(&share_id.to_string())
    }
}

/// Completes the folder name being typed at the end of `text`.
pub fn complete_path(text: &str, show_hidden: bool) -> String {
    let expanded = if text == "~" {
        format!("{}/", util::home().to_string_lossy())
    } else if let Some(rest) = text.strip_prefix("~/") {
        format!("{}/{}", util::home().to_string_lossy(), rest)
    } else {
        text.to_string()
    };
    let (dir, prefix) = match expanded.rfind('/') {
        Some(i) => (&expanded[..=i], &expanded[i + 1..]),
        None => return text.to_string(),
    };
    let Ok(rd) = std::fs::read_dir(dir) else { return text.to_string() };
    let lower = prefix.to_lowercase();
    let mut names: Vec<String> = rd
        .flatten()
        .filter(|e| e.path().is_dir())
        .map(|e| e.file_name().to_string_lossy().to_string())
        .filter(|n| (show_hidden || !n.starts_with('.') || prefix.starts_with('.')) && n.to_lowercase().starts_with(&lower))
        .collect();
    names.sort();
    match names.len() {
        0 => text.to_string(),
        1 => format!("{}{}/", dir, names[0]),
        _ => {
            // Longest common prefix (case-insensitive match, keep first's case).
            let first: Vec<char> = names[0].chars().collect();
            let mut len = first.len();
            for n in &names[1..] {
                let c: Vec<char> = n.chars().collect();
                len = len.min(c.len());
                for i in 0..len {
                    if first[i].to_lowercase().ne(c[i].to_lowercase()) {
                        len = i;
                        break;
                    }
                }
            }
            let common: String = first[..len.max(prefix.chars().count()).min(first.len())].iter().collect();
            format!("{}{}", dir, common)
        }
    }
}

/// Extracts into a private staging folder next to the archive, then moves
/// the result into place under free names, so nothing that already exists
/// is ever overwritten and a failed run leaves nothing behind.
///
/// * into_subfolder: a single top-level folder is used as is (no
///   "demo/demo" nesting); several entries get a folder named after the
///   archive.
/// * otherwise every top-level entry lands next to the archive.
fn extract_safely(
    arch: &Path,
    parent: &Path,
    into_subfolder: bool,
    pass: &str,
    tag: u64,
    cancelled: &dyn Fn() -> bool,
) -> Result<(Vec<PathBuf>, Option<String>), ArchiveError> {
    let staging = parent.join(format!(".seabunny-extract-{}-{}", std::process::id(), tag));
    let result = archive::extract(arch, &staging, pass, cancelled);
    if let Err(e) = result {
        let _ = fsops::remove_tree(&staging);
        return Err(e);
    }
    let entries: Vec<PathBuf> = std::fs::read_dir(&staging)
        .map(|r| r.flatten().map(|e| e.path()).collect())
        .unwrap_or_default();
    let mut created = Vec::new();
    let mut failed: Option<String> = None;
    let mut place = |from: &Path, name: &str| match fsops::place_unique(from, parent, name) {
        Ok(to) => created.push(to),
        Err(e) => {
            failed.get_or_insert(format!("{}: {}", name, e));
        }
    };
    if into_subfolder && !(entries.len() == 1 && entries[0].is_dir()) {
        // Several entries (or one file): wrap them in a folder.
        place(&staging, &archive::base_name(arch));
    } else {
        // Keep going after a failure so everything that did land is
        // reported and can be undone.
        for e in &entries {
            place(e, &file_name(e));
        }
    }
    let _ = fsops::remove_tree(&staging);
    fsops::sync_filesystem(parent);
    Ok((created, failed))
}

/// Renames several items at once; swaps (a->b, b->a) work because every
/// item first moves to a temporary name.
pub fn batch_rename_pairs(pairs: &[(PathBuf, PathBuf)]) -> Result<(), String> {
    let sources: std::collections::HashSet<&PathBuf> = pairs.iter().map(|(f, _)| f).collect();
    let mut targets = std::collections::HashSet::new();
    for (_, to) in pairs {
        if !targets.insert(to) {
            return Err(format!("Two items would be named “{}”", file_name(to)));
        }
        if std::fs::symlink_metadata(to).is_ok() && !sources.contains(to) {
            return Err(format!("“{}” already exists", file_name(to)));
        }
    }
    let mut staged: Vec<(PathBuf, PathBuf, PathBuf)> = Vec::new();
    for (i, (from, to)) in pairs.iter().enumerate() {
        let tmp = from.with_file_name(format!(".seabunny-rename-{}-{}", std::process::id(), i));
        if let Err(e) = std::fs::rename(from, &tmp) {
            for (f, t, _) in staged.iter().rev() {
                let _ = std::fs::rename(t, f);
            }
            return Err(format!("{}: {}", file_name(from), e));
        }
        staged.push((from.clone(), tmp, to.clone()));
    }
    let mut finished: Vec<(PathBuf, PathBuf)> = Vec::new();
    for (from, tmp, to) in &staged {
        if let Err(e) = std::fs::rename(tmp, to) {
            // Roll everything back to the original names.
            for (f, t) in finished.iter().rev() {
                let _ = std::fs::rename(t, f);
            }
            for (f, t, _) in &staged {
                if t.exists() {
                    let _ = std::fs::rename(t, f);
                }
            }
            return Err(format!("{}: {}", file_name(from), e));
        }
        finished.push((from.clone(), to.clone()));
    }
    Ok(())
}

fn run_transfer(op: &Op, sources: Vec<PathBuf>, dest: PathBuf, mode: &str, res: &str) -> Outcome {
    let (bytes, _) = if mode == "link" { (0, 0) } else { fsops::measure(&sources.iter().filter(|path| !path.to_string_lossy().starts_with(crate::pane::ARCHIVE_SCHEME)).cloned().collect::<Vec<_>>(), op) };
    op.total.store(bytes.max(1), Ordering::Relaxed);
    let mut pairs: Vec<(PathBuf, PathBuf)> = Vec::new();
    let mut errors: Vec<String> = Vec::new();
    let mut skipped = 0;
    let mut transferred = 0;
    let mut merged = Vec::new();
    let plan: serde_json::Value = serde_json::from_str(res).unwrap_or_default();
    let merge = plan["mode"] == "merge";
    let choices = serde_json::from_value(plan["collisions"].clone()).unwrap_or_default();
    for src in &sources {
        if op.cancelled() {
            break;
        }
        let name = file_name(src);
        let same_dir = src.parent() == Some(dest.as_path());
        if mode == "move" && same_dir {
            continue;
        }
        if fsops::is_inside(&dest, src) && mode != "link" {
            errors.push(format!("Can't put “{}” inside itself", name));
            continue;
        }
        let plain = dest.join(&name);
        let exists = std::fs::symlink_metadata(&plain).is_ok();
        if merge {
            match crate::merge::transfer(src, &plain, mode == "move", &choices, &mut merged, op) {
                Ok(()) => transferred += 1,
                Err(error) => errors.push(error),
            }
            continue;
        }
        if src.to_string_lossy().starts_with(crate::pane::ARCHIVE_SCHEME) {
            let raw = src.to_string_lossy();
            let (archive, member) = crate::pane::split_archive_url(&raw[crate::pane::ARCHIVE_SCHEME.len()..]);
            match crate::archive_reader::run(&serde_json::json!({"action":"copy","archive":archive,"selection":[member],"destination":dest}), || op.cancelled()) {
                Ok(result) => { for path in result["paths"].as_array().into_iter().flatten().filter_map(|v|v.as_str()) { merged.push(UndoAction::Create(vec![PathBuf::from(path)])); } transferred += 1; }
                Err(error) => errors.push(error),
            }
            continue;
        }
        let (target, overwrite) = if same_dir || (exists && res == "rename") {
            (fsops::unique_name(&dest, &name), false)
        } else if exists && res == "skip" {
            skipped += 1;
            continue;
        } else if exists && res == "overwrite" {
            (plain, true)
        } else if exists {
            skipped += 1;
            continue;
        } else {
            (plain, false)
        };
        let result = match (mode, overwrite) {
            ("link", true) => fsops::replace_with_link(src, &target),
            ("link", false) => std::os::unix::fs::symlink(src, &target),
            ("move", false) => fsops::move_path(src, &target, op),
            ("move", true) => fsops::replace(src, &target, true, op),
            (_, false) => fsops::copy_tree(src, &target, op),
            (_, true) => fsops::replace(src, &target, false, op),
        };
        match result {
            Ok(()) => {
                transferred += 1;
                if !overwrite {
                    pairs.push((src.clone(), target));
                }
            }
            Err(e) if e.kind() == std::io::ErrorKind::Interrupted => break,
            Err(e) => errors.push(format!("{}: {}", name, e)),
        }
    }
    if mode != "link" && transferred > 0 && needs_sync(&dest) {
        *util::lock(&op.current) = "Writing to the drive…".into();
        op.publish_soon();
        fsops::sync_filesystem(&dest);
    }
    let created: Vec<String> = pairs.iter().map(|(_, t)| t.to_string_lossy().to_string()).collect();
    let n = transferred;
    let verb = match mode {
        "move" => "Moved",
        "link" => "Linked",
        _ => "Copied",
    };
    let mut o = if errors.is_empty() {
        let mut msg = if n == 0 { String::new() } else { format!("{} {}", verb, plural(n, "item", "items")) };
        if skipped > 0 {
            msg.push_str(&format!("{}{} skipped", if msg.is_empty() { "" } else { ", " }, skipped));
        }
        Outcome::ok(msg)
    } else {
        Outcome::err(format!("{} {}; {} failed: {}", verb, plural(n, "item", "items"), errors.len(), errors.join("; ")))
    };
    if !pairs.is_empty() {
        let action = match mode {
            "move" => UndoAction::Move(pairs),
            "link" => UndoAction::Create(pairs.into_iter().map(|(_, t)| t).collect()),
            _ => UndoAction::Copy(pairs),
        };
        let label = match mode {
            "move" => "Move",
            "link" => "Link",
            _ => "Copy",
        };
        o.undo = Some(UndoEntry { label: label.into(), action });
    }
    if !merged.is_empty() {
        if let Some(entry) = o.undo.take() { merged.push(entry.action); }
        o.undo = Some(UndoEntry { label: "Merge".into(), action: UndoAction::Group(merged) });
    }
    o.result = serde_json::json!({"created": created, "mode": mode});
    o
}

/// Result of undoing or redoing an action that may stop partway.
struct Partial {
    /// Reverses what was done (goes to the opposite stack).
    reverse: Option<UndoAction>,
    /// The part that was not processed (goes back onto the same stack).
    rest: Option<UndoAction>,
    error: Option<String>,
}

impl Partial {
    fn done(reverse: UndoAction) -> Self {
        Partial { reverse: Some(reverse), rest: None, error: None }
    }
    fn stopped(reverse: Option<UndoAction>, rest: Option<UndoAction>, error: String) -> Self {
        Partial { reverse, rest, error: Some(error) }
    }
}

fn some_if<T>(v: Vec<T>, wrap: impl FnOnce(Vec<T>) -> UndoAction) -> Option<UndoAction> {
    if v.is_empty() { None } else { Some(wrap(v)) }
}

/// Reverses an action.
fn invert(action: &UndoAction, op: &dyn fsops::Monitor) -> Partial {
    match action {
        UndoAction::Group(actions) => {
            let mut done = Vec::new();
            for index in (0..actions.len()).rev() {
                let part = invert(&actions[index], op);
                if let Some(reverse) = part.reverse { done.push(reverse); }
                if let Some(error) = part.error {
                    let mut rest = actions[..index].to_vec(); if let Some(action) = part.rest { rest.push(action); }
                    done.reverse(); return Partial::stopped(some_if(done, UndoAction::Group), some_if(rest, UndoAction::Group), error);
                }
            }
            done.reverse(); Partial::done(UndoAction::Group(done))
        }
        UndoAction::RemovedDirectory(path, mode) => {
            let result = std::fs::create_dir(path).and_then(|_| { use std::os::unix::fs::PermissionsExt; std::fs::set_permissions(path, std::fs::Permissions::from_mode(*mode)) });
            match result { Ok(()) => Partial::done(action.clone()), Err(e) => Partial::stopped(None,Some(action.clone()),e.to_string()) }
        }
        UndoAction::MadeDirectory(path, _) => match std::fs::remove_dir(path) {
            Ok(()) => Partial::done(action.clone()), Err(e) => Partial::stopped(None,Some(action.clone()),e.to_string()),
        },

        UndoAction::Rename(pairs) => {
            let back: Vec<(PathBuf, PathBuf)> = pairs.iter().map(|(f, t)| (t.clone(), f.clone())).collect();
            match batch_rename_pairs(&back) {
                Ok(()) => Partial::done(action.clone()),
                Err(e) => Partial::stopped(None, Some(action.clone()), e),
            }
        }
        UndoAction::Create(paths) => {
            // Never destroy data on undo: created items go to the trash.
            for (i, p) in paths.iter().enumerate() {
                if std::fs::symlink_metadata(p).is_ok() {
                    if let Err(e) = trash::trash(p) {
                        return Partial::stopped(
                            some_if(paths[..i].to_vec(), UndoAction::Create),
                            some_if(paths[i..].to_vec(), UndoAction::Create),
                            format!("{}: {}", file_name(p), e),
                        );
                    }
                }
            }
            Partial::done(action.clone())
        }
        UndoAction::Copy(pairs) => {
            for (i, (_, t)) in pairs.iter().enumerate() {
                if std::fs::symlink_metadata(t).is_ok() {
                    if let Err(e) = trash::trash(t) {
                        return Partial::stopped(
                            some_if(pairs[..i].to_vec(), UndoAction::Copy),
                            some_if(pairs[i..].to_vec(), UndoAction::Copy),
                            format!("{}: {}", file_name(t), e),
                        );
                    }
                }
            }
            Partial::done(action.clone())
        }
        UndoAction::Move(pairs) => {
            for idx in (0..pairs.len()).rev() {
                let (from, to) = &pairs[idx];
                let err = if std::fs::symlink_metadata(from).is_ok() {
                    Some(format!("“{}” exists again at its old place", file_name(from)))
                } else {
                    fsops::move_path(to, from, op).err().map(|e| format!("{}: {}", file_name(to), e))
                };
                if let Some(e) = err {
                    return Partial::stopped(
                        some_if(pairs[idx + 1..].to_vec(), UndoAction::Move),
                        some_if(pairs[..=idx].to_vec(), UndoAction::Move),
                        e,
                    );
                }
            }
            Partial::done(action.clone())
        }
        UndoAction::Trash(items) => {
            let mut restored = Vec::new();
            for (i, it) in items.iter().enumerate() {
                match trash::restore(it) {
                    // Remember where it really landed ("a (2).txt" when the
                    // old name was taken) so Redo trashes this file, not
                    // whatever now lives at the old name.
                    Ok(to) => restored.push(trash::TrashedItem { original: to, ..it.clone() }),
                    Err(e) => {
                        return Partial::stopped(
                            some_if(restored, UndoAction::Trash),
                            some_if(items[i..].to_vec(), UndoAction::Trash),
                            format!("{}: {}", file_name(&it.original), e),
                        )
                    }
                }
            }
            Partial::done(UndoAction::Trash(restored))
        }
    }
}

/// Performs an action again.
fn replay(action: &UndoAction, op: &dyn fsops::Monitor) -> Partial {
    match action {
        UndoAction::Group(actions) => {
            let mut done = Vec::new();
            for (index, action) in actions.iter().enumerate() {
                let part = replay(action, op);
                if let Some(reverse) = part.reverse { done.push(reverse); }
                if let Some(error) = part.error {
                    let mut rest = Vec::new(); if let Some(action) = part.rest { rest.push(action); } rest.extend_from_slice(&actions[index+1..]);
                    return Partial::stopped(some_if(done, UndoAction::Group), some_if(rest, UndoAction::Group), error);
                }
            }
            Partial::done(UndoAction::Group(done))
        }
        UndoAction::MadeDirectory(path, mode) => {
            let result = std::fs::create_dir(path).and_then(|_| { use std::os::unix::fs::PermissionsExt; std::fs::set_permissions(path, std::fs::Permissions::from_mode(*mode)) });
            match result { Ok(()) => Partial::done(action.clone()), Err(e) => Partial::stopped(None,Some(action.clone()),e.to_string()) }
        }
        UndoAction::RemovedDirectory(path, _) => match std::fs::remove_dir(path) {
            Ok(()) => Partial::done(action.clone()), Err(e) => Partial::stopped(None,Some(action.clone()),e.to_string()),
        },

        UndoAction::Rename(pairs) => match batch_rename_pairs(pairs) {
            Ok(()) => Partial::done(action.clone()),
            Err(e) => Partial::stopped(None, Some(action.clone()), e),
        },
        UndoAction::Create(paths) => {
            // Bring the created items back out of the trash when possible.
            let records = trash::list();
            let mut back = Vec::new();
            for p in paths {
                if let Some(rec) = records.iter().filter(|r| &r.original == p).max_by(|a, b| a.deleted.cmp(&b.deleted)) {
                    if let Ok(to) = trash::restore(rec) {
                        back.push(to);
                    }
                }
            }
            if back.is_empty() {
                return Partial::stopped(None, None, "the items are no longer in the trash".into());
            }
            Partial::done(UndoAction::Create(back))
        }
        UndoAction::Copy(pairs) => {
            let mut made = Vec::new();
            for (i, (src, dst)) in pairs.iter().enumerate() {
                let target = if std::fs::symlink_metadata(dst).is_ok() {
                    fsops::unique_name(dst.parent().unwrap_or(Path::new("/")), &file_name(dst))
                } else {
                    dst.clone()
                };
                if let Err(e) = fsops::copy_tree(src, &target, op) {
                    return Partial::stopped(
                        some_if(made, UndoAction::Copy),
                        some_if(pairs[i..].to_vec(), UndoAction::Copy),
                        format!("{}: {}", file_name(src), e),
                    );
                }
                made.push((src.clone(), target));
            }
            Partial::done(UndoAction::Copy(made))
        }
        UndoAction::Move(pairs) => {
            for (i, (from, to)) in pairs.iter().enumerate() {
                if let Err(e) = fsops::move_path(from, to, op) {
                    return Partial::stopped(
                        some_if(pairs[..i].to_vec(), UndoAction::Move),
                        some_if(pairs[i..].to_vec(), UndoAction::Move),
                        format!("{}: {}", file_name(from), e),
                    );
                }
            }
            Partial::done(action.clone())
        }
        UndoAction::Trash(items) => {
            let mut again = Vec::new();
            for (i, it) in items.iter().enumerate() {
                match trash::trash(&it.original) {
                    Ok(t) => again.push(t),
                    Err(e) => {
                        return Partial::stopped(
                            some_if(again, UndoAction::Trash),
                            some_if(items[i..].to_vec(), UndoAction::Trash),
                            format!("{}: {}", file_name(&it.original), e),
                        )
                    }
                }
            }
            Partial::done(UndoAction::Trash(again))
        }
    }
}

impl cxx_qt::Initialize for qobject::SeabunnyCore {
    fn initialize(mut self: Pin<&mut Self>) {
        self.as_mut().refresh_system_theme();
        self.as_mut().load_places();
        self.as_mut().load_smb_profiles();
        self.as_mut().refresh_frequent_dirs();
        self.as_mut().update_trash_empty();
        // Warm the application cache off the UI thread.
        std::thread::spawn(|| {
            let _ = apps::all();
        });
        let t = self.qt_thread();
        let dw = watcher::DeviceWatcher::new(move || {
            let _ = t.queue(|core| core.load_drives());
        });
        self.as_mut().rust_mut().device_watcher = dw;
        // Follow wallpaper palette changes without polling.
        let t2 = self.qt_thread();
        let cw = watcher::DirWatcher::new(move || {
            let _ = t2.queue(|core| {
                core.reload_wallpaper_colors();
            });
        });
        if let Some(w) = cw.as_ref() {
            if let Some(dir) = theme::read_wallpaper_colors_source()
                .and_then(|(p, _, _)| Path::new(&p).parent().map(|x| x.to_path_buf()))
                .or_else(|| wallpaper_dirs().into_iter().next())
            {
                w.watch(&dir);
            }
        }
        self.as_mut().rust_mut().color_watcher = cw;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extraction_never_nests_or_overwrites() {
        let d = std::env::temp_dir().join(format!("seabunny-extract-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(d.join("src/demo/sub")).unwrap();
        std::fs::write(d.join("src/demo/sub/a.txt"), b"new").unwrap();
        let arch = d.join("demo.tar.gz");
        archive::compress(&arch, &[d.join("src/demo")], "tar.gz", "", &|| false).unwrap();
        let out = d.join("out");
        std::fs::create_dir_all(out.join("demo/sub")).unwrap();
        std::fs::write(out.join("demo/sub/a.txt"), b"precious").unwrap();
        std::fs::rename(&arch, out.join("demo.tar.gz")).unwrap();
        let arch = out.join("demo.tar.gz");

        // Extract Here next to an existing "demo": the old one is untouched.
        let here = extract_safely(&arch, &out, false, "", 1, &|| false).unwrap().0;
        assert_eq!(std::fs::read(out.join("demo/sub/a.txt")).unwrap(), b"precious");
        assert_eq!(here, vec![out.join("demo (2)")]);
        assert_eq!(std::fs::read(out.join("demo (2)/sub/a.txt")).unwrap(), b"new");

        // Extract to Folder with a single top-level folder: no demo/demo.
        let sub = extract_safely(&arch, &out, true, "", 2, &|| false).unwrap().0;
        assert_eq!(sub, vec![out.join("demo (3)")]);
        assert!(out.join("demo (3)/sub/a.txt").exists());
        // No staging folders are left behind.
        assert!(!std::fs::read_dir(&out).unwrap().flatten().any(|e| e.file_name().to_string_lossy().starts_with(".seabunny-extract")));
        std::fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn path_completion() {
        let d = std::env::temp_dir().join(format!("seabunny-complete-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(d.join("Documents")).unwrap();
        std::fs::create_dir_all(d.join("Downloads")).unwrap();
        std::fs::create_dir_all(d.join("Music")).unwrap();
        std::fs::write(d.join("Mfile"), b"").unwrap();
        let base = d.to_string_lossy().to_string();
        assert_eq!(complete_path(&format!("{}/mu", base), false), format!("{}/Music/", base));
        assert_eq!(complete_path(&format!("{}/Do", base), false), format!("{}/Do", base));
        assert_eq!(complete_path(&format!("{}/Doc", base), false), format!("{}/Documents/", base));
        assert_eq!(complete_path(&format!("{}/zz", base), false), format!("{}/zz", base));
        std::fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn names_are_validated() {
        assert!(validate_name("").is_err());
        assert!(validate_name("a/b").is_err());
        assert!(validate_name("..").is_err());
        assert_eq!(validate_name("  ok.txt ").unwrap(), "ok.txt");
    }

    #[test]
    fn batch_rename_handles_swaps_and_rolls_back() {
        let d = std::env::temp_dir().join(format!("seabunny-batch-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        std::fs::write(d.join("a"), b"A").unwrap();
        std::fs::write(d.join("b"), b"B").unwrap();
        batch_rename_pairs(&[(d.join("a"), d.join("b")), (d.join("b"), d.join("a"))]).unwrap();
        assert_eq!(std::fs::read(d.join("a")).unwrap(), b"B");
        assert_eq!(std::fs::read(d.join("b")).unwrap(), b"A");
        std::fs::write(d.join("c"), b"C").unwrap();
        let err = batch_rename_pairs(&[(d.join("a"), d.join("x")), (d.join("b"), d.join("c"))]);
        assert!(err.is_err());
        assert!(d.join("a").exists() && d.join("b").exists() && !d.join("x").exists());
        let dup = batch_rename_pairs(&[(d.join("a"), d.join("y")), (d.join("b"), d.join("y"))]);
        assert!(dup.is_err());
        std::fs::remove_dir_all(&d).unwrap();
    }
    #[test]
    fn merge_journal_keeps_old_files_and_roundtrips_cut_and_copy() {
        for cut in [false, true] {
            let root = std::env::temp_dir().join(format!("seabunny-merge-journal-{}-{cut}", std::process::id()));
            std::fs::create_dir_all(root.join("source/nested")).unwrap();
            std::fs::create_dir_all(root.join("target/nested")).unwrap();
            std::fs::write(root.join("source/nested/same.txt"), b"new").unwrap();
            std::fs::write(root.join("target/nested/same.txt"), b"old").unwrap();
            std::fs::write(root.join("source/new.txt"), b"new file").unwrap();
            std::fs::write(root.join("target/untouched.txt"), b"keep").unwrap();
            let choices = [(root.join("source/nested/same.txt").to_string_lossy().to_string(), "replace".to_string())].into_iter().collect();
            let mut journal = Vec::new();
            crate::merge::transfer(&root.join("source"), &root.join("target"), cut, &choices, &mut journal, &fsops::Silent).unwrap();
            assert_eq!(std::fs::read(root.join("target/nested/same.txt")).unwrap(),b"new");
            let undone = invert(&UndoAction::Group(journal), &fsops::Silent);
            assert!(undone.error.is_none(), "{:?}", undone.error);
            assert_eq!(std::fs::read(root.join("target/nested/same.txt")).unwrap(),b"old");
            assert!(root.join("source/new.txt").exists());
            let redone = replay(&undone.reverse.unwrap(), &fsops::Silent);
            assert!(redone.error.is_none(), "{:?}", redone.error);
            assert_eq!(std::fs::read(root.join("target/nested/same.txt")).unwrap(),b"new");
            assert_eq!(std::fs::read(root.join("target/untouched.txt")).unwrap(),b"keep");
            std::fs::remove_dir_all(root).unwrap();
        }
    }

}
