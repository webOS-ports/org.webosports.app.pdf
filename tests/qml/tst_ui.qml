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
        // One screen a run, the one the stand-ins were loaded for: see
        // tests/run-qml-tests.sh.
        return [{ tag: Settings.profileName + " " + Settings.displayWidth + "x" + Settings.displayHeight,
                  profile: Settings.profileName }];
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
        // Going back is the back gesture's: no Back key in the header, and
        // so room for the app's icon on a phone too.
        verify(!findChild(v, "viewerHeader").showBack, "no Back key");
        // Opaque, for the page scrolls under it.
        var backdrop = findChild(v, "viewerHeaderBackdrop");
        verify(backdrop.visible && backdrop.color.a === 1, "the header has a solid backdrop");
        // What the header shows does not change with the page under it.
        var headerItem = findChild(v, "viewerHeader");
        var view = findChild(v, "documentView");
        view.restoreAnchor({ page: 0, fx: 0.1, fy: 0.25, vx: headerItem.width * 0.3, vy: headerItem.height * 0.8 });
        wait(200);
        var overText = grabImage(headerItem);
        view.restoreAnchor({ page: 0, fx: 0.5, fy: 0.6, vx: headerItem.width * 0.3, vy: headerItem.height * 0.8 });
        wait(200);
        var overBlank = grabImage(headerItem);
        var px = Math.round(headerItem.width * 0.2), py = Math.round(headerItem.height * 0.8);
        compare(String(overText.pixel(px, py)), String(overBlank.pixel(px, py)), "a word under the header does not show through");
        view.restoreAnchor({ page: 0, fx: 0, fy: 0, vx: 0, vy: 0 });

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
        // Digits, labels or not: on a keypad T9 would make "w" of a 9.
        compare(field.textInput.inputMethodHints, Qt.ImhDigitsOnly);
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
        shot("link-dialog");
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

    // The keys of a dialog stay above the keyboard, in the room it leaves on
    // the Q25: its card is 608 pixels tall and the keyboard 295 of them, so
    // 313 are left, 19.5 grid units. Laid out for that on every screen.
    function test_dialogs_clear_of_keyboard(data) {
        startApp(data.profile);
        app.openDocument(dataDir + "/locked.pdf");
        var v = viewer();
        tryVerify(function() { return v.document.status === PdfDocument.Locked; }, 5000);
        var dialog = findChild(v, "passwordDialog");
        tryVerify(function() { return dialog.opened; }, 2000);
        clearOfKeyboard(dialog, ["passwordField", "passwordOpenButton", "passwordCancelButton"]);
        shot("password-keyboard");
        findChild(dialog, "passwordField").text = "secret";
        dialog.accept();
        tryVerify(function() { return v.document.status === PdfDocument.Ready; }, 5000);

        var goTo = findChild(v, "goToDialog");
        mouseClick(findChild(v, "pageButton"));
        tryVerify(function() { return goTo.opened; }, 2000);
        clearOfKeyboard(goTo, ["pageField", "goToButton", "goToCancelButton"]);
        shot("goto-keyboard");
        goTo.reject();
    }

    function clearOfKeyboard(dialog, names) {
        var area = dialog.parent;
        dialog.keyboardHeightForTest = area.height - Units.gu(19.5);
        var keyboardTop = area.height - dialog.keyboardHeightForTest;
        wait(50);
        for (var i = 0; i < names.length; ++i) {
            var item = findChild(dialog, names[i]);
            verify(item && item.visible, names[i] + " shown");
            var bottom = item.mapToItem(area, 0, item.height).y;
            verify(bottom <= keyboardTop, names[i] + " ends at " + bottom + ", the keyboard starts at "
                   + keyboardTop + " (" + area.width + "x" + area.height + ")");
            verify(item.mapToItem(area, 0, 0).y >= 0, names[i] + " is not above the window");
        }
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
        // The handles as the OS draws them: the start's above the word,
        // pointing down at its top left, the end's below, pointing up at its
        // bottom right.
        var startHandle = findChild(v, "selectionStartHandle");
        var endHandle = findChild(v, "selectionEndHandle");
        var topLeft = word.mapToItem(v, 0, 0);
        var bottomRight = word.mapToItem(v, word.width, word.height);
        var startImage = findChild(startHandle, "selectionHandleImage");
        var endImage = findChild(endHandle, "selectionHandleImage");
        // Turned over, the shield's point - the top of the picture - is at the bottom.
        fuzzyCompare(startImage.mapToItem(v, startImage.width / 2, 0).y, topLeft.y, 1);
        fuzzyCompare(startHandle.mapToItem(v, startHandle.width / 2, 0).x, topLeft.x, 1);
        compare(startImage.rotation, 180);
        verify(startHandle.mapToItem(v, 0, startHandle.height).y <= topLeft.y + 1, "the start's handle above the word");
        fuzzyCompare(endImage.mapToItem(v, endImage.width / 2, 0).y, bottomRight.y, 1);
        fuzzyCompare(endHandle.mapToItem(v, endHandle.width / 2, 0).x, bottomRight.x, 1);
        compare(endImage.rotation, 0);
        verify(endHandle.mapToItem(v, 0, 0).y >= bottomRight.y - 1, "the end's handle below the word");
        shot("selection");
        // Dragged to the right, the end's handle takes more of the line.
        var before = view.selection.width;
        var from = endHandle.mapToItem(v, endHandle.width / 2, endHandle.height / 2);
        mousePress(v, from.x, from.y);
        for (var step = 1; step <= 6; ++step)
            mouseMove(v, from.x + step * 15, from.y);
        mouseRelease(v, from.x + 90, from.y);
        verify(view.selection.width > before, "the selection grew to the right");
        v.endSelection();

        // Held low on the screen, the word and its handle are brought up
        // out from under the copy bar.
        // Page 2's "Chapter", where page i's is: page i cannot be brought that low.
        var fy = (842 - 775) / size.height;
        view.restoreAnchor({ page: 1, fx: 0, fy: fy, vx: 0, vy: v.height - Units.gu(4) });
        wait(50);
        var second = view.flickable.itemAtIndex(1);
        verify(second.y - view.flickable.contentY + fy * second.height > selBar.mapToItem(v, 0, 0).y,
               "the word starts under where the copy bar goes");
        v.startSelection(1, 70 / size.width, fy);
        compare(v.selectedText(), "Chapter");
        wait(100);
        endHandle = findChild(v, "selectionEndHandle");
        word = findChild(view.flickable.itemAtIndex(1), "selectionRect");
        var barTop = selBar.mapToItem(v, 0, 0).y;
        verify(word.mapToItem(v, 0, word.height).y <= barTop, "the word above the copy bar");
        verify(endHandle.mapToItem(v, 0, endHandle.height).y <= barTop + 1, "its handle above the copy bar");
        mouseClick(findChild(v, "copyButton"));
        verify(!view.selecting);
        // "Copied", for a moment, above the command bar.
        var toast = findChild(v, "toast");
        compare(toast.text, "Copied");
        verify(toast.parent.showing, "the toast shows");
        var bar = findChild(v, "commandBar");
        fuzzyCompare(toast.parent.mapToItem(v, 0, toast.parent.height).y, bar.mapToItem(v, 0, 0).y - Units.gu(2), 1);
        wait(300);
        shot("toast");
        tryVerify(function() { return !toast.parent.visible; }, 3000, "the toast goes by itself");
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
