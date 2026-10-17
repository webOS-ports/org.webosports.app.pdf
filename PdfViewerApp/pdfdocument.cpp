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

#include "pdfdocument.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QFileInfo>
#include <QGuiApplication>
#include <QPointer>
#include <QRectF>
#include <QUrl>
#include <QtConcurrent/QtConcurrentRun>

#include <poppler-qt6.h>

#include <algorithm>

// Everything read from the document on the worker thread, handed over whole.
struct PdfDocument::Contents
{
    QString documentId;
    DocumentLease lease;
    DocumentRegistry::LoadError loadError = DocumentRegistry::LoadError::None;
    QVector<QSizeF> pageSizes;
    QStringList pageLabels;
    bool hasPageLabels = false;
    QVariantList outline;
    QString title, author, subject, keywords, creator, producer;
    QDateTime creationDate, modificationDate;
    QString pdfVersion;
    qint64 fileSize = 0;
    bool encrypted = false;
    bool canCopy = true;
};

namespace {

void addOutline(const QVector<Poppler::OutlineItem> &items, int level, QVariantList *out)
{
    for (const Poppler::OutlineItem &item : items) {
        if (item.isNull())
            continue;
        QVariantMap entry;
        entry.insert(QStringLiteral("title"), item.name().simplified());
        entry.insert(QStringLiteral("level"), level);
        int page = -1;
        double top = -1.0;
        const QSharedPointer<const Poppler::LinkDestination> destination = item.destination();
        if (destination && destination->pageNumber() > 0) {
            page = destination->pageNumber() - 1;
            if (destination->isChangeTop())
                top = destination->top();
        }
        entry.insert(QStringLiteral("page"), page);
        entry.insert(QStringLiteral("top"), top);
        entry.insert(QStringLiteral("uri"), item.uri());
        out->append(entry);
        // Deep outlines (a manual's every paragraph) are cut at six levels.
        if (item.hasChildren() && level < 5)
            addOutline(item.children(), level + 1, out);
    }
}

void readContents(PdfDocument::Contents *contents)
{
    Poppler::Document *document = contents->lease.get();
    const int pages = document->numPages();
    contents->pageSizes.reserve(pages);
    contents->pageLabels.reserve(pages);
    for (int i = 0; i < pages; ++i) {
        std::unique_ptr<Poppler::Page> page = document->page(i);
        // A page that cannot be read is shown as a blank A4.
        contents->pageSizes.append(page ? page->pageSizeF() : QSizeF(595.0, 842.0));
        const QString label = page ? page->label() : QString();
        contents->pageLabels.append(label.isEmpty() ? QString::number(i + 1) : label);
        if (contents->pageLabels.last() != QString::number(i + 1))
            contents->hasPageLabels = true;
    }
    addOutline(document->outline(), 0, &contents->outline);
    contents->title = document->info(QStringLiteral("Title")).simplified();
    contents->author = document->info(QStringLiteral("Author")).simplified();
    contents->subject = document->info(QStringLiteral("Subject")).simplified();
    contents->keywords = document->info(QStringLiteral("Keywords")).simplified();
    contents->creator = document->info(QStringLiteral("Creator")).simplified();
    contents->producer = document->info(QStringLiteral("Producer")).simplified();
    contents->creationDate = document->creationDate();
    contents->modificationDate = document->modificationDate();
    const Poppler::Document::PdfVersion version = document->getPdfVersion();
    contents->pdfVersion = QStringLiteral("%1.%2").arg(version.major).arg(version.minor);
    contents->encrypted = document->isEncrypted();
    contents->canCopy = document->okToCopy();
}

} // namespace

PdfDocument::PdfDocument(QObject *parent)
    : QObject(parent)
{
}

PdfDocument::~PdfDocument()
{
    close();
}

QString PdfDocument::fileName() const
{
    return m_path.isEmpty() ? QString() : QFileInfo(m_path).fileName();
}

void PdfDocument::setSource(const QString &source)
{
    if (source == m_source)
        return;
    m_source = source;
    m_path = localPath(source);
    emit sourceChanged();
    open(QByteArray());
}

void PdfDocument::unlock(const QString &password)
{
    if (m_status != Locked)
        return;
    open(password.toUtf8());
}

void PdfDocument::close()
{
    ++m_generation;
    m_lease = DocumentLease();
    if (!m_documentId.isEmpty())
        DocumentRegistry::instance().remove(m_documentId);
    m_documentId.clear();
    m_pageSizes.clear();
    m_pageLabels.clear();
    m_hasPageLabels = false;
    m_outline.clear();
    m_title.clear();
    m_author.clear();
    m_subject.clear();
    m_keywords.clear();
    m_creator.clear();
    m_producer.clear();
    m_creationDate = QDateTime();
    m_modificationDate = QDateTime();
    m_pdfVersion.clear();
    m_fileSize = 0;
    m_encrypted = false;
    m_canCopy = true;
    m_links.clear();
}

void PdfDocument::setStatus(Status status, const QString &error)
{
    if (status == m_status && error == m_error)
        return;
    m_status = status;
    m_error = error;
    emit statusChanged();
}

void PdfDocument::open(const QByteArray &password)
{
    close();
    emit loaded();

    if (m_source.isEmpty()) {
        setStatus(Null);
        return;
    }
    if (m_path.isEmpty()) {
        setStatus(Error, tr("Only documents on this device can be opened."));
        return;
    }

    setStatus(Loading);
    const quint64 generation = m_generation;
    const QString id = DocumentRegistry::instance().add(m_path, password);
    const QString filePath = m_path;
    QPointer<PdfDocument> self(this);
    auto contents = std::make_shared<Contents>();
    contents->documentId = id;

    QThreadPool *pool = DocumentRegistry::instance().taskPool();
    (void)QtConcurrent::run(pool, [self, generation, id, filePath, contents]() {
        contents->lease = DocumentRegistry::instance().acquire(id, &contents->loadError);
        contents->fileSize = QFileInfo(filePath).size();
        if (contents->lease)
            readContents(contents.get());
        // Back on the GUI thread; nothing happens there if the viewer went
        // away meanwhile, and the lease goes back from here.
        QMetaObject::invokeMethod(
            qApp,
            [self, generation, contents]() {
                if (self)
                    self->finishLoading(generation, contents);
                else
                    DocumentRegistry::instance().remove(contents->documentId);
            },
            Qt::QueuedConnection);
    });
}

void PdfDocument::finishLoading(quint64 generation, const std::shared_ptr<Contents> &contents)
{
    if (generation != m_generation) {
        // Superseded by another source or password.
        contents->lease = DocumentLease();
        DocumentRegistry::instance().remove(contents->documentId);
        return;
    }
    m_documentId = contents->documentId;
    if (!contents->lease) {
        switch (contents->loadError) {
        case DocumentRegistry::LoadError::Locked:
            setStatus(Locked, tr("This document is protected by a password."));
            break;
        case DocumentRegistry::LoadError::NotFound:
            setStatus(Error, tr("The document is no longer there."));
            break;
        default:
            setStatus(Error, tr("This file is damaged or is not a PDF document."));
            break;
        }
        return;
    }
    if (contents->pageSizes.isEmpty()) {
        setStatus(Error, tr("This document has no pages."));
        return;
    }

    m_lease = std::move(contents->lease);
    m_pageSizes = std::move(contents->pageSizes);
    m_pageLabels = std::move(contents->pageLabels);
    m_hasPageLabels = contents->hasPageLabels;
    m_outline = std::move(contents->outline);
    m_title = contents->title;
    m_author = contents->author;
    m_subject = contents->subject;
    m_keywords = contents->keywords;
    m_creator = contents->creator;
    m_producer = contents->producer;
    m_creationDate = contents->creationDate;
    m_modificationDate = contents->modificationDate;
    m_pdfVersion = contents->pdfVersion;
    m_fileSize = contents->fileSize;
    m_encrypted = contents->encrypted;
    m_canCopy = contents->canCopy;
    emit loaded();
    setStatus(Ready);
}

QSizeF PdfDocument::pageSize(int page) const
{
    if (page < 0 || page >= m_pageSizes.size())
        return QSizeF();
    return m_pageSizes.at(page);
}

QString PdfDocument::pageLabel(int page) const
{
    if (page < 0 || page >= m_pageLabels.size())
        return QString();
    return m_pageLabels.at(page);
}

int PdfDocument::pageForLabel(const QString &text) const
{
    const QString wanted = text.trimmed();
    if (wanted.isEmpty())
        return -1;
    if (m_hasPageLabels) {
        for (int i = 0; i < m_pageLabels.size(); ++i) {
            if (m_pageLabels.at(i).compare(wanted, Qt::CaseInsensitive) == 0)
                return i;
        }
    }
    bool ok = false;
    const int number = wanted.toInt(&ok);
    if (ok && number >= 1 && number <= m_pageSizes.size())
        return number - 1;
    return -1;
}

QVariantList PdfDocument::links(int page)
{
    if (!m_lease || page < 0 || page >= m_pageSizes.size())
        return {};
    auto cached = m_links.constFind(page);
    if (cached != m_links.constEnd())
        return *cached;

    QVariantList result;
    std::unique_ptr<Poppler::Page> popplerPage = m_lease->page(page);
    if (popplerPage) {
        for (const std::unique_ptr<Poppler::Link> &link : popplerPage->links()) {
            const QRectF area = link->linkArea().normalized();
            QVariantMap entry;
            entry.insert(QStringLiteral("x"), area.x());
            entry.insert(QStringLiteral("y"), area.y());
            entry.insert(QStringLiteral("width"), area.width());
            entry.insert(QStringLiteral("height"), area.height());
            if (link->linkType() == Poppler::Link::Goto) {
                const auto *go = static_cast<const Poppler::LinkGoto *>(link.get());
                if (go->isExternal())
                    continue;
                const Poppler::LinkDestination destination = go->destination();
                if (destination.pageNumber() < 1 || destination.pageNumber() > m_pageSizes.size())
                    continue;
                entry.insert(QStringLiteral("page"), destination.pageNumber() - 1);
                entry.insert(QStringLiteral("top"), destination.isChangeTop() ? destination.top() : -1.0);
            } else if (link->linkType() == Poppler::Link::Browse) {
                const auto *browse = static_cast<const Poppler::LinkBrowse *>(link.get());
                if (browse->url().isEmpty())
                    continue;
                entry.insert(QStringLiteral("uri"), browse->url());
            } else {
                continue;
            }
            result.append(entry);
        }
    }
    m_links.insert(page, result);
    return result;
}

QString PdfDocument::text(int page, qreal x, qreal y, qreal width, qreal height)
{
    if (!m_lease || page < 0 || page >= m_pageSizes.size() || !m_canCopy)
        return QString();
    std::unique_ptr<Poppler::Page> popplerPage = m_lease->page(page);
    if (!popplerPage)
        return QString();
    const QSizeF size = m_pageSizes.at(page);
    const QRectF area(x * size.width(), y * size.height(), width * size.width(), height * size.height());
    return popplerPage->text(area.normalized()).trimmed();
}

QVariantMap PdfDocument::wordAt(int page, qreal x, qreal y)
{
    if (!m_lease || page < 0 || page >= m_pageSizes.size())
        return {};
    std::unique_ptr<Poppler::Page> popplerPage = m_lease->page(page);
    if (!popplerPage)
        return {};
    const QSizeF size = m_pageSizes.at(page);
    const QPointF at(x * size.width(), y * size.height());
    // The nearest word within a few points: a finger is not a mouse.
    constexpr qreal reach = 6.0;
    QRectF best;
    qreal bestDistance = reach;
    for (const std::unique_ptr<Poppler::TextBox> &box : popplerPage->textList()) {
        const QRectF r = box->boundingBox();
        const qreal dx = std::max({ r.left() - at.x(), 0.0, at.x() - r.right() });
        const qreal dy = std::max({ r.top() - at.y(), 0.0, at.y() - r.bottom() });
        const qreal distance = std::max(dx, dy);
        if (distance < bestDistance) {
            bestDistance = distance;
            best = r;
            if (distance == 0.0)
                break;
        }
    }
    if (best.isNull())
        return {};
    return { { QStringLiteral("x"), best.x() / size.width() },
             { QStringLiteral("y"), best.y() / size.height() },
             { QStringLiteral("width"), best.width() / size.width() },
             { QStringLiteral("height"), best.height() / size.height() } };
}

bool PdfDocument::copy(const QString &text)
{
    if (!m_canCopy || text.isEmpty())
        return false;
    QGuiApplication::clipboard()->setText(text);
    return true;
}

QString PdfDocument::localPath(const QString &target)
{
    const QString trimmed = target.trimmed();
    if (trimmed.startsWith(QLatin1Char('/')))
        return QFileInfo(trimmed).absoluteFilePath();
    const QUrl url(trimmed);
    if (url.isLocalFile())
        return QFileInfo(url.toLocalFile()).absoluteFilePath();
    return QString();
}
