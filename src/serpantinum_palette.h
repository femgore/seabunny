#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QQmlEngine>
#include <QTimer>
#include <QVariantMap>

class SerpantinumPalette : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString sourcePath READ sourcePath CONSTANT)
    Q_PROPERTY(QVariantMap colors READ colors NOTIFY colorsChanged)
    Q_PROPERTY(bool available READ available NOTIFY colorsChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit SerpantinumPalette(QObject *parent = nullptr);
    QString sourcePath() const { return m_path; }
    QVariantMap colors() const { return m_colors; }
    bool available() const { return !m_colors.isEmpty(); }
    QString status() const { return m_status; }

signals:
    void colorsChanged();
    void statusChanged();

private:
    void watchSource();
    void reload();
    void setStatus(const QString &status);

    QString m_path;
    QString m_status;
    QVariantMap m_colors;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
