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

#ifndef PDFVIEWERAPP_DOCUMENTREGISTRY_H
#define PDFVIEWERAPP_DOCUMENTREGISTRY_H

#include <QByteArray>
#include <QMutex>
#include <QString>
#include <QThreadPool>

#include <memory>
#include <unordered_map>
#include <vector>

namespace Poppler {
class Document;
}

class DocumentRegistry;

/*
 * One loaded copy of an open document, for one thread at a time. A poppler
 * Document must not be used from two threads at once, so the page renders,
 * the search and the viewer itself each lease a copy of their own; the copy
 * goes back to the registry for the next lease when this is destroyed.
 */
class DocumentLease
{
public:
    DocumentLease() = default;
    DocumentLease(DocumentLease &&other) noexcept;
    DocumentLease &operator=(DocumentLease &&other) noexcept;
    DocumentLease(const DocumentLease &) = delete;
    DocumentLease &operator=(const DocumentLease &) = delete;
    ~DocumentLease();

    Poppler::Document *get() const { return m_document.get(); }
    Poppler::Document *operator->() const { return m_document.get(); }
    explicit operator bool() const { return m_document != nullptr; }

private:
    friend class DocumentRegistry;
    DocumentLease(DocumentRegistry *registry, const QString &id, std::unique_ptr<Poppler::Document> document);
    void release();

    DocumentRegistry *m_registry = nullptr;
    QString m_id;
    std::unique_ptr<Poppler::Document> m_document;
};

/*
 * The documents the app has open, by an id that stands for them in image
 * URLs ("image://pdfpage/<id>/..."), so neither the path nor a password
 * ends up in one. Also owns the threads that work on them: they are
 * stopped before the documents go, at exit.
 */
class DocumentRegistry
{
public:
    enum class LoadError { None, NotFound, Locked, Damaged };

    static DocumentRegistry &instance();

    DocumentRegistry();
    ~DocumentRegistry();

    // Registers a document; the id is new each time, never reused.
    QString add(const QString &path, const QByteArray &password = QByteArray());
    // Copies not leased are freed now, leased ones when they come back.
    void remove(const QString &id);
    bool contains(const QString &id) const;
    QString path(const QString &id) const;

    // A copy of the document for the calling thread: an idle one, or a new
    // one loaded now. Empty when the id is unknown or it does not load.
    DocumentLease acquire(const QString &id, LoadError *error = nullptr);

    // Loads with the hints every render uses (antialiasing, thin lines).
    static std::unique_ptr<Poppler::Document> load(const QString &path, const QByteArray &password,
                                                   LoadError *error);

    // Page renders (two threads: the UI keeps a core) and the rest - loads,
    // the search.
    QThreadPool *renderPool() { return &m_renderPool; }
    QThreadPool *taskPool() { return &m_taskPool; }

    // How many idle copies a document keeps for later leases.
    static constexpr int MaxIdleCopies = 2;

private:
    friend class DocumentLease;
    void giveBack(const QString &id, std::unique_ptr<Poppler::Document> document);

    struct Entry
    {
        QString path;
        QByteArray password;
        std::vector<std::unique_ptr<Poppler::Document>> idle;
    };

    mutable QMutex m_mutex;
    std::unordered_map<QString, Entry> m_entries;
    quint64 m_nextId = 1;

    // Declared last: destroyed first, waiting for the threads, while the
    // entries their leases go back to are still there.
    QThreadPool m_taskPool;
    QThreadPool m_renderPool;
};

#endif // PDFVIEWERAPP_DOCUMENTREGISTRY_H
