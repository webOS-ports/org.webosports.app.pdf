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

#include "documentsearch.h"
#include "pdfdocument.h"
#include "testdata.h"

#include <QtCore/QThread>

namespace {

class DocumentSearchTest : public ::testing::Test
{
protected:
    void SetUp() override
    {
        m_doc.setSource(testData("guide.pdf"));
        ASSERT_TRUE(waitFor([&]() { return m_doc.status() == PdfDocument::Ready; }));
        m_search.setDocument(&m_doc);
    }

    bool done()
    {
        return waitFor([&]() { return !m_search.running(); });
    }

    PdfDocument m_doc;
    DocumentSearch m_search;
};

} // namespace

TEST_F(DocumentSearchTest, FindsEveryMatchInPageOrder)
{
    m_search.start(QStringLiteral("lunar"), 0);
    EXPECT_TRUE(m_search.running());
    ASSERT_TRUE(done());
    EXPECT_EQ(m_search.count(), 4);
    EXPECT_EQ(m_search.pagesSearched(), 12);
    EXPECT_EQ(m_search.match(0).value("page").toInt(), 2);
    EXPECT_EQ(m_search.match(1).value("page").toInt(), 4);
    EXPECT_EQ(m_search.match(2).value("page").toInt(), 4);
    EXPECT_EQ(m_search.match(3).value("page").toInt(), 8);
    EXPECT_TRUE(m_search.match(4).isEmpty());
    EXPECT_TRUE(m_search.match(-1).isEmpty());
    const QVariantList onFive = m_search.matchesOn(4);
    ASSERT_EQ(onFive.size(), 2);
    EXPECT_EQ(onFive.at(0).toMap().value("index").toInt(), 1);
    EXPECT_LT(onFive.at(0).toMap().value("y").toDouble(), onFive.at(1).toMap().value("y").toDouble());
    EXPECT_TRUE(m_search.matchesOn(0).isEmpty());
}

TEST_F(DocumentSearchTest, StartsFromTheReadersPage)
{
    // From page 6 on, the next is page 9's; the order stays the page order.
    m_search.start(QStringLiteral("lunar"), 5);
    ASSERT_TRUE(done());
    EXPECT_EQ(m_search.count(), 4);
    EXPECT_EQ(m_search.nextFrom(5), 3);
    EXPECT_EQ(m_search.nextFrom(4), 1);
    EXPECT_EQ(m_search.nextFrom(9), 0) << "wraps round";
}

TEST_F(DocumentSearchTest, CaseAndWholeWords)
{
    m_search.start(QStringLiteral("LUNAR"), 0);
    ASSERT_TRUE(done());
    EXPECT_EQ(m_search.count(), 4);
    m_search.start(QStringLiteral("LUNAR"), 0, true);
    ASSERT_TRUE(done());
    EXPECT_EQ(m_search.count(), 0);
    m_search.start(QStringLiteral("luna"), 0, false, true);
    ASSERT_TRUE(done());
    EXPECT_EQ(m_search.count(), 0);
    m_search.start(QStringLiteral("luna"), 0);
    ASSERT_TRUE(done());
    EXPECT_EQ(m_search.count(), 4);
}

TEST_F(DocumentSearchTest, ANewSearchReplacesTheOld)
{
    m_search.start(QStringLiteral("lunar"), 0);
    m_search.start(QStringLiteral("Chapter"), 0);
    ASSERT_TRUE(done());
    waitFor([]() { return false; }, 200);
    EXPECT_EQ(m_search.text(), QStringLiteral("Chapter"));
    // Every page's heading, and page i's "Go to chapter 9".
    EXPECT_EQ(m_search.count(), 13);
}

TEST_F(DocumentSearchTest, ClearAndNothing)
{
    m_search.start(QStringLiteral("lunar"), 0);
    m_search.clear();
    EXPECT_FALSE(m_search.running());
    waitFor([]() { return false; }, 200);
    EXPECT_EQ(m_search.count(), 0);
    m_search.start(QStringLiteral("   "), 0);
    EXPECT_FALSE(m_search.running());
    m_search.start(QStringLiteral("zebra"), 0);
    ASSERT_TRUE(done());
    EXPECT_EQ(m_search.count(), 0);
    EXPECT_EQ(m_search.nextFrom(0), -1);
}

TEST(DocumentSearch, NothingFromTheSearchBefore)
{
    PdfDocument doc;
    doc.setSource(testData("tracemonkey.pdf"));
    ASSERT_TRUE(waitFor([&]() { return doc.status() == PdfDocument::Ready; }));
    DocumentSearch search;
    search.setDocument(&doc);
    search.start(QStringLiteral("the"), 0);
    // The worker posts pages of "the" while the GUI thread sleeps...
    QThread::msleep(300);
    // ...and those arrive after this search began.
    search.start(QStringLiteral("zebra"), 0);
    ASSERT_TRUE(waitFor([&]() { return !search.running(); }));
    EXPECT_EQ(search.count(), 0);
    EXPECT_EQ(search.pagesSearched(), 14);
}

TEST(DocumentSearch, DestroyedWhileSearching)
{
    PdfDocument doc;
    doc.setSource(testData("tracemonkey.pdf"));
    ASSERT_TRUE(waitFor([&]() { return doc.status() == PdfDocument::Ready; }));
    auto *search = new DocumentSearch;
    search->setDocument(&doc);
    search->start(QStringLiteral("the"), 0);
    delete search;
    waitFor([]() { return false; }, 300);
    SUCCEED();
}
