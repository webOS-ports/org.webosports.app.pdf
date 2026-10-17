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

/*
 * The reader's command menu along the bottom: the legacy dark toolbar with
 * five keys at most - contents, the page before, which page (tap to go to
 * another), the page after, and fitting width or page.
 */
ToolBar {
    id: bar

    property string pageText
    property bool canGoBack: false
    property bool canGoForward: false
    // "width" when the next tap fits the whole page, as its picture shows.
    property string fitMode: "width"

    signal contentsClicked()
    signal previousClicked()
    signal pageClicked()
    signal nextClicked()
    signal fitClicked()

    height: Math.max(Units.gu(6.5), 58)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Units.gu(0.5)
        anchors.rightMargin: Units.gu(0.5)
        spacing: Units.gu(0.5)

        IconButton {
            objectName: "contentsButton"
            image: "contents"
            onClicked: bar.contentsClicked()
        }

        Item { Layout.fillWidth: true }

        IconButton {
            objectName: "previousButton"
            image: "previous"
            enabled: bar.canGoBack
            autoRepeat: true
            onClicked: bar.previousClicked()
        }

        ToolButton {
            objectName: "pageButton"
            Layout.minimumWidth: Units.gu(12)
            Layout.preferredHeight: Math.max(Units.gu(5), 54)
            text: bar.pageText
            font.pixelSize: FontUtils.sizeToPixels("medium")
            onClicked: bar.pageClicked()
        }

        IconButton {
            objectName: "nextButton"
            image: "next"
            enabled: bar.canGoForward
            autoRepeat: true
            onClicked: bar.nextClicked()
        }

        Item { Layout.fillWidth: true }

        IconButton {
            objectName: "fitButton"
            image: bar.fitMode === "width" ? "fit-page" : "fit-width"
            onClicked: bar.fitClicked()
        }
    }
}
