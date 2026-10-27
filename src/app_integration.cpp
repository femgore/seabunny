#include "app_integration.h"
#include <QCoreApplication>
#include <QGuiApplication>
#include <QFileInfo>
#include <QFile>
#include <QDir>
#include <QIcon>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QRegularExpression>
#include <QUrl>
#include <QClipboard>
#include <QMimeData>
#include <QMimeDatabase>
#include <cstdio>
#include <cstring>
#include <cmath>

namespace {
QtMessageHandler previousHandler = nullptr;

void messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &message) {
    if (seabunny_ignorable_focus_warning(type, context, message)) return;
    if (previousHandler) previousHandler(type, context, message);
    else {
        const QByteArray formatted = qFormatLogMessage(type, context, message).toLocal8Bit();
        std::fprintf(stderr, "%s\n", formatted.constData());
    }
}
}

bool seabunny_ignorable_focus_warning(QtMsgType type, const QMessageLogContext &context, const QString &message) {
    if (qEnvironmentVariableIntValue("SEABUNNY_SHOW_QT_FOCUS_WARNINGS") == 1) return false;
    if (type != QtWarningMsg || !context.category || std::strcmp(context.category, "qt.qpa.wayland.textinput") != 0) return false;
    static const QRegularExpression pattern(QStringLiteral(
        "^.*QWaylandTextInputv3::disableSurface\\(wl_surface\\*\\) Trying to disable 0x[0-9a-fA-F]+ but (?:0x0|\\(nil\\)) is focused$"));
    return pattern.match(message).hasMatch();
}

void configure_seabunny() {
    QCoreApplication::setApplicationName("Seabunny");
    QCoreApplication::setOrganizationDomain("github.com/femgore");
    QGuiApplication::setApplicationDisplayName("Seabunny");
    QGuiApplication::setDesktopFileName("org.femgore.Seabunny");
    QGuiApplication::setWindowIcon(QIcon(":/seabunny/branding/seabunny_logo.svg"));
    static bool installed = false;
    if (!installed) {
        previousHandler = qInstallMessageHandler(messageHandler);
        installed = true;
    }
}

QString seabunny_startup_arguments() {
    QJsonArray result;
    bool positionalOnly = false;
    for (const QString &argument : QCoreApplication::arguments().mid(1)) {
        if (!positionalOnly && argument == "--") { positionalOnly = true; continue; }
        if (!positionalOnly && argument.startsWith('-')) continue;
        const QUrl url(argument);
        QString path;
        if (url.isLocalFile() && (url.host().isEmpty() || url.host() == "localhost")) path = url.toLocalFile();
        else if (!argument.contains("://")) path = argument;
        if (!path.isEmpty()) result.append(QFileInfo(path).absoluteFilePath());
    }
    return QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact));
}

// Use the window-system clipboard so separate processes and other file managers
// see the same selection. Never interpret plain clipboard text as file paths.
QString seabunny_clipboard_files() {
    QJsonArray paths;
    bool cut = false;
    const QMimeData *mime = QGuiApplication::clipboard()->mimeData();
    if (mime) {
        QList<QUrl> urls;
        if (mime->hasFormat("x-special/gnome-copied-files")) {
            auto lines = mime->data("x-special/gnome-copied-files").split('\n');
            const auto action = lines.isEmpty() ? QByteArray() : lines.takeFirst().trimmed();
            if (action == "copy" || action == "cut") {
                cut = action == "cut";
                for (const auto &line : lines) if (!line.trimmed().isEmpty()) urls.append(QUrl::fromEncoded(line.trimmed()));
            }
        } else {
            urls = mime->urls();
            cut = mime->data("application/x-kde-cutselection") == "1";
        }
        for (const auto &url : urls) {
            if (url.isValid() && url.isLocalFile() && (url.host().isEmpty() || url.host() == "localhost")) {
                const auto path = url.toLocalFile();
                if (QDir::isAbsolutePath(path) && !paths.contains(path)) paths.append(path);
            }
        }
        // Archive entries are virtual locations, not local files to hand to
        // another application's text/uri-list handler.
        if (paths.isEmpty() && mime->hasFormat("application/x-seabunny-archive-files")) {
            const auto entries = QJsonDocument::fromJson(mime->data("application/x-seabunny-archive-files")).array();
            for (const auto &entry : entries)
                if (entry.isString() && entry.toString().startsWith("seabunny-archive:")) paths.append(entry);
            cut = false;
        }
    }
    return QString::fromUtf8(QJsonDocument(QJsonArray{paths, cut}).toJson(QJsonDocument::Compact));
}

void seabunny_set_clipboard_files(const QString &pathsJson, bool cut) {
    const auto paths = QJsonDocument::fromJson(pathsJson.toUtf8()).array();
    if (paths.isEmpty()) { QGuiApplication::clipboard()->clear(); return; }
    auto *mime = new QMimeData;
    QList<QUrl> urls;
    QJsonArray archives;
    for (const auto &entry : paths) {
        const auto path = entry.toString();
        if (path.startsWith("seabunny-archive:")) archives.append(path);
        else if (QDir::isAbsolutePath(path)) urls.append(QUrl::fromLocalFile(path));
    }
    if (!urls.isEmpty()) {
        mime->setUrls(urls);
        QByteArray gnome = cut ? "cut" : "copy";
        for (const auto &url : urls) gnome += '\n' + url.toEncoded();
        mime->setData("x-special/gnome-copied-files", gnome);
        mime->setData("application/x-kde-cutselection", cut ? "1" : "0");
    }
    if (!archives.isEmpty()) mime->setData("application/x-seabunny-archive-files", QJsonDocument(archives).toJson(QJsonDocument::Compact));
    QGuiApplication::clipboard()->setMimeData(mime);
}

namespace {
QString sidebarStatePath(bool chooser) {
    const QString state = qEnvironmentVariable("XDG_STATE_HOME", QDir::homePath() + "/.local/state");
    return state + "/seabunny/" + (chooser ? "chooser-sidebar.json" : "explorer-sidebar.json");
}
bool validSidebarState(const QJsonObject &state) {
    const double width = state.value("width").toDouble(0);
    return state.value("version").toInt() == 1 && state.value("expanded").isBool()
        && std::isfinite(width) && width >= 180 && width <= 520;
}
}

QString seabunny_sidebar_state(bool chooser) {
    QFile file(sidebarStatePath(chooser));
    if (QFileInfo(file).isSymLink() || !file.open(QIODevice::ReadOnly) || file.size() > 4096) return {};
    const auto state = QJsonDocument::fromJson(file.readAll()).object();
    if (!validSidebarState(state)) return {};
    return QString::fromUtf8(QJsonDocument(state).toJson(QJsonDocument::Compact));
}

bool seabunny_save_sidebar_state(bool chooser, bool expanded, double width) {
    if (!std::isfinite(width) || width < 180 || width > 520) return false;
    const QString path = sidebarStatePath(chooser);
    const QFileInfo existing(path);
    // Retain malformed, future-version or symlinked state instead of replacing it.
    if (existing.isSymLink() || (existing.exists() && seabunny_sidebar_state(chooser).isEmpty())) return false;
    if (!QDir().mkpath(existing.absolutePath())) return false;
    QSaveFile file(path);
    const auto data = QJsonDocument(QJsonObject{{"version", 1}, {"expanded", expanded}, {"width", width}})
                          .toJson(QJsonDocument::Compact);
    if (!file.open(QIODevice::WriteOnly) || file.write(data) != data.size() || !file.commit()) {
        qWarning("Seabunny could not save sidebar state");
        return false;
    }
    return true;
}

bool seabunny_matches_filter(const QString &path, const QString &rulesJson) {
    const auto rules = QJsonDocument::fromJson(rulesJson.toUtf8()).array();
    if (rules.isEmpty()) return true;
    for (const auto &value : rules) {
        const auto rule = value.toObject(); const auto pattern = rule.value("pattern").toString();
        if (rule.value("kind").toInt() == 0 && QRegularExpression(QRegularExpression::wildcardToRegularExpression(pattern)).match(QFileInfo(path).fileName()).hasMatch()) return true;
        if (rule.value("kind").toInt() == 1) {
            const auto mime = QMimeDatabase().mimeTypeForFile(path, QMimeDatabase::MatchExtension);
            if (mime.inherits(pattern) || (pattern.endsWith("/*") && mime.name().startsWith(pattern.left(pattern.size()-1)))) return true;
        }
    }
    return false;
}
