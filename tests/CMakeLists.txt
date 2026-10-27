cmake_minimum_required(VERSION 3.21)
project(SeabunnySerpantinumTests LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Test DBus)
qt_standard_project_setup()
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)
qt_add_executable(serpantinum-tests
    tst_serpantinum.cpp
    ../src/serpantinum_palette.h
    ../src/serpantinum_palette.cpp
    ../src/thumbnail_provider.cpp
    ../src/icon_provider.h
    ../src/icon_provider.cpp
    ../src/app_integration.cpp
)
target_include_directories(serpantinum-tests PRIVATE ../src)
target_link_libraries(serpantinum-tests PRIVATE Qt6::Quick Qt6::Test)
set_source_files_properties(../qml/Theme.qml PROPERTIES QT_RESOURCE_ALIAS qml/Theme.qml)
set_source_files_properties(../qml/SerpantinumColors.js PROPERTIES QT_RESOURCE_ALIAS qml/SerpantinumColors.js)
qt_add_qml_module(serpantinum-tests
    URI app.seabunny
    VERSION 1.0
    QML_FILES ../qml/Theme.qml ../qml/SerpantinumColors.js
)
qt_add_resources(FONT_RESOURCES ../assets/resources.qrc)
target_sources(serpantinum-tests PRIVATE ${FONT_RESOURCES})
target_compile_definitions(serpantinum-tests PRIVATE
    SEABUNNY_THEME_PATH="${CMAKE_CURRENT_SOURCE_DIR}/../qml/Theme.qml"
)
enable_testing()
add_test(NAME serpantinum COMMAND serpantinum-tests)
set_tests_properties(serpantinum PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

find_package(KF6WindowSystem REQUIRED)
qt_add_executable(portal-tests tst_portal.cpp ../src/portal_backend.h ../src/portal_backend.cpp)
target_include_directories(portal-tests PRIVATE ../src)
target_link_libraries(portal-tests PRIVATE Qt6::Quick Qt6::Test Qt6::DBus KF6::WindowSystem)
add_test(NAME portal COMMAND portal-tests)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GIO REQUIRED IMPORTED_TARGET gio-unix-2.0)
qt_add_executable(open-with-tests tst_open_with.cpp ../src/open_with.h ../src/open_with.cpp)
target_include_directories(open-with-tests PRIVATE ../src)
target_link_libraries(open-with-tests PRIVATE Qt6::Core Qt6::Test PkgConfig::GIO)
find_package(Python3 REQUIRED COMPONENTS Interpreter)
add_test(NAME open-with COMMAND ${Python3_EXECUTABLE} -B
    ${CMAKE_CURRENT_SOURCE_DIR}/run_open_with_checks.py --native-only
    --native-binary $<TARGET_FILE:open-with-tests>)

qt_add_executable(clipboard-tests tst_clipboard.cpp ../src/app_integration.cpp)
target_include_directories(clipboard-tests PRIVATE ../src)
target_link_libraries(clipboard-tests PRIVATE Qt6::Gui Qt6::Test)
add_test(NAME clipboard COMMAND ${Python3_EXECUTABLE} -B
    ${CMAKE_CURRENT_SOURCE_DIR}/run_clipboard_checks.py --native-binary $<TARGET_FILE:clipboard-tests>)
