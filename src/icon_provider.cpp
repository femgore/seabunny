#include "icon_provider.h"
#include <QCache>
#include <QGuiApplication>
#include <QImageReader>
#include <QIcon>
#include <QDir>
#include <QStandardPaths>
#include <QSettings>
#include <QMutex>
#include <QMutexLocker>
#include <QPainter>
#include <QPointer>
#include <QProcess>
#include <QQuickImageProvider>
#include <QUrl>
#include <QUrlQuery>
#include <QQmlApplicationEngine>
#include <QQmlProperty>

namespace {
QString validIconTheme(QString value) {
    value = value.trimmed();
    if (value.size() >= 2 && value.startsWith('\'') && value.endsWith('\''))
        value = value.mid(1, value.size() - 2);
    if (value.isEmpty() || value.contains('/') || value.contains('\n'))
        return {};
    return value;
}

QString gtkIconTheme() {
    QString configHome = qEnvironmentVariable("SEABUNNY_DESKTOP_CONFIG_HOME");
    if (configHome.isEmpty())
        configHome = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    for (const QString &toolkit : {QStringLiteral("gtk-4.0"), QStringLiteral("gtk-3.0")}) {
        QSettings settings(QDir(configHome).filePath(toolkit + QStringLiteral("/settings.ini")), QSettings::IniFormat);
        const QString theme = validIconTheme(settings.value(QStringLiteral("Settings/gtk-icon-theme-name")).toString());
        if (!theme.isEmpty())
            return theme;
    }
    return {};
}

class IconProvider : public QQuickImageProvider {
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Image), systemTheme(QIcon::themeName()) {
        searchPaths = QIcon::themeSearchPaths();
        for (const auto &root : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation))
            searchPaths.append(root + "/icons");
        const QString desktopDataHome = qEnvironmentVariable("SEABUNNY_DESKTOP_DATA_HOME");
        if (!desktopDataHome.isEmpty())
            searchPaths.append(QDir(desktopDataHome).filePath("icons"));
        searchPaths.append(QDir::homePath() + "/.icons");
        searchPaths.removeDuplicates();
        const QString gtkTheme = gtkIconTheme();
        if (!gtkTheme.isEmpty()) {
            systemTheme = gtkTheme;
        } else {
            QProcess settings;
            settings.start("gsettings", {"get", "org.gnome.desktop.interface", "icon-theme"});
            if (settings.waitForFinished(500) && settings.exitCode() == 0) {
                const QString value = validIconTheme(QString::fromUtf8(settings.readAllStandardOutput()));
                if (!value.isEmpty()) systemTheme = value;
            } else if (settings.state() != QProcess::NotRunning) {
                settings.kill();
                settings.waitForFinished(500);
            }
        }
    }

    QImage requestImage(const QString &id, QSize *size, const QSize &requested) override {
        QMutexLocker lock(&mutex);
        const int edge = qBound(16, qMax(requested.width(), requested.height()), 512);
        const QString key = id + "#" + QString::number(edge);
        if (auto cached = images.object(key)) {
            if (size) *size = cached->size();
            return *cached;
        }
        const QUrl url("image://seabunnyicon/" + id);
        const QUrlQuery query(url);
        const QString name = QUrl::fromPercentEncoding(url.path().mid(1).toUtf8());
        const QString previous = QIcon::themeName();
        const QStringList previousPaths = QIcon::themeSearchPaths();
        const QString selected = query.queryItemValue("theme");
        QIcon::setThemeName(selected.isEmpty() ? systemTheme : selected);
        QIcon::setThemeSearchPaths(searchPaths);
        QIcon icon = QIcon::fromTheme(name);
        if (icon.isNull() && name.endsWith("-symbolic")) icon = QIcon::fromTheme(name.chopped(9));
        QImage image = icon.pixmap(edge, edge).toImage();
        if (name == "seabunny-logo") {
            QImageReader reader(":/seabunny/branding/seabunny.svg");
            reader.setScaledSize(QSize(edge, edge));
            image = reader.read();
        }
        QIcon::setThemeName(previous);
        QIcon::setThemeSearchPaths(previousPaths);
        QColor foreground(query.queryItemValue("color", QUrl::FullyDecoded));
        if (!foreground.isValid()) foreground = QColor("#808080");
        if (image.isNull()) {
            image = QImage(edge, edge, QImage::Format_ARGB32_Premultiplied);
            image.fill(Qt::transparent);
            QPainter painter(&image);
            painter.setRenderHint(QPainter::Antialiasing);
            painter.setPen(QPen(foreground, qMax(2, edge / 24)));
            painter.setBrush(Qt::NoBrush);
            painter.drawRoundedRect(QRectF(edge * .16, edge * .12, edge * .68, edge * .76), edge * .06, edge * .06);
        } else if (name.endsWith("-symbolic") || name == "seabunny-logo") {
            QPainter painter(&image);
            painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
            painter.fillRect(image.rect(), foreground);
        }
        if (size) *size = image.size();
        images.insert(key, new QImage(image), qMax(1, int(image.sizeInBytes() / 1024)));
        return image;
    }
private:
    QString systemTheme;
    QStringList searchPaths;
    QMutex mutex;
    QCache<QString, QImage> images{8 * 1024};
};
}

void install_icon_provider(QQmlApplicationEngine &engine) {
    engine.addImageProvider("seabunnyicon", new IconProvider);
}

void SeabunnyStyle::setApplicationAccent(const QColor &color) {
    if (!color.isValid()) return;
    QGuiApplication::setWindowIcon(QIcon(":/seabunny/branding/seabunny_logo.svg"));
}

void SeabunnyStyle::finishAnimations(QObject *root) {
    if (!root) return;
    QList<QPointer<QObject>> objects;
    for (QObject *object : root->findChildren<QObject *>()) objects.append(object);
    for (const auto &object : objects) {
        if (!object) continue;
        const auto meta = object->metaObject();
        if (meta->indexOfProperty("running") >= 0 && meta->indexOfMethod("complete()") >= 0 && object->property("running").toBool()) {
            const QPointer<QObject> target = object->property("target").value<QObject *>();
            const QString property = object->property("property").toString();
            const QVariant finalValue = object->property("to");
            QMetaObject::invokeMethod(object, "complete", Qt::DirectConnection);
            if (target && !property.isEmpty() && finalValue.isValid())
                QQmlProperty(target, property).write(finalValue);
        }
    }
}
