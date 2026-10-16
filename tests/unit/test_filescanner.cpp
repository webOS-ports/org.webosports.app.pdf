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

#include "filescanner.h"
#include "testdata.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QTemporaryDir>

namespace {

void touch(const QString &path)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    ASSERT_TRUE(f.open(QIODevice::WriteOnly));
    f.write("%PDF-1.4\n");
}

QStringList names(const QVariantList &files)
{
    QStringList out;
    for (const QVariant &f : files)
        out << f.toMap().value("name").toString();
    return out;
}

} // namespace

TEST(FileScanner, FindsPdfsByNameAndSkipsTheRest)
{
    QTemporaryDir dir;
    ASSERT_TRUE(dir.isValid());
    const QString root = dir.path();
    touch(root + "/b.pdf");
    touch(root + "/Part 10.pdf");
    touch(root + "/Part 2.pdf");
    touch(root + "/Downloads/a manual.PDF");
    touch(root + "/Downloads/notes.txt");
    touch(root + "/.hidden/secret.pdf");
    touch(root + "/deep/1/2/3/4/5/6/7/8/9/10/11/12/13/too-deep.pdf");
    QFile::link(root + "/Downloads", root + "/loop");

    const QVariantList files = FileScanner::scan({ root }, nullptr);
    // Numbers in names by value.
    EXPECT_EQ(names(files), QStringList({ "a manual", "b", "Part 2", "Part 10" }));
    const QVariantMap first = files.at(0).toMap();
    EXPECT_EQ(first.value("folder").toString(), QStringLiteral("Downloads"));
    EXPECT_EQ(first.value("path").toString(), root + "/Downloads/a manual.PDF");
    EXPECT_EQ(first.value("size").toLongLong(), 9);
    EXPECT_GT(first.value("modified").toLongLong(), 0);
    EXPECT_EQ(files.at(1).toMap().value("folder").toString(), QString());
}

TEST(FileScanner, StopsWhenCancelled)
{
    std::atomic_bool cancel { true };
    EXPECT_TRUE(FileScanner::scan({ QStringLiteral(TEST_DATA_DIR) }, &cancel).isEmpty());
}

TEST(FileScanner, ScansOnAWorker)
{
    FileScanner scanner;
    EXPECT_EQ(scanner.roots(), QStringList({ "/media/internal" }));
    scanner.setRoots({ QStringLiteral(TEST_DATA_DIR) });
    scanner.rescan();
    EXPECT_TRUE(scanner.running());
    ASSERT_TRUE(waitFor([&]() { return !scanner.running(); }));
    EXPECT_EQ(names(scanner.files()), QStringList({ "guide", "helloworld", "locked", "tracemonkey" }));
    // Again before the first is done: the last one counts.
    scanner.rescan();
    scanner.rescan();
    ASSERT_TRUE(waitFor([&]() { return !scanner.running(); }));
    EXPECT_EQ(scanner.files().size(), 4);
}

TEST(FileScanner, FileInfo)
{
    EXPECT_EQ(FileScanner::fileInfo(testData("guide.pdf")).value("name").toString(), QStringLiteral("guide"));
    EXPECT_TRUE(FileScanner::fileInfo(testData("no-such.pdf")).isEmpty());
    EXPECT_TRUE(FileScanner::fileInfo(QStringLiteral(TEST_DATA_DIR)).isEmpty());
}
