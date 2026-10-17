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

#ifndef PDFVIEWERAPP_DOCUMENTSEARCH_H
#define PDFVIEWERAPP_DOCUMENTSEARCH_H

#include "pdfdocument.h"

#include <QFuture>
#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QVariantList>
#include <QVector>

#include <atomic>
#include <memory>

/*
 * Finds text in a document, page by page on a worker thread, from the page
 * the reader is on round to the one before it - so the first match is the
 * next one. Matches come in as each page is searched (count grows); a new
 * search, or clear(), stops the one running.
 *
 * Match rectangles are from 0 to 1 of the page as stored, like
 * PdfDocument's links.
 */
class DocumentSearch : public QObject
{
    Q_OBJECT
    Q_PROPERTY(PdfDocument *document READ document WRITE setDocument NOTIFY documentChanged)
    Q_PROPERTY(QString text READ text NOTIFY resultsChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(int count READ count NOTIFY resultsChanged)
    Q_PROPERTY(int pagesSearched READ pagesSearched NOTIFY resultsChanged)
    // Bumped when matches arrive, for bindings that call matchesOn().
    Q_PROPERTY(int revision READ revision NOTIFY resultsChanged)

public:
    explicit DocumentSearch(QObject *parent = nullptr);
    ~DocumentSearch() override;

    PdfDocument *document() const { return m_document; }
    void setDocument(PdfDocument *document);

    QString text() const { return m_text; }
    bool running() const { return m_running; }
    int count() const { return static_cast<int>(m_matches.size()); }
    int pagesSearched() const { return m_pagesSearched; }
    int revision() const { return m_revision; }

    Q_INVOKABLE void start(const QString &text, int fromPage, bool matchCase = false, bool wholeWords = false);
    Q_INVOKABLE void clear();

    // A match by its number: page, x, y, width, height. Empty when there is
    // no such match.
    Q_INVOKABLE QVariantMap match(int index) const;
    // The matches on a page, each with its number as index.
    Q_INVOKABLE QVariantList matchesOn(int page) const;
    // The first match on or after a page, wrapping round; -1 for none.
    Q_INVOKABLE int nextFrom(int page) const;

    struct Match
    {
        int page;
        QRectF rect;
    };

signals:
    void documentChanged();
    void resultsChanged();
    void runningChanged();
    // The search went through every page.
    void finished();

private:
    void stop();
    void addMatches(quint64 generation, int page, const QVector<QRectF> &rects);
    void pageDone(quint64 generation, bool last);

    QPointer<PdfDocument> m_document;
    QString m_text;
    bool m_running = false;
    int m_pagesSearched = 0;
    int m_revision = 0;
    quint64 m_generation = 0;
    // Kept in page order, though pages arrive from the reader's onwards.
    QVector<Match> m_matches;
    std::shared_ptr<std::atomic_bool> m_cancel;
    QFuture<void> m_future;
};

#endif // PDFVIEWERAPP_DOCUMENTSEARCH_H
