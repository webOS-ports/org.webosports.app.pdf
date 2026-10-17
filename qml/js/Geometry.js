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

.pragma library

/*
 * Pages turned and scaled. PdfDocument gives sizes in points and links,
 * matches and selections from 0 to 1 of the page as stored; the viewer shows
 * a page turned clockwise by 0, 90, 180 or 270 degrees.
 */

// How far a page is magnified, as a multiple of fitting its width: each
// page fits the width of the view by itself (a landscape page among
// portrait ones does not make them all small).
var maxZoom = 6;
var minZoom = 0.25;

function normalRotation(degrees) {
    var r = Math.round((degrees || 0) / 90) * 90 % 360;
    return r < 0 ? r + 360 : r;
}

// The page's size as shown: width and height swap when it is on its side.
function shownSize(size, rotation) {
    if (!size || !(size.width > 0) || !(size.height > 0))
        return { width: 0, height: 0 };
    var sideways = normalRotation(rotation) % 180 !== 0;
    return sideways ? { width: size.height, height: size.width } : { width: size.width, height: size.height };
}

// The multiple of fitting the width at which a page also fits whole in the
// height available: 1 when the width is what limits it.
function pageFitZoom(size, rotation, width, height) {
    var shown = shownSize(size, rotation);
    if (!(shown.width > 0) || !(width > 0) || !(height > 0))
        return 1;
    var heightAtFitWidth = width * shown.height / shown.width;
    return Math.min(1, height / heightAtFitWidth);
}

function clampZoom(zoom) {
    return Math.max(minZoom, Math.min(maxZoom, zoom));
}

// A rectangle from 0 to 1 of the page as stored, to the same on the page as
// shown, turned clockwise.
function mapRect(r, rotation) {
    switch (normalRotation(rotation)) {
    case 90:
        return { x: 1 - (r.y + r.height), y: r.x, width: r.height, height: r.width };
    case 180:
        return { x: 1 - (r.x + r.width), y: 1 - (r.y + r.height), width: r.width, height: r.height };
    case 270:
        return { x: r.y, y: 1 - (r.x + r.width), width: r.height, height: r.width };
    default:
        return { x: r.x, y: r.y, width: r.width, height: r.height };
    }
}

// A point from 0 to 1 of the page as shown, back to the page as stored.
function unmapPoint(x, y, rotation) {
    switch (normalRotation(rotation)) {
    case 90:
        return { x: y, y: 1 - x };
    case 180:
        return { x: 1 - x, y: 1 - y };
    case 270:
        return { x: 1 - y, y: x };
    default:
        return { x: x, y: y };
    }
}

// Two corners on the page as shown, to a rectangle on the page as stored.
function unmapRect(x1, y1, x2, y2, rotation) {
    var a = unmapPoint(x1, y1, rotation);
    var b = unmapPoint(x2, y2, rotation);
    var left = Math.max(0, Math.min(a.x, b.x));
    var top = Math.max(0, Math.min(a.y, b.y));
    var right = Math.min(1, Math.max(a.x, b.x));
    var bottom = Math.min(1, Math.max(a.y, b.y));
    return { x: left, y: top, width: Math.max(0, right - left), height: Math.max(0, bottom - top) };
}

// The link under a point (0-1 of the page as stored), or null. The smallest
// wins where links overlap (a footnote marker inside a linked paragraph).
function linkAt(links, x, y) {
    var best = null;
    for (var i = 0; i < links.length; ++i) {
        var l = links[i];
        if (x >= l.x && x <= l.x + l.width && y >= l.y && y <= l.y + l.height) {
            if (!best || l.width * l.height < best.width * best.height)
                best = l;
        }
    }
    return best;
}

// How wide to render a page shown width x height pixels (device pixels
// already counted), within a pixel budget; rounded up to 32 so small
// changes do not render again.
function renderWidth(width, height, budget) {
    if (!(width > 0) || !(height > 0))
        return 0;
    var w = width;
    if (width * height > budget)
        w = Math.sqrt(budget * width / height);
    return Math.max(32, Math.ceil(w / 32) * 32);
}

// The part of a page (x, y, width, height in its own pixels) that is inside
// the viewport, or null.
function visiblePart(itemX, itemY, itemWidth, itemHeight, viewX, viewY, viewWidth, viewHeight) {
    var left = Math.max(itemX, viewX);
    var top = Math.max(itemY, viewY);
    var right = Math.min(itemX + itemWidth, viewX + viewWidth);
    var bottom = Math.min(itemY + itemHeight, viewY + viewHeight);
    if (right <= left || bottom <= top)
        return null;
    return { x: left - itemX, y: top - itemY, width: right - left, height: bottom - top };
}
