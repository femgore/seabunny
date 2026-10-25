pub mod bridge;
mod favorites;
mod folder_sort;
mod permissions;
mod archive;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};

fn main() {
    let arguments = std::env::args().skip(1).collect::<Vec<_>>();
    if arguments == ["--version"] {
        println!("Seabunny {}", env!("CARGO_PKG_VERSION"));
        return;
    }
    if arguments == ["--help"] || arguments == ["-h"] {
        println!("Seabunny — file manager\nUsage: seabunny [FOLDER|ARCHIVE|FILE-URI]...\n\n--version  Show version\n--help     Show this help");
        return;
    }
    let mut app = QGuiApplication::new();
    bridge::qobject::configure_seabunny();
    let mut engine = QQmlApplicationEngine::new();

    // Allow loading QML from the source tree during development:
    //   SEABUNNY_QML=/path/to/main.qml target/debug/seabunny
    // Falls back to the compiled-in qrc resource for normal runs.
    let url = match std::env::var("SEABUNNY_QML") {
        Ok(path) if !path.is_empty() => QUrl::from(&format!("file://{path}")),
        _ => QUrl::from("qrc:/qt/qml/app/seabunny/qml/main.qml"),
    };

    if let Some(mut engine) = engine.as_mut() {
        bridge::qobject::install_thumbnail_provider(engine.as_mut());
        engine.load(&url);
    }

    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
