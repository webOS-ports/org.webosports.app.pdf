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
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1

import "../js/Geometry.js" as Geometry

/*
 * One page of the reader: blank paper with its number until it is drawn,
 * then the page at the size shown - or, zoomed in past the pixel budget,
 * the whole page a little soft with the part on screen drawn sharp over it
 * (detail). Search matches and the selection are drawn on top.
 *
 * Taps come out as points from 0 to 1 of the page as shown.
 */
Item {
    id: pageItem

    property int page: 0
    property string documentId
    property int pageRotation: 0
    property bool night: false
    property real devicePixelRatio: 1
    // The most pixels the whole page is drawn with (see Geometry.renderWidth).
    property real pixelBudget: 4000000
    // Matches on this page: x, y, width, height (as stored) and index.
    property var matches: []
    property int currentMatch: -1
    // The selection, from 0 to 1 of the page as shown; null for none.
    property var selection: null
    property string label
    // How far right of where the list put it the page is drawn, and so
    // where it is in the list's content.
    property real xShift: 0
    readonly property real shownX: x + xShift

    transform: Translate { x: pageItem.xShift }

    readonly property int renderWidth: Geometry.renderWidth(width * devicePixelRatio, height * devicePixelRatio,
                                                            pixelBudget)
    readonly property bool reduced: renderWidth < Math.floor(width * devicePixelRatio)
    readonly property bool drawn: base.status === Image.Ready || preview.status === Image.Ready
    // Drawn whole once: the quick preview is not wanted again.
    property bool everDrawn: false

    signal tapped(real x, real y)
    signal doubleTapped(real x, real y)
    signal held(real x, real y)

    function pageUrl(widthPx, crop) {
        return "image://pdfpage/" + documentId + "/" + page + "/" + widthPx + "/" + pageRotation + "/"
                + (night ? 1 : 0) + (crop ? "/" + crop : "");
    }

    // The part of the page on screen (its own coordinates): drawn sharp
    // when the whole page is not. Null drops the detail.
    function showDetail(part) {
        if (!part || !reduced || documentId === "") {
            detail.source = "";
            detail.part = null;
            return;
        }
        var full = Math.floor(width * devicePixelRatio);
        var k = full / width;
        var x = Math.floor(part.x * k);
        var y = Math.floor(part.y * k);
        var w = Math.ceil(part.width * k);
        var h = Math.ceil(part.height * k);
        detail.part = { x: x / k, y: y / k, width: w / k, height: h / k };
        detail.source = pageUrl(full, x + "," + y + "," + w + "," + h);
    }

    // A new size or turn: the detail no longer fits.
    onWidthChanged: showDetail(null)
    onPageRotationChanged: showDetail(null)
    onNightChanged: showDetail(null)

    Rectangle {
        anchors.fill: parent
        color: pageItem.night ? "#1b1b1b" : "#ffffff"
        border.color: "#40000000"
        border.width: pageItem.drawn ? 0 : 1
    }

    Label {
        anchors.centerIn: parent
        visible: !pageItem.drawn
        text: pageItem.label
        color: "#9a9a9a"
        font.pixelSize: Math.max(FontUtils.sizeToPixels("medium"), Math.min(pageItem.width, pageItem.height) / 8)
    }

    // A quarter as wide, and so drawn many times sooner on a slow device:
    // something to read while the page itself is drawn.
    Image {
        id: preview
        objectName: "pagePreview"
        anchors.fill: parent
        asynchronous: true
        cache: false
        smooth: true
        visible: base.status !== Image.Ready
        source: !pageItem.everDrawn && pageItem.documentId !== "" && pageItem.renderWidth > 128
                ? pageItem.pageUrl(Math.ceil(pageItem.renderWidth / 4 / 32) * 32) : ""
    }

    Image {
        id: base
        objectName: "pageImage"
        anchors.fill: parent
        asynchronous: true
        cache: false
        smooth: true
        // Scrolled past before it was drawn: the render is cancelled.
        source: pageItem.documentId !== "" && pageItem.renderWidth > 0 ? pageItem.pageUrl(pageItem.renderWidth) : ""
        // While a sharper one renders after a zoom, the old one stretched.
        retainWhileLoading: true
        onStatusChanged: if (status === Image.Ready) pageItem.everDrawn = true
    }

    Image {
        id: detail
        property var part: null
        x: part ? part.x : 0
        y: part ? part.y : 0
        width: part ? part.width : 0
        height: part ? part.height : 0
        visible: part !== null && status === Image.Ready
        asynchronous: true
        cache: false
        smooth: true
    }

    Repeater {
        model: pageItem.matches
        delegate: Rectangle {
            readonly property var r: Geometry.mapRect(modelData, pageItem.pageRotation)
            x: r.x * pageItem.width - 1
            y: r.y * pageItem.height - 1
            width: r.width * pageItem.width + 2
            height: r.height * pageItem.height + 2
            radius: 2
            color: modelData.index === pageItem.currentMatch ? "#80ff8c00" : "#60ffe600"
            border.color: modelData.index === pageItem.currentMatch ? "#e06000" : "transparent"
        }
    }

    Rectangle {
        objectName: "selectionRect"
        visible: pageItem.selection !== null
        x: visible ? pageItem.selection.x * pageItem.width : 0
        y: visible ? pageItem.selection.y * pageItem.height : 0
        width: visible ? pageItem.selection.width * pageItem.width : 0
        height: visible ? pageItem.selection.height * pageItem.height : 0
        // The selection's yellow, as LuneOS's fields and web apps have it
        // (#FFEA58), let through enough to read the words under it.
        color: "#8cffea58"
    }

    TapHandler {
        id: taps
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onSingleTapped: function(point) {
            pageItem.tapped(point.position.x / pageItem.width, point.position.y / pageItem.height);
        }
        onDoubleTapped: function(point) {
            pageItem.doubleTapped(point.position.x / pageItem.width, point.position.y / pageItem.height);
        }
        onLongPressed: pageItem.held(taps.point.position.x / pageItem.width,
                                     taps.point.position.y / pageItem.height)
    }
}
