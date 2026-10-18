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
    QCoreApplication::setApplicationVersion("0.1.0");
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
