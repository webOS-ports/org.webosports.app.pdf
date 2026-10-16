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

#ifndef PDFVIEWERAPP_PAGEIMAGEPROVIDER_H
#define PDFVIEWERAPP_PAGEIMAGEPROVIDER_H

#include <QImage>
#include <QQuickAsyncImageProvider>
#include <QString>

#include <atomic>

namespace Poppler {
class Document;
}
struct PageRequest;

/*
 * Draws one page of a document. Shared by the page provider and the tests;
 * abort, when given, is checked while drawing so a page scrolled past stops
 * early. Sets error and returns a null image when it cannot.
 */
QImage renderPage(Poppler::Document *document, const PageRequest &request, const std::atomic_bool *abort,
                  QString *error);

/*
 * image://pdfpage/<request> - a page of an open document (see PageRequest),
 * drawn on DocumentRegistry's render threads.
 */
class PageImageProvider : public QQuickAsyncImageProvider
{
public:
    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;
};

/*
 * image://pdfthumb/<percent-encoded path> - the first page of a file, for
 * the library, at the requested size (sourceSize). Kept on disk under the
 * cache directory, by path, size and modification time, so the library
 * does not open every document each time it is shown.
 */
class ThumbnailImageProvider : public QQuickAsyncImageProvider
{
public:
    explicit ThumbnailImageProvider(const QString &cacheDir);

    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;

    // The cache file for a document as it is now ("" if it is not a file).
    static QString cacheFile(const QString &cacheDir, const QString &path, int size);
    // Keeps the newest maxFiles thumbnails.
    static void prune(const QString &cacheDir, int maxFiles);

private:
    QString m_cacheDir;
};

#endif // PDFVIEWERAPP_PAGEIMAGEPROVIDER_H
