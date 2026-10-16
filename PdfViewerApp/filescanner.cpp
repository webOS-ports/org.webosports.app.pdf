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

#include "filescanner.h"
#include "documentregistry.h"

#include <QCollator>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QPointer>
#include <QtConcurrent/QtConcurrentRun>

#include <algorithm>
#include <utility>
#include <vector>

namespace {

QVariantMap describe(const QFileInfo &info, const QString &root)
{
    QString folder = info.absolutePath();
    if (!root.isEmpty() && folder.startsWith(root))
        folder = folder.mid(root.size());
    if (folder.startsWith(QLatin1Char('/')))
        folder.remove(0, 1);
    return { { QStringLiteral("path"), info.absoluteFilePath() },
             { QStringLiteral("name"), info.completeBaseName() },
             { QStringLiteral("folder"), folder },
             { QStringLiteral("size"), info.size() },
             { QStringLiteral("modified"), info.lastModified().toMSecsSinceEpoch() } };
}

} // namespace

FileScanner::FileScanner(QObject *parent)
    : QObject(parent)
    , m_roots({ QStringLiteral("/media/internal") })
{
}

FileScanner::~FileScanner()
{
    if (m_cancel)
        m_cancel->store(true);
    m_future.waitForFinished();
}

void FileScanner::setRoots(const QStringList &roots)
{
    if (roots == m_roots)
        return;
    m_roots = roots;
    emit rootsChanged();
}

void FileScanner::rescan()
{
    if (m_cancel)
        m_cancel->store(true);
    auto cancel = std::make_shared<std::atomic_bool>(false);
    m_cancel = cancel;
    const quint64 generation = ++m_generation;
    if (!m_running) {
        m_running = true;
        emit runningChanged();
    }

    QPointer<FileScanner> self(this);
    const QStringList scanRoots = m_roots;
    m_future = QtConcurrent::run(DocumentRegistry::instance().taskPool(), [self, scanRoots, cancel, generation]() {
        QVariantList found = scan(scanRoots, cancel.get());
        if (cancel->load())
            return;
        QMetaObject::invokeMethod(
            qApp,
            [self, generation, found = std::move(found)]() {
                if (!self || generation != self->m_generation)
                    return;
                self->m_files = found;
                self->m_cancel.reset();
                self->m_running = false;
                emit self->filesChanged();
                emit self->runningChanged();
            },
            Qt::QueuedConnection);
    });
}

QVariantMap FileScanner::fileInfo(const QString &path)
{
    const QFileInfo info(path);
    if (!info.isFile())
        return {};
    return describe(info, QString());
}

QVariantList FileScanner::scan(const QStringList &roots, const std::atomic_bool *cancel)
{
    std::vector<std::pair<QString, QVariantMap>> found;
    for (const QString &rootPath : roots) {
        const QString root = QDir(rootPath).absolutePath();
        std::vector<std::pair<QString, int>> pending { { root, 0 } };
        while (!pending.empty() && !(cancel && cancel->load())
               && found.size() < static_cast<size_t>(MaxFiles)) {
            const auto [dirPath, depth] = pending.back();
            pending.pop_back();
            const QFileInfoList entries =
                QDir(dirPath).entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot | QDir::Readable);
            for (const QFileInfo &entry : entries) {
                if (entry.isSymLink())
                    continue;
                if (entry.isDir()) {
                    if (depth + 1 < MaxDepth)
                        pending.emplace_back(entry.absoluteFilePath(), depth + 1);
                } else if (entry.suffix().compare(QLatin1String("pdf"), Qt::CaseInsensitive) == 0) {
                    found.emplace_back(entry.completeBaseName(), describe(entry, root));
                    if (found.size() >= static_cast<size_t>(MaxFiles))
                        break;
                }
            }
        }
    }
    // A collator of its own: QString::localeAwareCompare() keeps one per
    // thread that is never freed when a pool thread ends. Numbers by value:
    // "Part 2" before "Part 10".
    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    collator.setNumericMode(true);
    std::stable_sort(found.begin(), found.end(),
                     [&collator](const auto &a, const auto &b) { return collator.compare(a.first, b.first) < 0; });
    QVariantList result;
    result.reserve(static_cast<qsizetype>(found.size()));
    for (auto &entry : found)
        result.append(std::move(entry.second));
    return result;
}
