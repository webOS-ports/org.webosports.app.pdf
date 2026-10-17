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

#ifndef PDFVIEWERAPP_FILESCANNER_H
#define PDFVIEWERAPP_FILESCANNER_H

#include <QFuture>
#include <QObject>
#include <QStringList>
#include <QVariantList>

#include <atomic>
#include <memory>

/*
 * Finds the PDF documents on the device: every *.pdf under the roots
 * (/media/internal, where USB copies and downloads land), on a worker
 * thread. The media indexer does not index documents, so the old app's
 * db8 query for com.palm.media.misc.file found none.
 *
 * Hidden folders are skipped, and so are symbolic links (no loops, no file
 * twice); it stops at MaxDepth folders down and at MaxFiles documents.
 */
class FileScanner : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList roots READ roots WRITE setRoots NOTIFY rootsChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    // Each: path, name (without ".pdf"), folder (under its root), size,
    // modified (ms since the epoch). By name.
    Q_PROPERTY(QVariantList files READ files NOTIFY filesChanged)

public:
    explicit FileScanner(QObject *parent = nullptr);
    ~FileScanner() override;

    QStringList roots() const { return m_roots; }
    void setRoots(const QStringList &roots);
    bool running() const { return m_running; }
    QVariantList files() const { return m_files; }

    Q_INVOKABLE void rescan();
    // The same fields as in files for one document; empty if it is gone.
    Q_INVOKABLE static QVariantMap fileInfo(const QString &path);

    // The scan itself, for the tests: blocking, stopping when cancel is set.
    static QVariantList scan(const QStringList &roots, const std::atomic_bool *cancel);

    static constexpr int MaxDepth = 12;
    static constexpr int MaxFiles = 5000;

signals:
    void rootsChanged();
    void runningChanged();
    void filesChanged();

private:
    QStringList m_roots;
    bool m_running = false;
    QVariantList m_files;
    quint64 m_generation = 0;
    std::shared_ptr<std::atomic_bool> m_cancel;
    QFuture<void> m_future;
};

#endif // PDFVIEWERAPP_FILESCANNER_H
