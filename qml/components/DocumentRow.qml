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
import LuneOS.Components 1.0
import LuneOS.Forms 1.0

/*
 * A document in the library: its first page, its name, and where it is and
 * how big - or, among the recent ones, how far it was read.
 */
ItemDelegate {
    id: row

    property string path
    property string name
    property string details
    // 0 to 1, or less than 0 for no bar.
    property real progress: -1
    property int index: 0
    property int count: 0
    // False while the library is not on screen (a document opened from
    // another app is read over it): its pictures wait, and do not take the
    // CPU from the page being drawn.
    property bool showThumbnail: true
    property bool _thumbnailWanted: false
    onShowThumbnailChanged: if (showThumbnail) _thumbnailWanted = true
    Component.onCompleted: if (showThumbnail) _thumbnailWanted = true

    signal held()

    height: Units.gu(8)
    padding: 0

    onPressAndHold: row.held()

    contentItem: RowLayout {
        spacing: Units.gu(1.5)

        Item {
            Layout.leftMargin: Units.gu(1)
            Layout.preferredWidth: Units.gu(5)
            Layout.preferredHeight: Units.gu(6.5)

            // Until the first page is drawn, or when it cannot be (locked).
            ArtworkImage {
                anchors.centerIn: parent
                width: Units.gu(4.4)
                height: Units.gu(5.5)
                svg: Qt.resolvedUrl("../images/document.svg")
                visible: thumbnail.status !== Image.Ready
            }

            Rectangle {
                anchors.centerIn: parent
                width: thumbnail.paintedWidth + 2
                height: thumbnail.paintedHeight + 2
                visible: thumbnail.status === Image.Ready
                color: "transparent"
                border.color: "#8c8c8c"
            }

            Image {
                id: thumbnail
                objectName: "thumbnail"
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(Math.ceil(Units.gu(6.5) * 2), Math.ceil(Units.gu(6.5) * 2))
                source: row.path !== "" && row._thumbnailWanted ? "image://pdfthumb/" + encodeURIComponent(row.path) : ""
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.rightMargin: Units.gu(1.5)
            spacing: Units.gu(0.3)

            Label {
                Layout.fillWidth: true
                text: row.name
                elide: Text.ElideRight
                font.pixelSize: FontUtils.sizeToPixels("medium")
                color: Colors.text
            }

            Label {
                Layout.fillWidth: true
                text: row.details
                visible: text !== ""
                elide: Text.ElideMiddle
                font.pixelSize: FontUtils.sizeToPixels("small")
                color: Colors.secondaryText
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Units.gu(0.3)
                Layout.preferredHeight: Units.gu(0.5)
                visible: row.progress >= 0
                radius: height / 2
                color: Colors.ruleDark

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, row.progress))
                    height: parent.height
                    radius: parent.radius
                    color: "#4a8fd8"
                }
            }
        }
    }

    ListDelegateSeparator {
        anchors.fill: parent
        index: row.index
        count: row.count
    }
}
