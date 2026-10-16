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

import LunaNext.Common 0.1
import PdfViewerApp 1.0

/*
 * The app as a whole, on the real plugin and the test documents in
 * tests/data: the library, opening, the page bars, go to page, find, links,
 * the contents, turning, night mode, a password, a damaged file, launch
 * parameters, coming back where the reader left, and copying text. Each
 * state is also saved as a picture in build/test-output/ui/ to look at.
 */
TestCase {
    id: test
    name: "Ui"
    when: windowShown

    readonly property string dataDir: decodeURIComponent(Qt.resolvedUrl("../data").toString().replace(/^file:\/\//, ""))
    readonly property string shotDir: decodeURIComponent(Qt.resolvedUrl("../../build/test-output/ui").toString()
                                                         .replace(/^file:\/\//, ""))
    property var app: null
    property string profile: "tp"

    function shot(name) {
        var done = false;
        var ok = app.contentItem.grabToImage(function(result) {
            result.saveToFile(shotDir + "/" + profile + "-" + name + ".png");
            done = true;
        });
        verify(ok, "grab " + name);
        tryVerify(function() { return done; }, 5000, "saved " + name);
    }

    function startApp(profileName) {
        profile = profileName;
        Settings.setProfile(profileName);
        var component = Qt.createComponent(Qt.resolvedUrl("../../qml/main.qml"));
        if (component.status === Component.Error)
            fail(component.errorString());
        app = component.createObject(null);
        verify(app !== null, "main.qml made");
        // Each test from a library with nothing read yet.
        app.reading.documents = "{}";
        app.prefs.nightMode = false;
        app.prefs.sortOrder = "name";
        app.scanner.roots = [dataDir];
        app.scanner.rescan();
        tryVerify(function() { return app.scanner.files.length === 4; }, 5000, "the four test documents found");
        wait(50);
    }

    function stopApp() {
        if (app) {
            app.destroy();
            app = null;
        }
        wait(50);
    }

    function cleanup() {
        stopApp();
    }

    // The page on top, once the stack has finished moving (it takes no
    // input while it moves).
    function settled() {
        tryVerify(function() { return !app.pageStack.busy; }, 3000, "the page stack settles");
        return app.pageStack.currentItem;
    }

    function viewer() {
        var v = settled();
        compare(v.objectName, "viewerPage");
        return v;
    }

    function openGuide() {
        app.openDocument(dataDir + "/guide.pdf");
        var v = viewer();
        tryVerify(function() { return v.document.status === PdfDocument.Ready; }, 5000, "guide.pdf opens");
        tryVerify(function() { return v.restored; }, 5000, "position restored");
        var first = findChild(v, "pageImage");
        tryVerify(function() { return first && first.status === Image.Ready; }, 5000, "a page drawn");
        return v;
    }

    // Two quick taps of a finger, as on the device.
    function doubleTap(item, x, y) {
        for (var i = 0; i < 2; ++i) {
            var touch = touchEvent(item);
            touch.press(0, item, x, y).commit();
            touch.release(0, item, x, y).commit();
            wait(30);
        }
    }

    // Every test on each device shape: a tablet, tall and small phones, and
    // the Q25's square.
    function init_data() {
        return [{ tag: "tp 1024x768", profile: "tp" }, { tag: "gnex 720x1280", profile: "gnex" },
                { tag: "mindphone 480x800", profile: "mindphone" }, { tag: "q25 720x720", profile: "q25" }];
    }

    function test_library(data) {
        startApp(data.profile);
        var list = findChild(settled(), "documentList");
        tryVerify(function() { return list.count === 4; }, 5000, "four rows");
        // The thumbnail of the first page, except the locked one's.
        tryVerify(function() {
            var drawn = 0;
            for (var i = 0; i < list.count; ++i) {
                var row = list.itemAtIndex(i);
                var t = row ? findChild(row, "thumbnail") : null;
                if (t && t.status === Image.Ready)
                    ++drawn;
            }
            return drawn === 3;
        }, 8000, "three thumbnails");
        shot("library");
    }

    function test_open_and_read(data) {
        startApp(data.profile);
        var v = openGuide();
        var doc = v.document;
        compare(doc.pageCount, 12);
        compare(doc.title, "Viewer Test Guide");
        compare(doc.pageLabel(0), "i");
        compare(doc.pageLabel(2), "1");
        compare(doc.pageForLabel("ii"), 1);
        compare(doc.pageForLabel("5"), 6);
        compare(doc.outline.length, 7);
        compare(doc.links(0).length, 2);
        compare(v.currentPage, 0);
        // The page in the middle, with the same margin either side.
        var first = findChild(v, "documentView").flickable.itemAtIndex(0);
        var left = first.mapToItem(v, 0, 0).x;
        fuzzyCompare(left, v.width - (left + first.width), 1.5, "centred: " + left);
        verify(left > 0, "a margin on the left");
        var bar = findChild(v, "commandBar");
        verify(bar.y < v.height, "the bars show at first");
        shot("viewer");

        // A tap on the page (not a link) hides the bars; another brings them back.
        var view = findChild(v, "documentView");
        mouseClick(view, view.width / 2, view.height * 0.6);
        tryVerify(function() { return !v.chromeVisible; }, 2000, "full screen");
        tryVerify(function() { return bar.y >= v.height; }, 2000);
        shot("fullscreen");
        mouseClick(view, view.width / 2, view.height * 0.6);
        tryVerify(function() { return v.chromeVisible; }, 2000);
        tryVerify(function() { return bar.y === v.height - bar.height; }, 2000, "the bar back in place");

        // The command menu's next and previous.
        mouseClick(findChild(v, "nextButton"));
        tryCompare(v, "currentPage", 1, 3000);
        mouseClick(findChild(v, "previousButton"));
        tryCompare(v, "currentPage", 0, 3000);

        // Go to Page by label: "5" is the seventh page, the wide one.
        var dialog = findChild(v, "goToDialog");
        mouseClick(findChild(v, "pageButton"));
        tryVerify(function() { return dialog.opened; }, 2000);
        var field = findChild(dialog, "pageField");
        field.text = "5";
        compare(dialog.chosen, 6);
        shot("goto");
        dialog.accept();
        tryCompare(v, "currentPage", 6, 3000);
        wait(300);
        shot("wide-page");
    }

    function test_find(data) {
        startApp(data.profile);
        var v = openGuide();
        mouseClick(findChild(v, "searchButton"));
        verify(v.searchVisible);
        var field = findChild(v, "findField");
        field.text = "lunar";
        field.accepted();
        var search = v.document ? findChild(v, "searchBar").search : null;
        tryVerify(function() { return !search.running && search.text === "lunar"; }, 5000, "search done");
        compare(search.count, 4);
        compare(search.matchesOn(4).length, 2);
        // The first match from page i on: page 3's.
        tryCompare(v, "currentMatch", 0, 2000);
        compare(search.match(0).page, 2);
        tryCompare(v, "currentPage", 2, 3000);
        // A match on screen but under the find bar is brought out from under it.
        var view = findChild(v, "documentView");
        var bar = findChild(v, "searchBar");
        var m = search.match(0);
        var header = findChild(v, "viewerHeader");
        view.restoreAnchor({ page: 2, fx: 0.5, fy: m.y, vx: view.width / 2, vy: header.height + bar.height / 2 });
        v.goToMatch(0);
        var item = view.flickable.itemAtIndex(2);
        var matchTop = item.y + m.y * item.height - view.flickable.contentY;
        verify(matchTop >= bar.mapToItem(view, 0, bar.height).y, "match at " + matchTop + " is below the find bar");
        wait(300);
        shot("find");
        mouseClick(findChild(v, "findNext"));
        compare(v.currentMatch, 1);
        compare(search.match(1).page, 4);
        mouseClick(findChild(v, "findPrevious"));
        compare(v.currentMatch, 0);
        mouseClick(findChild(v, "findPrevious"));
        compare(v.currentMatch, 3, "wraps round to the last");
        // Back closes the search first, then the viewer.
        keyClick(Qt.Key_Escape);
        verify(!v.searchVisible);
        compare(search.count, 0);
        keyClick(Qt.Key_Escape);
        tryCompare(app.pageStack, "depth", 1, 2000);
    }

    function test_links_and_contents(data) {
        startApp(data.profile);
        var v = openGuide();
        var view = findChild(v, "documentView");
        var link = v.document.links(0)[0];
        compare(link.page, 8);
        var item = view.flickable.itemAtIndex(0);
        mouseClick(item, (link.x + link.width / 2) * item.width, (link.y + link.height / 2) * item.height);
        tryCompare(v, "currentPage", 8, 3000);
        var back = findChild(v, "linkBackButton");
        verify(back.visible);
        compare(back.text, "Back to page i");
        mouseClick(back);
        tryCompare(v, "currentPage", 0, 3000);
        verify(!back.visible);

        // The web link asks first.
        var web = v.document.links(0)[1];
        compare(web.uri, "https://webos-ports.org/");
        mouseClick(item, (web.x + web.width / 2) * item.width, (web.y + web.height / 2) * item.height);
        var linkDialog = findChild(v, "linkDialog");
        tryVerify(function() { return linkDialog.opened; }, 2000);
        linkDialog.reject();

        // The contents: an outline entry goes to its page.
        var contents = findChild(v, "contentsPanel");
        mouseClick(findChild(v, "contentsButton"));
        tryVerify(function() { return contents.opened; }, 2000);
        wait(300);
        shot("contents");
        var outline = findChild(contents.contentItem, "outlineList");
        mouseClick(outline.itemAtIndex(4));
        // Gone, not only closing: its shade takes the taps until then.
        tryVerify(function() { return !contents.visible; }, 2000);
        tryCompare(v, "currentPage", 4, 3000);

        // And the page grid.
        mouseClick(findChild(v, "contentsButton"));
        tryVerify(function() { return contents.opened; }, 2000);
        findChild(contents.contentItem, "contentsTabs").currentIndex = 1;
        wait(500);
        shot("pages");
        contents.close();
    }

    function test_turn_fit_and_night(data) {
        startApp(data.profile);
        var v = openGuide();
        var view = findChild(v, "documentView");
        var widthAtFit = view.flickable.itemAtIndex(0).width;
        v.rotate(90);
        compare(view.pageRotation, 90);
        tryVerify(function() { var i = view.flickable.itemAtIndex(view.currentPage);
                               return i && Math.abs(i.width - widthAtFit) < 2 && i.height < i.width; },
                  3000, "on its side, still fitting the width");
        mouseClick(findChild(v, "fitButton"));
        compare(view.fitMode, "page");
        app.prefs.nightMode = true;
        wait(500);
        shot("turned-night");
        app.prefs.nightMode = false;
        v.rotate(-90);
        compare(view.pageRotation, 0);

        // Ctrl+wheel and double tap zoom about the point.
        mouseClick(findChild(v, "fitButton"));
        compare(view.fitMode, "width");
        var chrome = v.chromeVisible;
        doubleTap(view, view.width / 2, view.height / 2);
        tryCompare(view, "fitMode", "custom", 2000);
        verify(view.zoom > 2);
        wait(600);
        compare(v.chromeVisible, chrome, "a double tap is not a tap as well");
        wait(600);
        shot("zoomed");
        doubleTap(view, view.width / 2, view.height / 2);
        tryCompare(view, "fitMode", "width", 2000);
    }

    function test_password(data) {
        startApp(data.profile);
        app.openDocument(dataDir + "/locked.pdf");
        var v = viewer();
        tryVerify(function() { return v.document.status === PdfDocument.Locked; }, 5000);
        var dialog = findChild(v, "passwordDialog");
        tryVerify(function() { return dialog.opened; }, 2000);
        var field = findChild(dialog, "passwordField");
        field.text = "wrong";
        dialog.accept();
        tryVerify(function() { return v.document.status === PdfDocument.Locked && dialog.opened; }, 5000);
        verify(dialog.wrong);
        shot("password");
        field.text = "secret";
        dialog.accept();
        tryVerify(function() { return v.document.status === PdfDocument.Ready; }, 5000);
        compare(v.document.pageCount, 12);
        verify(v.document.encrypted);
        // The field gives the focus back, so the keyboard does not stay up.
        verify(!field.children[0].activeFocus, "the password field let go of the focus");
        verify(findChild(v, "documentView").activeFocus, "the page has it");
    }

    function test_damaged_and_missing(data) {
        startApp(data.profile);
        app.openDocument(dataDir + "/make-test-pdfs.sh");
        var v = viewer();
        tryVerify(function() { return v.document.status === PdfDocument.Error; }, 5000);
        verify(findChild(v, "viewerError").visible);
        shot("damaged");
        app.openDocument(dataDir + "/no-such-file.pdf");
        tryVerify(function() { return v.document.status === PdfDocument.Error; }, 5000);
        compare(v.document.error, "The document is no longer there.");
        app.openDocument("https://example.com/remote.pdf");
        verify(app.notice !== "");
    }

    function test_launch_params(data) {
        startApp(data.profile);
        app.launchParams = JSON.stringify({ "target": "file://" + encodeURI(dataDir + "/helloworld.pdf") });
        var v = viewer();
        tryVerify(function() { return v.document.status === PdfDocument.Ready; }, 5000);
        compare(v.document.fileName, "helloworld.pdf");
        // Another document, the same viewer.
        app.launchParams = JSON.stringify({ "target": dataDir + "/guide.pdf" });
        tryVerify(function() { return v.document.status === PdfDocument.Ready && v.document.pageCount === 12; },
                  5000);
        compare(app.pageStack.depth, 2);

        // The library under the reader draws no pictures until it is shown.
        var library = app.pageStack.get(0);
        var list = findChild(library, "documentList");
        // The four documents, and the two just read under Recent.
        tryVerify(function() { return list.count === 6; }, 5000);
        for (var i = 0; i < list.count; ++i)
            compare(String(findChild(list.itemAtIndex(i), "thumbnail").source), "", "no picture yet, row " + i);
        keyClick(Qt.Key_Escape);
        tryCompare(app.pageStack, "depth", 1, 2000);
        tryVerify(function() {
            return String(findChild(list.itemAtIndex(0), "thumbnail").source) !== "";
        }, 3000, "pictures once the library shows");
    }

    // The quick preview of a page goes once the page is drawn.
    function test_preview_dropped() {
        startApp("tp");
        var v = openGuide();
        var view = findChild(v, "documentView");
        var item = view.flickable.itemAtIndex(0);
        tryVerify(function() { return findChild(item, "pageImage").status === Image.Ready; }, 5000);
        compare(String(findChild(item, "pagePreview").source), "");
        verify(item.everDrawn);
    }

    function test_resume_where_left(data) {
        startApp(data.profile);
        var v = openGuide();
        v.goToPage(6);
        tryCompare(v, "currentPage", 6, 3000);
        keyClick(Qt.Key_Escape);
        tryCompare(app.pageStack, "depth", 1, 2000);
        var list = findChild(settled(), "documentList");
        tryVerify(function() {
            var row = list.itemAtIndex(0);
            return row && row.name === "guide" && row.details === "Page 7 of 12";
        }, 3000, "Recent says how far");
        shot("library-recent");
        v = openGuide();
        tryCompare(v, "currentPage", 6, 3000);
    }

    function test_copy_text(data) {
        startApp(data.profile);
        var v = openGuide();
        var view = findChild(v, "documentView");
        // Held on "Chapter" of page i: the word is selected.
        var item = view.flickable.itemAtIndex(0);
        var size = v.document.pageSize(0);
        v.startSelection(0, 70 / size.width, (842 - 775) / size.height);
        verify(view.selecting);
        compare(v.selectedText(), "Chapter");
        // The copy bar is clear of the word.
        var selBar = findChild(v, "selectionBar");
        var word = findChild(view.flickable.itemAtIndex(0), "selectionRect");
        var wordBottom = word.mapToItem(v, 0, word.height).y;
        verify(selBar.mapToItem(v, 0, 0).y > wordBottom, "the copy bar does not cover the word");
        shot("selection");
        mouseClick(findChild(v, "copyButton"));
        verify(!view.selecting);
    }

    function test_document_info(data) {
        startApp(data.profile);
        var v = openGuide();
        app.showDocumentInfo(v.document);
        tryCompare(app.pageStack.currentItem, "objectName", "documentInfoPage", 2000);
        settled();
        shot("info");
        keyClick(Qt.Key_Escape);
        tryCompare(app.pageStack.currentItem, "objectName", "viewerPage", 2000);
    }
}
