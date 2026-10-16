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
import QtQuick.Window
import QtQuick.Controls.LuneOS 2.0

import LunaNext.Common 0.1
import LuneOS.Components 1.0
import LuneOS.Forms 1.0

import PdfViewerApp 1.0

/*
 * The way round a document, sliding in from the left: its table of
 * contents, when it has one, and every page small.
 */
Drawer {
    id: drawer

    property PdfDocument document
    property int currentPage: 0
    property bool night: false

    signal pageChosen(int page, real top)

    width: Math.min(Units.gu(42), parent ? parent.width * 0.85 : Units.gu(42))
    height: parent ? parent.height : 0
    edge: Qt.LeftEdge

    readonly property bool hasOutline: document && document.outline.length > 0

    onOpened: {
        if (tabs.currentIndex === 1 || !hasOutline)
            pagesGrid.positionViewAtIndex(currentPage, GridView.Center);
    }

    background: Rectangle {
        color: Colors.pageBackground
        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: "#888888"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            id: tabs
            objectName: "contentsTabs"
            Layout.fillWidth: true
            currentIndex: drawer.hasOutline ? 0 : 1

            TabButton {
                text: "Contents"
                enabled: drawer.hasOutline
            }
            TabButton {
                text: "Pages"
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex

            ListView {
                id: outlineList
                objectName: "outlineList"
                clip: true
                model: drawer.document ? drawer.document.outline : []

                delegate: ItemDelegate {
                    width: outlineList.width
                    height: Units.gu(6)
                    enabled: modelData.page >= 0
                    leftPadding: Units.gu(1.5) + modelData.level * Units.gu(2)
                    rightPadding: Units.gu(1.5)

                    contentItem: RowLayout {
                        spacing: Units.gu(1)
                        Label {
                            Layout.fillWidth: true
                            text: modelData.title
                            elide: Text.ElideRight
                            font.bold: modelData.level === 0
                            font.pixelSize: FontUtils.sizeToPixels(modelData.level === 0 ? "medium" : "small")
                            color: Colors.text
                        }
                        Label {
                            text: modelData.page >= 0 ? drawer.document.pageLabel(modelData.page) : ""
                            color: Colors.secondaryText
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }
                    }

                    onClicked: drawer.pageChosen(modelData.page, modelData.top)

                    ListDelegateSeparator {
                        anchors.fill: parent
                        index: model.index
                        count: outlineList.count
                    }
                }

                ScrollIndicator.vertical: ScrollIndicator { }
            }

            GridView {
                id: pagesGrid
                objectName: "pagesGrid"
                clip: true
                model: drawer.document && drawer.document.status === PdfDocument.Ready ? drawer.document.pageCount : 0
                readonly property int columns: Math.max(2, Math.floor(width / Units.gu(13)))
                cellWidth: width / columns
                cellHeight: cellWidth * 1.45
                cacheBuffer: height

                delegate: Item {
                    width: pagesGrid.cellWidth
                    height: pagesGrid.cellHeight

                    readonly property size pageSize: drawer.document.pageSize(index)
                    readonly property real fit: Math.min((width - Units.gu(2)) / pageSize.width,
                                                         (height - Units.gu(4)) / pageSize.height)

                    Rectangle {
                        id: frame
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Units.gu(1)
                        width: Math.round(parent.pageSize.width * parent.fit) + 4
                        height: Math.round(parent.pageSize.height * parent.fit) + 4
                        color: drawer.night ? "#1b1b1b" : "#ffffff"
                        border.width: 2
                        border.color: index === drawer.currentPage ? "#4a8fd8" : "#a0a0a0"

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            asynchronous: true
                            source: "image://pdfpage/" + drawer.document.documentId + "/" + index + "/"
                                    + Math.ceil(width * Screen.devicePixelRatio / 32) * 32 + "/0/"
                                    + (drawer.night ? 1 : 0)
                        }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: frame.bottom
                        anchors.topMargin: Units.gu(0.3)
                        text: drawer.document.pageLabel(index)
                        font.pixelSize: FontUtils.sizeToPixels("small")
                        font.bold: index === drawer.currentPage
                        color: Colors.text
                    }

                    TapHandler {
                        onTapped: drawer.pageChosen(index, -1)
                    }
                }

                ScrollIndicator.vertical: ScrollIndicator { }
            }
        }
    }
}
