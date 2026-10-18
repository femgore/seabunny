#pragma once
#include <QString>
#include <QtCore/qlogging.h>

void configure_seabunny();
QString seabunny_startup_arguments();
QString seabunny_sidebar_state(bool chooser);
bool seabunny_save_sidebar_state(bool chooser, bool expanded, double width);
bool seabunny_ignorable_focus_warning(QtMsgType type, const QMessageLogContext &context, const QString &message);
