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

#include <gtest/gtest.h>

#include "pdfdocument.h"
#include "testdata.h"

#include <QtGui/QClipboard>
#include <QtGui/QGuiApplication>
#include <QtTest/QSignalSpy>

namespace {

bool settles(PdfDocument &doc)
{
    return waitFor([&]() { return doc.status() != PdfDocument::Loading; });
}

} // namespace

TEST(PdfDocument, OpensAndReadsTheDocument)
{
    PdfDocument doc;
    doc.setSource(testData("guide.pdf"));
    EXPECT_EQ(doc.status(), PdfDocument::Loading);
    ASSERT_TRUE(settles(doc));
    ASSERT_EQ(doc.status(), PdfDocument::Ready) << doc.error().toStdString();
    EXPECT_FALSE(doc.documentId().isEmpty());
    EXPECT_EQ(doc.pageCount(), 12);
    EXPECT_EQ(doc.title(), QStringLiteral("Viewer Test Guide"));
    EXPECT_EQ(doc.author(), QStringLiteral("webOS Ports"));
    EXPECT_EQ(doc.subject(), QStringLiteral("Test document"));
    EXPECT_EQ(doc.fileName(), QStringLiteral("guide.pdf"));
    EXPECT_GT(doc.fileSize(), 0);
    EXPECT_FALSE(doc.encrypted());
    EXPECT_TRUE(doc.canCopy());
    EXPECT_TRUE(doc.creationDate().isValid());
    EXPECT_EQ(doc.pageSize(0), QSizeF(595, 842));
    // Page 7 is the wide one.
    EXPECT_EQ(doc.pageSize(6), QSizeF(842, 595));
    EXPECT_FALSE(doc.pageSize(12).isValid());
    EXPECT_FALSE(doc.pageSize(-1).isValid());
}

TEST(PdfDocument, PageLabels)
{
    PdfDocument doc;
    doc.setSource(testData("guide.pdf"));
    ASSERT_TRUE(settles(doc));
    EXPECT_TRUE(doc.hasPageLabels());
    EXPECT_EQ(doc.pageLabel(0), QStringLiteral("i"));
    EXPECT_EQ(doc.pageLabel(1), QStringLiteral("ii"));
    EXPECT_EQ(doc.pageLabel(2), QStringLiteral("1"));
    EXPECT_EQ(doc.pageLabel(11), QStringLiteral("10"));
    EXPECT_EQ(doc.pageLabel(12), QString());
    // A label first, then a number from 1 for what is no label.
    EXPECT_EQ(doc.pageForLabel(QStringLiteral("ii")), 1);
    EXPECT_EQ(doc.pageForLabel(QStringLiteral(" II ")), 1);
    EXPECT_EQ(doc.pageForLabel(QStringLiteral("5")), 6);
    EXPECT_EQ(doc.pageForLabel(QStringLiteral("12")), 11);
    EXPECT_EQ(doc.pageForLabel(QStringLiteral("13")), -1);
    EXPECT_EQ(doc.pageForLabel(QStringLiteral("0")), -1);
    EXPECT_EQ(doc.pageForLabel(QStringLiteral("xyz")), -1);
    EXPECT_EQ(doc.pageForLabel(QString()), -1);

    PdfDocument plain;
    plain.setSource(testData("tracemonkey.pdf"));
    ASSERT_TRUE(settles(plain));
    EXPECT_FALSE(plain.hasPageLabels());
    EXPECT_EQ(plain.pageLabel(0), QStringLiteral("1"));
    EXPECT_EQ(plain.pageForLabel(QStringLiteral("14")), 13);
}

TEST(PdfDocument, Outline)
{
    PdfDocument doc;
    doc.setSource(testData("guide.pdf"));
    ASSERT_TRUE(settles(doc));
    const QVariantList outline = doc.outline();
    ASSERT_EQ(outline.size(), 7);
    const QStringList titles { "Front matter", "Contents", "Preface", "Part One", "Landing", "Wide page", "Part Two" };
    const QList<int> levels { 0, 1, 1, 0, 1, 1, 0 };
    const QList<int> pages { 0, 0, 1, 2, 4, 6, 8 };
    for (int i = 0; i < outline.size(); ++i) {
        const QVariantMap e = outline.at(i).toMap();
        EXPECT_EQ(e.value("title").toString(), titles.at(i));
        EXPECT_EQ(e.value("level").toInt(), levels.at(i));
        EXPECT_EQ(e.value("page").toInt(), pages.at(i)) << i;
    }
}

TEST(PdfDocument, Links)
{
    PdfDocument doc;
    doc.setSource(testData("guide.pdf"));
    ASSERT_TRUE(settles(doc));
    const QVariantList links = doc.links(0);
    ASSERT_EQ(links.size(), 2);
    QVariantMap toPage, toWeb;
    for (const QVariant &l : links) {
        const QVariantMap m = l.toMap();
        (m.contains("uri") ? toWeb : toPage) = m;
    }
    EXPECT_EQ(toPage.value("page").toInt(), 8);
    EXPECT_EQ(toWeb.value("uri").toString(), QStringLiteral("https://webos-ports.org/"));
    // From 0 to 1, top down: the first link is above the second.
    for (const QVariantMap &m : { toPage, toWeb }) {
        EXPECT_GT(m.value("x").toDouble(), 0.0);
        EXPECT_LT(m.value("x").toDouble() + m.value("width").toDouble(), 1.0);
        EXPECT_GT(m.value("height").toDouble(), 0.0);
    }
    EXPECT_LT(toPage.value("y").toDouble(), toWeb.value("y").toDouble());
    // Page ii links into another file: not followed, so not listed.
    EXPECT_TRUE(doc.links(1).isEmpty());
    EXPECT_TRUE(doc.links(2).isEmpty());
    EXPECT_TRUE(doc.links(12).isEmpty());
    EXPECT_TRUE(doc.links(-1).isEmpty());
}

TEST(PdfDocument, TextAndWords)
{
    PdfDocument doc;
    doc.setSource(testData("guide.pdf"));
    ASSERT_TRUE(settles(doc));
    // The top of page i holds "Chapter 1".
    EXPECT_EQ(doc.text(0, 0.0, 0.0, 1.0, 0.1), QStringLiteral("Chapter 1"));
    EXPECT_TRUE(doc.text(0, 0.0, 0.9, 1.0, 0.1).isEmpty());
    EXPECT_TRUE(doc.text(20, 0.0, 0.0, 1.0, 1.0).isEmpty());

    const QSizeF size = doc.pageSize(0);
    const QVariantMap word = doc.wordAt(0, 70 / size.width(), (842 - 775) / size.height());
    ASSERT_FALSE(word.isEmpty());
    const QString text = doc.text(0, word.value("x").toDouble(), word.value("y").toDouble(),
                                  word.value("width").toDouble(), word.value("height").toDouble());
    EXPECT_EQ(text, QStringLiteral("Chapter"));
    // Nothing near the foot of the page.
    EXPECT_TRUE(doc.wordAt(0, 0.5, 0.95).isEmpty());

    EXPECT_TRUE(doc.copy(QStringLiteral("Chapter")));
    EXPECT_EQ(QGuiApplication::clipboard()->text(), QStringLiteral("Chapter"));
    EXPECT_FALSE(doc.copy(QString()));
}

TEST(PdfDocument, PasswordProtected)
{
    PdfDocument doc;
    doc.setSource(testData("locked.pdf"));
    ASSERT_TRUE(settles(doc));
    EXPECT_EQ(doc.status(), PdfDocument::Locked);
    EXPECT_EQ(doc.pageCount(), 0);
    doc.unlock(QStringLiteral("wrong"));
    ASSERT_TRUE(settles(doc));
    EXPECT_EQ(doc.status(), PdfDocument::Locked);
    doc.unlock(QStringLiteral("secret"));
    ASSERT_TRUE(settles(doc));
    EXPECT_EQ(doc.status(), PdfDocument::Ready);
    EXPECT_EQ(doc.pageCount(), 12);
    EXPECT_TRUE(doc.encrypted());
    // Only from Locked.
    const QString id = doc.documentId();
    doc.unlock(QStringLiteral("secret"));
    EXPECT_EQ(doc.documentId(), id);
}

TEST(PdfDocument, WhatCannotBeOpened)
{
    PdfDocument doc;
    doc.setSource(testData("no-such.pdf"));
    ASSERT_TRUE(settles(doc));
    EXPECT_EQ(doc.status(), PdfDocument::Error);
    EXPECT_EQ(doc.error(), QStringLiteral("The document is no longer there."));
    doc.setSource(testData("make-test-pdfs.sh"));
    ASSERT_TRUE(settles(doc));
    EXPECT_EQ(doc.status(), PdfDocument::Error);
    EXPECT_EQ(doc.error(), QStringLiteral("This file is damaged or is not a PDF document."));
    doc.setSource(QStringLiteral("https://example.com/a.pdf"));
    EXPECT_EQ(doc.status(), PdfDocument::Error);
    doc.setSource(QString());
    EXPECT_EQ(doc.status(), PdfDocument::Null);
}

TEST(PdfDocument, ANewSourceWinsOverOneStillLoading)
{
    PdfDocument doc;
    QSignalSpy loaded(&doc, &PdfDocument::loaded);
    doc.setSource(testData("tracemonkey.pdf"));
    doc.setSource(testData("guide.pdf"));
    ASSERT_TRUE(settles(doc));
    // Let the first load's late answer arrive too.
    waitFor([]() { return false; }, 300);
    EXPECT_EQ(doc.status(), PdfDocument::Ready);
    EXPECT_EQ(doc.pageCount(), 12);
}

TEST(PdfDocument, DestroyedWhileLoading)
{
    auto *doc = new PdfDocument;
    doc->setSource(testData("tracemonkey.pdf"));
    delete doc;
    // The load finishing after must not touch it.
    waitFor([]() { return false; }, 500);
    SUCCEED();
}

TEST(PdfDocument, LocalPaths)
{
    EXPECT_EQ(PdfDocument::localPath(QStringLiteral("/media/internal/a.pdf")), QStringLiteral("/media/internal/a.pdf"));
    EXPECT_EQ(PdfDocument::localPath(QStringLiteral("file:///media/internal/My%20Book.pdf")),
              QStringLiteral("/media/internal/My Book.pdf"));
    EXPECT_EQ(PdfDocument::localPath(QStringLiteral("/media/internal/../internal/a.pdf")),
              QStringLiteral("/media/internal/a.pdf"));
    EXPECT_TRUE(PdfDocument::localPath(QStringLiteral("https://example.com/a.pdf")).isEmpty());
    EXPECT_TRUE(PdfDocument::localPath(QStringLiteral("a.pdf")).isEmpty());
    EXPECT_TRUE(PdfDocument::localPath(QString()).isEmpty());
}
