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
    readonly property int chosen: document ? document.pageForLabel(field.text) : -1

    signal pageChosen(int page)

    function accept() {
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
    message: field.text.trim() !== "" && chosen < 0 ? "There is no page “" + field.text.trim() + "”." : ""
    dialogWidth: Units.gu(30)
    dialogHeight: Units.gu(31)

    onAboutToShow: {
        slider.value = currentPage + 1;
        field.text = document ? document.pageLabel(currentPage) : "";
        Qt.callLater(function() {
            if (field.children.length > 0) {
                field.children[0].forceActiveFocus();
                field.children[0].selectAll();
            }
        });
    }

    // DialogLineInput sits 2 units above the middle of its row: a row this
    // tall keeps it clear of the message.
    Row {
        height: Units.gu(5)
        DialogLineInput {
            id: field
            objectName: "pageField"
            onAccepted: dialog.accept()
            onTextChanged: if (dialog.chosen >= 0) slider.value = dialog.chosen + 1
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
            visible: dialog.pageCount > 1
            onMoved: field.text = dialog.document ? dialog.document.pageLabel(Math.round(value) - 1) : ""
        }
    }
    Row {
        DialogButton {
            objectName: "goToButton"
            text: "Go"
            color: "#171717"
            fontcolor: "white"
            buttonWidth: Units.gu(26)
            opacity: dialog.chosen >= 0 ? 1 : 0.5
            onClicked: dialog.accept()
        }
    }
    Row {
        DialogButton {
            text: "Cancel"
            color: "transparent"
            fontcolor: "#444444"
            buttonWidth: Units.gu(26)
            onClicked: dialog.reject()
        }
    }
}
