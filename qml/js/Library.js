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
 * The library's lists, and where the reader was in each document: plain
 * functions over plain objects, so the tests need no app around them.
 */

// How many documents "Recent" remembers, and shows.
var maxRemembered = 50;
var maxRecentShown = 5;

// A launch target as a path: file: URLs decoded; "" for anything that is not
// on this device (PdfDocument refuses those too).
function localPath(target) {
    var s = String(target || "").trim();
    if (s.indexOf("file://") === 0) {
        s = s.substring(7);
        try {
            s = decodeURIComponent(s);
        } catch (e) {
            return "";
        }
    }
    return s.charAt(0) === "/" ? s : "";
}

function fileName(path) {
    var s = String(path || "");
    var slash = s.lastIndexOf("/");
    return slash >= 0 ? s.substring(slash + 1) : s;
}

// "Manual.pdf" -> "Manual"; what the library shows.
function displayName(path) {
    var name = fileName(path);
    return name.replace(/\.pdf$/i, "");
}

function formatSize(bytes) {
    var b = Number(bytes) || 0;
    if (b < 1024)
        return b + " B";
    var units = ["KB", "MB", "GB"];
    var value = b;
    var unit = -1;
    do {
        value /= 1024;
        ++unit;
    } while (value >= 1024 && unit < units.length - 1);
    return (value >= 10 || unit === 0 ? Math.round(value) : Math.round(value * 10) / 10) + " " + units[unit];
}

// Today's documents by time, this year's by day and month, older by date.
function formatDate(ms, nowMs, use24h) {
    if (!ms)
        return "";
    var d = new Date(ms);
    var now = new Date(nowMs || Date.now());
    if (d.toDateString() === now.toDateString()) {
        var h = d.getHours();
        var m = (d.getMinutes() < 10 ? "0" : "") + d.getMinutes();
        if (use24h === false)
            return ((h + 11) % 12 + 1) + ":" + m + (h < 12 ? " AM" : " PM");
        return h + ":" + m;
    }
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    var day = months[d.getMonth()] + " " + d.getDate();
    return d.getFullYear() === now.getFullYear() ? day : day + ", " + d.getFullYear();
}

// The files whose name or folder holds every word of the query.
function filter(files, query) {
    var words = String(query || "").toLowerCase().split(/\s+/).filter(function(w) { return w !== ""; });
    if (words.length === 0)
        return files.slice();
    return files.filter(function(f) {
        var hay = (String(f.name || "") + " " + String(f.folder || "")).toLowerCase();
        return words.every(function(w) { return hay.indexOf(w) >= 0; });
    });
}

// "name" A to Z, numbers by value ("Part 2" before "Part 10"), "date"
// newest first, "size" largest first.
function sorted(files, order) {
    var copy = files.slice();
    if (order === "date")
        copy.sort(function(a, b) { return (b.modified || 0) - (a.modified || 0); });
    else if (order === "size")
        copy.sort(function(a, b) { return (b.size || 0) - (a.size || 0); });
    else
        copy.sort(function(a, b) { return naturalCompare(a.name, b.name); });
    return copy;
}

// Names as a reader orders them: case aside, and runs of digits by value.
// (QML's localeCompare() takes no options: there is no Intl.)
function naturalCompare(a, b) {
    var x = String(a || "").toLowerCase().match(/\d+|\D+/g) || [];
    var y = String(b || "").toLowerCase().match(/\d+|\D+/g) || [];
    for (var i = 0; i < Math.min(x.length, y.length); ++i) {
        if (x[i] === y[i])
            continue;
        var nx = /^\d/.test(x[i]);
        var ny = /^\d/.test(y[i]);
        if (nx && ny && Number(x[i]) !== Number(y[i]))
            return Number(x[i]) - Number(y[i]);
        return x[i].localeCompare(y[i]);
    }
    return x.length - y.length;
}

// The store is { "<path>": { page, offset, zoomMode, zoom, rotation,
// pageCount, opened } }; opened (ms) orders "Recent".
function parseStore(json) {
    try {
        var s = JSON.parse(json || "{}");
        return s && typeof s === "object" && !Array.isArray(s) ? s : {};
    } catch (e) {
        return {};
    }
}

// Remembers where the reader is in a document, as the most recent one, and
// forgets the oldest past maxRemembered.
function remember(store, path, state, nowMs) {
    var next = {};
    for (var k in store)
        next[k] = store[k];
    var entry = {};
    var old = next[path] || {};
    for (var o in old)
        entry[o] = old[o];
    for (var s in state)
        entry[s] = state[s];
    entry.opened = nowMs || Date.now();
    next[path] = entry;

    var paths = Object.keys(next);
    if (paths.length > maxRemembered) {
        paths.sort(function(a, b) { return (next[b].opened || 0) - (next[a].opened || 0); });
        for (var i = maxRemembered; i < paths.length; ++i)
            delete next[paths[i]];
    }
    return next;
}

function forget(store, path) {
    var next = {};
    for (var k in store) {
        if (k !== path)
            next[k] = store[k];
    }
    return next;
}

// The most recently opened documents that still exist: exists(path) says.
function recent(store, exists, count) {
    var paths = Object.keys(store).filter(function(p) { return exists(p); });
    paths.sort(function(a, b) { return (store[b].opened || 0) - (store[a].opened || 0); });
    return paths.slice(0, count === undefined ? maxRecentShown : count).map(function(p) {
        var e = store[p];
        return { path: p, page: e.page || 0, pageCount: e.pageCount || 0, opened: e.opened || 0 };
    });
}

// "Page 12 of 340", or "" before the document was read.
function progressText(entry) {
    if (!entry || !(entry.pageCount > 0))
        return "";
    return "Page " + (Math.min(entry.page, entry.pageCount - 1) + 1) + " of " + entry.pageCount;
}
