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
import LuneOS.Components 1.0

import PdfViewerApp 1.0

/*
 * Go to Page, in the platform's dialog: a page typed - its number, or its
 * label where the document prints its own ("xii") - or chosen with the
 * slider through the whole document.
 */
KeyboardClearDialog {
    id: dialog

    property PdfDocument document
    property int currentPage: 0
    readonly property int pageCount: document ? document.pageCount : 0
    // What is typed, an uncommitted T9 letter included.
    property string typed: ""
    readonly property int chosen: document ? document.pageForLabel(typed) : -1

    signal pageChosen(int page)

    function accept() {
        typed = typedText(field);
        if (chosen < 0)
            return;
        close();
        pageChosen(chosen);
    }

    function reject() {
        close();
    }

    title: "Go to Page (1 – " + pageCount + ")"
    // Only to say what is wrong: the line to type in sits just under it.
    message: typed.trim() !== "" && chosen < 0 ? "There is no page “" + typed.trim() + "”." : ""
    dialogWidth: Units.gu(30)
    fullHeight: Units.gu(31)
    // Without the slider (the number is typed), the keys side by side.
    compactHeight: Units.gu(20.5)
    readonly property real keyWidth: compact ? Units.gu(12.75) : Units.gu(26)

    onAboutToShow: {
        slider.value = currentPage + 1;
        field.text = document ? document.pageLabel(currentPage) : "";
        padField(field);
        var input = inputOf(field);
        if (input) {
            // Numbers, even where the document has labels of its own ("xii"):
            // on a phone keypad T9 would make letters of the digits, and a
            // page's number always finds it. The slider shows the labels.
            input.inputMethodHints = Qt.ImhDigitsOnly;
            Qt.callLater(function() {
                input.forceActiveFocus();
                input.selectAll();
            });
        }
    }

    // DialogLineInput sits 2 units above the middle of its row: a row this
    // tall keeps it clear of the message.
    Row {
        height: Units.gu(5)
        DialogLineInput {
            id: field
            objectName: "pageField"
            onAccepted: dialog.accept()
            onTextChanged: {
                dialog.typed = text;
                if (dialog.chosen >= 0)
                    slider.value = dialog.chosen + 1;
            }
        }
    }
    Row {
        Slider {
            id: slider
            objectName: "pageSlider"
            width: Units.gu(26)
            from: 1
            to: Math.max(1, dialog.pageCount)
            stepSize: 1
            snapMode: Slider.SnapAlways
            visible: dialog.pageCount > 1 && !dialog.compact
            onMoved: field.text = dialog.document ? dialog.document.pageLabel(Math.round(value) - 1) : ""
        }
    }
    // As the password dialog's: side by side where the keyboard leaves too
    // little room, Cancel on the left.
    Grid {
        columns: dialog.compact ? 2 : 1
        layoutDirection: dialog.compact ? Qt.RightToLeft : Qt.LeftToRight
        spacing: Units.gu(0.5)
        DialogButton {
            objectName: "goToButton"
            text: "Go"
            // The green of an accepting key (LuneOSButton.affirmativeColor).
            color: "#2aa100"
            fontcolor: "white"
            buttonWidth: dialog.keyWidth
            opacity: dialog.chosen >= 0 ? 1 : 0.5
            onClicked: dialog.accept()
        }
        DialogButton {
            objectName: "goToCancelButton"
            text: "Cancel"
            color: "transparent"
            fontcolor: "#444444"
            buttonWidth: dialog.keyWidth
            onClicked: dialog.reject()
        }
    }
}
