#include "open_with.h"
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeDatabase>
#include <QtTest>
#undef signals
#include <gio/gdesktopappinfo.h>

class OpenWithTests : public QObject {
    Q_OBJECT
    QString root, first, second, receipt;
    void write(const QString &path, const QByteArray &bytes) {
        QFile file(path); QVERIFY(file.open(QIODevice::WriteOnly)); QCOMPARE(file.write(bytes), bytes.size());
    }
    QByteArray read(const QString &path) {
        QFile file(path); if (!file.open(QIODevice::ReadOnly)) return {}; return file.readAll();
    }
    QString paths(const QStringList &files) { return QJsonDocument(QJsonArray::fromStringList(files)).toJson(QJsonDocument::Compact); }
    QJsonObject apps(const QStringList &files) { return QJsonDocument::fromJson(seabunny_open_with_apps(paths(files)).toUtf8()).object(); }
private slots:
    void initTestCase() {
        QVERIFY(qEnvironmentVariableIsSet("SEABUNNY_ISOLATED_OPEN_WITH_TEST"));
        root = QDir::homePath();
        QVERIFY(root.contains("seabunny-open-with-"));
        QDir().mkpath(root + "/work");
        QDir().mkpath(qEnvironmentVariable("XDG_DATA_HOME") + "/applications");
        QDir().mkpath(qEnvironmentVariable("XDG_CONFIG_HOME"));
        first = root + "/work/a # 日本語.txt"; second = root + "/work/b %.txt";
        write(first, "one\n"); write(second, "two\n");
        receipt = root + "/launch-receipt";
        qputenv("SEABUNNY_OPEN_WITH_RECEIPT", receipt.toUtf8());
        const QString recorder = root + "/app recorder";
        write(recorder, "#!/bin/sh\nprintf '%s\\n' \"$@\" >> \"$SEABUNNY_OPEN_WITH_RECEIPT\"\n");
        QVERIFY(QFile::setPermissions(recorder, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        const QString directory = qEnvironmentVariable("XDG_DATA_HOME") + "/applications/";
        for (const auto &name : {QString("one"), QString("two"), QString("hidden")}) {
            write(directory + name + ".desktop", ("[Desktop Entry]\nType=Application\nName=" + name
                + " Viewer\nExec=\"" + recorder + "\" " + name + " %F\nIcon=application-x-executable\n"
                  "MimeType=text/plain;image/png;application/x-shellscript;\n"
                + (name == "hidden" ? "Hidden=true\n" : "")).toUtf8());
        }
        write(directory + "mimeinfo.cache", "[MIME Cache]\ntext/plain=one.desktop;two.desktop;\nimage/png=two.desktop;\n");
        write(directory + "org.femgore.Seabunny.desktop", ("[Desktop Entry]\nType=Application\nName=Seabunny\nExec=\""
            + recorder + "\" seabunny %F\nMimeType=text/plain;application/pdf;\n").toUtf8());
    }
    void savesDefaultWithoutLaunching() {
        const auto before = read(receipt);
        QCOMPARE(seabunny_set_default_app(paths({first}), "one.desktop"), QString());
        QCOMPARE(read(receipt), before);
        QVERIFY(!seabunny_set_default_app(paths({first}), "org.femgore.Seabunny.desktop").isEmpty());
        QCOMPARE(read(receipt), before);
    }
    void listsInstalledApplicationsAndTypes() {
        const auto result = apps({first});
        QCOMPARE(result["mimeType"].toString(), "text/plain");
        QVERIFY(result["canSetDefault"].toBool());
        const auto available = result["apps"].toArray();
        QCOMPARE(available.size(), 2);
        for (const auto &app : available) {
            QVERIFY(app.toObject()["recommended"].toBool());
            QVERIFY(!app.toObject()["id"].toString().contains("hidden"));
        }
        write(root + "/work/image.png", QByteArray::fromHex("89504e470d0a1a0a"));
        QVERIFY(!apps({first, root + "/work/image.png"})["canSetDefault"].toBool());
        QVERIFY(apps({root + "/missing"}).contains("error"));
    }
    void launchesWithSafeArgumentsAndSavesDefault() {
        const QString config = qEnvironmentVariable("XDG_CONFIG_HOME") + "/mimeapps.list";
        const QByteArray before = read(config);
        QCOMPARE(seabunny_open_with(paths({first, second}), "one.desktop", false), QString());
        QTRY_VERIFY(read(receipt).contains(second.toUtf8() + '\n'));
        QVERIFY(read(receipt).contains(first.toUtf8() + '\n'));
        QCOMPARE(read(config), before);
        QCOMPARE(seabunny_open_with(paths({first}), "two.desktop", true), QString());
        QTRY_VERIFY(read(receipt).contains("two\n"));
        QVERIFY(read(config).contains("text/plain=two.desktop"));
        const auto available = apps({first})["apps"].toArray();
        QCOMPARE(available.first().toObject()["id"].toString(), "two.desktop");
        QVERIFY(available.first().toObject()["isDefault"].toBool());
        const auto previousSize = read(receipt).size();
        QCOMPARE(seabunny_open_file(first), QString());
        QTRY_VERIFY(read(receipt).size() > previousSize);
    }
    void validatesSelectionsAndDoesNotWriteDefaultOnFailure() {
        const QString config = qEnvironmentVariable("XDG_CONFIG_HOME") + "/mimeapps.list";
        const QByteArray before = read(config);
        QVERIFY(!seabunny_open_with(paths({first}), "../one.desktop", true).isEmpty());
        QVERIFY(!seabunny_open_with(paths({first}), "missing.desktop", true).isEmpty());
        QVERIFY(!seabunny_open_with(paths({first}), "hidden.desktop", true).isEmpty());
        QVERIFY(!seabunny_open_with(paths({first, root + "/work/image.png"}), "one.desktop", true).isEmpty());
        QVERIFY(!seabunny_open_with(paths({root + "/missing"}), "one.desktop", true).isEmpty());
        QCOMPARE(read(config), before);
    }
    void programsRunDirectlyInsteadOfUsingDocumentHandlers() {
        const QString executable = root + "/work/Example # ö.AppImage";
        QVERIFY(QFile::copy("/usr/bin/true", executable));
        QVERIFY(QFile::setPermissions(executable, QFile::ReadOwner | QFile::WriteOwner));
        QVERIFY(!apps({executable})["canSetDefault"].toBool());
        QVERIFY(!seabunny_open_with(paths({executable}), "one.desktop", true).isEmpty());
        QVERIFY(seabunny_open_file(executable).contains("Make executable"));
        QVERIFY(QFile::setPermissions(executable, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        const auto before = read(receipt);
        QCOMPARE(seabunny_open_file(executable), QString());
        QCOMPARE(read(receipt), before);
        const QString script = root + "/work/script ; ö.sh";
        write(script, "#!/bin/sh\nprintf 'direct-script\\n' >> \"$SEABUNNY_OPEN_WITH_RECEIPT\"\n");
        QVERIFY(QFile::setPermissions(script, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        QCOMPARE(seabunny_open_file(script), QString());
        QTRY_VERIFY(read(receipt).contains("direct-script\n"));
        const QString invalid = root + "/work/invalid.AppImage";
        write(invalid, "not a runnable program\n");
        QVERIFY(QFile::setPermissions(invalid, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        QVERIFY(!seabunny_open_file(invalid).isEmpty());
    }
    void exactDefaultLookupAndSelfHandlerNeverLoop() {
        auto self = g_desktop_app_info_new_from_filename((qEnvironmentVariable("XDG_DATA_HOME")
            + "/applications/org.femgore.Seabunny.desktop").toUtf8().constData());
        QVERIFY(self);
        GError *error = nullptr;
        QVERIFY(g_app_info_set_as_default_for_type(G_APP_INFO(self), "text/plain", &error));
        g_object_unref(self);
        const QByteArray before = read(receipt);
        QVERIFY(seabunny_open_file(first).contains("Open With"));
        QCOMPARE(read(receipt), before);
        QVERIFY(!seabunny_open_with(paths({first}), "org.femgore.Seabunny.desktop", false).isEmpty());
        const auto available = apps({first})["apps"].toArray();
        for (const auto &app : available) QVERIFY(app.toObject()["id"].toString() != "org.femgore.Seabunny.desktop");
        const QString document = root + "/work/content mismatch.pdf";
        write(document, "plain text inside a file named PDF\n");
        QCOMPARE(QMimeDatabase().mimeTypeForFile(document).name(), "application/pdf");
        QCOMPARE(seabunny_open_with(paths({document}), "two.desktop", true), QString());
        QTRY_VERIFY(read(receipt).size() > before.size());
        const auto size = read(receipt).size();
        QCOMPARE(seabunny_open_file(document), QString());
        QTRY_VERIFY(read(receipt).size() > size);
        QVERIFY(!read(receipt).contains("seabunny\n"));
        QCOMPARE(seabunny_open_with(paths({first}), "two.desktop", true), QString());
        QCOMPARE(seabunny_open_file(first), QString());
    }
    void executableDesktopLaunchersRunTheirApplication() {
        const QString launcher = root + "/work/Viewer ö.desktop";
        write(launcher, ("[Desktop Entry]\nType=Application\nName=Viewer\nExec=\"" + root
            + "/app recorder\" desktop-launcher\n").toUtf8());
        QVERIFY(QFile::setPermissions(launcher, QFile::ReadOwner | QFile::WriteOwner));
        QVERIFY(seabunny_open_file(launcher).contains("Make executable"));
        QVERIFY(QFile::setPermissions(launcher, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        QCOMPARE(seabunny_open_file(launcher), QString());
        QTRY_VERIFY(read(receipt).contains("desktop-launcher\n"));
    }
};
QTEST_GUILESS_MAIN(OpenWithTests)
#include "tst_open_with.moc"
