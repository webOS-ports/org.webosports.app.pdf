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

#ifndef PDFVIEWERAPP_PDFDOCUMENT_H
#define PDFVIEWERAPP_PDFDOCUMENT_H

#include "documentregistry.h"

#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QSizeF>
#include <QStringList>
#include <QVariantList>
#include <QVector>

#include <memory>

/*
 * The document a viewer shows. Setting source (a path or file: URL) opens
 * it on a worker thread; status says how that went. Once Ready, pages are
 * drawn through image://pdfpage/<documentId>/... and the rest - sizes,
 * labels, links, the outline, text - comes from here.
 *
 * Page numbers are from 0 throughout; labels are what the document prints
 * on its pages ("iv", "A-3"), when it has any.
 */
class PdfDocument : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(Status status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString error READ error NOTIFY statusChanged)
    Q_PROPERTY(QString documentId READ documentId NOTIFY loaded)
    Q_PROPERTY(QString path READ path NOTIFY sourceChanged)
    Q_PROPERTY(QString fileName READ fileName NOTIFY sourceChanged)
    Q_PROPERTY(int pageCount READ pageCount NOTIFY loaded)
    Q_PROPERTY(bool hasPageLabels READ hasPageLabels NOTIFY loaded)
    Q_PROPERTY(QVariantList outline READ outline NOTIFY loaded)
    Q_PROPERTY(QString title READ title NOTIFY loaded)
    Q_PROPERTY(QString author READ author NOTIFY loaded)
    Q_PROPERTY(QString subject READ subject NOTIFY loaded)
    Q_PROPERTY(QString keywords READ keywords NOTIFY loaded)
    Q_PROPERTY(QString creator READ creator NOTIFY loaded)
    Q_PROPERTY(QString producer READ producer NOTIFY loaded)
    Q_PROPERTY(QDateTime creationDate READ creationDate NOTIFY loaded)
    Q_PROPERTY(QDateTime modificationDate READ modificationDate NOTIFY loaded)
    Q_PROPERTY(QString pdfVersion READ pdfVersion NOTIFY loaded)
    Q_PROPERTY(qint64 fileSize READ fileSize NOTIFY loaded)
    Q_PROPERTY(bool encrypted READ encrypted NOTIFY loaded)
    Q_PROPERTY(bool canCopy READ canCopy NOTIFY loaded)

public:
    enum Status { Null, Loading, Ready, Locked, Error };
    Q_ENUM(Status)

    explicit PdfDocument(QObject *parent = nullptr);
    ~PdfDocument() override;

    QString source() const { return m_source; }
    void setSource(const QString &source);

    Status status() const { return m_status; }
    QString error() const { return m_error; }
    QString documentId() const { return m_documentId; }
    QString path() const { return m_path; }
    QString fileName() const;
    int pageCount() const { return static_cast<int>(m_pageSizes.size()); }
    bool hasPageLabels() const { return m_hasPageLabels; }
    QVariantList outline() const { return m_outline; }
    QString title() const { return m_title; }
    QString author() const { return m_author; }
    QString subject() const { return m_subject; }
    QString keywords() const { return m_keywords; }
    QString creator() const { return m_creator; }
    QString producer() const { return m_producer; }
    QDateTime creationDate() const { return m_creationDate; }
    QDateTime modificationDate() const { return m_modificationDate; }
    QString pdfVersion() const { return m_pdfVersion; }
    qint64 fileSize() const { return m_fileSize; }
    bool encrypted() const { return m_encrypted; }
    bool canCopy() const { return m_canCopy; }

    // Tries again with a password, after status became Locked.
    Q_INVOKABLE void unlock(const QString &password);

    // In points, as stored (before any turning); an empty size for no page.
    Q_INVOKABLE QSizeF pageSize(int page) const;
    // The page's label, or its number from 1 when the document has none.
    Q_INVOKABLE QString pageLabel(int page) const;
    // The page a reader means by text: a label first, then a number from 1.
    // -1 when it is neither.
    Q_INVOKABLE int pageForLabel(const QString &text) const;

    // Each link on a page: x, y, width, height from 0 to 1 of the page as
    // stored; then page and top (0-1, or -1) for a jump within the
    // document, or uri for a web link.
    Q_INVOKABLE QVariantList links(int page);
    // The text inside a part of a page, given from 0 to 1 as links are.
    Q_INVOKABLE QString text(int page, qreal x, qreal y, qreal width, qreal height);
    // The word at a point (0 to 1 of the page as stored) as x, y, width,
    // height on the same scale; empty when there is none.
    Q_INVOKABLE QVariantMap wordAt(int page, qreal x, qreal y);
    // To the clipboard; false when the document forbids copying.
    Q_INVOKABLE bool copy(const QString &text);

    // A path for a launch parameter or a URL: file: URLs decoded, anything
    // else that is not an absolute path refused ("").
    Q_INVOKABLE static QString localPath(const QString &target);

    struct Contents;

signals:
    void sourceChanged();
    void statusChanged();
    void loaded();

private:
    void open(const QByteArray &password);
    void finishLoading(quint64 generation, const std::shared_ptr<Contents> &contents);
    void close();
    void setStatus(Status status, const QString &error = QString());

    QString m_source;
    QString m_path;
    Status m_status = Null;
    QString m_error;
    QString m_documentId;
    quint64 m_generation = 0;

    // The viewer's own copy, for links and text, on the GUI thread.
    DocumentLease m_lease;

    QVector<QSizeF> m_pageSizes;
    QStringList m_pageLabels;
    bool m_hasPageLabels = false;
    QVariantList m_outline;
    QString m_title, m_author, m_subject, m_keywords, m_creator, m_producer;
    QDateTime m_creationDate, m_modificationDate;
    QString m_pdfVersion;
    qint64 m_fileSize = 0;
    bool m_encrypted = false;
    bool m_canCopy = true;

    QHash<int, QVariantList> m_links;
};

#endif // PDFVIEWERAPP_PDFDOCUMENT_H
