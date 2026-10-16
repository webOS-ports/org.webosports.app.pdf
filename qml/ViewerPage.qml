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
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1
import LuneOS.Components 1.0 as LC
import LuneOS.Forms 1.0

import PdfViewerApp 1.0

import "components"
import "js/Geometry.js" as Geometry
import "js/Library.js" as Library

/*
 * Reading a document. The header and the command menu sit over the page; a
 * tap on the page hides them for reading full screen, and brings them back
 * (the legacy Full Screen Mode). Pinch or double tap to zoom; follow links;
 * find; the contents and every page from the command menu; hold on a word
 * to copy text. Where the reader was is kept, and the document opens there
 * next time.
 */
Page {
    id: page
    objectName: "viewerPage"

    property string source
    property bool chromeVisible: true
    property bool searchVisible: false
    property int currentMatch: -1
    // Pages a link was followed from, to go back to.
    property var linkHistory: []
    property bool restored: false

    readonly property alias document: pdf
    readonly property string displayTitle: pdf.title !== "" && pdf.title.length < 80 ? pdf.title
                                         : Library.displayName(pdf.path)
    readonly property int pageCount: pdf.status === PdfDocument.Ready ? pdf.pageCount : 0
    readonly property int currentPage: view.currentPage

    clip: true
    background: Rectangle {
        color: appWindow.prefs.nightMode ? "#2b2b2b" : "#8a8a8a"
    }

    PdfDocument {
        id: pdf
        source: page.source

        onStatusChanged: {
            if (status === PdfDocument.Locked) {
                passwordDialog.open();
            } else if (status === PdfDocument.Ready) {
                passwordDialog.close();
                page.restoreReading();
            }
        }
    }

    DocumentSearch {
        id: search
        document: pdf
        // The first match comes in: show it.
        onCountChanged: {
            if (page.currentMatch < 0 && count > 0)
                page.goToMatch(nextFrom(view.currentPage));
        }
    }

    onSourceChanged: {
        saveReading();
        restored = false;
        linkHistory = [];
        closeSearch();
        view.selecting = false;
    }

    // Saved as the reader goes, and on leaving.
    function saveReading() {
        if (!restored || pdf.status !== PdfDocument.Ready || pdf.path === "")
            return;
        var p = view.position();
        appWindow.reading.remember(pdf.path, {
            page: p.page,
            offset: p.offset,
            pageCount: pdf.pageCount,
            fitMode: view.fitMode,
            zoom: view.customZoom,
            rotation: view.pageRotation
        });
    }

    function restoreReading() {
        var state = appWindow.reading.stateFor(pdf.path);
        view.pageRotation = state && state.rotation ? Geometry.normalRotation(state.rotation) : 0;
        view.customZoom = state && state.zoom > 0 ? state.zoom : 1;
        view.fitMode = state && state.fitMode ? state.fitMode : appWindow.prefs.defaultFit;
        Qt.callLater(function() {
            if (state && state.page > 0 || state && state.offset > 0)
                view.restorePosition(Math.min(state.page, pdf.pageCount - 1), state.offset);
            else
                view.goToPage(0);
            page.restored = true;
            page.saveReading();
        });
    }

    Timer {
        id: saveTimer
        interval: 1500
        onTriggered: page.saveReading()
    }

    Connections {
        target: view
        function onCurrentPageChanged() { saveTimer.restart(); }
    }

    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state !== Qt.ApplicationActive)
                page.saveReading();
        }
    }

    StackView.onDeactivating: saveReading()
    Component.onDestruction: saveReading()

    // ---- What the commands do ---------------------------------------------

    function showChrome(show) {
        chromeVisible = show;
    }

    function goToPage(index) {
        view.goToPage(Math.max(0, Math.min(pageCount - 1, index)));
    }

    function openSearch() {
        searchVisible = true;
        chromeVisible = true;
        searchBar.focusField();
    }

    function closeSearch() {
        searchVisible = false;
        currentMatch = -1;
        search.clear();
        view.forceActiveFocus();
    }

    function goToMatch(index) {
        if (index < 0 || index >= search.count)
            return;
        currentMatch = index;
        view.showMatch(search.match(index));
    }

    function rotate(by) {
        view.pageRotation = Geometry.normalRotation(view.pageRotation + by);
        saveTimer.restart();
    }

    function followLink(link, fromPage) {
        if (link.uri !== undefined) {
            linkDialog.uri = link.uri;
            linkDialog.open();
            return;
        }
        linkHistory = linkHistory.concat([view.position()]);
        view.goToPage(link.page, link.top);
    }

    function goBackFromLink() {
        if (linkHistory.length === 0)
            return;
        var p = linkHistory[linkHistory.length - 1];
        linkHistory = linkHistory.slice(0, linkHistory.length - 1);
        view.restorePosition(p.page, p.offset);
    }

    function startSelection(index, x, y) {
        if (!pdf.canCopy) {
            toast.show("This document does not allow copying");
            return;
        }
        var stored = Geometry.unmapPoint(x, y, view.pageRotation);
        var word = pdf.wordAt(index, stored.x, stored.y);
        var shown;
        if (word.width !== undefined) {
            shown = Geometry.mapRect(word, view.pageRotation);
        } else {
            shown = { x: Math.max(0, x - 0.15), y: Math.max(0, y - 0.02), width: 0.3, height: 0.04 };
        }
        view.selectionPage = index;
        view.selection = shown;
        view.selecting = true;
        chromeVisible = true;
    }

    function endSelection() {
        view.selecting = false;
        view.selection = null;
        view.selectionPage = -1;
    }

    function selectedText() {
        if (!view.selection)
            return "";
        var s = view.selection;
        var r = Geometry.unmapRect(s.x, s.y, s.x + s.width, s.y + s.height, view.pageRotation);
        return pdf.text(view.selectionPage, r.x, r.y, r.width, r.height);
    }

    function appMenuItems() {
        var ready = pdf.status === PdfDocument.Ready;
        return [
            { text: "Go to Page…", enabled: ready, action: function() { goToDialog.open(); } },
            { text: "Find…", enabled: ready, action: page.openSearch },
            { text: "Rotate Clockwise", enabled: ready, action: function() { page.rotate(90); } },
            { text: "Rotate Counterclockwise", enabled: ready, action: function() { page.rotate(-90); } },
            { text: "Night Mode", checked: appWindow.prefs.nightMode,
              action: function() { appWindow.prefs.nightMode = !appWindow.prefs.nightMode; } },
            { text: "Send by Email", enabled: pdf.path !== "",
              action: function() { appWindow.sendByEmail(pdf.path); } },
            { text: "Document Info", enabled: ready, action: function() { appWindow.showDocumentInfo(pdf); } }
        ];
    }

    // Back closes what is open over the page first.
    function handleBack() {
        if (view.selecting) {
            endSelection();
            return true;
        }
        if (contents.opened) {
            contents.close();
            return true;
        }
        if (searchVisible) {
            closeSearch();
            return true;
        }
        return false;
    }

    // ---- The page ---------------------------------------------------------

    DocumentView {
        id: view
        objectName: "documentView"

        anchors.fill: parent
        focus: true
        document: pdf
        search: search
        night: appWindow.prefs.nightMode
        currentMatch: page.currentMatch
        // The bars' room is kept even while they are hidden, so the page
        // does not move when they come and go.
        topInset: header.height
        bottomInset: commandBar.height
        // Over the page too while finding: matches are shown below it.
        overlayTop: page.searchVisible ? searchBar.height : 0

        onTapped: function(x, y) {
            if (selecting)
                page.endSelection();
            else
                page.showChrome(!page.chromeVisible);
        }
        onLinkActivated: function(link, fromPage) { page.followLink(link, fromPage); }
        onHeld: function(index, x, y) { page.startSelection(index, x, y); }

        Keys.onPressed: function(event) {
            switch (event.key) {
            case Qt.Key_PageDown:
            case Qt.Key_Space:
                page.goToPage(view.currentPage + 1);
                break;
            case Qt.Key_PageUp:
                page.goToPage(view.currentPage - 1);
                break;
            case Qt.Key_Home:
                page.goToPage(0);
                break;
            case Qt.Key_End:
                page.goToPage(page.pageCount - 1);
                break;
            default:
                if (event.matches(StandardKey.Find)) {
                    page.openSearch();
                    break;
                }
                return;
            }
            event.accepted = true;
        }
    }

    // Scrolling on reads full screen; the bars come back with a tap.
    Connections {
        target: view.flickable
        function onMovementStarted() {
            if (!page.searchVisible && !view.selecting && page.restored)
                page.showChrome(false);
        }
    }

    // Opening, or what went wrong.
    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - Units.gu(4), Units.gu(50))
        spacing: Units.gu(2)
        visible: pdf.status !== PdfDocument.Ready

        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: pdf.status === PdfDocument.Loading
            visible: running
        }

        Label {
            objectName: "viewerError"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: pdf.status === PdfDocument.Error || pdf.status === PdfDocument.Locked
            text: pdf.error
            color: appWindow.prefs.nightMode ? "#dddddd" : "#ffffff"
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: pdf.status === PdfDocument.Locked
            text: "Enter Password"
            onClicked: passwordDialog.open()
        }
    }

    // Which page, while scrolling with the bars away.
    Label {
        id: pageBubble
        objectName: "pageBubble"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Units.gu(1.5)
        padding: Units.gu(1)
        leftPadding: Units.gu(1.5)
        rightPadding: Units.gu(1.5)
        visible: opacity > 0
        opacity: !page.chromeVisible && view.moving && page.pageCount > 0 ? 1 : 0
        text: page.pageText(true)
        color: "#ffffff"
        font.pixelSize: FontUtils.sizeToPixels("medium")
        background: Rectangle {
            radius: height / 2
            color: "#c0202020"
        }
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
    }

    function pageText(brief) {
        if (pageCount === 0)
            return "";
        var n = currentPage + 1;
        // Narrow: "iv (4/120)" or "4/120".
        var where = brief ? n + "/" + pageCount : n + " of " + pageCount;
        if (pdf.hasPageLabels && pdf.pageLabel(currentPage) !== String(n))
            return pdf.pageLabel(currentPage) + " (" + where + ")";
        return where;
    }

    // Back from a link, while there is somewhere to go back to.
    Button {
        objectName: "linkBackButton"
        anchors.left: parent.left
        anchors.bottom: commandBar.top
        anchors.margins: Units.gu(1.5)
        visible: page.linkHistory.length > 0
        text: page.linkHistory.length > 0
              ? "Back to page " + pdf.pageLabel(page.linkHistory[page.linkHistory.length - 1].page) : ""
        LuneOSButton.mainColor: LuneOSButton.secondaryColor
        onClicked: page.goBackFromLink()
    }

    // ---- The bars over the page -------------------------------------------

    Column {
        id: top
        anchors.left: parent.left
        anchors.right: parent.right
        y: page.chromeVisible || page.searchVisible ? 0 : -height
        Behavior on y {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }

        AppHeader {
            id: header
            objectName: "viewerHeader"
            width: parent.width
            height: appWindow.headerHeight
            title: page.displayTitle
            icon: appWindow.appIcon
            compact: appWindow.compact
            showBack: true
            onBackClicked: appWindow.pageStack.pop()

            actionComponent: Row {
                spacing: Units.gu(0.5)
                IconButton {
                    objectName: "searchButton"
                    image: "search-dark"
                    plain: true
                    enabled: pdf.status === PdfDocument.Ready
                    onClicked: page.searchVisible ? page.closeSearch() : page.openSearch()
                }
                IconButton {
                    objectName: "viewerMenuButton"
                    image: "more-dark"
                    plain: true
                    onClicked: appWindow.openAppMenu()
                }
            }
        }

        SearchBar {
            id: searchBar
            objectName: "searchBar"
            width: parent.width
            visible: page.searchVisible
            search: search
            current: page.currentMatch
            onSearchRequested: function(text) {
                page.currentMatch = -1;
                search.start(text, view.currentPage);
            }
            onNextClicked: page.goToMatch(page.currentMatch < 0 ? search.nextFrom(view.currentPage)
                                                                : (page.currentMatch + 1) % search.count)
            onPreviousClicked: page.goToMatch(page.currentMatch <= 0 ? search.count - 1 : page.currentMatch - 1)
            onCloseClicked: page.closeSearch()
        }

    }

    // Selection handles: the corners of the selection, dragged.
    Repeater {
        model: view.selecting ? 2 : 0
        delegate: Rectangle {
            id: handle
            readonly property var item: view.selectionPage >= 0 ? view.flickable.itemAtIndex(view.selectionPage) : null
            readonly property var s: view.selection
            readonly property bool start: index === 0
            width: Units.gu(3.5)
            height: width
            radius: width / 2
            color: "#4a8fd8"
            border.color: "#ffffff"
            border.width: 2
            visible: item !== null && s !== null
            x: visible ? item.shownX - view.flickable.contentX + (start ? s.x : s.x + s.width) * item.width - width / 2 : 0
            y: visible ? item.y - view.flickable.contentY + (start ? s.y : s.y + s.height) * item.height - height / 2 : 0

            DragHandler {
                target: null
                property real startX
                property real startY
                onActiveChanged: {
                    if (active) {
                        startX = handle.start ? handle.s.x : handle.s.x + handle.s.width;
                        startY = handle.start ? handle.s.y : handle.s.y + handle.s.height;
                    }
                }
                onTranslationChanged: {
                    if (!active || !handle.item)
                        return;
                    var px = Math.max(0, Math.min(1, startX + translation.x / handle.item.width));
                    var py = Math.max(0, Math.min(1, startY + translation.y / handle.item.height));
                    var s = handle.s;
                    var x1 = handle.start ? px : s.x;
                    var y1 = handle.start ? py : s.y;
                    var x2 = handle.start ? s.x + s.width : px;
                    var y2 = handle.start ? s.y + s.height : py;
                    view.selection = { x: Math.min(x1, x2), y: Math.min(y1, y2),
                                       width: Math.abs(x2 - x1), height: Math.abs(y2 - y1) };
                }
            }
        }
    }

    // Holding a word: the text, to copy - at the foot, clear of the words
    // being chosen, which are often near the top.
    Pane {
        objectName: "selectionBar"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: commandBar.top
        z: 1
        visible: view.selecting
        padding: Units.gu(0.75)
        background: Rectangle { color: "#e9e9e9" }

        contentItem: RowLayout {
            spacing: Units.gu(1)
            Label {
                id: selectionPreview
                Layout.fillWidth: true
                text: view.selecting ? page.selectedText() : ""
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                font.pixelSize: FontUtils.sizeToPixels("small")
                color: text !== "" ? Colors.text : Colors.secondaryText
            }
            Button {
                objectName: "copyButton"
                text: "Copy"
                enabled: selectionPreview.text !== ""
                LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                onClicked: {
                    if (pdf.copy(page.selectedText()))
                        toast.show("Copied");
                    page.endSelection();
                }
            }
            Button {
                text: "Done"
                onClicked: page.endSelection()
            }
        }
    }

    CommandBar {
        id: commandBar
        objectName: "commandBar"
        anchors.left: parent.left
        anchors.right: parent.right
        y: page.chromeVisible ? page.height - height : page.height
        Behavior on y {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }
        enabled: pdf.status === PdfDocument.Ready
        pageText: page.pageText(appWindow.compact)
        canGoBack: view.currentPage > 0
        canGoForward: view.currentPage < page.pageCount - 1
        fitMode: view.fitMode

        onContentsClicked: contents.open()
        onPreviousClicked: page.goToPage(view.currentPage - 1)
        onNextClicked: page.goToPage(view.currentPage + 1)
        onPageClicked: goToDialog.open()
        onFitClicked: {
            view.setFitMode(view.fitMode === "width" ? "page" : "width");
            saveTimer.restart();
        }
    }

    ContentsPanel {
        id: contents
        objectName: "contentsPanel"
        document: pdf
        currentPage: view.currentPage
        night: appWindow.prefs.nightMode
        onPageChosen: function(index, top) {
            contents.close();
            view.goToPage(index, top);
        }
    }

    // ---- Dialogs ----------------------------------------------------------

    GoToPageDialog {
        id: goToDialog
        objectName: "goToDialog"
        document: pdf
        currentPage: view.currentPage
        onPageChosen: function(index) { page.goToPage(index); }
        onClosed: view.forceActiveFocus()
    }

    PasswordDialog {
        id: passwordDialog
        objectName: "passwordDialog"
        fileName: Library.displayName(pdf.path)
        // Tried and still locked: the password was wrong.
        wrong: false
        onPasswordEntered: function(password) {
            passwordDialog.wrong = true;
            pdf.unlock(password);
        }
        onRejected: if (pdf.status === PdfDocument.Locked) appWindow.pageStack.pop()
        onClosed: view.forceActiveFocus()
    }

    // A web link leaves the app: asked first, in the platform's dialog.
    LC.ConfirmDialog {
        id: linkDialog
        objectName: "linkDialog"
        property string uri
        readonly property bool opened: visible
        function open() { visible = true; }
        function reject() { visible = false; }
        visible: false
        title: "Open Link?"
        message: uri
        onAccepted: {
            visible = false;
            appWindow.openUrl(uri);
        }
        onRejected: visible = false
    }

    // A word or two that goes by itself.
    Label {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: commandBar.top
        anchors.bottomMargin: Units.gu(2)
        padding: Units.gu(1)
        leftPadding: Units.gu(2)
        rightPadding: Units.gu(2)
        visible: opacity > 0
        opacity: 0
        color: "#ffffff"
        font.pixelSize: FontUtils.sizeToPixels("medium")
        background: Rectangle {
            radius: height / 2
            color: "#d0202020"
        }
        function show(message) {
            text = message;
            opacity = 1;
            toastTimer.restart();
        }
        Behavior on opacity {
            NumberAnimation { duration: 250 }
        }
        Timer {
            id: toastTimer
            interval: 1800
            onTriggered: toast.opacity = 0
        }
    }
}
