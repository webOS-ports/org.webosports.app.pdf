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

import "components"
import "js/Library.js" as Library

/*
 * The documents on the device: the few read last, with how far, then all
 * of them - by name, date or size - narrowed by the search field.
 */
Page {
    id: page
    objectName: "libraryPage"

    readonly property var files: appWindow.scanner.files
    readonly property bool searching: searchField.text.trim() !== ""

    // What the list shows: section, path, name, details, progress.
    readonly property var rows: {
        // Read for the binding: a document opened or forgotten.
        var revision = appWindow.reading.revision;
        var result = [];
        var known = {};
        for (var i = 0; i < files.length; ++i)
            known[files[i].path] = files[i];

        if (!searching) {
            var recent = appWindow.reading.recent(function(path) {
                return known[path] !== undefined || page.fileExists(path);
            });
            for (var r = 0; r < recent.length; ++r) {
                var entry = recent[r];
                result.push({
                    section: "Recent",
                    path: entry.path,
                    name: Library.displayName(entry.path),
                    details: Library.progressText(entry),
                    progress: entry.pageCount > 0 ? (entry.page + 1) / entry.pageCount : -1
                });
            }
        }

        var shown = Library.sorted(Library.filter(files, searchField.text), appWindow.prefs.sortOrder);
        var section = searching ? "Matches" : "All Documents";
        for (var j = 0; j < shown.length; ++j) {
            var f = shown[j];
            result.push({
                section: section,
                path: f.path,
                name: f.name,
                details: [f.folder, Library.formatSize(f.size), Library.formatDate(f.modified, Date.now())]
                         .filter(function(s) { return s !== ""; }).join(" · "),
                progress: -1
            });
        }
        return result;
    }

    // A recent document outside the scanned folders (opened from Email) is
    // still listed while it exists.
    function fileExists(path) {
        return appWindow.scanner.fileInfo(path).path !== undefined;
    }

    // Sections need a model with roles; the rows are copied in.
    ListModel {
        id: rowModel
    }

    function syncRows() {
        rowModel.clear();
        for (var i = 0; i < rows.length; ++i)
            rowModel.append(rows[i]);
    }

    onRowsChanged: syncRows()

    function appMenuItems() {
        return [
            { text: "Sort by Name", checked: appWindow.prefs.sortOrder === "name",
              action: function() { appWindow.prefs.sortOrder = "name"; } },
            { text: "Sort by Date", checked: appWindow.prefs.sortOrder === "date",
              action: function() { appWindow.prefs.sortOrder = "date"; } },
            { text: "Sort by Size", checked: appWindow.prefs.sortOrder === "size",
              action: function() { appWindow.prefs.sortOrder = "size"; } },
            { text: "Refresh", action: function() { appWindow.scanner.rescan(); } }
        ];
    }

    function handleBack() {
        if (searchField.text !== "") {
            searchField.text = "";
            return true;
        }
        return false;
    }

    Component.onCompleted: {
        syncRows();
        appWindow.scanner.rescan();
    }

    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: Colors.pageGradientTop }
            GradientStop { position: 1.0; color: Colors.pageGradientBottom }
        }
    }

    AppHeader {
        id: header
        objectName: "libraryHeader"

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: appWindow.headerHeight

        title: "PDF Viewer"
        icon: appWindow.appIcon
        compact: appWindow.compact
        actionComponent: IconButton {
            objectName: "libraryMenuButton"
            image: "more-dark"
            plain: true
            onClicked: appWindow.openAppMenu()
        }
    }

    ColumnLayout {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 0

        StatusNotice {
            objectName: "libraryNotice"
            Layout.fillWidth: true
            Layout.margins: Units.gu(1)
            Layout.bottomMargin: 0
            visible: text !== ""
            text: appWindow.notice
            onDismissed: appWindow.notice = ""
        }

        GroupBox {
            objectName: "documentsGroup"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Units.gu(1)
            title: "Documents"

            ColumnLayout {
                anchors.fill: parent
                spacing: Units.gu(0.5)

                TextField {
                    id: searchField
                    objectName: "searchField"
                    Layout.fillWidth: true
                    visible: page.files.length >= 6 || text !== ""
                    placeholderText: "Search"
                    inputMethodHints: Qt.ImhNoPredictiveText
                }

                ListView {
                    id: list
                    objectName: "documentList"

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: rowModel

                    section.property: "section"
                    section.criteria: ViewSection.FullString
                    section.delegate: Item {
                        width: list.width
                        height: sectionLabel.implicitHeight + Units.gu(1.5)
                        Label {
                            id: sectionLabel
                            x: Units.gu(1)
                            y: Units.gu(1)
                            text: section
                            font.pixelSize: FontUtils.sizeToPixels("small")
                            font.bold: true
                            color: Colors.secondaryText
                        }
                    }

                    delegate: DocumentRow {
                        width: list.width
                        path: model.path
                        name: model.name
                        details: model.details
                        progress: model.progress
                        index: model.index
                        count: list.count
                        showThumbnail: page.StackView.status === StackView.Active

                        onClicked: appWindow.openDocument(model.path)
                        onHeld: {
                            documentMenu.row = { path: model.path, section: model.section };
                            documentMenu.popup();
                        }
                    }

                    Column {
                        parent: list
                        anchors.centerIn: list
                        width: list.width - Units.gu(4)
                        spacing: Units.gu(1)
                        visible: list.count === 0

                        BusyIndicator {
                            anchors.horizontalCenter: parent.horizontalCenter
                            running: appWindow.scanner.running
                            visible: running
                        }

                        Label {
                            objectName: "emptyLabel"
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            visible: !appWindow.scanner.running || page.searching
                            text: page.searching ? "No document matches “" + searchField.text.trim() + "”."
                                                 : "No PDF documents on this device yet.\n\nCopy them over USB, "
                                                   + "or open one from Email or the browser."
                            color: Colors.secondaryText
                            font.pixelSize: FontUtils.sizeToPixels("medium")
                        }
                    }

                    ScrollIndicator.vertical: ScrollIndicator { }
                }
            }
        }
    }

    Menu {
        id: documentMenu
        objectName: "documentMenu"

        property var row: null

        MenuItem {
            text: "Open"
            onTriggered: appWindow.openDocument(documentMenu.row.path)
        }
        MenuItem {
            text: "Send by Email"
            onTriggered: appWindow.sendByEmail(documentMenu.row.path)
        }
        MenuItem {
            text: "Remove from Recent"
            enabled: documentMenu.row !== null && documentMenu.row.section === "Recent"
            height: enabled ? implicitHeight : 0
            onTriggered: appWindow.reading.forget(documentMenu.row.path)
        }
    }
}
