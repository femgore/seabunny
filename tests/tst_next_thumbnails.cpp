#include "seabunny/thumbnails.h"
#include <QFile>
#include <QGuiApplication>
#include <QImage>
#include <QQuickTextureFactory>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

class ThumbnailTests : public QObject {
    Q_OBJECT
    void verifyProvider(const QString &path) {
        seabunny::ThumbnailProvider provider;
        const QString id = QString::fromLatin1(QFile::encodeName(path).toHex()) + "-test";
        std::unique_ptr<QQuickImageResponse> response(provider.requestImageResponse(id, QSize(64,64)));
        QSignalSpy finished(response.get(), &QQuickImageResponse::finished);
        QVERIFY(finished.wait(5000));
        QCOMPARE(response->errorString(), QString());
        std::unique_ptr<QQuickTextureFactory> image(response->textureFactory());
        QVERIFY(image && !image->image().isNull());
        QVERIFY(image->image().width() <= 64);
    }
private slots:
    void closingOneChooserDoesNotDisableLaterThumbnails() {
        QTemporaryDir fixture;
        QVERIFY(fixture.isValid());
        for (const QString &name : {QString("first # ö.png"), QString("second 日本語.png")}) {
            const auto path = fixture.path() + "/" + name;
            QImage image(160,120,QImage::Format_ARGB32);
            image.fill(Qt::red); QVERIFY(image.save(path));
            verifyProvider(path);
        }
    }
};
int main(int argc, char **argv) {
    QGuiApplication app(argc,argv);
    ThumbnailTests tests;
    return QTest::qExec(&tests,argc,argv);
}
#include "tst_next_thumbnails.moc"
