#[cxx_qt::bridge]
pub mod ffi {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("seabunny/src/app_integration.h");
        fn configure_seabunny();
        fn seabunny_sidebar_state(chooser: bool) -> QString;
        fn seabunny_save_sidebar_state(chooser: bool, expanded: bool, width: f64) -> bool;
        fn seabunny_matches_filter(path: &QString, rules: &QString) -> bool;
        include!("seabunny/src/open_with.h");
        fn seabunny_open_with_apps(paths: &QString) -> QString;
        fn seabunny_open_with(paths: &QString, desktop_id: &QString, make_default: bool) -> QString;
        fn seabunny_set_default_app(paths: &QString, desktop_id: &QString) -> QString;
        fn seabunny_open_file(path: &QString) -> QString;
        include!("seabunny/src/portal_backend.h");
        fn start_seabunny_portal() -> bool;
        fn seabunny_portal_mode() -> bool;
    }
}
