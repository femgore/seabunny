#pragma once
#include <QObject>
#include <QColor>
#include <QQmlEngine>

class QQmlApplicationEngine;
void install_icon_provider(QQmlApplicationEngine &engine);

class SeabunnyStyle : public QObject {
    Q_OBJECT
    QML_ELEMENT
public:
    explicit SeabunnyStyle(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE void finishAnimations(QObject *root);
    Q_INVOKABLE void setApplicationAccent(const QColor &color);
};
