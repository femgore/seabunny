#include "serpantinum_palette.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>

SerpantinumPalette::SerpantinumPalette(QObject *parent)
    : QObject(parent), m_watcher(this), m_debounce(this) {
    m_path = qEnvironmentVariable("SEABUNNY_SERPANTINUM_COLORS");
    if (m_path.isEmpty()) m_path = qEnvironmentVariable("QS_COLORS_JSON");
    if (m_path.isEmpty()) {
        QString state = qEnvironmentVariable("XDG_STATE_HOME");
        if (state.isEmpty()) state = QDir::homePath() + "/.local/state";
        m_path = state + "/serpantinum/qs_colors.json";
    }
    m_path = QFileInfo(m_path).absoluteFilePath();
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(60);
    connect(&m_debounce, &QTimer::timeout, this, &SerpantinumPalette::reload);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this,
            [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this,
            [this] { m_debounce.start(); });
    reload();
}

void SerpantinumPalette::setStatus(const QString &status) {
    if (m_status == status) return;
    m_status = status;
    emit statusChanged();
}

void SerpantinumPalette::watchSource() {
    QString directory = QFileInfo(m_path).absolutePath();
    while (!QFileInfo::exists(directory)) {
        const QString parent = QFileInfo(directory).absolutePath();
        if (parent == directory) break;
        directory = parent;
    }
    const QStringList directories = m_watcher.directories();
    for (const QString &watched : directories) {
        if (watched != directory) m_watcher.removePath(watched);
    }
    if (!m_watcher.directories().contains(directory)) m_watcher.addPath(directory);
    if (QFileInfo::exists(m_path) && !m_watcher.files().contains(m_path))
        m_watcher.addPath(m_path);
}

void SerpantinumPalette::reload() {
    watchSource();
    QFile file(m_path);
    if (!file.open(QIODevice::ReadOnly)) {
        setStatus("Palette unavailable; using the last valid palette or Seabunny Violet.");
        return;
    }
    const QByteArray contents = file.read(65537);
    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(contents, &error);
    if (contents.size() > 65536 || error.error != QJsonParseError::NoError || !document.isObject()) {
        setStatus("Invalid palette; keeping the last valid colors.");
        return;
    }
    QJsonObject object = document.object();
    if (object.value("colors").isObject()) object = object.value("colors").toObject();
    static const QStringList names = {
        "base", "mantle", "crust", "text", "subtext0", "subtext1",
        "surface0", "surface1", "surface2", "overlay0", "overlay1", "overlay2",
        "blue", "sapphire", "peach", "green", "red", "mauve", "pink", "yellow", "maroon", "teal"
    };
    static const QRegularExpression hex("^#[0-9a-fA-F]{6}$");
    QVariantMap next;
    for (const QString &name : names) {
        const QString value = object.value(name).toString();
        if (!hex.match(value).hasMatch()) {
            setStatus("Incomplete palette; keeping the last valid colors.");
            return;
        }
        next.insert(name, value);
    }
    if (next != m_colors) {
        m_colors = next;
        emit colorsChanged();
    }
    setStatus("Following Serpantinum's active palette.");
}
