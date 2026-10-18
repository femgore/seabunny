#include "thumbnail_provider.h"
#include "icon_provider.h"

#include <QCache>
#include <QCryptographicHash>
#include <QDir>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QImageReader>
#include <QImageIOHandler>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMutex>
#include <QMutexLocker>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQuickAsyncImageProvider>
#include <QQuickTextureFactory>
#include <QRunnable>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTemporaryFile>
#include <QThreadPool>
#include <QThread>
#include <QUrl>
#include <atomic>
#include <memory>
#include <mutex>

namespace {
std::atomic<int> requests{0}, memoryHits{0}, diskHits{0}, generated{0}, cancellations{0}, active{0}, peak{0};
struct ThumbnailCache {
    QMutex mutex;
    QCache<QString, QImage> images{32 * 1024};
    QHash<QString, std::weak_ptr<QMutex>> gates;
    unsigned writes = 0;
};

bool runDecoder(const QString &program, const QStringList &arguments,
                const std::atomic_bool &cancelled) {
    if (cancelled.load()) return false;
    QProcess process;
    process.setProcessChannelMode(QProcess::SeparateChannels);
    process.setStandardOutputFile(QProcess::nullDevice());
    process.setStandardErrorFile(QProcess::nullDevice());
    process.start(program, arguments);
    QElapsedTimer elapsed;
    elapsed.start();
    while (!process.waitForFinished(40)) {
        if (process.state() == QProcess::NotRunning) break;
        if (cancelled.load() || elapsed.elapsed() > 5000) {
            process.kill();
            process.waitForFinished(1000);
            return false;
        }
    }
    return !cancelled.load() && process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0;
}

class ThumbnailResponse : public QQuickImageResponse, public QRunnable {
public:
    ThumbnailResponse(QString request, QSize requested, std::shared_ptr<ThumbnailCache> cache)
        : request(std::move(request)), requested(requested), cache(std::move(cache)) {
        setAutoDelete(false);
    }

    void cancel() override { cancelled.store(true); }
    QQuickTextureFactory *textureFactory() const override {
        const int edge = qBound(32, qMax(requested.width(), requested.height()), 512);
        return QQuickTextureFactory::textureFactoryForImage(
            image.width() > edge || image.height() > edge
                ? image.scaled(edge, edge, Qt::KeepAspectRatio, Qt::SmoothTransformation) : image);
    }
    QString errorString() const override { return {}; }

    void run() override {
        const int workers = active.fetch_add(1) + 1;
        int previous = peak.load();
        while (workers > previous && !peak.compare_exchange_weak(previous, workers)) {}
        if (!cancelled.load()) image = load();
        if (cancelled.load()) cancellations.fetch_add(1);
        active.fetch_sub(1);
        emit finished();
    }

private:
    QImage load() {
        const QString path = QUrl::fromPercentEncoding(request.section('?', 0, 0).toUtf8());
        const QFileInfo info(path);
        if (!info.isFile()) return {};
        const int edge = 512;
        const QByteArray identity = (request + ":" + QString::number(info.size()) + ":"
            + QString::number(info.lastModified().toMSecsSinceEpoch()) + ":" + QString::number(edge)).toUtf8();
        const QString key = QString::fromLatin1(QCryptographicHash::hash(identity, QCryptographicHash::Sha256).toHex());
        std::shared_ptr<QMutex> gate;
        {
            QMutexLocker guard(&cache->mutex);
            if (const QImage *cached = cache->images.object(key)) {
                memoryHits.fetch_add(1);
                return *cached;
            }
            gate = cache->gates.value(key).lock();
            if (!gate) {
                gate = std::make_shared<QMutex>();
                if (cache->gates.size() > 128) {
                    for (auto entry = cache->gates.begin(); entry != cache->gates.end();) {
                        if (entry.value().expired()) entry = cache->gates.erase(entry); else ++entry;
                    }
                }
                cache->gates.insert(key, gate);
            }
        }
        std::unique_lock<QMutex> decoding(*gate, std::defer_lock);
        while (!decoding.try_lock()) {
            if (cancelled.load()) return {};
            QThread::msleep(10);
        }
        {
            QMutexLocker guard(&cache->mutex);
            if (const QImage *cached = cache->images.object(key)) {
                memoryHits.fetch_add(1);
                return *cached;
            }
        }
        const QString directory = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/thumbnails-v2";
        QDir().mkpath(directory);
        const QString destination = directory + "/" + key + ".png";
        QImage result(destination);
        if (!result.isNull()) diskHits.fetch_add(1);
        if (result.isNull() && !cancelled.load()) {
            QImageReader reader(path);
            reader.setAutoTransform(true);
            const QSize original = reader.size();
            reader.setScaledSize(original.scaled(edge, edge, Qt::KeepAspectRatio));
            if (reader.supportsOption(QImageIOHandler::ScaledSize)
                    || (qint64(original.width()) * original.height() <= 8000000 && original.isValid()))
                result = reader.read();
            if (result.isNull()) {
                QTemporaryFile temporary(directory + "/.decode-XXXXXX.png");
                if (temporary.open()) {
                    const QString output = temporary.fileName();
                    temporary.close();
                    const QString suffix = info.suffix().toLower();
                    if (QStringList{"mp4", "mkv", "webm", "mov", "avi", "flv", "wmv"}.contains(suffix)) {
                        const QStringList common{"-loglevel", "error", "-nostdin", "-threads", "1"};
                        for (const QString &seek : {QString("1"), QString("0")}) {
                            if (runDecoder("ffmpeg", common + QStringList{"-ss", seek, "-i", path,
                                "-frames:v", "1", "-vf", QString("scale=%1:%1:force_original_aspect_ratio=decrease").arg(edge),
                                "-threads", "1", "-y", output}, cancelled)) {
                                result.load(output);
                                if (!result.isNull()) break;
                            }
                            if (cancelled.load()) break;
                        }
                    } else if (suffix == "kra" || suffix == "ora") {
                        const QString script = "import sys,zipfile\nwith zipfile.ZipFile(sys.argv[1]) as z:\n for name in ['preview.png','Thumbnails/thumbnail.png','mergedimage.png']:\n  if name in z.namelist() and z.getinfo(name).file_size<=16777216:\n   open(sys.argv[2],'wb').write(z.read(name));break\n";
                        if (runDecoder("python3", {"-c", script, path, output}, cancelled)) result.load(output);
                    } else if (runDecoder("magick", {"-limit", "memory", "64MiB", "-limit", "map", "64MiB",
                        "-limit", "disk", "128MiB", path + "[0]", "-thumbnail", QString("%1x%1").arg(edge), output}, cancelled)) {
                        result.load(output);
                    }
                }
            }
            if (!result.isNull() && !cancelled.load()) {
                result = result.scaled(edge, edge, Qt::KeepAspectRatio, Qt::SmoothTransformation);
                QSaveFile output(destination);
                if (output.open(QIODevice::WriteOnly) && result.save(&output, "PNG") && output.commit()) generated.fetch_add(1);
                QMutexLocker guard(&cache->mutex);
                if (++cache->writes % 32 == 0) {
                    const QFileInfoList entries = QDir(directory).entryInfoList({"*.png"}, QDir::Files, QDir::Time);
                    qint64 bytes = 0;
                    int count = 0;
                    for (const QFileInfo &entry : entries) {
                        bytes += entry.size();
                        if (++count > 2048 || bytes > 128 * 1024 * 1024) QFile::remove(entry.absoluteFilePath());
                    }
                }
            }
        }
        if (cancelled.load()) return {};
        {
            QMutexLocker guard(&cache->mutex);
            cache->images.insert(key, new QImage(result), qMax(1, int(result.sizeInBytes() / 1024)));
        }
        return result;
    }

    QString request;
    QSize requested;
    std::shared_ptr<ThumbnailCache> cache;
    std::atomic_bool cancelled{false};
    QImage image;
};

class ThumbnailProvider : public QQuickAsyncImageProvider {
public:
    ThumbnailProvider() { pool.setMaxThreadCount(2); }
    ~ThumbnailProvider() override { pool.waitForDone(); }
    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &size) override {
        requests.fetch_add(1);
        auto *response = new ThumbnailResponse(id, size, cache);
        pool.start(response);
        return response;
    }
private:
    QThreadPool pool;
    std::shared_ptr<ThumbnailCache> cache = std::make_shared<ThumbnailCache>();
};
}

void install_thumbnail_provider(QQmlApplicationEngine &engine) {
    install_icon_provider(engine);
    engine.addImageProvider("seabunnythumb", new ThumbnailProvider);
}

QString thumbnail_statistics() {
    return QString::fromUtf8(QJsonDocument(QJsonObject{
        {"requests", requests.load()}, {"memoryHits", memoryHits.load()},
        {"diskHits", diskHits.load()}, {"generated", generated.load()},
        {"cancelled", cancellations.load()}, {"peakWorkers", peak.load()}
    }).toJson(QJsonDocument::Compact));
}
