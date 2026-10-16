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
 * Find in the document, under the header: the words, which match of how
 * many, and the keys to the one before and after. Enter searches, and the
 * next Enter goes to the next match.
 */
Pane {
    id: bar

    property DocumentSearch search
    property int current: -1
    property alias text: field.text

    signal searchRequested(string text)
    signal previousClicked()
    signal nextClicked()
    signal closeClicked()

    function focusField() {
        field.forceActiveFocus();
        field.selectAll();
    }

    padding: Units.gu(0.75)
    background: Rectangle {
        color: "#e9e9e9"
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Colors.ruleDark
        }
    }

    readonly property string status: {
        if (!search || search.text === "")
            return "";
        if (search.count === 0)
            return search.running ? "Searching…" : "Not found";
        var n = (current >= 0 ? current + 1 : 0) + " of " + search.count;
        return search.running ? n + "…" : n;
    }

    contentItem: RowLayout {
        spacing: Units.gu(0.5)

        TextField {
            id: field
            objectName: "findField"
            Layout.fillWidth: true
            placeholderText: "Find in document"
            inputMethodHints: Qt.ImhNoPredictiveText
            onAccepted: {
                if (bar.search && bar.search.text === text.trim() && bar.search.count > 0)
                    bar.nextClicked();
                else
                    bar.searchRequested(text);
            }
        }

        Label {
            objectName: "findStatus"
            text: bar.status
            visible: text !== ""
            color: bar.search && bar.search.count === 0 && !bar.search.running ? Colors.error : Colors.secondaryText
            font.pixelSize: FontUtils.sizeToPixels("small")
        }

        IconButton {
            objectName: "findPrevious"
            image: "previous-dark"
            plain: true
            enabled: bar.search && bar.search.count > 0
            onClicked: bar.previousClicked()
        }

        IconButton {
            objectName: "findNext"
            image: "next-dark"
            plain: true
            enabled: bar.search && bar.search.count > 0
            onClicked: bar.nextClicked()
        }

        IconButton {
            objectName: "findClose"
            image: "close-dark"
            plain: true
            onClicked: bar.closeClicked()
        }
    }
}
