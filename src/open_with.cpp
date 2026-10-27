#include "open_with.h"
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeDatabase>
#include <QProcess>
#include <QSet>
#include <QUrl>
#include <algorithm>
// Qt's signals macro conflicts with a field in the GLib headers.
#undef signals
#include <gio/gdesktopappinfo.h>

namespace {
QString errorText(GError *error, const char *fallback) {
    const QString text = error ? QString::fromUtf8(error->message) : QString::fromUtf8(fallback);
    if (error) g_error_free(error);
    return text;
}

QStringList pathsFromJson(const QString &json) {
    const auto document = QJsonDocument::fromJson(json.toUtf8());
    if (!document.isArray()) return {};
    QStringList paths;
    for (const auto &value : document.array()) {
        const QString path = value.toString();
        const QFileInfo info(path);
        if (!info.isAbsolute() || !info.exists() || (!info.isFile() && !info.isDir())) return {};
        if (!paths.contains(path)) paths.append(path);
    }
    return paths;
}

QString commonType(const QStringList &paths) {
    QMimeDatabase database;
    QString type;
    for (const QString &path : paths) {
        const QString next = database.mimeTypeForFile(path).name();
        if (!type.isEmpty() && type != next) return {};
        type = next;
    }
    return type;
}

QByteArray fileHeader(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.read(256) : QByteArray();
}

bool isNativeProgram(const QFileInfo &info, const QByteArray &header) {
    return info.isFile() && (info.suffix().compare("appimage", Qt::CaseInsensitive) == 0
        || info.suffix().compare("desktop", Qt::CaseInsensitive) == 0
        || header.startsWith(QByteArray("\x7f" "ELF", 4)) || (header.startsWith("#!") && info.isExecutable()));
}

bool containsProgram(const QStringList &paths) {
    return std::any_of(paths.begin(), paths.end(), [](const QString &path) {
        const QFileInfo info(path);
        return info.isFile() && isNativeProgram(info, fileHeader(path));
    });
}

bool isSeabunny(GAppInfo *app) {
    const QString id = QString::fromUtf8(g_app_info_get_id(app) ? g_app_info_get_id(app) : "");
    const char *command = g_app_info_get_executable(app);
    const QString executable = command ? QFileInfo(QString::fromUtf8(command)).fileName() : QString();
    return id == "org.femgore.Seabunny.desktop" || id.toLower() == "seabunny.desktop"
        || executable == "seabunny" || executable == "seabunny.fish"
        || executable == "xdg-desktop-portal-seabunny";
}

bool selectable(GAppInfo *app, bool foldersOnly = false) {
    const char *id = g_app_info_get_id(app);
    return id && (foldersOnly || !isSeabunny(app)) && g_app_info_should_show(app)
        && (g_app_info_supports_files(app) || g_app_info_supports_uris(app));
}
}

QString seabunny_open_with_apps(const QString &json) {
    const QStringList paths = pathsFromJson(json);
    if (paths.isEmpty()) return "{\"error\":\"The selected items are no longer available.\"}";
    const QString type = commonType(paths);
    const bool foldersOnly = std::all_of(paths.begin(), paths.end(), [](const QString &path) { return QFileInfo(path).isDir(); });
    const QByteArray mime = type.toUtf8();
    QSet<QString> recommended;
    GList *related = type.isEmpty() ? nullptr : g_app_info_get_all_for_type(mime.constData());
    for (GList *item = related; item; item = item->next) {
        const char *id = g_app_info_get_id(G_APP_INFO(item->data));
        if (id) recommended.insert(QString::fromUtf8(id));
    }
    g_list_free_full(related, g_object_unref);
    GAppInfo *current = type.isEmpty() ? nullptr : g_app_info_get_default_for_type(mime.constData(), false);
    const QString defaultId = current && g_app_info_get_id(current)
        ? QString::fromUtf8(g_app_info_get_id(current)) : QString();
    if (current) g_object_unref(current);
    QList<QJsonObject> apps;
    GList *all = g_app_info_get_all();
    for (GList *item = all; item; item = item->next) {
        auto app = G_APP_INFO(item->data);
        if (!selectable(app, foldersOnly)) continue;
        const QString id = QString::fromUtf8(g_app_info_get_id(app));
        QString icon = "application-x-executable";
        GIcon *gicon = g_app_info_get_icon(app);
        if (gicon && G_IS_THEMED_ICON(gicon)) {
            const char *const *names = g_themed_icon_get_names(G_THEMED_ICON(gicon));
            if (names && names[0]) icon = QString::fromUtf8(names[0]);
        } else if (gicon && G_IS_FILE_ICON(gicon)) {
            char *path = g_file_get_path(g_file_icon_get_file(G_FILE_ICON(gicon)));
            if (path) { icon = QUrl::fromLocalFile(QString::fromUtf8(path)).toString(); g_free(path); }
        }
        apps.append(QJsonObject{{"id", id}, {"name", QString::fromUtf8(g_app_info_get_display_name(app))},
            {"icon", icon}, {"recommended", recommended.contains(id)}, {"isDefault", id == defaultId}});
    }
    g_list_free_full(all, g_object_unref);
    std::sort(apps.begin(), apps.end(), [](const auto &left, const auto &right) {
        if (left["isDefault"].toBool() != right["isDefault"].toBool()) return left["isDefault"].toBool();
        if (left["recommended"].toBool() != right["recommended"].toBool()) return left["recommended"].toBool();
        return QString::localeAwareCompare(left["name"].toString(), right["name"].toString()) < 0;
    });
    QJsonArray array;
    for (const auto &app : apps) array.append(app);
    const bool program = containsProgram(paths);
    const QJsonObject result{{"apps", array}, {"mimeType", type}, {"canSetDefault", !type.isEmpty() && !program},
        {"defaultNote", program ? "Programs run directly. Open With uses this application once."
                                : "Select items of one file type to set a default."},
        {"typeName", type.isEmpty() ? "these files" : QMimeDatabase().mimeTypeForName(type).comment()}};
    return QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact));
}

QString seabunny_open_with(const QString &json, const QString &desktopId, bool makeDefault) {
    const QStringList paths = pathsFromJson(json);
    if (paths.isEmpty()) return "The selected items are no longer available.";
    if (!desktopId.endsWith(".desktop") || desktopId.contains('/') || desktopId.contains('\\'))
        return "Choose an installed application.";
    const QString type = commonType(paths);
    if (makeDefault && type.isEmpty()) return "Choose files of one type to set a default application.";
    if (makeDefault && containsProgram(paths)) return "Programs run directly. Choose an application without setting a default.";
    auto desktop = g_desktop_app_info_new(desktopId.toUtf8().constData());
    if (!desktop) return "This application is no longer installed.";
    GAppInfo *app = G_APP_INFO(desktop);
    const bool foldersOnly = std::all_of(paths.begin(), paths.end(), [](const QString &path) { return QFileInfo(path).isDir(); });
    if (!selectable(app, foldersOnly)) {
        const QString message = isSeabunny(app) ? "Choose an application other than Seabunny to open this file."
                                              : "This application cannot open files.";
        g_object_unref(app);
        return message;
    }
    GList *files = nullptr;
    for (const auto &path : paths) files = g_list_append(files, g_file_new_for_path(QFile::encodeName(path).constData()));
    GError *error = nullptr;
    const bool launched = g_app_info_launch(app, files, nullptr, &error);
    g_list_free_full(files, g_object_unref);
    QString failure;
    if (!launched) failure = errorText(error, "The application could not be opened.");
    else if (makeDefault && !g_app_info_set_as_default_for_type(app, type.toUtf8().constData(), &error))
        failure = "The application opened, but its default could not be saved: " + errorText(error, "Unknown error");
    g_object_unref(app);
    return failure;
}

QString seabunny_open_file(const QString &path) {
    const QFileInfo info(path);
    if (!info.isAbsolute() || !info.isFile()) return "This file is missing or unavailable.";
    const QByteArray header = fileHeader(path);
    const bool program = isNativeProgram(info, header);
    if (program) {
        if (!info.isExecutable()) return "This program is not executable. Enable Make executable in Properties first.";
        if (info.suffix().compare("desktop", Qt::CaseInsensitive) == 0) {
            auto app = g_desktop_app_info_new_from_filename(QFile::encodeName(info.absoluteFilePath()).constData());
            if (!app) return "This desktop launcher is invalid or its application is unavailable.";
            GError *error = nullptr;
            const bool launched = g_app_info_launch(G_APP_INFO(app), nullptr, nullptr, &error);
            g_object_unref(app);
            return launched ? QString() : errorText(error, "Could not launch this application.");
        }
        if (!header.startsWith(QByteArray("\x7f" "ELF", 4)) && !header.startsWith("#!"))
            return "This file is not a valid native program or script.";
        QProcess process;
        process.setProgram(info.absoluteFilePath());
        process.setWorkingDirectory(info.absolutePath());
        if (!process.startDetached()) return "Could not run this program: " + process.errorString();
        return {};
    }
    GError *error = nullptr;
    // Use exactly the MIME lookup used by the picker when it saves the default.
    // URI-based launching can sniff a different type and pick another handler.
    const QByteArray type = commonType({path}).toUtf8();
    GAppInfo *app = g_app_info_get_default_for_type(type.constData(), false);
    if (!app) return "No default application is available for this file type. Choose one with Open With…";
    if (isSeabunny(app)) {
        g_object_unref(app);
        return "Seabunny is registered as this file's handler. Choose another default with Open With…";
    }
    GFile *file = g_file_new_for_path(QFile::encodeName(info.absoluteFilePath()).constData());
    GList files{file, nullptr, nullptr};
    const bool launched = g_app_info_launch(app, &files, nullptr, &error);
    g_object_unref(file);
    g_object_unref(app);
    return launched ? QString() : errorText(error, "Could not open this application.");
}
