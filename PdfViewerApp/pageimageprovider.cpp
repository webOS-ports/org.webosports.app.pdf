/*
 * (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "pageimageprovider.h"
#include "documentregistry.h"
#include "renderplan.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFileInfo>
#include <QRunnable>
#include <QSaveFile>
#include <QTimeZone>
#include <QUrl>

#include <poppler-qt6.h>

#include <algorithm>

namespace {

bool shouldAbort(const QVariant &closure)
{
    const auto *abort = static_cast<const std::atomic_bool *>(closure.value<void *>());
    return abort && abort->load();
}

Poppler::Page::Rotation popplerRotation(int degrees)
{
    switch (degrees) {
    case 90:
        return Poppler::Page::Rotate90;
    case 180:
        return Poppler::Page::Rotate180;
    case 270:
        return Poppler::Page::Rotate270;
    default:
        return Poppler::Page::Rotate0;
    }
}

/*
 * A response that is its own job, as in Qt's example: the engine owns it
 * and deletes it once finished() is out, so the pool must not (no
 * autoDelete), and finished() is the last thing run() does.
 */
class ImageJob : public QQuickImageResponse, public QRunnable
{
public:
    ImageJob() { setAutoDelete(false); }

    QQuickTextureFactory *textureFactory() const override
    {
        return QQuickTextureFactory::textureFactoryForImage(m_image);
    }
    QString errorString() const override { return m_error; }
    void cancel() override { m_cancelled = true; }

    void run() override
    {
        if (!m_cancelled)
            work();
        emit finished();
    }

protected:
    virtual void work() = 0;

    QImage m_image;
    QString m_error;
    std::atomic_bool m_cancelled { false };
};

class PageJob : public ImageJob
{
public:
    explicit PageJob(const QString &id)
        : m_id(id)
    {
    }

protected:
    void work() override
    {
        const std::optional<PageRequest> request = PageRequest::parse(m_id);
        if (!request) {
            m_error = QStringLiteral("Not a page request: %1").arg(m_id);
            return;
        }
        DocumentLease document = DocumentRegistry::instance().acquire(request->documentId);
        if (!document) {
            m_error = QStringLiteral("The document is not open");
            return;
        }
        m_image = renderPage(document.get(), *request, &m_cancelled, &m_error);
    }

private:
    QString m_id;
};

class ThumbnailJob : public ImageJob
{
public:
    ThumbnailJob(const QString &cacheDir, const QString &path, int size)
        : m_cacheDir(cacheDir)
        , m_path(path)
        , m_size(size)
    {
    }

protected:
    void work() override
    {
        const QString cached = ThumbnailImageProvider::cacheFile(m_cacheDir, m_path, m_size);
        if (cached.isEmpty()) {
            m_error = QStringLiteral("No such file");
            return;
        }
        if (m_image.load(cached, "PNG"))
            return;

        DocumentRegistry::LoadError loadError = DocumentRegistry::LoadError::None;
        std::unique_ptr<Poppler::Document> document = DocumentRegistry::load(m_path, QByteArray(), &loadError);
        if (!document || document->numPages() < 1) {
            // A locked document has no picture: the library shows its icon.
            m_error = QStringLiteral("Cannot open %1").arg(m_path);
            return;
        }
        std::unique_ptr<Poppler::Page> page = document->page(0);
        if (!page) {
            m_error = QStringLiteral("No first page");
            return;
        }
        const QSizeF points = page->pageSizeF();
        // The longer side at the requested size.
        const int width = points.width() >= points.height()
            ? m_size
            : std::max(1, static_cast<int>(m_size * points.width() / points.height()));
        PageRequest request;
        request.page = 0;
        request.width = width;
        m_image = renderPage(document.get(), request, &m_cancelled, &m_error);
        if (m_image.isNull() || m_cancelled)
            return;

        QDir().mkpath(m_cacheDir);
        QSaveFile file(cached);
        if (file.open(QIODevice::WriteOnly) && m_image.save(&file, "PNG"))
            file.commit();
        else
            file.cancelWriting();
        ThumbnailImageProvider::prune(m_cacheDir, 400);
    }

private:
    QString m_cacheDir;
    QString m_path;
    int m_size;
};

} // namespace

QImage renderPage(Poppler::Document *document, const PageRequest &request, const std::atomic_bool *abort,
                  QString *error)
{
    if (!document || request.page < 0 || request.page >= document->numPages()) {
        if (error)
            *error = QStringLiteral("No page %1").arg(request.page + 1);
        return QImage();
    }
    std::unique_ptr<Poppler::Page> page = document->page(request.page);
    if (!page) {
        if (error)
            *error = QStringLiteral("Page %1 cannot be read").arg(request.page + 1);
        return QImage();
    }
    const std::optional<RenderPlan> plan =
        RenderPlan::make(page->pageSizeF(), request.rotation, request.width, request.crop, MaxRenderPixels);
    if (!plan) {
        if (error)
            *error = QStringLiteral("Page %1 has no size").arg(request.page + 1);
        return QImage();
    }

    QImage image = page->renderToImage(plan->dpi, plan->dpi, plan->area.x(), plan->area.y(), plan->area.width(),
                                       plan->area.height(), popplerRotation(request.rotation), nullptr, nullptr,
                                       shouldAbort,
                                       QVariant::fromValue(static_cast<void *>(const_cast<std::atomic_bool *>(abort))));
    if (image.isNull()) {
        if (error)
            *error = abort && abort->load() ? QStringLiteral("Cancelled")
                                            : QStringLiteral("Page %1 cannot be drawn").arg(request.page + 1);
        return image;
    }
    if (request.night)
        image.invertPixels(QImage::InvertRgb);
    return image;
}

// The size comes in the id: the width, and the part of the page.
QQuickImageResponse *PageImageProvider::requestImageResponse(const QString &id, const QSize &)
{
    auto *job = new PageJob(id);
    DocumentRegistry::instance().renderPool()->start(job);
    return job;
}

ThumbnailImageProvider::ThumbnailImageProvider(const QString &cacheDir)
    : m_cacheDir(cacheDir)
{
}

QQuickImageResponse *ThumbnailImageProvider::requestImageResponse(const QString &id, const QSize &requestedSize)
{
    const int size = qBound(16, std::max(requestedSize.width(), requestedSize.height()), 512);
    const QString path = QUrl::fromPercentEncoding(id.toUtf8());
    auto *job = new ThumbnailJob(m_cacheDir, path, requestedSize.isValid() ? size : 128);
    DocumentRegistry::instance().taskPool()->start(job);
    return job;
}

QString ThumbnailImageProvider::cacheFile(const QString &cacheDir, const QString &path, int size)
{
    const QFileInfo info(path);
    if (!info.isFile())
        return QString();
    const QByteArray key = info.absoluteFilePath().toUtf8() + '\n' + QByteArray::number(info.size()) + '\n'
        + QByteArray::number(info.lastModified(QTimeZone::UTC).toMSecsSinceEpoch()) + '\n'
        + QByteArray::number(size);
    return cacheDir + QLatin1Char('/')
        + QString::fromLatin1(QCryptographicHash::hash(key, QCryptographicHash::Sha1).toHex())
        + QStringLiteral(".png");
}

void ThumbnailImageProvider::prune(const QString &cacheDir, int maxFiles)
{
    QDir dir(cacheDir);
    const QFileInfoList files = dir.entryInfoList({ QStringLiteral("*.png") }, QDir::Files, QDir::Time);
    for (qsizetype i = maxFiles; i < files.size(); ++i)
        QFile::remove(files.at(i).absoluteFilePath());
}
