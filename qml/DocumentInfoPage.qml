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

import "js/Library.js" as Library

/*
 * Document Info: what the document says about itself, and the file.
 */
Page {
    id: page
    objectName: "documentInfoPage"

    property PdfDocument document

    function dateText(d) {
        return d && !isNaN(d.getTime()) ? d.toLocaleString(Qt.locale(), Locale.ShortFormat) : "";
    }

    readonly property var rows: document ? [
        { label: "Title", value: document.title },
        { label: "Author", value: document.author },
        { label: "Subject", value: document.subject },
        { label: "Keywords", value: document.keywords },
        { label: "Pages", value: String(document.pageCount) },
        { label: "Created", value: dateText(document.creationDate) },
        { label: "Modified", value: dateText(document.modificationDate) },
        { label: "Made with", value: document.creator },
        { label: "PDF producer", value: document.producer },
        { label: "PDF version", value: document.pdfVersion },
        { label: "Protected", value: document.encrypted ? (document.canCopy ? "Yes" : "Yes, no copying") : "No" },
        { label: "File", value: document.fileName },
        { label: "Size", value: Library.formatSize(document.fileSize) },
        { label: "Folder", value: document.path.substring(0, document.path.lastIndexOf("/")) }
    ].filter(function(r) { return r.value !== ""; }) : []

    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: Colors.pageGradientTop }
            GradientStop { position: 1.0; color: Colors.pageGradientBottom }
        }
    }

    AppHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: appWindow.headerHeight
        title: "Document Info"
        icon: appWindow.appIcon
        compact: appWindow.compact
        showBack: true
        onBackClicked: appWindow.pageStack.pop()
    }

    Flickable {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: group.height + Units.gu(2)
        clip: true

        GroupBox {
            id: group
            x: Units.gu(1)
            y: Units.gu(1)
            width: parent.width - Units.gu(2)
            title: "About this document"

            ColumnLayout {
                width: parent.width
                spacing: 0

                Repeater {
                    model: page.rows
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Units.gu(0.6)
                        Layout.bottomMargin: Units.gu(0.6)
                        spacing: Units.gu(0.2)

                        Label {
                            text: modelData.label
                            color: Colors.secondaryText
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.value
                            wrapMode: Text.Wrap
                            color: Colors.text
                            font.pixelSize: FontUtils.sizeToPixels("medium")
                        }
                    }
                }
            }
        }
    }
}
