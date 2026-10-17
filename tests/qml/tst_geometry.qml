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

import "../../qml/js/Geometry.js" as Geometry

/*
 * qml/js/Geometry.js: turning, fitting, links under a finger and how big to
 * draw.
 */
TestCase {
    name: "Geometry"

    function fuzzyRect(actual, expected, msg) {
        fuzzyCompare(actual.x, expected.x, 1e-9, msg + " x");
        fuzzyCompare(actual.y, expected.y, 1e-9, msg + " y");
        fuzzyCompare(actual.width, expected.width, 1e-9, msg + " width");
        fuzzyCompare(actual.height, expected.height, 1e-9, msg + " height");
    }

    function test_normalRotation() {
        compare(Geometry.normalRotation(0), 0);
        compare(Geometry.normalRotation(450), 90);
        compare(Geometry.normalRotation(-90), 270);
        compare(Geometry.normalRotation(-360), 0);
        compare(Geometry.normalRotation(undefined), 0);
    }

    function test_shownSize() {
        compare(Geometry.shownSize({ width: 595, height: 842 }, 0), { width: 595, height: 842 });
        compare(Geometry.shownSize({ width: 595, height: 842 }, 90), { width: 842, height: 595 });
        compare(Geometry.shownSize({ width: 595, height: 842 }, 180), { width: 595, height: 842 });
        compare(Geometry.shownSize({ width: 0, height: 842 }, 0), { width: 0, height: 0 });
    }

    function test_pageFitZoom() {
        // A4 in a 600 x 600 view: the height limits it.
        fuzzyCompare(Geometry.pageFitZoom({ width: 595, height: 842 }, 0, 600, 600), 595 / 842, 1e-9);
        // On its side the width does: 1.
        compare(Geometry.pageFitZoom({ width: 595, height: 842 }, 90, 600, 600), 1);
        compare(Geometry.pageFitZoom({ width: 0, height: 0 }, 0, 600, 600), 1);
    }

    function test_clampZoom() {
        compare(Geometry.clampZoom(100), Geometry.maxZoom);
        compare(Geometry.clampZoom(0), Geometry.minZoom);
        compare(Geometry.clampZoom(2), 2);
    }

    // Turning a rectangle and the point inside it agree, every way round.
    function test_mapAndUnmap_data() {
        return [{ tag: "0", r: 0 }, { tag: "90", r: 90 }, { tag: "180", r: 180 }, { tag: "270", r: 270 }];
    }

    function test_mapAndUnmap(data) {
        var rect = { x: 0.1, y: 0.2, width: 0.3, height: 0.05 };
        var shown = Geometry.mapRect(rect, data.r);
        var back = Geometry.unmapRect(shown.x, shown.y, shown.x + shown.width, shown.y + shown.height, data.r);
        fuzzyRect(back, rect, "round trip");
        var centre = Geometry.unmapPoint(shown.x + shown.width / 2, shown.y + shown.height / 2, data.r);
        fuzzyCompare(centre.x, 0.25, 1e-9, "centre x");
        fuzzyCompare(centre.y, 0.225, 1e-9, "centre y");
    }

    function test_mapRectClockwise() {
        // The top left corner goes to the top right when turned clockwise.
        fuzzyRect(Geometry.mapRect({ x: 0, y: 0, width: 0.1, height: 0.2 }, 90), { x: 0.8, y: 0, width: 0.2, height: 0.1 }, "90");
        fuzzyRect(Geometry.mapRect({ x: 0, y: 0, width: 0.1, height: 0.2 }, 270), { x: 0, y: 0.9, width: 0.2, height: 0.1 }, "270");
    }

    function test_unmapRectClamps() {
        fuzzyRect(Geometry.unmapRect(-0.5, 0.5, 1.5, 0.2, 0), { x: 0, y: 0.2, width: 1, height: 0.3 }, "clamped");
    }

    function test_linkAt() {
        var links = [{ x: 0.1, y: 0.1, width: 0.8, height: 0.2, page: 3 },
                     { x: 0.4, y: 0.15, width: 0.05, height: 0.05, uri: "https://x" }];
        compare(Geometry.linkAt(links, 0.2, 0.2).page, 3);
        compare(Geometry.linkAt(links, 0.42, 0.17).uri, "https://x", "the smaller wins");
        compare(Geometry.linkAt(links, 0.5, 0.5), null);
        compare(Geometry.linkAt([], 0.5, 0.5), null);
    }

    function test_renderWidth() {
        compare(Geometry.renderWidth(1000, 1414, 4e6), 1024, "rounded up to 32");
        var w = Geometry.renderWidth(4000, 5656, 4e6);
        verify(w < 4000, "over the budget, smaller");
        verify(w * w * 5656 / 4000 <= 4e6 * 1.1, "about the budget");
        compare(Geometry.renderWidth(0, 100, 4e6), 0);
        compare(Geometry.renderWidth(10, 10, 4e6), 32, "never below 32");
    }

    function test_visiblePart() {
        compare(Geometry.visiblePart(100, 100, 500, 700, 0, 0, 400, 300), { x: 0, y: 0, width: 300, height: 200 });
        compare(Geometry.visiblePart(100, 1000, 500, 700, 0, 0, 400, 300), null);
    }
}
