#include "portal_backend.h"
#ifndef SEABUNNY_PORTAL_CONTROLLER_TEST
#include "seabunny/native.h"
#endif
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMetaType>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QMimeDatabase>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QRegularExpression>
#include <QSet>
#include <QUrl>
#include <QWindow>
#include <KWindowSystem>

#define PORTAL_STRUCT(Type, Write, Read) \
QDBusArgument &operator<<(QDBusArgument &a, const Type &v) { a.beginStructure(); Write; a.endStructure(); return a; } \
const QDBusArgument &operator>>(const QDBusArgument &a, Type &v) { a.beginStructure(); Read; a.endStructure(); return a; }
PORTAL_STRUCT(PortalRule, a << v.kind << v.pattern, a >> v.kind >> v.pattern)
PORTAL_STRUCT(PortalFilter, a << v.name << v.rules, a >> v.name >> v.rules)
PORTAL_STRUCT(PortalPair, a << v.id << v.value, a >> v.id >> v.value)
PORTAL_STRUCT(PortalChoice, a << v.id << v.label << v.options << v.selected, a >> v.id >> v.label >> v.options >> v.selected)
#undef PORTAL_STRUCT

static bool portalMode = false;
bool seabunny_portal_mode() { return portalMode; }
void register_portal_types() {
    qDBusRegisterMetaType<PortalRule>(); qDBusRegisterMetaType<PortalRules>();
    qDBusRegisterMetaType<PortalFilter>(); qDBusRegisterMetaType<PortalFilters>();
    qDBusRegisterMetaType<PortalPair>(); qDBusRegisterMetaType<PortalPairs>();
    qDBusRegisterMetaType<PortalChoice>(); qDBusRegisterMetaType<PortalChoices>();
    qDBusRegisterMetaType<QList<QByteArray>>();
}
static QString bytesPath(const QVariant &value) {
    auto bytes = qdbus_cast<QByteArray>(value);
    if (bytes.endsWith('\0')) bytes.chop(1);
    if (bytes.contains('\0')) return {};
    const QString decoded = QString::fromUtf8(bytes);
    // Qt's filename APIs cannot faithfully round-trip invalid UTF-8 filenames.
    return decoded.toUtf8() == bytes ? decoded : QString();
}
static bool basename(const QString &name) {
    return !name.isEmpty() && name != "." && name != ".." && !name.contains('/') && !name.contains(QChar(0));
}
static bool exists(const QString &path) {
    QFileInfo info(path); return info.exists() || info.isSymLink();
}
PortalRequest::PortalRequest(const QString &method, const QString &title, const QVariantMap &o, QObject *parent)
    : QObject(parent), m_method(method) {
    const bool save = method == "SaveFile";
    const bool directory = method == "SaveFiles" || (method == "OpenFile" && o.value("directory").toBool());
    QString folder = bytesPath(o.value("current_folder"));
    QString name = o.value("current_name").toString();
    const QString file = bytesPath(o.value("current_file"));
    if (save && QDir::isAbsolutePath(file)) {
        folder = QFileInfo(file).absolutePath();
        if (name.isEmpty()) name = QFileInfo(file).fileName();
    }
    if (!QDir::isAbsolutePath(folder) || !QFileInfo(folder).isDir()) folder = QDir::homePath();
    m_filters = qdbus_cast<PortalFilters>(o.value("filters"));
    const auto current = qdbus_cast<PortalFilter>(o.value("current_filter"));
    int currentIndex = 0;
    if (!current.name.isEmpty()) {
        bool found = false;
        for (int i = 0; i < m_filters.size(); ++i) {
            const auto &f = m_filters[i];
            bool same = f.name == current.name && f.rules.size() == current.rules.size();
            for (int j = 0; same && j < f.rules.size(); ++j)
                same = f.rules[j].kind == current.rules[j].kind && f.rules[j].pattern == current.rules[j].pattern;
            if (same) { currentIndex = i; found = true; break; }
        }
        if (!found) { currentIndex = m_filters.size(); m_filters.append(current); }
    }
    QStringList filterNames;
    for (const auto &f : m_filters) filterNames << f.name;
    m_choices = qdbus_cast<PortalChoices>(o.value("choices"));
    QVariantList choices;
    QSet<QString> choiceIds;
    for (auto &c : m_choices) {
        if (c.id.isEmpty() || choiceIds.contains(c.id)) valid = false;
        choiceIds.insert(c.id);
        QVariantList values;
        if (c.options.isEmpty()) c.options = {{"false", "No"}, {"true", "Yes"}};
        bool found = false;
        for (const auto &p : c.options) { values << QVariantMap{{"id", p.id}, {"label", p.value}}; found |= p.id == c.selected; }
        if (!found) c.selected = c.options.first().id;
        choices << QVariantMap{{"id", c.id}, {"label", c.label}, {"options", values}, {"selected", c.selected}};
    }
    if (method == "SaveFiles") {
        for (auto bytes : qdbus_cast<QList<QByteArray>>(o.value("files"))) {
            const QString fileName = bytesPath(bytes);
            if (!basename(fileName)) valid = false;
            m_files << fileName;
        }
        if (m_files.isEmpty()) valid = false;
    }
    QString label = o.value("accept_label", save ? "Save" : directory ? "Select Folder" : "Open").toString();
    QString acceptKey, displayLabel;
    for (int i = 0; i < label.size(); ++i) {
        if (label[i] == '_' && i + 1 < label.size()) {
            ++i;
            if (label[i] != '_' && acceptKey.isEmpty()) acceptKey = "Alt+" + label.mid(i, 1);
        }
        displayLabel += label[i];
    }
    m_config = {{"title", title}, {"save", save}, {"directory", directory},
        {"multiple", method == "OpenFile" && o.value("multiple").toBool()},
        {"modal", o.value("modal", true)}, {"folder", folder}, {"name", name},
        {"filters", filterNames}, {"filterIndex", currentIndex}, {"choices", choices},
        {"acceptLabel", displayLabel}, {"acceptKey", acceptKey}};
}
QString PortalRequest::filterRules(int index) const {
    QJsonArray rules;
    if (index >= 0 && index < m_filters.size()) for (const auto &rule : m_filters[index].rules)
        rules.append(QJsonObject{{"kind", int(rule.kind)}, {"pattern", rule.pattern}});
    return QString::fromUtf8(QJsonDocument(rules).toJson(QJsonDocument::Compact));
}
bool PortalRequest::matches(const QString &path, int index) const {
    QFileInfo info(path);
    if (info.isDir()) return true;
    if (m_config.value("directory").toBool()) return false;
    if (index < 0 || index >= m_filters.size()) return true;
    QMimeDatabase db;
    for (const auto &r : m_filters[index].rules) {
        if (r.kind == 0 && QRegularExpression(QRegularExpression::wildcardToRegularExpression(r.pattern)).match(info.fileName()).hasMatch()) return true;
        if (r.kind == 1) {
            const auto mime = db.mimeTypeForFile(path, QMimeDatabase::MatchExtension);
            if (mime.inherits(r.pattern) || (r.pattern.endsWith("/*") && mime.name().startsWith(r.pattern.left(r.pattern.size()-1)))) return true;
        }
    }
    return m_filters[index].rules.isEmpty();
}
QString PortalRequest::saveName(const QString &inputName, int filter) const {
    QString name = inputName;
    // Shared by the visible filename field and acceptance, so an inferred
    // extension can be seen and edited before the request is submitted.
    if (basename(name) && QFileInfo(name).suffix().isEmpty() && filter >= 0 && filter < m_filters.size()) {
        QStringList extensions;
        bool ambiguous = false;
        for (const auto &rule : m_filters[filter].rules) {
            if (rule.kind == 0 && QRegularExpression("^\\*\\.[A-Za-z0-9]+$").match(rule.pattern).hasMatch()) extensions << rule.pattern.mid(1);
            else if (rule.kind == 1) {
                const auto suffix = QMimeDatabase().mimeTypeForName(rule.pattern).preferredSuffix();
                if (!suffix.isEmpty()) extensions << "." + suffix;
                else ambiguous = true;
            } else ambiguous = true;
        }
        extensions.removeDuplicates();
        if (!ambiguous && extensions.size() == 1) name += extensions.first();
    }
    return name;
}
QVariantMap PortalRequest::accept(const QString &folder, const QStringList &selected, const QString &inputName,
                                int filter, const QVariantMap &choices, bool overwrite) {
    auto error = [](const QString &s) { return QVariantMap{{"error", s}}; };
    if (m_finished) return error("This request has already finished.");
    if (!QDir::isAbsolutePath(folder) || !QFileInfo(folder).isDir()) return error("Choose an existing local folder.");
    QStringList paths;
    if (m_method == "SaveFile") {
        const QString name = saveName(inputName, filter);
        if (!basename(name)) return error("Enter a filename without slashes.");
        const QString path = QDir(folder).absoluteFilePath(name);
        if (QFileInfo(path).isDir()) return error("That name belongs to a folder.");
        if (exists(path) && (!overwrite || m_confirmPath != path)) {
            m_confirmPath = path;
            return {{"overwrite", true}, {"path", path}};
        }
        paths << path;
    } else if (m_method == "SaveFiles") {
        QString destination = selected.isEmpty() ? folder : selected.first();
        if (!QDir::isAbsolutePath(destination) || !QFileInfo(destination).isDir()) return error("Choose an existing local folder.");
        QSet<QString> reserved;
        for (const auto &name : m_files) {
            QString candidate = QDir(destination).absoluteFilePath(name);
            const QFileInfo info(name);
            const QString suffix = info.completeSuffix().isEmpty() ? "" : "." + info.completeSuffix();
            int n = 1;
            while (exists(candidate) || reserved.contains(candidate)) {
                if (n > 10000) return error("Too many filename collisions in this folder.");
                candidate = QDir(destination).absoluteFilePath(info.baseName() + " (" + QString::number(n++) + ")" + suffix);
            }
            reserved.insert(candidate); paths << candidate;
        }
    } else {
        paths = selected;
        if (paths.isEmpty() && m_config.value("directory").toBool()) paths << folder;
        if (paths.isEmpty()) return error("Select a file.");
        if (!m_config.value("multiple").toBool() && paths.size() != 1) return error("Select one item.");
        for (const auto &path : paths) {
            QFileInfo info(path);
            if (!QDir::isAbsolutePath(path) || !info.exists() ||
                (m_config.value("directory").toBool() ? !info.isDir() : !info.isFile()))
                return error("The selection is not an existing item of the requested type.");
            if (!matches(path, filter)) return error("The selection does not match the selected file type.");
        }
    }
    PortalPairs selectedChoices;
    for (const auto &c : m_choices) {
        const QString value = choices.value(c.id, c.selected).toString();
        bool found = false;
        for (const auto &p : c.options) found |= p.id == value;
        if (!found) return error("Invalid choice value.");
        selectedChoices.append({c.id, value});
    }
    QStringList uris;
    for (const auto &path : paths) uris << QUrl::fromLocalFile(QDir::cleanPath(path)).toString(QUrl::FullyEncoded);
    QVariantMap results{{"uris", uris}};
    if (!m_choices.isEmpty()) results.insert("choices", QVariant::fromValue(selectedChoices));
    if (filter >= 0 && filter < m_filters.size() && m_method != "SaveFiles") results.insert("current_filter", QVariant::fromValue(m_filters[filter]));
    finish(0, results);
    return {{"accepted", true}};
}
void PortalRequest::finish(uint response, const QVariantMap &results) {
    if (m_finished) return;
    m_finished = true;
    if (completed) completed(response, results);
}
void PortalRequest::cancel() { finish(1); }

static const QString root = "/org/freedesktop/portal/desktop";
static const QString iface = "org.freedesktop.impl.portal.FileChooser";
PortalBackend::PortalBackend(QObject *parent) : QDBusVirtualObject(parent) {}
QString PortalBackend::introspect(const QString &path) const {
    if (path != root) return m_pending.contains(path) ? QStringLiteral("<interface name='org.freedesktop.impl.portal.Request'><method name='Close'/></interface>") : QString();
    QString xml = "<interface name='" + iface + "'><property name='version' type='u' access='read'/>";
    for (const auto &method : {"OpenFile", "SaveFile", "SaveFiles"})
        xml += QString("<method name='%1'><arg name='handle' type='o' direction='in'/><arg name='app_id' type='s' direction='in'/><arg name='parent_window' type='s' direction='in'/><arg name='title' type='s' direction='in'/><arg name='options' type='a{sv}' direction='in'/><arg name='response' type='u' direction='out'/><arg name='results' type='a{sv}' direction='out'/></method>").arg(method);
    return xml + "</interface><interface name='org.freedesktop.DBus.Properties'><method name='Get'><arg type='s' direction='in'/><arg type='s' direction='in'/><arg type='v' direction='out'/></method><method name='GetAll'><arg type='s' direction='in'/><arg type='a{sv}' direction='out'/></method></interface>";
}
bool PortalBackend::handleMessage(const QDBusMessage &message, const QDBusConnection &bus) {
    const auto args = message.arguments();
    if (message.path() != root) {
        auto it = m_pending.find(message.path());
        if (it == m_pending.end()) return false;
        if (message.interface() != "org.freedesktop.impl.portal.Request" || message.member() != "Close" || !args.isEmpty()) return false;
        if (it->sender != message.service()) { bus.send(message.createErrorReply(QDBusError::AccessDenied, "Request belongs to another caller")); return true; }
        auto request = it->request;
        bus.send(message.createReply());
        if (request) request->cancel();
        return true;
    }
    if (message.interface() == "org.freedesktop.DBus.Properties") {
        if (message.member() == "Get" && args.size() == 2 && args[0].toString() == iface && args[1].toString() == "version")
            bus.send(message.createReply(QVariantList{QVariant::fromValue(QDBusVariant(uint(3)))}));
        else if (message.member() == "GetAll" && args.size() == 1 && args[0].toString() == iface)
            bus.send(message.createReply(QVariantList{QVariantMap{{"version", uint(3)}}}));
        else bus.send(message.createErrorReply(QDBusError::InvalidArgs, "Unknown property"));
        return true;
    }
    if (message.interface() != iface || !QStringList{"OpenFile", "SaveFile", "SaveFiles"}.contains(message.member())) return false;
    if (message.signature() != "osssa{sv}" || args.size() != 5) {
        bus.send(message.createErrorReply(QDBusError::InvalidArgs, "Expected osssa{sv}")); return true;
    }
    const auto handle = qdbus_cast<QDBusObjectPath>(args[0]).path();
    if (!handle.startsWith(root + "/request/") || m_pending.contains(handle) || m_pending.size() >= 32) {
        bus.send(message.createErrorReply(QDBusError::InvalidArgs, "Invalid, duplicate or excessive request handle")); return true;
    }
    auto request = new PortalRequest(message.member(), args[3].toString(), qdbus_cast<QVariantMap>(args[4]), this);
    if (!request->valid) { request->deleteLater(); bus.send(message.createReply(QVariantList{uint(2), QVariantMap{}})); return true; }
    message.setDelayedReply(true);
    m_pending.insert(handle, {request, message.service()});
    request->completed = [this, request, handle, message, bus](uint response, const QVariantMap &results) {
        m_pending.remove(handle);
        bus.send(message.createReply(QVariantList{response, results}));
        request->deleteLater();
    };
    auto watcher = new QDBusServiceWatcher(message.service(), bus, QDBusServiceWatcher::WatchForUnregistration, request);
    connect(watcher, &QDBusServiceWatcher::serviceUnregistered, request, [request] { request->cancel(); });
    if (!showDialog(request, args[2].toString())) request->finish(2);
    return true;
}
bool PortalBackend::showDialog(PortalRequest *request, const QString &parent) {
#ifdef SEABUNNY_PORTAL_CONTROLLER_TEST
    Q_UNUSED(request); Q_UNUSED(parent); return false;
#else
    auto engine = new QQmlApplicationEngine(request);
    rust::Vec<rust::String> paths;
    seabunny::setup_engine(*engine, paths, "chooser,new-window");
    engine->rootContext()->setContextProperty("portalRequest", request);
    engine->load(QUrl("qrc:/qt/qml/app/seabunny/qml/main.qml"));
    if (engine->rootObjects().isEmpty()) return false;
    auto window = qobject_cast<QWindow *>(engine->rootObjects().first());
    if (window) {
        window->setModality(request->config().value("modal").toBool() ? Qt::WindowModal : Qt::NonModal);
        if (parent.startsWith("wayland:") && QGuiApplication::platformName().startsWith("wayland"))
            KWindowSystem::setMainWindow(window, parent.mid(8));
        else if (parent.startsWith("x11:") && QGuiApplication::platformName() == "xcb") {
            bool ok = false; auto id = parent.mid(4).toULongLong(&ok, 16);
            if (ok && id) KWindowSystem::setMainWindow(window, WId(id));
        }
        window->show();
    }
    if (window) QObject::connect(request, &QObject::destroyed, window, [window]() {
        // Request cancellation can delete an engine before a resize debounce fires.
        QMetaObject::invokeMethod(window, "persistSidebarState", Qt::DirectConnection);
    });
    return window != nullptr;
#endif
}
bool start_seabunny_portal() {
    portalMode = true;
    register_portal_types();
    QGuiApplication::setQuitOnLastWindowClosed(false);
    auto bus = QDBusConnection::sessionBus();
    bus.connect(QString(), QString(), "org.freedesktop.DBus.Local", "Disconnected", qApp, SLOT(quit()));
    auto backend = new PortalBackend(qApp);
    if (!bus.isConnected() || !bus.registerVirtualObject(root, backend, QDBusConnection::SubPath) ||
        !bus.registerService("org.freedesktop.impl.portal.desktop.seabunny")) {
        qWarning("Seabunny portal could not acquire its session bus name/object");
        backend->deleteLater(); return false;
    }
    return true;
}
