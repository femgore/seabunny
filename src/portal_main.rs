pub mod bridge;
mod favorites;
mod folder_sort;
mod archive;

use cxx_qt_lib::QGuiApplication;

fn main() {
    let mut app = QGuiApplication::new();
    bridge::qobject::configure_seabunny();
    if !bridge::qobject::start_seabunny_portal() { std::process::exit(1); }
    if let Some(app) = app.as_mut() { app.exec(); }
}
