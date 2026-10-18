#include "serpantinum_palette.h"
#include "thumbnail_provider.h"
#include "icon_provider.h"
#include "app_integration.h"
#include <QIcon>
#include <QImageReader>
#include <QRawFont>
#include <QFontDatabase>

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlApplicationEngine>
#include <QQuickAsyncImageProvider>
#include <QProcess>
#include <QStandardPaths>
#include <QStyleHints>
#include <QSaveFile>
#include <QScopeGuard>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>
#include <memory>

class SettingsFixture : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool is_dark MEMBER dark CONSTANT)
    Q_PROPERTY(QString wallpaper_colors_json MEMBER wallpaper CONSTANT)
public:
    bool dark = true;
    QString wallpaper = "{}";
    QMap<QString, QString> settings;
    Q_INVOKABLE QString get_setting(const QString &key) { return settings.value(key); }
    Q_INVOKABLE void set_setting(const QString &key, const QString &value) { settings[key] = value; }
};

class SerpantinumTests : public QObject {
    Q_OBJECT
    QTemporaryDir temporary;
    QString path;

    static QJsonObject palette(bool light = false) {
        QJsonObject result;
        const QStringList names = {
            "base", "mantle", "crust", "text", "subtext0", "subtext1",
            "surface0", "surface1", "surface2", "overlay0", "overlay1", "overlay2",
            "blue", "sapphire", "peach", "green", "red", "mauve", "pink", "yellow", "maroon", "teal"
        };
        int index = 1;
        for (const QString &name : names) result[name] = QString("#%1").arg(index++ * 6000, 6, 16, QLatin1Char('0'));
        result["base"] = light ? "#fafafa" : "#101010";
        result["text"] = light ? "#101010" : "#fafafa";
        result["blue"] = light ? "#123456" : "#abcdef";
        return result;
    }

    static void publish(const QString &target, const QByteArray &bytes) {
        QSaveFile file(target);
        QVERIFY(file.open(QIODevice::WriteOnly));
        QCOMPARE(file.write(bytes), bytes.size());
        QVERIFY(file.commit());
    }

    void publish(const QJsonObject &colors) { publish(path, QJsonDocument(colors).toJson()); }

private slots:
    void sidebarStatePersistence() {
        QTemporaryDir state;
        QVERIFY(state.isValid());
        const bool hadState = qEnvironmentVariableIsSet("XDG_STATE_HOME");
        const QByteArray previous = qgetenv("XDG_STATE_HOME");
        const auto restore = qScopeGuard([&] {
            if (hadState) qputenv("XDG_STATE_HOME", previous); else qunsetenv("XDG_STATE_HOME");
        });
        qputenv("XDG_STATE_HOME", state.path().toUtf8());
        QVERIFY(seabunny_sidebar_state(false).isEmpty());
        QVERIFY(seabunny_sidebar_state(true).isEmpty());
        QVERIFY(seabunny_save_sidebar_state(false, true, 410));
        QVERIFY(seabunny_save_sidebar_state(true, false, 350));
        const auto explorer = QJsonDocument::fromJson(seabunny_sidebar_state(false).toUtf8()).object();
        const auto chooser = QJsonDocument::fromJson(seabunny_sidebar_state(true).toUtf8()).object();
        QVERIFY(explorer["expanded"].toBool());
        QCOMPARE(explorer["width"].toDouble(), 410.0);
        QVERIFY(!chooser["expanded"].toBool());
        QCOMPARE(chooser["width"].toDouble(), 350.0);
        QVERIFY(!seabunny_save_sidebar_state(false, false, 20));
        QCOMPARE(QJsonDocument::fromJson(seabunny_sidebar_state(false).toUtf8()).object(), explorer);
        QFile malformed(state.path() + "/seabunny/chooser-sidebar.json");
        QVERIFY(malformed.open(QIODevice::WriteOnly));
        malformed.write("preserve malformed data"); malformed.close();
        QVERIFY(seabunny_sidebar_state(true).isEmpty());
        QVERIFY(!seabunny_save_sidebar_state(true, true, 300));
        QVERIFY(malformed.open(QIODevice::ReadOnly));
        QCOMPARE(malformed.readAll(), QByteArray("preserve malformed data"));
    }
    void specificFocusWarningFilterAndBrandIdentity() {
        qunsetenv("SEABUNNY_SHOW_QT_FOCUS_WARNINGS");
        const QMessageLogContext wayland(nullptr, 0, nullptr, "qt.qpa.wayland.textinput");
        const QString prefix = "virtual void QtWaylandClient::QWaylandTextInputv3::disableSurface(wl_surface*) Trying to disable 0x1234 but ";
        QVERIFY(seabunny_ignorable_focus_warning(QtWarningMsg, wayland, prefix + "0x0 is focused"));
        QVERIFY(!seabunny_ignorable_focus_warning(QtCriticalMsg, wayland, prefix + "0x0 is focused"));
        QVERIFY(!seabunny_ignorable_focus_warning(QtWarningMsg, wayland, prefix + "0x9999 is focused"));
        QVERIFY(!seabunny_ignorable_focus_warning(QtWarningMsg, wayland, prefix + "0x0 is enabled"));
        const QMessageLogContext other(nullptr, 0, nullptr, "seabunny.test");
        QVERIFY(!seabunny_ignorable_focus_warning(QtWarningMsg, other, prefix + "0x0 is focused"));
        qputenv("SEABUNNY_SHOW_QT_FOCUS_WARNINGS", "1");
        QVERIFY(!seabunny_ignorable_focus_warning(QtWarningMsg, wayland, prefix + "0x0 is focused"));
        qunsetenv("SEABUNNY_SHOW_QT_FOCUS_WARNINGS");
        configure_seabunny();
        QCOMPARE(QGuiApplication::applicationDisplayName(), "Seabunny");
        QCOMPARE(QGuiApplication::desktopFileName(), "org.femgore.Seabunny");
        QVERIFY(!QGuiApplication::windowIcon().isNull());
    }

    void seabunnySvgUsesExactThemeColor() {
        QQmlApplicationEngine engine;
        install_icon_provider(engine);
        auto provider = static_cast<QQuickImageProvider *>(engine.imageProvider("seabunnyicon"));
        for (const QString color : {QString("#ff7755"), QString("#3355ee")}) {
            QSize size;
            QImage image = provider->requestImage("seabunny-logo?color=" + QUrl::toPercentEncoding(color), &size, QSize(96, 96)).convertToFormat(QImage::Format_ARGB32);
            QVERIFY(!image.isNull());
            int opaque = 0;
            for (int row = 0; row < image.height(); ++row) {
                for (int column = 0; column < image.width(); ++column) {
                    const QColor pixel = image.pixelColor(column, row);
                    if (pixel.alpha() == 255) { QCOMPARE(pixel.rgb(), QColor(color).rgb()); ++opaque; }
                }
            }
            QVERIFY(opaque > 100);
        }
        SeabunnyStyle tools;
        tools.setApplicationAccent(QColor("#ff7755"));
        const QImage applicationIcon = QGuiApplication::windowIcon().pixmap(96, 96).toImage();
        QVERIFY(!applicationIcon.isNull());
        QCOMPARE(applicationIcon.pixelColor(0, 0).alpha(), 0);
        QCOMPARE(applicationIcon.pixelColor(48, 10), QColor("#1e1e2e"));
        QImageReader source(":/seabunny/branding/seabunny.svg");
        const QImage inAppIcon = source.read();
        QVERIFY(!inAppIcon.isNull());
        QCOMPARE(inAppIcon.pixelColor(0, 0).alpha(), 0);
    }

    void init() {
        QVERIFY(temporary.isValid());
        path = temporary.filePath(QUuid::createUuid().toString(QUuid::WithoutBraces) + ".json");
        qputenv("SEABUNNY_SERPANTINUM_COLORS", path.toUtf8());
        qunsetenv("QS_COLORS_JSON");
    }

    void initialLoad() {
        publish(palette());
        SerpantinumPalette source;
        QVERIFY(source.available());
        QCOMPARE(source.colors(), palette().toVariantMap());
        QCOMPARE(source.sourcePath(), path);
    }

    void nativeIconThemesInheritanceAndFallback() {
        const QStringList previousPaths = QIcon::themeSearchPaths();
        const QString previousTheme = QIcon::themeName();
        const QString icons = temporary.filePath("icons");
        for (const auto &name : {QString("SeabunnyTest"), QString("SeabunnyChild")}) {
            QDir().mkpath(icons + "/" + name + "/48x48/places");
            publish(icons + "/" + name + "/index.theme", ("[Icon Theme]\nName=" + name
                + "\nInherits=" + (name == "SeabunnyChild" ? "SeabunnyTest" : "hicolor")
                + "\nDirectories=48x48/places\n[48x48/places]\nSize=48\nType=Fixed\nContext=Places\n").toUtf8());
        }
        QImage fixture(48, 48, QImage::Format_ARGB32);
        fixture.fill(Qt::red);
        QVERIFY(fixture.save(icons + "/SeabunnyTest/48x48/places/fixture-folder.png"));
        QVERIFY(fixture.save(icons + "/SeabunnyTest/48x48/places/fixture-symbolic.png"));
        QIcon::setThemeSearchPaths(QStringList{icons} + previousPaths);
        QQmlApplicationEngine engine;
        install_icon_provider(engine);
        auto provider = static_cast<QQuickImageProvider *>(engine.imageProvider("seabunnyicon"));
        QSize size;
        auto direct = provider->requestImage("fixture-folder?theme=SeabunnyTest", &size, QSize(48, 48));
        QCOMPARE(direct.pixelColor(24, 24), QColor(Qt::red));
        auto inherited = provider->requestImage("fixture-folder?theme=SeabunnyChild", &size, QSize(48, 48));
        QCOMPARE(inherited.pixelColor(24, 24), QColor(Qt::red));
        auto symbolic = provider->requestImage("fixture-symbolic?theme=SeabunnyTest&color=%230000ff", &size, QSize(48, 48));
        QCOMPARE(symbolic.pixelColor(24, 24), QColor(Qt::blue));
        const auto adwaita = provider->requestImage("folder?theme=Adwaita", &size, QSize(48, 48));
        QVERIFY(adwaita.pixelColor(24, 24).alpha() > 0);
        auto missing = provider->requestImage("does-not-exist?theme=Adwaita", &size, QSize(48, 48));
        QVERIFY(!missing.isNull());
        bool painted = false;
        for (int row = 0; row < missing.height(); ++row)
            for (int column = 0; column < missing.width(); ++column) painted |= missing.pixelColor(column, row).alpha() > 0;
        QVERIFY(painted);
        QCOMPARE(QIcon::themeName(), previousTheme);
        QCOMPARE(QIcon::themeSearchPaths(), QStringList{icons} + previousPaths);
        QIcon::setThemeSearchPaths(previousPaths);
    }

    void symbolsFontAndRunningAnimations() {
        const int fontId = QFontDatabase::addApplicationFont(":/seabunny/fonts/SymbolsNerdFontMono-Regular.ttf");
        QVERIFY(fontId >= 0);
        QFont font(QFontDatabase::applicationFontFamilies(fontId).first());
        const QRawFont raw = QRawFont::fromFont(font);
        for (auto glyph : {QChar(0xf07b), QChar(0xf15b), QChar(0xf03e), QChar(0xf015)})
            QVERIFY(raw.glyphIndexesForString(QString(glyph)).first() != 0);
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData("import QtQuick\nItem { id: fixtureRoot; NumberAnimation { objectName: 'timed'; target: fixtureRoot; property: 'x'; to: 100; duration: 10000 } SpringAnimation { objectName: 'spring'; target: fixtureRoot; property: 'y'; to: 100; spring: 3; damping: 0.3 } }", QUrl());
        std::unique_ptr<QObject> item(component.create());
        QVERIFY2(item != nullptr, qPrintable(component.errorString()));
        for (const auto &name : {QString("timed"), QString("spring")})
            QVERIFY(QMetaObject::invokeMethod(item->findChild<QObject *>(name), "start"));
        SeabunnyStyle tools;
        tools.finishAnimations(item.get());
        QCOMPARE(item->property("x").toReal(), 100.0);
        QCOMPARE(item->property("y").toReal(), 100.0);
    }

    void thumbnailSizingCachingAndInvalidation() {
        QQmlApplicationEngine engine;
        install_thumbnail_provider(engine);
        const QString input = temporary.filePath("picture #100% ö.png");
        QImage image(1000, 800, QImage::Format_RGB32);
        image.fill(Qt::red);
        QVERIFY(image.save(input));
        QQmlComponent component(&engine);
        component.setData("import QtQuick\nImage { source: thumbnailSource; sourceSize: Qt.size(96,96); asynchronous: true; cache: false }", QUrl());
        engine.rootContext()->setContextProperty("thumbnailSource", "image://seabunnythumb/" + QString::fromLatin1(QUrl::toPercentEncoding(input)));
        std::unique_ptr<QObject> first(component.create());
        QVERIFY2(first != nullptr, qPrintable(component.errorString()));
        QTRY_COMPARE(first->property("status").toInt(), 1);
        QVERIFY(first->property("implicitWidth").toReal() <= 96);
        const auto before = QJsonDocument::fromJson(thumbnail_statistics().toUtf8()).object();
        std::unique_ptr<QObject> again(component.create());
        QTRY_COMPARE(again->property("status").toInt(), 1);
        const auto cached = QJsonDocument::fromJson(thumbnail_statistics().toUtf8()).object();
        QVERIFY(cached.value("memoryHits").toInt() > before.value("memoryHits").toInt());
        first->setProperty("sourceSize", QSize(256, 256));
        QTRY_COMPARE(first->property("implicitWidth").toInt(), 256);
        const auto zoomed = QJsonDocument::fromJson(thumbnail_statistics().toUtf8()).object();
        QCOMPARE(zoomed.value("generated"), before.value("generated"));
        QVERIFY(zoomed.value("memoryHits").toInt() > cached.value("memoryHits").toInt());
        {
            QQmlApplicationEngine reopened;
            install_thumbnail_provider(reopened);
            reopened.rootContext()->setContextProperty("thumbnailSource", "image://seabunnythumb/" + QString::fromLatin1(QUrl::toPercentEncoding(input)));
            QQmlComponent restored(&reopened);
            restored.setData("import QtQuick\nImage { source: thumbnailSource; sourceSize: Qt.size(160,160); asynchronous: true; cache: false }", QUrl());
            std::unique_ptr<QObject> preview(restored.create());
            QTRY_COMPARE(preview->property("status").toInt(), 1);
            const auto revisited = QJsonDocument::fromJson(thumbnail_statistics().toUtf8()).object();
            QCOMPARE(revisited.value("generated"), before.value("generated"));
            QVERIFY(revisited.value("diskHits").toInt() > zoomed.value("diskHits").toInt());
        }
        image.fill(Qt::blue);
        QVERIFY(image.save(input));
        engine.rootContext()->setContextProperty("thumbnailSource", "image://seabunnythumb/" + QString::fromLatin1(QUrl::toPercentEncoding(input)) + "?version=changed");
        QTRY_VERIFY(QJsonDocument::fromJson(thumbnail_statistics().toUtf8()).object().value("generated").toInt() > before.value("generated").toInt());
    }

    void thumbnailCancellationStopsOwnedDecoder() {
        const QString directory = temporary.filePath("decoder");
        QVERIFY(QDir().mkpath(directory));
        const QString marker = directory + "/started";
        QFile helper(directory + "/ffmpeg");
        QVERIFY(helper.open(QIODevice::WriteOnly));
        helper.write(("#!/usr/bin/python3\nimport time\nopen(" + QString("'%1'").arg(marker) + ", 'w').write('fixture')\ntime.sleep(5)\n").toUtf8());
        helper.close();
        QVERIFY(helper.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        const QByteArray previous = qgetenv("PATH");
        qputenv("PATH", directory.toUtf8() + ":" + previous);
        const QString input = directory + "/fixture.mp4";
        publish(input, "synthetic non-video");
        QQmlApplicationEngine engine;
        install_thumbnail_provider(engine);
        auto *provider = dynamic_cast<QQuickAsyncImageProvider *>(engine.imageProvider("seabunnythumb"));
        QVERIFY(provider != nullptr);
        auto *response = provider->requestImageResponse(QString::fromLatin1(QUrl::toPercentEncoding(input)), QSize(96,96));
        QSignalSpy finished(response, &QQuickImageResponse::finished);
        QTRY_VERIFY(QFile::exists(marker));
        response->cancel();
        QTRY_COMPARE(finished.count(), 1);
        delete response;
        qputenv("PATH", previous);
        QVERIFY(QJsonDocument::fromJson(thumbnail_statistics().toUtf8()).object().value("cancelled").toInt() > 0);
    }

    void realShortVideoThumbnail() {
        if (QStandardPaths::findExecutable("ffmpeg").isEmpty()) QSKIP("FFmpeg is not installed");
        const QString input = temporary.filePath("short clip ö.mp4");
        QCOMPARE(QProcess::execute("ffmpeg", {"-loglevel", "error", "-nostdin", "-y", "-f", "lavfi", "-i",
            "color=c=blue:s=160x90:d=0.4", "-c:v", "mpeg4", "-threads", "1", input}), 0);
        QQmlApplicationEngine engine;
        install_thumbnail_provider(engine);
        engine.rootContext()->setContextProperty("thumbnailSource", "image://seabunnythumb/" + QString::fromLatin1(QUrl::toPercentEncoding(input)));
        QQmlComponent component(&engine);
        component.setData("import QtQuick\nImage { source: thumbnailSource; sourceSize: Qt.size(96,96); asynchronous: true }", QUrl());
        std::unique_ptr<QObject> preview(component.create());
        QVERIFY2(preview != nullptr, qPrintable(component.errorString()));
        QTRY_COMPARE_WITH_TIMEOUT(preview->property("status").toInt(), 1, 12000);
        QVERIFY(preview->property("implicitWidth").toReal() <= 96);
        QVERIFY(preview->property("implicitHeight").toReal() > 0);
    }

    void repeatedAtomicReplacements() {
        publish(palette());
        SerpantinumPalette source;
        QSignalSpy changes(&source, &SerpantinumPalette::colorsChanged);
        for (int index = 1; index <= 3; ++index) {
            auto next = palette();
            next["base"] = QString("#00000%1").arg(index);
            publish(next);
            QTRY_COMPARE(source.colors().value("base").toString(), next.value("base").toString());
        }
        QCOMPARE(changes.count(), 3);
    }

    void coalescesRapidChanges() {
        publish(palette());
        SerpantinumPalette source;
        QSignalSpy changes(&source, &SerpantinumPalette::colorsChanged);
        for (int index = 1; index <= 10; ++index) {
            auto next = palette();
            next["base"] = QString("#%1").arg(index, 6, 16, QLatin1Char('0'));
            publish(next);
        }
        QTRY_COMPARE(source.colors().value("base").toString(), QString("#00000a"));
        QCOMPARE(changes.count(), 1);
    }

    void malformedAndIncompleteKeepLastGood() {
        publish(palette());
        SerpantinumPalette source;
        publish(path, "{broken");
        QTRY_VERIFY(source.status().startsWith("Invalid"));
        QCOMPARE(source.colors(), palette().toVariantMap());
        auto incomplete = palette(); incomplete.remove("text");
        publish(incomplete);
        QTRY_VERIFY(source.status().startsWith("Incomplete"));
        QCOMPARE(source.colors(), palette().toVariantMap());
        publish(palette(true));
        QTRY_COMPARE(source.colors(), palette(true).toVariantMap());
    }

    void invalidColorAndOversizeRejected() {
        auto invalid = palette(); invalid["primary"] = "unused"; invalid["text"] = "red";
        publish(invalid);
        SerpantinumPalette source;
        QVERIFY(!source.available());
        publish(path, QByteArray(65537, ' '));
        QTRY_VERIFY(source.status().startsWith("Invalid"));
        QVERIFY(!source.available());
    }

    void missingAndRecreatedFile() {
        SerpantinumPalette source;
        QVERIFY(!source.available());
        publish(palette());
        QTRY_VERIFY(source.available());
        QVERIFY(QFile::remove(path));
        QTRY_VERIFY(source.status().startsWith("Palette unavailable"));
        QCOMPARE(source.colors(), palette().toVariantMap());
        publish(palette(true));
        QTRY_COMPARE(source.colors(), palette(true).toVariantMap());
    }

    void parentCreatedLater() {
        path = temporary.filePath("late/created/palette.json");
        qputenv("SEABUNNY_SERPANTINUM_COLORS", path.toUtf8());
        SerpantinumPalette source;
        QVERIFY(!source.available());
        QVERIFY(QDir().mkpath(QFileInfo(path).absolutePath()));
        publish(palette());
        QTRY_VERIFY(source.available());
    }

    void wrappedPaletteAndUnchangedContent() {
        publish(QJsonObject{{"colors", palette()}});
        SerpantinumPalette source;
        QVERIFY(source.available());
        QSignalSpy changes(&source, &SerpantinumPalette::colorsChanged);
        publish(palette());
        QTest::qWait(160);
        QCOMPARE(changes.count(), 0);
    }

    void explicitPathNeverFallsBackToOtherSources() {
        const QString other = temporary.filePath("other.json");
        publish(other, QJsonDocument(palette()).toJson());
        qputenv("QS_COLORS_JSON", other.toUtf8());
        SerpantinumPalette source;
        QVERIFY(!source.available());
        QCOMPARE(source.sourcePath(), path);
    }

    void nativeEnvironmentDiscovery() {
        publish(palette());
        qunsetenv("SEABUNNY_SERPANTINUM_COLORS");
        qputenv("QS_COLORS_JSON", path.toUtf8());
        SerpantinumPalette source;
        QCOMPARE(source.colors(), palette().toVariantMap());
    }

    void xdgStateDiscovery() {
        const QByteArray previous = qgetenv("XDG_STATE_HOME");
        qunsetenv("SEABUNNY_SERPANTINUM_COLORS");
        const QString state = temporary.filePath("xdg-state");
        QVERIFY(QDir().mkpath(state + "/serpantinum"));
        qputenv("XDG_STATE_HOME", state.toUtf8());
        publish(state + "/serpantinum/qs_colors.json", QJsonDocument(palette()).toJson());
        SerpantinumPalette source;
        if (previous.isNull()) qunsetenv("XDG_STATE_HOME"); else qputenv("XDG_STATE_HOME", previous);
        QCOMPARE(source.colors(), palette().toVariantMap());
    }

    void inPlaceWritesRecoverAfterPartialOutput() {
        publish(palette());
        SerpantinumPalette source;
        {
            QFile output(path);
            QVERIFY(output.open(QIODevice::WriteOnly | QIODevice::Truncate));
            QCOMPARE(output.write("{"), 1);
        }
        QTRY_VERIFY(source.status().startsWith("Invalid"));
        QCOMPARE(source.colors(), palette().toVariantMap());
        {
            QFile output(path);
            QVERIFY(output.open(QIODevice::WriteOnly | QIODevice::Truncate));
            const QByteArray next = QJsonDocument(palette(true)).toJson();
            QCOMPARE(output.write(next), next.size());
        }
        QTRY_COMPARE(source.colors(), palette(true).toVariantMap());
    }

    void themeLoadingSwitchingAndPersistence() {
        publish(palette());
        SettingsFixture settings;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty("engine", &settings);
        QQmlComponent component(&engine, QUrl::fromLocalFile(SEABUNNY_THEME_PATH));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QObject> theme(component.create());
        QVERIFY2(theme != nullptr, qPrintable(component.errorString()));
        theme->setProperty("accentName", "serpantinum");
        QVERIFY(theme->property("followsSerpantinum").toBool());
        QCOMPARE(theme->property("background").value<QColor>().name(), QString("#101010"));
        QCOMPARE(theme->property("primary").value<QColor>().name(), QString("#abcdef"));
        QCOMPARE(settings.settings.value("accentName"), QString("serpantinum"));
        std::unique_ptr<QObject> restored(component.create());
        QCOMPARE(restored->property("accentName").toString(), QString("serpantinum"));
        theme->setProperty("accentName", "nord");
        QCOMPARE(theme->property("background").value<QColor>().name(), QString("#2e3440"));
        publish(palette(true));
        QTest::qWait(160);
        QCOMPARE(theme->property("background").value<QColor>().name(), QString("#2e3440"));
        theme->setProperty("accentName", "serpantinum");
        QCOMPARE(theme->property("background").value<QColor>().name(), QString("#fafafa"));
    }

    void lightDarkAndAllSemanticRoles() {
        publish(palette());
        SettingsFixture settings;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty("engine", &settings);
        QQmlComponent component(&engine, QUrl::fromLocalFile(SEABUNNY_THEME_PATH));
        std::unique_ptr<QObject> theme(component.create());
        QVERIFY2(theme != nullptr, qPrintable(component.errorString()));
        theme->setProperty("accentName", "serpantinum");
        const QMap<QString, QString> mapping = {
            {"background", "base"}, {"surface", "base"}, {"surfaceContainerLowest", "crust"},
            {"surfaceContainerLow", "mantle"}, {"surfaceContainer", "surface0"},
            {"surfaceContainerHigh", "surface1"}, {"surfaceContainerHighest", "surface2"},
            {"primary", "blue"}, {"primaryContainer", "sapphire"}, {"secondary", "green"},
            {"secondaryContainer", "yellow"}, {"tertiary", "peach"}, {"tertiaryContainer", "pink"},
            {"textMain", "text"}, {"textMuted", "subtext0"}, {"outline", "subtext1"},
            {"outlineVariant", "overlay0"}, {"danger", "red"}, {"dangerContainer", "maroon"}
        };
        for (const bool light : {false, true}) {
            theme->setProperty("themeMode", "auto");
            publish(palette(light));
            QTRY_COMPARE(theme->property("isDark").toBool(), !light);
            const auto colors = palette(light);
            for (auto role = mapping.cbegin(); role != mapping.cend(); ++role)
                QCOMPARE(theme->property(role.key().toUtf8()).value<QColor>().name(), colors.value(role.value()).toString());
            for (const char *role : {"primaryFg", "primaryContainerFg", "secondaryFg", "secondaryContainerFg",
                                     "tertiaryFg", "tertiaryContainerFg", "dangerFg", "onError"}) {
                const QString color = theme->property(role).value<QColor>().name();
                QVERIFY(color == colors.value("base").toString() || color == colors.value("text").toString()
                        || color == colors.value("crust").toString());
            }
            theme->setProperty("themeMode", light ? "dark" : "light");
            QCOMPARE(theme->property("isDark").toBool(), light);
            const QColor background = theme->property("background").value<QColor>();
            const QColor foreground = theme->property("textMain").value<QColor>();
            QVERIFY(light ? background.lightnessF() < foreground.lightnessF()
                          : background.lightnessF() > foreground.lightnessF());
        }
    }

    void allBuiltinsAndMissingPaletteFallback() {
        SettingsFixture settings;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty("engine", &settings);
        QQmlComponent component(&engine, QUrl::fromLocalFile(SEABUNNY_THEME_PATH));
        std::unique_ptr<QObject> theme(component.create());
        QVERIFY2(theme != nullptr, qPrintable(component.errorString()));
        theme->setProperty("accentName", "serpantinum");
        QVERIFY(!theme->property("followsSerpantinum").toBool());
        QCOMPARE(theme->property("primary").value<QColor>().name(), QString("#d0bcff"));
        const QMap<QString, QStringList> expected = {
            {"wallpaper", {"#121214", "#fef8f4"}}, {"lavender", {"#121214", "#faf8fc"}},
            {"amber", {"#131315", "#fdf8f4"}}, {"catppuccin", {"#1e1e2e", "#eff1f5"}},
            {"nord", {"#2e3440", "#eceff4"}}, {"tokyonight", {"#1a1b26", "#d5d6db"}},
            {"gruvbox", {"#282828", "#fbf1c7"}}, {"rosepine", {"#191724", "#faf4ed"}}
        };
        for (auto builtin = expected.cbegin(); builtin != expected.cend(); ++builtin) {
            theme->setProperty("accentName", builtin.key());
            theme->setProperty("themeMode", "dark");
            QCOMPARE(theme->property("background").value<QColor>().name(), builtin.value()[0]);
            theme->setProperty("themeMode", "light");
            QCOMPARE(theme->property("background").value<QColor>().name(), builtin.value()[1]);
        }
    }

    void wallpaperDualSchemesAndSingleSchemeFallback() {
        SettingsFixture settings;
        settings.wallpaper = R"({"colors":{"dark":{"background":"#111122","on_surface":"#eeeeff","primary":"#aabbcc","on_primary":"#112233"},"light":{"background":"#fafaff","on_surface":"#111133","primary":"#223355","on_primary":"#ffffff"}}})";
        QQmlEngine engine;
        engine.rootContext()->setContextProperty("engine", &settings);
        QQmlComponent component(&engine, QUrl::fromLocalFile(SEABUNNY_THEME_PATH));
        std::unique_ptr<QObject> theme(component.create());
        QVERIFY2(theme != nullptr, qPrintable(component.errorString()));
        theme->setProperty("themeMode", "dark");
        QCOMPARE(theme->property("background").value<QColor>().name(), QString("#111122"));
        QCOMPARE(theme->property("primaryFg").value<QColor>().name(), QString("#112233"));
        theme->setProperty("themeMode", "light");
        QCOMPARE(theme->property("background").value<QColor>().name(), QString("#fafaff"));
        QCOMPARE(theme->property("primaryFg").value<QColor>().name(), QString("#ffffff"));
        settings.wallpaper = R"({"background":"#101010","on_surface":"#fafafa","primary":"#aabbcc"})";
        std::unique_ptr<QObject> single(component.create());
        single->setProperty("themeMode", "light");
        QVERIFY(single->property("background").value<QColor>().lightnessF() > 0.8);
        QVERIFY(single->property("textMain").value<QColor>().lightnessF() < 0.2);
    }

    void autoFollowsAppearanceNotifications() {
        SettingsFixture settings;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty("engine", &settings);
        QQmlComponent component(&engine, QUrl::fromLocalFile(SEABUNNY_THEME_PATH));
        std::unique_ptr<QObject> theme(component.create());
        QVERIFY2(theme != nullptr, qPrintable(component.errorString()));
        theme->setProperty("accentName", "lavender");
        theme->setProperty("themeMode", "auto");
        theme->setProperty("systemColorScheme", int(Qt::ColorScheme::Light));
        QTRY_VERIFY(!theme->property("isDark").toBool());
        theme->setProperty("systemColorScheme", int(Qt::ColorScheme::Dark));
        QTRY_VERIFY(theme->property("isDark").toBool());
    }
};

QTEST_MAIN(SerpantinumTests)
#include "tst_serpantinum.moc"
