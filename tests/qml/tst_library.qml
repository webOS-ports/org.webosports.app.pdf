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

import QtQuick
import QtTest

import "../../qml/js/Library.js" as Library

/*
 * qml/js/Library.js: names, sizes, dates, search, order, and remembering
 * where the reader was.
 */
TestCase {
    name: "Library"

    readonly property var files: [
        { path: "/m/b.pdf", name: "b", folder: "", size: 10, modified: 3000 },
        { path: "/m/Downloads/A Manual.pdf", name: "A Manual", folder: "Downloads", size: 5000, modified: 1000 },
        { path: "/m/c.pdf", name: "c", folder: "Books/Old", size: 300, modified: 2000 }
    ]

    function names(list) {
        return list.map(function(f) { return f.name; });
    }

    function test_localPath() {
        compare(Library.localPath("/media/internal/a.pdf"), "/media/internal/a.pdf");
        compare(Library.localPath("file:///media/internal/My%20Book.pdf"), "/media/internal/My Book.pdf");
        compare(Library.localPath("file:///bad%zz.pdf"), "");
        compare(Library.localPath("https://example.com/a.pdf"), "");
        compare(Library.localPath(""), "");
        compare(Library.localPath(undefined), "");
    }

    function test_names() {
        compare(Library.fileName("/a/b/Manual.PDF"), "Manual.PDF");
        compare(Library.displayName("/a/b/Manual.PDF"), "Manual");
        compare(Library.displayName("/a/b/notes.pdf.pdf"), "notes.pdf");
    }

    function test_formatSize() {
        compare(Library.formatSize(0), "0 B");
        compare(Library.formatSize(1023), "1023 B");
        compare(Library.formatSize(1536), "2 KB");
        compare(Library.formatSize(5 * 1024 * 1024 + 300 * 1024), "5.3 MB");
        compare(Library.formatSize(20 * 1024 * 1024), "20 MB");
        compare(Library.formatSize(3 * 1024 * 1024 * 1024), "3 GB");
    }

    function test_formatDate() {
        var now = new Date(2026, 9, 16, 15, 0).getTime();
        compare(Library.formatDate(new Date(2026, 9, 16, 9, 5).getTime(), now), "9:05");
        compare(Library.formatDate(new Date(2026, 9, 16, 21, 5).getTime(), now, false), "9:05 PM");
        compare(Library.formatDate(new Date(2026, 2, 3).getTime(), now), "Mar 3");
        compare(Library.formatDate(new Date(2024, 11, 24).getTime(), now), "Dec 24, 2024");
        compare(Library.formatDate(0, now), "");
    }

    function test_filter() {
        compare(names(Library.filter(files, "")), ["b", "A Manual", "c"]);
        compare(names(Library.filter(files, "manual")), ["A Manual"]);
        compare(names(Library.filter(files, "old c")), ["c"], "every word, name or folder");
        compare(names(Library.filter(files, "downloads")), ["A Manual"]);
        compare(names(Library.filter(files, "zzz")), []);
    }

    function test_sorted() {
        compare(names(Library.sorted(files, "name")), ["A Manual", "b", "c"]);
        compare(names(Library.sorted(files, "date")), ["b", "c", "A Manual"]);
        compare(names(Library.sorted(files, "size")), ["A Manual", "c", "b"]);
        compare(names(files), ["b", "A Manual", "c"], "the list itself is left alone");
        compare(names(Library.sorted([{ name: "Part 10" }, { name: "part 2" }, { name: "Part 1" }], "name")),
                ["Part 1", "part 2", "Part 10"], "numbers by value, case aside");
    }

    function test_naturalCompare() {
        verify(Library.naturalCompare("Part 2", "Part 10") < 0);
        verify(Library.naturalCompare("part 2", "Part 1") > 0);
        verify(Library.naturalCompare("a", "B") < 0);
        compare(Library.naturalCompare("Same", "same"), 0);
        verify(Library.naturalCompare("Part", "Part 1") < 0);
        verify(Library.naturalCompare("", "a") < 0);
        verify(Library.naturalCompare("v1.10", "v1.9") > 0);
    }

    function test_store() {
        compare(Library.parseStore("not json"), {});
        compare(Library.parseStore("[1,2]"), {});
        compare(Library.parseStore(""), {});
        var s = Library.remember({}, "/a.pdf", { page: 4, pageCount: 10 }, 100);
        s = Library.remember(s, "/b.pdf", { page: 0, pageCount: 3 }, 200);
        // Opening again keeps what was there and adds the new.
        s = Library.remember(s, "/a.pdf", { zoom: 2 }, 300);
        compare(s["/a.pdf"].page, 4);
        compare(s["/a.pdf"].zoom, 2);
        compare(s["/a.pdf"].opened, 300);
        var recent = Library.recent(s, function() { return true; });
        compare(recent.map(function(e) { return e.path; }), ["/a.pdf", "/b.pdf"]);
        compare(Library.recent(s, function(p) { return p !== "/a.pdf"; }).length, 1, "gone files left out");
        s = Library.forget(s, "/a.pdf");
        compare(Object.keys(s), ["/b.pdf"]);
    }

    function test_storeForgetsTheOldest() {
        var s = {};
        for (var i = 0; i < Library.maxRemembered + 5; ++i)
            s = Library.remember(s, "/" + i + ".pdf", { page: i }, 1000 + i);
        compare(Object.keys(s).length, Library.maxRemembered);
        verify(s["/0.pdf"] === undefined);
        verify(s["/" + (Library.maxRemembered + 4) + ".pdf"] !== undefined);
        compare(Library.recent(s, function() { return true; }).length, Library.maxRecentShown);
    }

    function test_progressText() {
        compare(Library.progressText({ page: 6, pageCount: 12 }), "Page 7 of 12");
        compare(Library.progressText({ page: 40, pageCount: 12 }), "Page 12 of 12");
        compare(Library.progressText({ page: 0, pageCount: 0 }), "");
        compare(Library.progressText(null), "");
    }
}
