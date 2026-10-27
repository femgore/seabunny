#pragma once
#include <QString>

QString seabunny_open_with_apps(const QString &paths);
QString seabunny_open_with(const QString &paths, const QString &desktopId, bool makeDefault);
QString seabunny_open_file(const QString &path);

QString seabunny_set_default_app(const QString &paths, const QString &desktopId);
