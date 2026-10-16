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
import QtCore

import "js/Library.js" as Library

/*
 * Where the reader was in each document - page, zoom, turn - and so which
 * were read last ("Recent"). One JSON value in the app's settings file; see
 * Library.js for its shape.
 */
Settings {
    id: store

    location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)
              + "/org.webosports.app.pdf/preferences.ini"
    category: "reading"

    property string documents: "{}"

    // Bumped on every change, for the library's bindings.
    property int revision: 0

    function stateFor(path) {
        var entry = Library.parseStore(documents)[path];
        return entry ? entry : null;
    }

    function remember(path, state) {
        documents = JSON.stringify(Library.remember(Library.parseStore(documents), path, state));
        revision++;
    }

    function forget(path) {
        documents = JSON.stringify(Library.forget(Library.parseStore(documents), path));
        revision++;
    }

    function recent(exists) {
        return Library.recent(Library.parseStore(documents), exists);
    }
}
