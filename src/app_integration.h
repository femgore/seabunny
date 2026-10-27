#pragma once
#include <QString>
#include <QtCore/qlogging.h>

void configure_seabunny();
QString seabunny_startup_arguments();
QString seabunny_sidebar_state(bool chooser);
bool seabunny_save_sidebar_state(bool chooser, bool expanded, double width);
QString seabunny_clipboard_files();
void seabunny_set_clipboard_files(const QString &paths, bool cut);
bool seabunny_ignorable_focus_warning(QtMsgType type, const QMessageLogContext &context, const QString &message);
