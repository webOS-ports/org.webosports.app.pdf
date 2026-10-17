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

    // For the tests, which have no keyboard: the height of one to lay out
    // for, when not negative.
    property real keyboardHeightForTest: -1

    // The keyboard's height as the input method gives it; where it says
    // nothing while showing, the lower 45% of the window is kept free.
    readonly property real keyboardHeight: keyboardHeightForTest >= 0 ? keyboardHeightForTest
                                         : !Qt.inputMethod.visible || !parent ? 0
                                         : Qt.inputMethod.keyboardRectangle.height > 0
                                           ? Qt.inputMethod.keyboardRectangle.height
                                           : parent.height * 0.45

    // The box's height, and a shorter one for when the keyboard leaves less
    // room than that: on a square screen (the Q25) it takes nearly half.
    property real fullHeight: Units.gu(20)
    property real compactHeight: fullHeight
    readonly property bool compact: !!parent && parent.height - keyboardHeight < fullHeight
    dialogHeight: compact ? compactHeight : fullHeight

    signal aboutToShow()

    function open() {
        aboutToShow();
        visible = true;
    }

    // Closed, the keyboard goes too: the field it was typing in is hidden
    // but would keep the focus, and the keyboard with it.
    signal closed()

    function close() {
        visible = false;
        Qt.inputMethod.hide();
        closed();
    }

    // What a DialogLineInput holds, with what the keyboard has not committed
    // yet put in at the cursor: in T9 the last letter waits there, and a tap
    // on the dialog's key would otherwise leave it out ("secre" for
    // "secret").
    function typedText(lineInput) {
        var input = lineInput && lineInput.children.length > 0 ? lineInput.children[0] : null;
        if (!input || input.preeditText === undefined)
            return lineInput ? lineInput.text : "";
        var text = input.text;
        var at = Math.max(0, Math.min(text.length, input.cursorPosition));
        return text.substring(0, at) + input.preeditText + text.substring(at);
    }

    // The line's own TextInput, for what DialogLineInput does not pass on.
    function inputOf(lineInput) {
        return lineInput && lineInput.children.length > 0 ? lineInput.children[0] : null;
    }

    // The frame's title and message, which Dialog does not name. The title
    // is the one in bold.
    function frameText(item, bold) {
        for (var i = 0; i < item.children.length; ++i) {
            var child = item.children[i];
            if (child.wrapMode !== undefined && child.font !== undefined
                    && child.textFormat !== undefined && (child.font.weight === Font.Bold) === bold)
                return child;
            var found = frameText(child, bold);
            if (found)
                return found;
        }
        return null;
    }

    // Set out as a heading over its message: Dialog prints its title at a
    // fixed 16 pixels, smaller than the 12pt message under it, and the
    // message flush left under a centred title and centred keys.
    Component.onCompleted: {
        var heading = frameText(dialog, true);
        if (heading)
            heading.font.pixelSize = FontUtils.sizeToPixels("18pt");
        var body = frameText(dialog, false);
        if (body)
            body.horizontalAlignment = Text.AlignHCenter;
    }

    // Room between the field's edge and what is typed in it.
    function padField(lineInput) {
        var input = inputOf(lineInput);
        if (input) {
            input.leftPadding = Units.gu(1);
            input.rightPadding = Units.gu(1);
        }
    }

    visible: false
    anchors.fill: undefined
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? Math.max(dialogHeight, parent.height - keyboardHeight) : 0

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
