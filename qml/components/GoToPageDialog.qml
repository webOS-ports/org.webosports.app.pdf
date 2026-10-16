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
import QtQuick.Layouts
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1
import LuneOS.Forms 1.0

import PdfViewerApp 1.0

/*
 * Go to Page: a slider through the whole document, or a page typed - its
 * number, or its label where the document prints its own ("xii").
 */
Dialog {
    id: dialog

    property PdfDocument document
    property int currentPage: 0
    readonly property int pageCount: document ? document.pageCount : 0
    readonly property int chosen: document ? document.pageForLabel(field.text) : -1

    signal pageChosen(int page)

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - Units.gu(4) : Units.gu(45), Units.gu(45))
    modal: true
    focus: true
    title: "Go to Page"
    standardButtons: Dialog.Ok | Dialog.Cancel

    onAboutToShow: {
        slider.value = currentPage + 1;
        field.text = document ? document.pageLabel(currentPage) : "";
        field.forceActiveFocus();
        field.selectAll();
    }

    onAccepted: if (chosen >= 0) pageChosen(chosen)

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        RowLayout {
            Layout.fillWidth: true
            spacing: Units.gu(1)

            TextField {
                id: field
                objectName: "pageField"
                Layout.fillWidth: true
                inputMethodHints: dialog.document && dialog.document.hasPageLabels ? Qt.ImhNoPredictiveText
                                                                                   : Qt.ImhDigitsOnly
                onTextEdited: {
                    if (dialog.chosen >= 0)
                        slider.value = dialog.chosen + 1;
                }
                onAccepted: if (dialog.chosen >= 0) dialog.accept()
            }

            Label {
                text: "of " + dialog.pageCount
                color: Colors.secondaryText
            }
        }

        Slider {
            id: slider
            objectName: "pageSlider"
            Layout.fillWidth: true
            from: 1
            to: Math.max(1, dialog.pageCount)
            stepSize: 1
            snapMode: Slider.SnapAlways
            visible: dialog.pageCount > 1
            onMoved: field.text = dialog.document ? dialog.document.pageLabel(Math.round(value) - 1) : ""
        }

        Label {
            Layout.fillWidth: true
            visible: field.text.trim() !== "" && dialog.chosen < 0
            text: "There is no page “" + field.text.trim() + "”."
            color: Colors.error
            font.pixelSize: FontUtils.sizeToPixels("small")
        }
    }
}
