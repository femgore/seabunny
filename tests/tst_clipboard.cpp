#include "app_integration.h"
#include <QClipboard>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QMimeData>
#include <QUrl>
#include <QtTest>

class ClipboardTests : public QObject {
    Q_OBJECT
    QJsonArray selection() { return QJsonDocument::fromJson(seabunny_clipboard_files().toUtf8()).array(); }
private slots:
    void initTestCase() { QVERIFY(qEnvironmentVariableIsSet("SEABUNNY_ISOLATED_CLIPBOARD_TEST")); }
    void localFilesRoundTrip() {
        const QJsonArray paths{"/tmp/a # 日本語.txt", "/tmp/b %.txt"};
        for (bool cut : {false, true}) {
            seabunny_set_clipboard_files(QJsonDocument(paths).toJson(), cut);
            QCOMPARE(selection(), (QJsonArray{paths, cut}));
            const auto *mime = QGuiApplication::clipboard()->mimeData();
            QCOMPARE(mime->urls().size(), 2);
            QVERIFY(mime->data("text/uri-list").contains("%23"));
            QVERIFY(mime->data("text/uri-list").contains("%25"));
            QVERIFY(mime->data("x-special/gnome-copied-files").startsWith(cut ? "cut\n" : "copy\n"));
            QCOMPARE(mime->data("application/x-kde-cutselection"), cut ? QByteArray("1") : QByteArray("0"));
        }
    }
    void importsOtherFileManagers() {
        auto *gnome = new QMimeData;
        gnome->setData("x-special/gnome-copied-files", "cut\nfile:///tmp/a%20%23.txt\nfile:///tmp/b.txt\n");
        QGuiApplication::clipboard()->setMimeData(gnome);
        QCOMPARE(selection(), (QJsonArray{QJsonArray{"/tmp/a #.txt", "/tmp/b.txt"}, true}));
        auto *kde = new QMimeData;
        kde->setUrls({QUrl::fromLocalFile("/tmp/ö.txt")});
        kde->setData("application/x-kde-cutselection", "1");
        QGuiApplication::clipboard()->setMimeData(kde);
        QCOMPARE(selection(), (QJsonArray{QJsonArray{"/tmp/ö.txt"}, true}));
    }
    void textAndNonlocalUrlsAreNotFiles() {
        QGuiApplication::clipboard()->setText("/tmp/a.txt");
        QCOMPARE(selection(), (QJsonArray{QJsonArray{}, false}));
        auto *mime = new QMimeData;
        mime->setUrls({QUrl("https://example.com/a.txt"), QUrl("file://remote/tmp/b.txt"), QUrl("relative.txt")});
        QGuiApplication::clipboard()->setMimeData(mime);
        QCOMPARE(selection(), (QJsonArray{QJsonArray{}, false}));
    }
    void archiveCopyIsPrivateAndClearWorks() {
        const QJsonArray paths{"seabunny-archive:synthetic"};
        seabunny_set_clipboard_files(QJsonDocument(paths).toJson(), false);
        QCOMPARE(selection(), (QJsonArray{paths, false}));
        QVERIFY(!QGuiApplication::clipboard()->mimeData()->hasUrls());
        seabunny_set_clipboard_files("[]", false);
        QCOMPARE(selection(), (QJsonArray{QJsonArray{}, false}));
    }
};
int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    ClipboardTests checks;
    return QTest::qExec(&checks, argc, argv);
}
#include "tst_clipboard.moc"
