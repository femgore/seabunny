use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
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
    .cpp_file("src/portal_backend.h")
    .cpp_file("src/portal_backend.cpp")
    .cc_builder(|cc| { cc.include(String::from_utf8_lossy(&kf_include.stdout).trim()); })
    .qt_module("DBus")
    .qt_module("Quick")
    .build(); }
}
