#include "portal_backend.h"
#include <QTest>
#include <QDBusMetaType>
#include <QDBusConnection>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QTimer>
#include <QTemporaryDir>
#include <QFile>
#include <QDir>
#include <QUrl>
#include <QQmlApplicationEngine>
// Controller/protocol unit tests do not render windows or need image providers.
void install_thumbnail_provider(QQmlApplicationEngine &) {}
class AcceptingBackend : public PortalBackend {
public:
    QStringList selection;
protected:
    bool showDialog(PortalRequest *request, const QString &) override {
        QTimer::singleShot(0, request, [this, request] {
            const auto config = request->config();
            request->accept(config["folder"].toString(), selection,
                config["name"].toString(), config["filterIndex"].toInt(), {}, false);
        });
        return true;
    }
};
class PortalTests : public QObject {
    Q_OBJECT
private slots:
    void initTestCase() { register_portal_types(); }
    void signatures() {
        QCOMPARE(QString(QDBusMetaType::typeToSignature(QMetaType::fromType<PortalFilters>())), "a(sa(us))");
        QCOMPARE(QString(QDBusMetaType::typeToSignature(QMetaType::fromType<PortalChoices>())), "a(ssa(ss)s)");
        QCOMPARE(QString(QDBusMetaType::typeToSignature(QMetaType::fromType<PortalPairs>())), "a(ss)");
        PortalBackend backend;
        const auto xml = backend.introspect("/org/freedesktop/portal/desktop");
        QVERIFY(xml.contains("SaveFiles")); QVERIFY(xml.contains("type='o'"));
    }
    void successfulWireReplies() {
        if (!qEnvironmentVariableIsSet("SEABUNNY_PRIVATE_BUS_TEST"))
            QSKIP("Run inside a disposable dbus-run-session with SEABUNNY_PRIVATE_BUS_TEST=1");
        auto bus = QDBusConnection::sessionBus();
        QVERIFY(bus.isConnected());
        auto client = QDBusConnection::connectToBus(QDBusConnection::SessionBus, "portal-wire-client");
        QVERIFY(client.isConnected());
        const QString root = "/org/freedesktop/portal/desktop";
        const QString service = "org.freedesktop.impl.portal.desktop.seabunny.test";
        AcceptingBackend backend;
        QVERIFY(bus.registerVirtualObject(root, &backend, QDBusConnection::SubPath));
        QVERIFY(bus.registerService(service));
        QTemporaryDir dir;
        const QString path = dir.path() + "/wire # 日本語%.txt";
        QFile file(path); QVERIFY(file.open(QIODevice::WriteOnly)); file.close();
        const PortalFilters filters{{"Text", {{0, "*.txt"}}}};
        const PortalChoices choices{{"flag", "Flag", {}, "true"}};
        QVariantMap options{{"current_folder", dir.path().toUtf8() + '\0'},
            {"current_name", "new 日本語"}, {"filters", QVariant::fromValue(filters)},
            {"current_filter", QVariant::fromValue(filters.first())},
            {"choices", QVariant::fromValue(choices)},
            {"files", QVariant::fromValue(QList<QByteArray>{"wire # 日本語%.txt", "new.txt"})}};
        for (const QString &method : {QString("OpenFile"), QString("SaveFile"), QString("SaveFiles")}) {
            backend.selection = method == "OpenFile" ? QStringList{path} : QStringList{};
            auto call = QDBusMessage::createMethodCall(service, root,
                "org.freedesktop.impl.portal.FileChooser", method);
            call.setArguments({QVariant::fromValue(QDBusObjectPath(root + "/request/wire/" + method)),
                QString("test.app"), QString(), QString("Wire test"), options});
            QDBusPendingCallWatcher watcher(client.asyncCall(call, 5000));
            QTRY_VERIFY_WITH_TIMEOUT(watcher.isFinished(), 6000);
            QDBusPendingReply<uint, QVariantMap> reply = watcher;
            QVERIFY2(!reply.isError(), qPrintable(reply.error().message()));
            QCOMPARE(reply.argumentAt<0>(), 0u);
            const auto result = reply.argumentAt<1>();
            const auto uris = qdbus_cast<QStringList>(result["uris"]);
            QCOMPARE(uris.size(), method == "SaveFiles" ? 2 : 1);
            for (const auto &uri : uris) QVERIFY(QUrl(uri).isLocalFile());
            const auto returnedChoices = qdbus_cast<PortalPairs>(result["choices"]);
            QCOMPARE(returnedChoices.size(), 1);
            QCOMPARE(returnedChoices[0].id, "flag");
            QCOMPARE(returnedChoices[0].value, "true");
            if (method != "SaveFiles") QCOMPARE(qdbus_cast<PortalFilter>(result["current_filter"]).name, "Text");
            if (method == "OpenFile") QCOMPARE(QUrl(uris.first()).toLocalFile(), path);
            if (method == "SaveFile") QVERIFY(uris.first().endsWith("new%20%E6%97%A5%E6%9C%AC%E8%AA%9E.txt"));
            if (method == "SaveFiles") QVERIFY(uris.first().contains("%20(1).txt"));
        }
        QCOMPARE(QDir(dir.path()).entryList(QDir::Files).size(), 1);
        bus.unregisterObject(root, QDBusConnection::UnregisterTree);
        bus.unregisterService(service);
        QDBusConnection::disconnectFromBus("portal-wire-client");
    }
    void openAndFolders() {
        QTemporaryDir dir; QVERIFY(dir.isValid());
        QString path = dir.path() + "/space # 日本語%.txt";
        QFile file(path); QVERIFY(file.open(QIODevice::WriteOnly)); file.close();
        uint response = 9; QVariantMap result;
        PortalRequest request("OpenFile", "Open", {});
        request.completed = [&](uint code, const QVariantMap &r) { response = code; result = r; };
        QVERIFY(request.accept(dir.path(), {dir.path()}, "", -1, {}, false).contains("error"));
        QVERIFY(request.accept(dir.path(), {path}, "", -1, {}, false).value("accepted").toBool());
        QCOMPARE(response, 0u);
        QCOMPARE(result["uris"].toStringList(), QStringList{QUrl::fromLocalFile(path).toString(QUrl::FullyEncoded)});
        request.cancel(); QCOMPARE(response, 0u);
        PortalRequest folders("OpenFile", "Folder", {{"directory", true}});
        QVERIFY(folders.accept(dir.path(), {path}, "", -1, {}, false).contains("error"));
        QVERIFY(folders.accept(dir.path(), {}, "", -1, {}, false).value("accepted").toBool());
        PortalRequest multiple("OpenFile", "Open", {{"multiple", true}});
        QVERIFY(multiple.accept(dir.path(), {path, path}, "", -1, {}, false).value("accepted").toBool());
        PortalRequest single("OpenFile", "Open", {});
        QVERIFY(single.accept(dir.path(), {path, path}, "", -1, {}, false).contains("error"));
    }
    void saveFiltersChoicesOverwrite() {
        QTemporaryDir dir;
        PortalFilters filters{{"Text", {{0, "*.txt"}}}, {"PNG", {{1, "image/png"}}}};
        PortalChoices choices{{"encoding", "Encoding", {{"utf8", "UTF-8"}, {"ascii", "ASCII"}}, "utf8"}, {"flag", "Flag", {}, "true"}};
        QVariantMap options{{"current_folder", (dir.path().toUtf8() + '\0')}, {"current_name", "suggested"},
            {"filters", QVariant::fromValue(filters)}, {"choices", QVariant::fromValue(choices)}};
        options["accept_label"] = "_Save";
        PortalRequest request("SaveFile", "Save", options);
        QCOMPARE(request.config()["acceptLabel"].toString(), "Save");
        QCOMPARE(request.config()["acceptKey"].toString(), "Alt+S");
        QCOMPARE(request.config()["folder"].toString(), dir.path());
        QCOMPARE(request.config()["name"].toString(), "suggested");
        QVERIFY(request.matches(dir.path(), 0)); QVERIFY(request.matches(dir.path()+"/foo.txt", 0));
        QVERIFY(!request.matches(dir.path()+"/foo.png", 0)); QVERIFY(request.matches(dir.path()+"/foo.png", 1));
        QFile existing(dir.path()+"/suggested.txt"); QVERIFY(existing.open(QIODevice::WriteOnly)); existing.write("original"); existing.close();
        QVariantMap result; uint response = 9;
        request.completed = [&](uint code, const QVariantMap &r) {response=code; result=r;};
        QVERIFY(request.accept(dir.path(), {}, "../escape", 0, {}, false).contains("error"));
        QVERIFY(request.accept(dir.path(), {}, "suggested", 0, {}, false).value("overwrite").toBool());
        QCOMPARE(response, 9u);
        QVERIFY(request.accept(dir.path(), {}, "suggested", 0, {{"encoding", "ascii"}}, true).value("accepted").toBool());
        QCOMPARE(response, 0u); QCOMPARE(qvariant_cast<PortalFilter>(result["current_filter"]).name, "Text");
        QCOMPARE(qvariant_cast<PortalPairs>(result["choices"])[0].value, "ascii");
        QVERIFY(existing.open(QIODevice::ReadOnly)); QCOMPARE(existing.readAll(), QByteArray("original"));
        PortalRequest newFile("SaveFile", "Save", options);
        newFile.completed = [&](uint, const QVariantMap &r) {result=r;};
        QVERIFY(newFile.accept(dir.path(), {}, "new", 1, {}, false).value("accepted").toBool());
        QVERIFY(result["uris"].toStringList().first().endsWith("new.png"));
        QVERIFY(!QFile::exists(dir.path()+"/new.png"));
        options["current_file"] = (dir.path()+"/original.txt").toUtf8()+'\0'; options.remove("current_name");
        PortalRequest current("SaveFile", "Save", options);
        QCOMPARE(current.config()["name"].toString(), "original.txt");
    }
    void visibleSaveNameSuggestions() {
        PortalFilters filters{{"Text", {{0, "*.txt"}}}, {"PNG", {{1, "image/png"}}},
            {"All files", {{0, "*"}}}, {"Several types", {{0, "*.txt"}, {0, "*.md"}}}};
        PortalRequest request("SaveFile", "Save", {{"filters", QVariant::fromValue(filters)}});
        QCOMPARE(request.saveName("Suggested 日本語", 0), "Suggested 日本語.txt");
        QCOMPARE(request.saveName("Suggested 日本語", 1), "Suggested 日本語.png");
        QCOMPARE(request.saveName("explicit.custom", 0), "explicit.custom");
        QCOMPARE(request.saveName("existing.txt", 1), "existing.txt");
        QCOMPARE(request.saveName("extensionless", 2), "extensionless");
        QCOMPARE(request.saveName("ambiguous", 3), "ambiguous");
        QCOMPARE(request.saveName("", 0), "");
    }
    void saveFilesAndCancel() {
        QTemporaryDir dir;
        QFile file(dir.path()+"/a.txt"); QVERIFY(file.open(QIODevice::WriteOnly)); file.close();
        QVariantMap options{{"files", QVariant::fromValue(QList<QByteArray>{QByteArray("a.txt\0",6), QByteArray("a.txt\0",6), QByteArray("ö.txt")})}};
        PortalRequest request("SaveFiles", "Save", options);
        QVERIFY(request.valid);
        QVariantMap result;
        request.completed = [&](uint, const QVariantMap &r){result=r;};
        QVERIFY(request.accept(dir.path(), {}, "", -1, {}, false).value("accepted").toBool());
        auto uris = result["uris"].toStringList(); QCOMPARE(uris.size(), 3);
        QVERIFY(uris[0].endsWith("a%20(1).txt")); QVERIFY(uris[1].endsWith("a%20(2).txt"));
        QCOMPARE(QDir(dir.path()).entryList(QDir::Files).size(), 1);
        PortalRequest cancel("OpenFile", "Open", {}); int count=0;
        cancel.completed = [&](uint response, const QVariantMap &r){ QCOMPARE(response, 1u); QVERIFY(r.isEmpty()); ++count;};
        cancel.cancel(); cancel.cancel(); QCOMPARE(count, 1);
        PortalRequest invalid("SaveFiles", "Save", {{"files", QVariant::fromValue(QList<QByteArray>{"../escape"})}});
        QVERIFY(!invalid.valid);
    }
};
QTEST_GUILESS_MAIN(PortalTests)
#include "tst_portal.moc"
