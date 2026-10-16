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

import LunaNext.Common 0.1
import LuneOS.Components 1.0

/*
 * LuneOS.Components' Dialog - the legacy dialog box over a dimmed page -
 * kept clear of the keyboard: it covers the part of the window above it,
 * and its box is centred there, so a field and the buttons under it stay
 * in sight while typing. Opened and closed like a Popup (open(), close(),
 * opened), which the pages and the tests use.
 */
Dialog {
    id: dialog

    readonly property bool opened: visible

    // The keyboard's height as the input method gives it; where it says
    // nothing while showing, the lower 45% of the window is kept free.
    readonly property real keyboardHeight: !Qt.inputMethod.visible || !parent ? 0
                                         : Qt.inputMethod.keyboardRectangle.height > 0
                                           ? Qt.inputMethod.keyboardRectangle.height
                                           : parent.height * 0.45

    signal aboutToShow()

    function open() {
        aboutToShow();
        visible = true;
    }

    function close() {
        visible = false;
    }

    visible: false
    anchors.fill: undefined
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? Math.max(dialogHeight + Units.gu(2), parent.height - keyboardHeight) : 0

    // The rest of the page dimmed as well: the input method can say there is
    // a keyboard when none shows (one on Bluetooth, the TouchPad).
    Rectangle {
        parent: dialog
        y: dialog.height
        width: dialog.width
        height: dialog.keyboardHeight
        visible: dialog.keyboardHeight > 0
        color: "black"
        opacity: 0.4
    }
}
