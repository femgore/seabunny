#pragma once
#include <QObject>
#include <QVariantMap>
#include <QDBusArgument>
#include <QDBusMessage>
#include <QDBusVirtualObject>
#include <QPointer>
#include <functional>

struct PortalRule { uint kind; QString pattern; };
using PortalRules = QList<PortalRule>;
struct PortalFilter { QString name; PortalRules rules; };
using PortalFilters = QList<PortalFilter>;
struct PortalPair { QString id; QString value; };
using PortalPairs = QList<PortalPair>;
struct PortalChoice { QString id; QString label; PortalPairs options; QString selected; };
using PortalChoices = QList<PortalChoice>;
Q_DECLARE_METATYPE(PortalRule)
Q_DECLARE_METATYPE(PortalRules)
Q_DECLARE_METATYPE(PortalFilter)
Q_DECLARE_METATYPE(PortalFilters)
Q_DECLARE_METATYPE(PortalPair)
Q_DECLARE_METATYPE(PortalPairs)
Q_DECLARE_METATYPE(PortalChoice)
Q_DECLARE_METATYPE(PortalChoices)
QDBusArgument &operator<<(QDBusArgument &, const PortalRule &);
const QDBusArgument &operator>>(const QDBusArgument &, PortalRule &);
QDBusArgument &operator<<(QDBusArgument &, const PortalFilter &);
const QDBusArgument &operator>>(const QDBusArgument &, PortalFilter &);
QDBusArgument &operator<<(QDBusArgument &, const PortalPair &);
const QDBusArgument &operator>>(const QDBusArgument &, PortalPair &);
QDBusArgument &operator<<(QDBusArgument &, const PortalChoice &);
const QDBusArgument &operator>>(const QDBusArgument &, PortalChoice &);
void register_portal_types();
bool start_seabunny_portal();
bool seabunny_portal_mode();

// One controller and one QML engine per request. No file creation or writing.
class PortalRequest : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap config READ config CONSTANT)
public:
    PortalRequest(const QString &method, const QString &title, const QVariantMap &options, QObject *parent = nullptr);
    QVariantMap config() const { return m_config; }
    Q_INVOKABLE bool matches(const QString &path, int filter) const;
    Q_INVOKABLE QString saveName(const QString &name, int filter) const;
    Q_INVOKABLE QVariantMap accept(const QString &folder, const QStringList &selected,
                                  const QString &name, int filter, const QVariantMap &choices, bool overwrite);
    Q_INVOKABLE void cancel();
    void finish(uint response, const QVariantMap &results = {});
    std::function<void(uint, const QVariantMap &)> completed;
    bool valid = true;
private:
    QString m_method;
    QVariantMap m_config;
    PortalFilters m_filters;
    PortalChoices m_choices;
    QStringList m_files;
    QString m_confirmPath;
    bool m_finished = false;
};

class PortalBackend : public QDBusVirtualObject {
    Q_OBJECT
public:
    explicit PortalBackend(QObject *parent = nullptr);
    QString introspect(const QString &path) const override;
    bool handleMessage(const QDBusMessage &, const QDBusConnection &) override;
protected:
    virtual bool showDialog(PortalRequest *, const QString &parentWindow);
private:
    struct Pending { QPointer<PortalRequest> request; QString sender; };
    QHash<QString, Pending> m_pending;
};
