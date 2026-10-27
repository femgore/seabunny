#include "serpantinum_palette.h"
#include "icon_provider.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QSaveFile>
#include <QScopeGuard>
#include <QTemporaryDir>
#include <QtTest>
#include <memory>

class AppearanceSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool is_dark MEMBER dark CONSTANT)
    Q_PROPERTY(QString wallpaper_colors_json MEMBER wallpaper NOTIFY wallpaperChanged)
public:
    bool dark = true;
    QString wallpaper = "{}";
    QMap<QString,QString> settings;
    Q_INVOKABLE QString get_setting(const QString &key) { return settings.value(key); }
    Q_INVOKABLE void set_setting(const QString &key, const QString &value) { settings[key] = value; }
    Q_INVOKABLE void reload_wallpaper_colors() {}
signals:
    void wallpaperChanged();
};

class AppearanceTests : public QObject {
    Q_OBJECT
    QTemporaryDir fixture;
    QString desktop;
    QMap<QByteArray,QByteArray> previous;
    static QJsonObject colors() {
        QJsonObject result;
        for (const auto &name : QStringList{"base","mantle","crust","text","subtext0","subtext1",
                "surface0","surface1","surface2","overlay0","overlay1","overlay2","blue","sapphire",
                "peach","green","red","mauve","pink","yellow","maroon","teal"}) result[name] = "#445566";
        result["base"] = "#101010"; result["text"] = "#fafafa"; result["blue"] = "#abcdef";
        return result;
    }
    static void publish(const QString &path, const QJsonObject &object) {
        QVERIFY(QDir().mkpath(QFileInfo(path).absolutePath()));
        QSaveFile file(path); QVERIFY(file.open(QIODevice::WriteOnly));
        auto bytes = QJsonDocument(object).toJson();
        QCOMPARE(file.write(bytes), bytes.size()); QVERIFY(file.commit());
    }
    std::unique_ptr<QObject> theme(QQmlEngine &engine, AppearanceSettings &settings) {
        engine.rootContext()->setContextProperty("core", &settings);
        QQmlComponent component(&engine, QUrl::fromLocalFile(SEABUNNY_THEME_PATH));
        if (!component.isReady()) qWarning().noquote() << component.errorString();
        return std::unique_ptr<QObject>(component.create());
    }
private slots:
    void initTestCase() {
        qmlRegisterType<SerpantinumPalette>("app.seabunny",1,0,"SerpantinumPalette");
        qmlRegisterType<SeabunnyStyle>("app.seabunny",1,0,"SeabunnyStyle");
    }
    void init() {
        QVERIFY(fixture.isValid());
        desktop = fixture.filePath(QUuid::createUuid().toString(QUuid::WithoutBraces));
        for (const auto &key : {"SEABUNNY_SERPANTINUM_COLORS","QS_COLORS_JSON","QS_STATE_DIR","SEABUNNY_DESKTOP_STATE_HOME","XDG_STATE_HOME"}) {
            previous[key] = qgetenv(key); qunsetenv(key);
        }
        qputenv("SEABUNNY_DESKTOP_STATE_HOME",desktop.toUtf8());
        qputenv("XDG_STATE_HOME",fixture.filePath("isolated-application-state").toUtf8());
    }
    void cleanup() {
        for (auto it=previous.cbegin();it!=previous.cend();++it) {
            if (it.value().isNull()) qunsetenv(it.key()); else qputenv(it.key(),it.value());
        }
    }
    void automaticDesktopPaletteAndAtomicUpdates() {
        const QString path=desktop+"/seabunny/serpantinum-colors.json";
        publish(path,colors());
        SerpantinumPalette source;
        QVERIFY(source.available()); QCOMPARE(source.sourcePath(),path);
        AppearanceSettings settings; QQmlEngine engine;
        auto item=theme(engine,settings); QVERIFY(item);
        QCOMPARE(item->property("accentName").toString(),QString("auto"));
        QVERIFY(item->property("followsSerpantinum").toBool());
        QCOMPARE(item->property("primary").value<QColor>(),QColor("#abcdef"));
        auto next=colors(); next["blue"]="#123456"; publish(path,next);
        QTRY_COMPARE(item->property("primary").value<QColor>(),QColor("#123456"));
        item->setProperty("accentName","nord");
        QCOMPARE(item->property("primary").value<QColor>(),QColor("#88c0d0"));
        next["blue"]="#fedcba"; publish(path,next); QTest::qWait(160);
        QCOMPARE(item->property("primary").value<QColor>(),QColor("#88c0d0"));
    }
    void explicitUnavailablePaletteDoesNotUseAnotherSource() {
        publish(desktop+"/seabunny/serpantinum-colors.json",colors());
        const QString missing=fixture.filePath("explicit-missing.json");
        qputenv("SEABUNNY_SERPANTINUM_COLORS",missing.toUtf8());
        SerpantinumPalette source; QVERIFY(!source.available()); QCOMPARE(source.sourcePath(),missing);
    }
    void wallpaperKeepsSeparateLightAndDarkSchemes() {
        AppearanceSettings settings; settings.settings["accentName"]="wallpaper";
        settings.wallpaper=R"({"colors":{"dark":{"background":"#111122","on_surface":"#eeeeff","primary":"#aabbcc","on_primary":"#112233"},"light":{"background":"#fafaff","on_surface":"#111133","primary":"#223355","on_primary":"#ffffff"}}})";
        QQmlEngine engine; auto item=theme(engine,settings); QVERIFY(item);
        item->setProperty("themeMode","dark");
        QCOMPARE(item->property("background").value<QColor>(),QColor("#111122"));
        QCOMPARE(item->property("primaryFg").value<QColor>(),QColor("#112233"));
        item->setProperty("themeMode","light");
        QCOMPARE(item->property("background").value<QColor>(),QColor("#fafaff"));
        QCOMPARE(item->property("primaryFg").value<QColor>(),QColor("#ffffff"));
    }
};
QTEST_MAIN(AppearanceTests)
#include "tst_next_appearance.moc"
