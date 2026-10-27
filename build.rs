use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    let gio_flags = std::process::Command::new("pkg-config")
        .args(["--cflags", "gio-unix-2.0"]).output().expect("pkg-config is required");
    assert!(gio_flags.status.success(), "GLib/GIO development files are required for Open With");
    let gio_libs = std::process::Command::new("pkg-config")
        .args(["--libs", "gio-unix-2.0"]).output().expect("pkg-config is required");
    assert!(gio_libs.status.success());
    for flag in String::from_utf8_lossy(&gio_libs.stdout).split_whitespace() {
        if let Some(name) = flag.strip_prefix("-l") { println!("cargo:rustc-link-lib={name}"); }
        else if let Some(path) = flag.strip_prefix("-L") { println!("cargo:rustc-link-search={path}"); }
        else { println!("cargo:rustc-link-arg={flag}"); }
    }
    let kf_include = std::process::Command::new("pkg-config")
        .args(["--variable=includedir", "KF6WindowSystem"]).output().expect("pkg-config is required");
    assert!(kf_include.status.success(), "KF6WindowSystem development files are required for portal parenting");
    println!("cargo:rustc-link-lib=KF6WindowSystem");
    let kf_lib = std::process::Command::new("pkg-config")
        .args(["--variable=libdir", "KF6WindowSystem"]).output().expect("pkg-config is required");
    assert!(kf_lib.status.success());
    println!("cargo:rustc-link-search={}", String::from_utf8_lossy(&kf_lib.stdout).trim());
    // cxx-qt's customization API is unsafe because it can alter compiler invariants;
    // only an include search directory is added here.
    unsafe { CxxQtBuilder::new_qml_module(
        QmlModule::new("app.seabunny")
            .qml_file("qml/main.qml")
            .qml_file("qml/SeabunnyLogo.qml")
            .qml_file("qml/FolderTabs.qml")
            .qml_file("qml/Theme.qml")
            .qml_file("qml/SeabunnyIcon.qml")
            .qml_file("qml/SettingsView.qml")
            .qml_file("qml/PCView.qml")
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
            .qml_file("qml/components/DriveCard.qml")
    )
    .qrc("assets/resources.qrc")
    .qrc_resources(["qml/SerpantinumColors.js", "qml/Sidebar.js"])
    .file("src/bridge.rs")
    .cpp_file("src/serpantinum_palette.h")
    .cpp_file("src/serpantinum_palette.cpp")
    .cpp_file("src/thumbnail_provider.cpp")
    .cpp_file("src/icon_provider.h")
    .cpp_file("src/icon_provider.cpp")
    .cpp_file("src/app_integration.h")
    .cpp_file("src/app_integration.cpp")
    .cpp_file("src/open_with.h")
    .cpp_file("src/open_with.cpp")
    .cpp_file("src/portal_backend.h")
    .cpp_file("src/portal_backend.cpp")
    .cc_builder(|cc| {
        cc.include(String::from_utf8_lossy(&kf_include.stdout).trim());
        for flag in String::from_utf8_lossy(&gio_flags.stdout).split_whitespace() { cc.flag(flag); }
    })
    .qt_module("DBus")
    .qt_module("Quick")
    .build(); }
}
