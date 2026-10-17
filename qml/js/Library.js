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
.import LuneOS.Components 1.0 as LC

/*
 * The library's lists, and where the reader was in each document: plain
 * functions over plain objects, so the tests need no app around them.
 * Paths, names, sizes and dates are LuneOS.Components' FileLists, as in
 * the other apps.
 */

// How many documents "Recent" remembers, and shows.
var maxRemembered = 50;
var maxRecentShown = 5;

// The files whose name or folder holds every word of the query, case and
// accents aside.
function filter(files, query) {
    return files.filter(function(f) {
        return LC.FileLists.matches(String(f.name || "") + " " + String(f.folder || ""), query);
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
        copy.sort(function(a, b) { return LC.FileLists.naturalCompare(a.name, b.name); });
    return copy;
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
