pub mod merge;
pub mod favorites;
pub mod integration;
pub mod folder_sort;
pub mod permissions;
pub mod apps;
pub mod archive_reader;
pub mod archive;
pub mod core;
pub mod drives;
pub mod fsops;
pub mod icons;
pub mod info;
pub mod listing;
pub mod native;
pub mod pane;
pub mod search;
pub mod share;
pub mod smb;
pub mod state;
pub mod theme;
pub mod trash;
pub mod util;
pub mod watcher;
pub mod xdg;

use cxx_qt_lib::QGuiApplication;
fn main() {
    let mut app = QGuiApplication::new();
    integration::ffi::configure_seabunny();
    if !integration::ffi::start_seabunny_portal() { std::process::exit(1); }
    if let Some(app) = app.as_mut() { app.exec(); }
}
