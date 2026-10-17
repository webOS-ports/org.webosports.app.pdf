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

#include "documentsearch.h"
#include "documentregistry.h"
#include "pdfdocument.h"

#include <QCoreApplication>
#include <QtConcurrent/QtConcurrentRun>

#include <poppler-qt6.h>

#include <algorithm>

DocumentSearch::DocumentSearch(QObject *parent)
    : QObject(parent)
{
}

DocumentSearch::~DocumentSearch()
{
    stop();
    // The worker calls back through a QPointer, but it must not outlive the
    // object it was started for by long: wait for the page it is on.
    m_future.waitForFinished();
}

void DocumentSearch::setDocument(PdfDocument *document)
{
    if (document == m_document)
        return;
    clear();
    m_document = document;
    emit documentChanged();
}

void DocumentSearch::stop()
{
    ++m_generation;
    if (m_cancel)
        m_cancel->store(true);
    m_cancel.reset();
    if (m_running) {
        m_running = false;
        emit runningChanged();
    }
}

void DocumentSearch::clear()
{
    stop();
    m_text.clear();
    m_matches.clear();
    m_pagesSearched = 0;
    ++m_revision;
    emit resultsChanged();
}

void DocumentSearch::start(const QString &text, int fromPage, bool matchCase, bool wholeWords)
{
    clear();
    const QString wanted = text.trimmed();
    if (wanted.isEmpty() || !m_document || m_document->status() != PdfDocument::Ready)
        return;

    m_text = wanted;
    m_running = true;
    emit runningChanged();
    emit resultsChanged();

    const quint64 generation = m_generation;
    const QString id = m_document->documentId();
    const int pages = m_document->pageCount();
    QVector<QSizeF> sizes;
    sizes.reserve(pages);
    for (int i = 0; i < pages; ++i)
        sizes.append(m_document->pageSize(i));
    const int first = qBound(0, fromPage, pages - 1);

    Poppler::Page::SearchFlags flags = Poppler::Page::IgnoreDiacritics | Poppler::Page::AcrossLines;
    if (!matchCase)
        flags |= Poppler::Page::IgnoreCase;
    if (wholeWords)
        flags |= Poppler::Page::WholeWords;

    auto cancel = std::make_shared<std::atomic_bool>(false);
    m_cancel = cancel;
    QPointer<DocumentSearch> self(this);

    m_future = QtConcurrent::run(DocumentRegistry::instance().taskPool(), [=]() {
        DocumentLease document = DocumentRegistry::instance().acquire(id);
        for (int n = 0; n < pages && !cancel->load(); ++n) {
            const int index = (first + n) % pages;
            QVector<QRectF> rects;
            if (document) {
                std::unique_ptr<Poppler::Page> page = document->page(index);
                const QSizeF size = sizes.at(index);
                if (page && size.width() > 0.0 && size.height() > 0.0) {
                    for (const QRectF &rect : page->search(wanted, flags)) {
                        rects.append(QRectF(rect.x() / size.width(), rect.y() / size.height(),
                                            rect.width() / size.width(), rect.height() / size.height()));
                    }
                }
            }
            const bool last = n == pages - 1 || !document;
            QMetaObject::invokeMethod(
                qApp,
                [self, generation, index, rects, last]() {
                    if (!self)
                        return;
                    if (!rects.isEmpty())
                        self->addMatches(generation, index, rects);
                    self->pageDone(generation, last);
                },
                Qt::QueuedConnection);
            if (!document)
                break;
        }
    });
}

void DocumentSearch::addMatches(quint64 generation, int page, const QVector<QRectF> &rects)
{
    if (generation != m_generation)
        return;
    auto at = std::lower_bound(m_matches.begin(), m_matches.end(), page,
                               [](const Match &match, int p) { return match.page < p; });
    qsizetype position = at - m_matches.begin();
    for (const QRectF &rect : rects)
        m_matches.insert(position++, Match { page, rect });
}

void DocumentSearch::pageDone(quint64 generation, bool last)
{
    if (generation != m_generation)
        return;
    ++m_pagesSearched;
    ++m_revision;
    emit resultsChanged();
    if (last) {
        m_cancel.reset();
        m_running = false;
        emit runningChanged();
        emit finished();
    }
}

QVariantMap DocumentSearch::match(int index) const
{
    if (index < 0 || index >= m_matches.size())
        return {};
    const Match &match = m_matches.at(index);
    return { { QStringLiteral("page"), match.page },
             { QStringLiteral("x"), match.rect.x() },
             { QStringLiteral("y"), match.rect.y() },
             { QStringLiteral("width"), match.rect.width() },
             { QStringLiteral("height"), match.rect.height() } };
}

QVariantList DocumentSearch::matchesOn(int page) const
{
    QVariantList result;
    auto at = std::lower_bound(m_matches.begin(), m_matches.end(), page,
                               [](const Match &match, int p) { return match.page < p; });
    for (auto it = at; it != m_matches.end() && it->page == page; ++it) {
        QVariantMap entry = match(static_cast<int>(it - m_matches.begin()));
        entry.insert(QStringLiteral("index"), static_cast<int>(it - m_matches.begin()));
        result.append(entry);
    }
    return result;
}

int DocumentSearch::nextFrom(int page) const
{
    if (m_matches.isEmpty())
        return -1;
    auto at = std::lower_bound(m_matches.begin(), m_matches.end(), page,
                               [](const Match &match, int p) { return match.page < p; });
    return at == m_matches.end() ? 0 : static_cast<int>(at - m_matches.begin());
}
