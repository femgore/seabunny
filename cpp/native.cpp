#include "seabunny/native.h"
#include "seabunny/thumbnails.h"
#include "icon_provider.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusReply>
#include <QFileInfo>
#include <QGuiApplication>
#include <QLocale>
#include <QMimeData>
#include <QMimeDatabase>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTranslator>
#include <QJsonDocument>
#include <QJsonArray>
#include <QUrl>

namespace seabunny {

static const char *kService = "org.femgore.Seabunny";
static const char *kPath = "/org/femgore/Seabunny";

static QString toQString(rust::Str s)
{
    return QString::fromUtf8(s.data(), static_cast<qsizetype>(s.size()));
}

static rust::String toRust(const QString &s)
{
    const QByteArray utf8 = s.toUtf8();
    return rust::String(utf8.constData(), static_cast<size_t>(utf8.size()));
}

// Accepts plain paths and file:// URIs; returns absolute local paths.
static QStringList toLocalPaths(const QStringList &items)
{
    QStringList out;
    for (const QString &item : items) {
        if (item.isEmpty())
            continue;
        const QUrl url = item.startsWith(QLatin1Char('/')) ? QUrl::fromLocalFile(item) : QUrl::fromUserInput(item);
        if (url.isLocalFile() && (url.host().isEmpty() || url.host() == "localhost"))
            out << QFileInfo(url.toLocalFile()).absoluteFilePath();
    }
    return out;
}

SeabunnyNative::SeabunnyNative(QObject *parent)
    : QObject(parent)
{
    if (QClipboard *cb = QGuiApplication::clipboard()) {
        // Parse once per change: reading another app's clipboard can block,
        // so menus must never do it synchronously.
        connect(cb, &QClipboard::dataChanged, this, [this] {
            m_clipboard = readClipboard();
            Q_EMIT clipboardChanged();
        });
        m_clipboard = readClipboard();
    }
}

void SeabunnyNative::setClipboardFiles(const QStringList &paths, bool cut)
{
    if (paths.isEmpty()) return;
    QList<QUrl> urls;
    QByteArray gnome = cut ? "cut" : "copy";
    QStringList plain;
    for (const QString &p : paths) {
        const QUrl u = QUrl::fromLocalFile(p);
        urls << u;
        gnome += '\n' + u.toEncoded();
        plain << p;
    }
    auto *data = new QMimeData;
    if (paths.first().startsWith("archive://")) {
        data->setData("application/x-seabunny-archive-files", QJsonDocument(QJsonArray::fromStringList(paths)).toJson(QJsonDocument::Compact));
        QGuiApplication::clipboard()->setMimeData(data); return;
    }
    data->setUrls(urls);
    data->setData(QStringLiteral("x-special/gnome-copied-files"), gnome);
    data->setData(QStringLiteral("application/x-kde-cutselection"), cut ? "1" : "0");
    data->setData(QStringLiteral("application/x-seabunny-files"), gnome);
    data->setText(plain.join(QLatin1Char('\n')));
    QGuiApplication::clipboard()->setMimeData(data);
}

QVariantMap SeabunnyNative::clipboardFiles() const
{
    return m_clipboard;
}

QVariantMap SeabunnyNative::readClipboard() const
{
    QVariantMap result{{QStringLiteral("cut"), false}, {QStringLiteral("paths"), QStringList()}};
    const QMimeData *data = QGuiApplication::clipboard()->mimeData();
    if (!data)
        return result;
    bool cut = false;
    QStringList paths;
    if (data->hasFormat("application/x-seabunny-archive-files")) {
        const auto entries = QJsonDocument::fromJson(data->data("application/x-seabunny-archive-files")).array();
        for (const auto &entry : entries) if (entry.toString().startsWith("archive://")) paths.append(entry.toString());
        result[QStringLiteral("paths")] = paths; return result;
    }
    if (data->hasFormat(QStringLiteral("x-special/gnome-copied-files"))) {
        const QList<QByteArray> lines = data->data(QStringLiteral("x-special/gnome-copied-files")).split('\n');
        for (int i = 0; i < lines.size(); ++i) {
            const QByteArray line = lines[i].trimmed();
            if (i == 0 && (line == "cut" || line == "copy")) {
                cut = line == "cut";
                continue;
            }
            if (line.isEmpty())
                continue;
            const QUrl u = QUrl::fromEncoded(line);
            if (u.isLocalFile() && (u.host().isEmpty() || u.host() == "localhost"))
                paths << u.toLocalFile();
        }
    }
    if (paths.isEmpty() && data->hasUrls()) {
        for (const QUrl &u : data->urls()) {
            if (u.isLocalFile() && (u.host().isEmpty() || u.host() == "localhost"))
                paths << u.toLocalFile();
        }
        cut = data->data(QStringLiteral("application/x-kde-cutselection")) == "1";
    }
    result[QStringLiteral("cut")] = cut;
    result[QStringLiteral("paths")] = paths;
    return result;
}

bool SeabunnyNative::clipboardHasFiles() const
{
    return !clipboardFiles().value(QStringLiteral("paths")).toStringList().isEmpty();
}

void SeabunnyNative::setClipboardText(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
}

void SeabunnyNative::clearClipboardIfOurs()
{
    const QMimeData *data = QGuiApplication::clipboard()->mimeData();
    if (data && data->hasFormat(QStringLiteral("application/x-seabunny-files")))
        QGuiApplication::clipboard()->clear();
}

void SeabunnyNative::pruneCutClipboard() {
    const auto current = readClipboard();
    if (!current.value("cut").toBool()) return;
    const auto paths = current.value("paths").toStringList();
    QStringList remaining;
    for (const auto &path : paths) { QFileInfo info(path); if (info.exists() || info.isSymLink()) remaining.append(path); }
    if (remaining.size() == paths.size()) return;
    if (remaining.isEmpty()) QGuiApplication::clipboard()->clear();
    else setClipboardFiles(remaining, true);
}

QString SeabunnyNative::mimeType(const QString &path, bool sniffContents) const
{
    static QMimeDatabase db;
    return db.mimeTypeForFile(path, sniffContents ? QMimeDatabase::MatchDefault : QMimeDatabase::MatchExtension).name();
}

QString SeabunnyNative::mimeComment(const QString &path) const
{
    static QMimeDatabase db;
    return db.mimeTypeForFile(path).comment();
}

QStringList SeabunnyNative::takePendingOpen()
{
    QStringList out;
    out.swap(m_pending);
    return out;
}

void SeabunnyNative::queueOpen(const QStringList &paths, const QString &mode)
{
    m_pending = paths;
    if (!mode.isEmpty())
        m_mode = mode;
    Q_EMIT openRequested(paths, mode);
}

bool SeabunnyNative::isAdmin() const
{
    return !qEnvironmentVariable("SEABUNNY_ADMIN").isEmpty();
}

FileManager1Adaptor::FileManager1Adaptor(QObject *host, SeabunnyNative *native)
    : QDBusAbstractAdaptor(host), m_native(native) {}

void FileManager1Adaptor::ShowFolders(const QStringList &uris, const QString &)
{
    Q_EMIT m_native->openRequested(toLocalPaths(uris), QStringLiteral("tab"));
}

void FileManager1Adaptor::ShowItems(const QStringList &uris, const QString &)
{
    Q_EMIT m_native->openRequested(toLocalPaths(uris), QStringLiteral("select"));
}

void FileManager1Adaptor::ShowItemProperties(const QStringList &uris, const QString &)
{
    Q_EMIT m_native->openRequested(toLocalPaths(uris), QStringLiteral("properties"));
}

SeabunnyAppAdaptor::SeabunnyAppAdaptor(QObject *host, SeabunnyNative *native)
    : QDBusAbstractAdaptor(host), m_native(native) {}

void SeabunnyAppAdaptor::Open(const QStringList &paths, const QString &mode)
{
    Q_EMIT m_native->openRequested(toLocalPaths(paths), mode.isEmpty() ? QStringLiteral("tab") : mode);
}

bool forward_to_running_instance(const rust::Vec<rust::String> &paths, rust::Str mode)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected() || !bus.interface())
        return false;
    if (!bus.interface()->isServiceRegistered(QString::fromLatin1(kService)))
        return false;
    QStringList raw;
    for (const rust::String &p : paths)
        raw << QString::fromUtf8(p.data(), static_cast<qsizetype>(p.size()));
    QDBusMessage msg = QDBusMessage::createMethodCall(QString::fromLatin1(kService), QString::fromLatin1(kPath),
                                                      QStringLiteral("org.femgore.Seabunny"), QStringLiteral("Open"));
    msg << toLocalPaths(raw) << toQString(mode);
    // A hung instance must not stall this launch for long.
    QDBusMessage reply = bus.call(msg, QDBus::Block, 3000);
    return reply.type() == QDBusMessage::ReplyMessage;
}

void setup_engine(QQmlApplicationEngine &engine, const rust::Vec<rust::String> &paths, rust::Str mode)
{
    auto *native = new SeabunnyNative(&engine);
    QStringList raw;
    for (const rust::String &p : paths)
        raw << QString::fromUtf8(p.data(), static_cast<qsizetype>(p.size()));
    // mode: "tab" or "mini", optionally with ",new-window".
    const QString modeStr = toQString(mode);
    const bool newWindow = modeStr.contains(QLatin1String("new-window"));
    native->queueOpen(toLocalPaths(raw), modeStr.section(QLatin1Char(','), 0, 0));

    QDBusConnection bus = QDBusConnection::sessionBus();
    // A separate window or an admin (root) instance must not take over the
    // user's services.
    if (bus.isConnected() && !native->isAdmin() && !newWindow) {
        // One object per path, each exporting just its own interface.
        auto *appObj = new QObject(native);
        new SeabunnyAppAdaptor(appObj, native);
        auto *fmObj = new QObject(native);
        new FileManager1Adaptor(fmObj, native);
        if (bus.registerService(QString::fromLatin1(kService)))
            bus.registerObject(QString::fromLatin1(kPath), appObj, QDBusConnection::ExportAdaptors);
        else
            qWarning("seabunny: another instance already owns %s", kService);
        // FileManager1 stays with whichever file manager claimed it first.
        if (bus.registerService(QStringLiteral("org.freedesktop.FileManager1")))
            bus.registerObject(QStringLiteral("/org/freedesktop/FileManager1"), fmObj, QDBusConnection::ExportAdaptors);
    }

    auto *translator = new QTranslator(&engine);
    if (translator->load(QLocale(), QStringLiteral("seabunny"), QStringLiteral("_"), QStringLiteral(":/i18n")))
        QCoreApplication::installTranslator(translator);

    engine.rootContext()->setContextProperty(QStringLiteral("native"), native);
    engine.addImageProvider(QStringLiteral("thumb"), new ThumbnailProvider);
    install_icon_provider(engine);
}

rust::String mime_type_for(rust::Str path, bool sniff)
{
    static QMimeDatabase db;
    return toRust(db.mimeTypeForFile(toQString(path), sniff ? QMimeDatabase::MatchDefault : QMimeDatabase::MatchExtension).name());
}

rust::String mime_comment_for(rust::Str mime)
{
    static QMimeDatabase db;
    return toRust(db.mimeTypeForName(toQString(mime)).comment());
}

void set_application_identity(rust::Str version)
{
    QCoreApplication::setApplicationVersion(toQString(version));
    QCoreApplication::setApplicationName(QStringLiteral("seabunny"));
    QCoreApplication::setOrganizationName(QStringLiteral("seabunny"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("Seabunny"));
    QGuiApplication::setDesktopFileName(QStringLiteral("org.femgore.Seabunny"));
}

} // namespace seabunny
