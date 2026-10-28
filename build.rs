use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    let gio_flags = std::process::Command::new("pkg-config").args(["--cflags", "gio-unix-2.0"]).output().unwrap();
    assert!(gio_flags.status.success());
    let gio_libs = std::process::Command::new("pkg-config").args(["--libs", "gio-unix-2.0"]).output().unwrap();
    assert!(gio_libs.status.success());
    for flag in String::from_utf8_lossy(&gio_libs.stdout).split_whitespace() {
        if let Some(lib) = flag.strip_prefix("-l") { println!("cargo:rustc-link-lib={lib}"); }
        else if let Some(dir) = flag.strip_prefix("-L") { println!("cargo:rustc-link-search={dir}"); }
    }
    let kf_include = std::process::Command::new("pkg-config").args(["--variable=includedir", "KF6WindowSystem"]).output().unwrap();
    println!("cargo:rustc-link-lib=KF6WindowSystem");
    let builder = CxxQtBuilder::new_qml_module(
        QmlModule::new("app.seabunny")
            .qml_file("qml/main.qml")
            .qml_file("qml/Theme.qml")
            .qml_file("qml/SeabunnyIcon.qml")
            .qml_file("qml/SeabunnyLogo.qml")
            .qml_file("qml/SettingsView.qml")
            .qml_file("qml/PCView.qml")
            .qml_file("qml/FilePane.qml")
            .qml_file("qml/Sidebar.qml")
            .qml_file("qml/QuickLook.qml")
            .qml_file("qml/PropertiesDialog.qml")
            .qml_file("qml/BatchRenameDialog.qml")
            .qml_file("qml/ConflictDialog.qml")
            .qml_file("qml/OperationsPanel.qml")
            .qml_file("qml/Toast.qml")
            .qml_file("qml/components/InlineRename.qml")
            .qml_file("qml/components/SeabunnyCheckBox.qml")
            .qml_file("qml/components/SeabunnyRadio.qml")
            .qml_file("qml/components/SeabunnyTextField.qml")
            .qml_file("qml/components/SeabunnyPopup.qml")
            .qml_file("qml/components/SeabunnyMenuItem.qml")
            .qml_file("qml/components/SeabunnyMenu.qml")
            .qml_file("qml/components/SeabunnySegmented.qml")
            .qml_file("qml/components/SeabunnySwitch.qml")
            .qml_file("qml/components/SeabunnyButton.qml")
            .qml_file("qml/components/SeabunnyCard.qml")
            .qml_file("qml/components/SectionHeader.qml")
            .qml_file("qml/components/SeabunnyDialog.qml")
            .qml_file("qml/components/SeabunnyTextPrompt.qml")
            .qml_file("qml/components/UsageBar.qml")
            .qml_file("qml/components/DriveCard.qml"),
    )
    .qt_module("DBus")
    .qt_module("Quick")
    .qrc("assets/resources.qrc")
    .qrc_resources(["qml/SerpantinumColors.js"])
    .file("src/integration.rs")
    .file("src/native.rs")
    .file("src/pane.rs")
    .file("src/core.rs")
    .cpp_file("cpp/seabunny/native.h")
    .cpp_file("cpp/seabunny/thumbnails.h")
    .cpp_file("src/app_integration.h")
    .cpp_file("src/app_integration.cpp")
    .cpp_file("src/open_with.h")
    .cpp_file("src/open_with.cpp")
    .cpp_file("src/serpantinum_palette.h")
    .cpp_file("src/serpantinum_palette.cpp")
    .cpp_file("src/icon_provider.h")
    .cpp_file("src/icon_provider.cpp")
    .cpp_file("src/portal_backend.h")
    .cpp_file("src/portal_backend.cpp")
    .cpp_file("cpp/native.cpp")
    .cpp_file("cpp/thumbnails.cpp");
    // Our own headers live in cpp/ ("seabunny/native.h").
    let builder = unsafe {
        builder.cc_builder(|cc| {
            cc.include("cpp");
            cc.include("src");
            cc.include(String::from_utf8_lossy(&kf_include.stdout).trim());
            for flag in String::from_utf8_lossy(&gio_flags.stdout).split_whitespace() { cc.flag(flag); }
        })
    };
    builder.build();
    // The generated C++ code uses these libraries; with --as-needed the early
    // pkg-config flags are dropped, so repeat GLib and Qt libraries last.
    for flag in String::from_utf8_lossy(&gio_libs.stdout).split_whitespace() {
        if let Some(lib) = flag.strip_prefix("-l") {
            println!("cargo:rustc-link-arg=-l{lib}");
        }
    }
    for lib in ["Qt6Quick", "Qt6Qml", "Qt6DBus", "Qt6Gui", "Qt6Core"] {
        println!("cargo:rustc-link-arg=-l{lib}");
    }
    println!("cargo:rustc-link-lib=static=cxx-qt-lib-cxxqt-generated");
}
