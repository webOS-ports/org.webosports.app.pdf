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

#include "documentregistry.h"

#include <QFileInfo>
#include <QMutexLocker>
#include <QThread>

#include <utility>

#include <poppler-qt6.h>

DocumentLease::DocumentLease(DocumentRegistry *registry, const QString &id,
                             std::unique_ptr<Poppler::Document> document)
    : m_registry(registry)
    , m_id(id)
    , m_document(std::move(document))
{
}

DocumentLease::DocumentLease(DocumentLease &&other) noexcept
    : m_registry(other.m_registry)
    , m_id(std::move(other.m_id))
    , m_document(std::move(other.m_document))
{
    other.m_registry = nullptr;
}

DocumentLease &DocumentLease::operator=(DocumentLease &&other) noexcept
{
    if (this != &other) {
        release();
        m_registry = other.m_registry;
        m_id = std::move(other.m_id);
        m_document = std::move(other.m_document);
        other.m_registry = nullptr;
    }
    return *this;
}

DocumentLease::~DocumentLease()
{
    release();
}

void DocumentLease::release()
{
    std::unique_ptr<Poppler::Document> document = std::move(m_document);
    DocumentRegistry *registry = std::exchange(m_registry, nullptr);
    if (registry && document)
        registry->giveBack(m_id, std::move(document));
}

DocumentRegistry &DocumentRegistry::instance()
{
    static DocumentRegistry registry;
    return registry;
}

DocumentRegistry::DocumentRegistry()
{
    // Renders are CPU-bound: leave a core to the UI on the dual-core devices.
    m_renderPool.setMaxThreadCount(qBound(1, QThread::idealThreadCount() - 1, 2));
    m_taskPool.setMaxThreadCount(2);
}

DocumentRegistry::~DocumentRegistry()
{
    m_renderPool.waitForDone();
    m_taskPool.waitForDone();
}

QString DocumentRegistry::add(const QString &path, const QByteArray &password)
{
    QMutexLocker locker(&m_mutex);
    const QString id = QStringLiteral("d%1").arg(m_nextId++);
    Entry &entry = m_entries[id];
    entry.path = path;
    entry.password = password;
    return id;
}

void DocumentRegistry::remove(const QString &id)
{
    std::vector<std::unique_ptr<Poppler::Document>> idle;
    {
        QMutexLocker locker(&m_mutex);
        auto it = m_entries.find(id);
        if (it == m_entries.end())
            return;
        idle = std::move(it->second.idle);
        m_entries.erase(it);
    }
    // Freed outside the lock: a large document takes a moment.
    idle.clear();
}

bool DocumentRegistry::contains(const QString &id) const
{
    QMutexLocker locker(&m_mutex);
    return m_entries.find(id) != m_entries.end();
}

QString DocumentRegistry::path(const QString &id) const
{
    QMutexLocker locker(&m_mutex);
    auto it = m_entries.find(id);
    return it == m_entries.end() ? QString() : it->second.path;
}

DocumentLease DocumentRegistry::acquire(const QString &id, LoadError *error)
{
    QString filePath;
    QByteArray password;
    {
        QMutexLocker locker(&m_mutex);
        auto it = m_entries.find(id);
        if (it == m_entries.end()) {
            if (error)
                *error = LoadError::NotFound;
            return {};
        }
        if (!it->second.idle.empty()) {
            std::unique_ptr<Poppler::Document> document = std::move(it->second.idle.back());
            it->second.idle.pop_back();
            if (error)
                *error = LoadError::None;
            return DocumentLease(this, id, std::move(document));
        }
        filePath = it->second.path;
        password = it->second.password;
    }

    // Loaded without the lock: other threads lease their own meanwhile.
    std::unique_ptr<Poppler::Document> document = load(filePath, password, error);
    if (!document)
        return {};
    return DocumentLease(this, id, std::move(document));
}

std::unique_ptr<Poppler::Document> DocumentRegistry::load(const QString &path, const QByteArray &password,
                                                          LoadError *error)
{
    if (error)
        *error = LoadError::None;
    if (!QFileInfo(path).isFile()) {
        if (error)
            *error = LoadError::NotFound;
        return nullptr;
    }
    std::unique_ptr<Poppler::Document> document = Poppler::Document::load(path, password, password);
    if (!document) {
        if (error)
            *error = LoadError::Damaged;
        return nullptr;
    }
    if (document->isLocked()) {
        if (error)
            *error = LoadError::Locked;
        return nullptr;
    }
    document->setRenderBackend(Poppler::Document::SplashBackend);
    document->setRenderHint(Poppler::Document::Antialiasing);
    document->setRenderHint(Poppler::Document::TextAntialiasing);
    document->setRenderHint(Poppler::Document::TextHinting);
    document->setRenderHint(Poppler::Document::TextSlightHinting);
    document->setRenderHint(Poppler::Document::ThinLineSolid);
    return document;
}

void DocumentRegistry::giveBack(const QString &id, std::unique_ptr<Poppler::Document> document)
{
    {
        QMutexLocker locker(&m_mutex);
        auto it = m_entries.find(id);
        if (it != m_entries.end() && static_cast<int>(it->second.idle.size()) < MaxIdleCopies) {
            it->second.idle.push_back(std::move(document));
            return;
        }
    }
    // Closed meanwhile, or enough idle copies: freed here, unlocked.
    document.reset();
}
