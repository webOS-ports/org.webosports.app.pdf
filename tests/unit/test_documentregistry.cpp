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

#include "documentregistry.h"
#include "testdata.h"

#include <poppler-qt6.h>

#include <QtCore/QThread>

TEST(DocumentRegistry, LeasesCopiesAndTakesThemBack)
{
    DocumentRegistry registry;
    const QString id = registry.add(testData("guide.pdf"));
    EXPECT_TRUE(registry.contains(id));
    EXPECT_EQ(registry.path(id), testData("guide.pdf"));

    Poppler::Document *first = nullptr;
    {
        DocumentLease a = registry.acquire(id);
        ASSERT_TRUE(a);
        EXPECT_EQ(a->numPages(), 12);
        DocumentLease b = registry.acquire(id);
        ASSERT_TRUE(b);
        // Two at once are two copies.
        EXPECT_NE(a.get(), b.get());
        first = a.get();
    }
    // Back in the registry: the next lease is one of them, not a new load.
    DocumentLease c = registry.acquire(id);
    DocumentLease d = registry.acquire(id);
    EXPECT_TRUE(c.get() == first || d.get() == first);
}

TEST(DocumentRegistry, IdsAreNeverReused)
{
    DocumentRegistry registry;
    const QString a = registry.add(testData("guide.pdf"));
    registry.remove(a);
    const QString b = registry.add(testData("guide.pdf"));
    EXPECT_NE(a, b);
    EXPECT_FALSE(registry.contains(a));
    EXPECT_FALSE(registry.acquire(a));
}

TEST(DocumentRegistry, ALeaseOutlivesItsDocument)
{
    DocumentRegistry registry;
    const QString id = registry.add(testData("guide.pdf"));
    DocumentLease lease = registry.acquire(id);
    ASSERT_TRUE(lease);
    registry.remove(id);
    // Still usable; freed when it goes back.
    EXPECT_EQ(lease->numPages(), 12);
    lease = DocumentLease();
    EXPECT_FALSE(registry.contains(id));
}

TEST(DocumentRegistry, MovedLeasesGoBackOnce)
{
    DocumentRegistry registry;
    const QString id = registry.add(testData("guide.pdf"));
    DocumentLease a = registry.acquire(id);
    Poppler::Document *doc = a.get();
    DocumentLease b(std::move(a));
    EXPECT_FALSE(a);
    EXPECT_EQ(b.get(), doc);
    DocumentLease c;
    c = std::move(b);
    EXPECT_EQ(c.get(), doc);
}

TEST(DocumentRegistry, SaysWhyItDoesNotLoad)
{
    DocumentRegistry::LoadError error = DocumentRegistry::LoadError::None;
    EXPECT_FALSE(DocumentRegistry::load(testData("no-such.pdf"), QByteArray(), &error));
    EXPECT_EQ(error, DocumentRegistry::LoadError::NotFound);
    EXPECT_FALSE(DocumentRegistry::load(testData("make-test-pdfs.sh"), QByteArray(), &error));
    EXPECT_EQ(error, DocumentRegistry::LoadError::Damaged);
    EXPECT_FALSE(DocumentRegistry::load(testData("locked.pdf"), QByteArray(), &error));
    EXPECT_EQ(error, DocumentRegistry::LoadError::Locked);
    EXPECT_FALSE(DocumentRegistry::load(testData("locked.pdf"), "wrong", &error));
    EXPECT_EQ(error, DocumentRegistry::LoadError::Locked);
    EXPECT_TRUE(DocumentRegistry::load(testData("locked.pdf"), "secret", &error));
    EXPECT_EQ(error, DocumentRegistry::LoadError::None);
}

TEST(DocumentRegistry, ManyThreadsAtOnce)
{
    DocumentRegistry registry;
    const QString id = registry.add(testData("tracemonkey.pdf"));
    std::atomic_int pages { 0 };
    QVector<QThread *> threads;
    for (int t = 0; t < 4; ++t) {
        threads.append(QThread::create([&]() {
            for (int i = 0; i < 5; ++i) {
                DocumentLease lease = registry.acquire(id);
                if (lease)
                    pages += lease->numPages();
            }
        }));
        threads.last()->start();
    }
    for (QThread *thread : threads) {
        thread->wait();
        delete thread;
    }
    EXPECT_EQ(pages.load(), 4 * 5 * 14);
}
