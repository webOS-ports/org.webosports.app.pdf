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
import LuneOS.Components 1.0

/*
 * The app's preferences. Every property here is saved; where the reader is
 * in each document lives in ReadingStore.
 */
Settings {
    // In the app's own file, as every QML app has (LuneOS.Components' AppFiles).
    location: AppFiles.preferencesFile("org.webosports.app.pdf")
    category: "viewer"

    // Light text on a dark page, for reading in the dark.
    property bool nightMode: false
    // The library's order: "name", "date" or "size".
    property string sortOrder: "name"
    // How a document opens the first time: "width" or "page".
    property string defaultFit: "width"
}
