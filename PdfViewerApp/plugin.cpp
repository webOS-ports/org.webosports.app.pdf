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

#include "plugin.h"
#include "documentsearch.h"
#include "filescanner.h"
#include "pageimageprovider.h"
#include "pdfdocument.h"

#include <QStandardPaths>
#include <QtQml/QtQml>

void PdfViewerAppPlugin::registerTypes(const char *uri)
{
    Q_ASSERT(uri == QLatin1String("PdfViewerApp"));

    // @uri PdfViewerApp
    qmlRegisterType<PdfDocument>(uri, 1, 0, "PdfDocument");
    qmlRegisterType<DocumentSearch>(uri, 1, 0, "DocumentSearch");
    qmlRegisterType<FileScanner>(uri, 1, 0, "FileScanner");
}

void PdfViewerAppPlugin::initializeEngine(QQmlEngine *engine, const char *)
{
    engine->addImageProvider(QStringLiteral("pdfpage"), new PageImageProvider);
    // Named by the app, not by QSettings' organisation: the QML runner is
    // shared by every QML app.
    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation)
        + QStringLiteral("/org.webosports.app.pdf/thumbnails");
    engine->addImageProvider(QStringLiteral("pdfthumb"), new ThumbnailImageProvider(cacheDir));
}
