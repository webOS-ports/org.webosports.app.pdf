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
#include "pageimageprovider.h"
#include "renderplan.h"
#include "testdata.h"

#include <poppler-qt6.h>

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QTemporaryDir>

namespace {

std::unique_ptr<Poppler::Document> guide()
{
    return DocumentRegistry::load(testData("guide.pdf"), QByteArray(), nullptr);
}

PageRequest request(int page, int width, int rotation = 0, bool night = false, QRect crop = QRect())
{
    PageRequest r;
    r.page = page;
    r.width = width;
    r.rotation = rotation;
    r.night = night;
    r.crop = crop;
    return r;
}

// How dark the image is on average, 0 (white) to 255 (black).
int darkness(const QImage &image)
{
    qint64 sum = 0;
    const QImage gray = image.convertToFormat(QImage::Format_Grayscale8);
    for (int y = 0; y < gray.height(); ++y) {
        const uchar *line = gray.constScanLine(y);
        for (int x = 0; x < gray.width(); ++x)
            sum += 255 - line[x];
    }
    return static_cast<int>(sum / (static_cast<qint64>(gray.width()) * gray.height()));
}

} // namespace

TEST(RenderPage, AtTheWidthAsked)
{
    auto doc = guide();
    QString error;
    const QImage image = renderPage(doc.get(), request(0, 300), nullptr, &error);
    ASSERT_FALSE(image.isNull()) << error.toStdString();
    EXPECT_EQ(image.width(), 300);
    // 842 x 300 / 595 = 424.5, rounded.
    EXPECT_EQ(image.height(), 425);
    // Mostly white paper, some text.
    EXPECT_GT(darkness(image), 0);
    EXPECT_LT(darkness(image), 30);
}

TEST(RenderPage, TurnedAndAtNight)
{
    auto doc = guide();
    const QImage turned = renderPage(doc.get(), request(0, 425, 90), nullptr, nullptr);
    EXPECT_EQ(turned.size(), QSize(425, 300));
    const QImage night = renderPage(doc.get(), request(0, 300, 0, true), nullptr, nullptr);
    EXPECT_GT(darkness(night), 220);
}

TEST(RenderPage, APart)
{
    auto doc = guide();
    const QImage part = renderPage(doc.get(), request(0, 1190, 0, false, QRect(100, 100, 200, 50)), nullptr, nullptr);
    EXPECT_EQ(part.size(), QSize(200, 50));
}

TEST(RenderPage, Refuses)
{
    auto doc = guide();
    QString error;
    EXPECT_TRUE(renderPage(doc.get(), request(12, 300), nullptr, &error).isNull());
    EXPECT_FALSE(error.isEmpty());
    EXPECT_TRUE(renderPage(nullptr, request(0, 300), nullptr, &error).isNull());
    std::atomic_bool abort { true };
    EXPECT_TRUE(renderPage(doc.get(), request(0, 2000), &abort, &error).isNull());
    EXPECT_EQ(error, QStringLiteral("Cancelled"));
}

TEST(Thumbnails, CachedByPathSizeAndTime)
{
    QTemporaryDir dir;
    ASSERT_TRUE(dir.isValid());
    const QString a = ThumbnailImageProvider::cacheFile(dir.path(), testData("guide.pdf"), 128);
    const QString b = ThumbnailImageProvider::cacheFile(dir.path(), testData("guide.pdf"), 256);
    const QString c = ThumbnailImageProvider::cacheFile(dir.path(), testData("helloworld.pdf"), 128);
    EXPECT_TRUE(a.startsWith(dir.path() + "/"));
    EXPECT_TRUE(a.endsWith(".png"));
    EXPECT_NE(a, b);
    EXPECT_NE(a, c);
    EXPECT_EQ(a, ThumbnailImageProvider::cacheFile(dir.path(), testData("guide.pdf"), 128));
    EXPECT_TRUE(ThumbnailImageProvider::cacheFile(dir.path(), testData("no-such.pdf"), 128).isEmpty());

    // A copy changed later is another thumbnail.
    const QString copy = dir.path() + "/copy.pdf";
    ASSERT_TRUE(QFile::copy(testData("guide.pdf"), copy));
    const QString before = ThumbnailImageProvider::cacheFile(dir.path(), copy, 128);
    QFile f(copy);
    ASSERT_TRUE(f.open(QIODevice::Append));
    f.write("\n");
    f.close();
    EXPECT_NE(before, ThumbnailImageProvider::cacheFile(dir.path(), copy, 128));
}

TEST(Thumbnails, PruneKeepsTheNewest)
{
    QTemporaryDir dir;
    ASSERT_TRUE(dir.isValid());
    for (int i = 0; i < 6; ++i) {
        QFile f(dir.path() + QStringLiteral("/%1.png").arg(i));
        ASSERT_TRUE(f.open(QIODevice::WriteOnly));
        f.write("x");
        f.flush();
        // Set while open: a closed QFile cannot.
        ASSERT_TRUE(f.setFileTime(QDateTime::currentDateTime().addSecs(i), QFileDevice::FileModificationTime));
        f.close();
    }
    ThumbnailImageProvider::prune(dir.path(), 4);
    EXPECT_EQ(QDir(dir.path()).entryList({ "*.png" }, QDir::Files, QDir::Name),
              QStringList({ "2.png", "3.png", "4.png", "5.png" }));
}
