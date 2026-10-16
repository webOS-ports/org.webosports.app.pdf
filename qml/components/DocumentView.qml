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
import QtQuick.Window
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1

import PdfViewerApp 1.0

import "../js/Geometry.js" as Geometry

/*
 * The pages of a document one under the other, scrolled through as one.
 *
 * Fitted to the width (fitMode "width"), to the whole page ("page"), or at
 * a zoom of the reader's own ("custom": a pinch, a double tap). Zooming
 * keeps the point under the fingers where it was. Pages are drawn as they
 * come into view, and the one off screen after cancelled.
 *
 * A tap on a link follows it; any other tap is tapped(), for the bars.
 */
Item {
    id: root

    property PdfDocument document
    property DocumentSearch search
    property int rotation: 0
    property bool night: false
    property string fitMode: "width"
    property real customZoom: 1
    property int currentMatch: -1
    // Room kept free at the top and bottom of the document, for the bars.
    property real topInset: 0
    property real bottomInset: 0
    // More over the top of the view for now (the find bar), without moving
    // the pages: only where a match is shown takes it into account.
    property real overlayTop: 0
    // While selecting, the page does not scroll.
    property bool selecting: false
    property int selectionPage: -1
    property var selection: null

    readonly property real margin: Units.gu(1)
    readonly property int currentPage: list.currentPageIndex
    readonly property bool moving: list.moving || pinch.active
    readonly property alias flickable: list

    // Each page fits the width at zoom 1 (see Geometry.js).
    readonly property real fitWidth: Math.max(1, list.width - 2 * margin)
    readonly property real fitHeight: Math.max(1, list.height - topInset - bottomInset - 2 * margin)
    // The zoom of the page on screen.
    readonly property real zoom: zoomOf(Math.max(0, currentPage))

    signal tapped(real x, real y)
    signal linkActivated(var link, int fromPage)
    signal held(int page, real x, real y)

    function zoomOf(page) {
        if (fitMode === "width")
            return 1;
        if (fitMode === "page")
            return document && document.status === PdfDocument.Ready
                    ? Geometry.pageFitZoom(document.pageSize(page), rotation, fitWidth, fitHeight) : 1;
        return Geometry.clampZoom(customZoom);
    }

    function pageItem(page) {
        return list.itemAtIndex(page);
    }

    // Where a point of the view is: page, and 0-1 across and down it as shown.
    function anchorAt(vx, vy) {
        var cx = list.contentX + vx;
        var cy = list.contentY + vy;
        var index = list.indexAt(list.contentWidth / 2 + list.originX, cy);
        if (index < 0)
            index = Math.max(0, currentPage);
        var item = list.itemAtIndex(index);
        if (!item)
            return { page: index, fx: 0.5, fy: 0, vx: vx, vy: vy };
        return { page: index, fx: (cx - item.x) / item.width, fy: (cy - item.y) / item.height, vx: vx, vy: vy };
    }

    // Brings that point of that page back under (vx, vy).
    function restoreAnchor(a) {
        list.forceLayout();
        list.positionViewAtIndex(a.page, ListView.Beginning);
        var item = list.itemAtIndex(a.page);
        if (!item)
            return;
        list.contentX = clampX(item.x + a.fx * item.width - a.vx);
        list.contentY = clampY(item.y + a.fy * item.height - a.vy);
        rememberTop();
        updateDetail();
    }

    // What is at the top of the view, after each move: a resize lays the
    // pages out again, and that is where the reader stays.
    property var _top: null
    function rememberTop() {
        _top = anchorAt(list.width / 2, topInset + margin);
    }

    function clampX(x) {
        return Math.max(list.originX, Math.min(list.originX + list.contentWidth - list.width, x));
    }

    function clampY(y) {
        var low = list.originY - list.topMargin;
        var high = list.originY + list.contentHeight + list.bottomMargin - list.height;
        return Math.max(low, Math.min(Math.max(low, high), y));
    }

    // Zooms to a new scale, keeping the point (vx, vy) of the view in place.
    function zoomTo(newZoom, vx, vy) {
        var a = anchorAt(vx, vy);
        customZoom = Geometry.clampZoom(newZoom);
        fitMode = "custom";
        restoreAnchor(a);
    }

    function setFitMode(mode) {
        var a = anchorAt(list.width / 2, topInset + margin);
        fitMode = mode;
        a.fx = 0.5;
        a.vx = list.width / 2;
        restoreAnchor(a);
    }

    // To a page; top (0-1 of the page as stored) when a link names one.
    function goToPage(page, top) {
        if (!document || page < 0 || page >= document.pageCount)
            return;
        var fy = 0;
        if (top !== undefined && top >= 0 && rotation % 360 === 0)
            fy = top;
        else if (top !== undefined && top >= 0 && rotation === 180)
            fy = 1 - top;
        restoreAnchor({ page: page, fx: 0.5, fy: fy, vx: list.width / 2, vy: topInset + margin });
    }

    // Makes a match (page, x, y, width, height as stored) visible, a third
    // of the way down, unless it is in view already.
    function showMatch(match) {
        if (!match || match.page === undefined)
            return;
        var r = Geometry.mapRect(match, rotation);
        var item = list.itemAtIndex(match.page);
        if (item) {
            var left = item.x + r.x * item.width - list.contentX;
            var top = item.y + r.y * item.height - list.contentY;
            var right = left + r.width * item.width;
            var bottom = top + r.height * item.height;
            if (left >= 0 && right <= list.width && top >= topInset + overlayTop
                    && bottom <= list.height - bottomInset)
                return;
        }
        var clearTop = topInset + overlayTop;
        restoreAnchor({ page: match.page, fx: r.x + r.width / 2, fy: r.y + r.height / 2,
                        vx: list.width / 2, vy: clearTop + (list.height - clearTop - bottomInset) / 3 });
    }

    // Where the reader is, to come back to: page and how far down it.
    function position() {
        var a = anchorAt(list.width / 2, topInset + margin);
        return { page: a.page, offset: Math.max(0, Math.min(1, a.fy)) };
    }

    function restorePosition(page, offset) {
        restoreAnchor({ page: page, fx: 0.5, fy: offset || 0, vx: list.width / 2, vy: topInset + margin });
    }

    // Sharp detail for the pages on screen that are drawn reduced.
    function updateDetail() {
        detailTimer.restart();
    }

    Timer {
        id: singleTap
        property real x
        property real y
        interval: Qt.styleHints.mouseDoubleClickInterval
        onTriggered: root.tapped(x, y)
    }

    Timer {
        id: detailTimer
        interval: 120
        onTriggered: {
            var children = list.contentItem.children;
            for (var i = 0; i < children.length; ++i) {
                var item = children[i];
                if (item.objectName !== "pageDelegate" || !item.visible)
                    continue;
                if (list.moving || pinch.active) {
                    item.showDetail(null);
                    continue;
                }
                var part = Geometry.visiblePart(item.x, item.y, item.width, item.height,
                                                list.contentX, list.contentY, list.width, list.height);
                item.showDetail(part);
            }
        }
    }

    // A new fit (the window turned, the page was turned): the page that was
    // on screen stays.
    onFitWidthChanged: Qt.callLater(_refit)
    onFitHeightChanged: if (fitMode === "page") Qt.callLater(_refit)
    onRotationChanged: Qt.callLater(_refit)
    function _refit() {
        if (!document || document.status !== PdfDocument.Ready)
            return;
        var a = _top ? _top : { page: Math.max(0, currentPage), fx: 0.5, fy: 0 };
        restoreAnchor({ page: a.page, fx: a.fx, fy: a.fy, vx: list.width / 2, vy: topInset + margin });
    }

    ListView {
        id: list
        objectName: "pageList"

        property int currentPageIndex: 0

        anchors.fill: parent
        clip: true
        model: root.document && root.document.status === PdfDocument.Ready ? root.document.pageCount : 0
        spacing: root.margin
        topMargin: root.topInset + root.margin
        bottomMargin: root.bottomInset + root.margin
        contentWidth: Math.max(width, root.fitWidth * (root.fitMode === "custom" ? Geometry.clampZoom(root.customZoom) : 1)
                               + 2 * root.margin)
        flickableDirection: Flickable.HorizontalAndVerticalFlick
        boundsBehavior: Flickable.DragOverBounds
        interactive: !root.selecting && !pinch.active
        // A screen of pages beyond what shows is made, and drawn, ahead.
        cacheBuffer: Math.max(0, height)
        maximumFlickVelocity: Units.gu(600)
        reuseItems: false

        // The page that takes the middle of the view (or the one at the
        // top, between pages).
        function updateCurrentPage() {
            var i = indexAt(contentWidth / 2 + originX, contentY + topMargin + height / 3);
            if (i >= 0)
                currentPageIndex = i;
        }
        onContentYChanged: updateCurrentPage()
        onCountChanged: updateCurrentPage()
        onMovementEnded: {
            root.rememberTop();
            root.updateDetail();
        }
        onFlickEnded: root.updateDetail()
        onContentXChanged: if (!moving) root.updateDetail()

        delegate: PageDelegate {
            id: delegateItem
            objectName: "pageDelegate"

            readonly property var shown: Geometry.shownSize(root.document.pageSize(index), root.rotation)

            x: (list.contentWidth - width) / 2
            width: Math.round(root.fitWidth * root.zoomOf(index))
            height: shown.width > 0 ? Math.round(width * shown.height / shown.width) : width
            page: index
            label: root.document.pageLabel(index)
            documentId: root.document.documentId
            rotation: root.rotation
            night: root.night
            devicePixelRatio: Screen.devicePixelRatio
            matches: root.search && root.search.revision >= 0 && root.search.count > 0
                     ? root.search.matchesOn(index) : []
            currentMatch: root.currentMatch
            selection: root.selectionPage === index ? root.selection : null

            onTapped: function(x, y) {
                var stored = Geometry.unmapPoint(x, y, root.rotation);
                var link = Geometry.linkAt(root.document.links(index), stored.x, stored.y);
                if (link) {
                    root.linkActivated(link, index);
                } else {
                    // A tap waits to see whether a second makes it a double tap.
                    singleTap.x = x;
                    singleTap.y = y;
                    singleTap.restart();
                }
            }
            onDoubleTapped: function(x, y) {
                singleTap.stop();
                var vx = x * delegateItem.width + delegateItem.x - list.contentX;
                var vy = y * delegateItem.height + delegateItem.y - list.contentY;
                if (root.zoom < 2.4)
                    root.zoomTo(2.5, vx, vy);
                else
                    root.setFitMode("width");
            }
            onHeld: function(x, y) {
                root.held(index, x, y);
            }
        }

        ScrollBar.vertical: ScrollBar {
            objectName: "pageScrollBar"
            // Dragged, it pages through a long document at once.
            interactive: true
            policy: list.contentHeight > list.height * 3 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            topPadding: root.topInset
            bottomPadding: root.bottomInset
        }
    }

    // Pinching scales the view as it is, and lays it out again at the new
    // zoom when the fingers lift.
    PinchHandler {
        id: pinch
        target: null
        enabled: !root.selecting

        property var startAnchor: null
        property real startZoom: 1
        property point centre

        onActiveChanged: {
            if (active) {
                centre = root.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y);
                startAnchor = root.anchorAt(centre.x, centre.y);
                startZoom = root.zoom;
                preview.origin.x = centre.x;
                preview.origin.y = centre.y;
            } else {
                var factor = preview.xScale;
                preview.xScale = 1;
                preview.yScale = 1;
                root.customZoom = Geometry.clampZoom(startZoom * factor);
                root.fitMode = "custom";
                root.restoreAnchor(startAnchor);
            }
        }
        onActiveScaleChanged: {
            if (!active)
                return;
            var wanted = Geometry.clampZoom(startZoom * activeScale);
            preview.xScale = wanted / startZoom;
            preview.yScale = wanted / startZoom;
        }
    }

    // Ctrl and the wheel zoom too, on a desktop and with a keyboard.
    WheelHandler {
        acceptedModifiers: Qt.ControlModifier
        target: null
        onWheel: function(event) {
            var p = root.mapFromItem(null, point.scenePosition.x, point.scenePosition.y);
            root.zoomTo(root.zoom * (event.angleDelta.y > 0 ? 1.25 : 0.8), p.x, p.y);
        }
    }

    transform: Scale {
        id: preview
    }
}
